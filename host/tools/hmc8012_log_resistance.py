#!/usr/bin/env python3
"""Log resistance readings from a Rohde & Schwarz HMC8012 multimeter to a CSV file.

Connects over USB (VISA/USBTMC via pyvisa-py), takes one resistance reading per
interval, and appends each reading to disk immediately (open in append mode +
flush + fsync) so that a crash never loses already-collected data.

Usage:
    python3 hmc8012_log_resistance.py [-o output.csv] [-i 1.0] [-r VISA_RESOURCE]

Press Enter to start logging, Ctrl+C to stop.
"""

import argparse
import csv
import datetime as dt
import os
import sys
import time
import warnings

import pyvisa

warnings.filterwarnings("ignore", category=UserWarning, module="pyvisa_py")


def find_instrument(rm):
    for resource in rm.list_resources():
        if resource.startswith("USB"):
            return resource
    return None


def open_instrument(resource=None):
    rm = pyvisa.ResourceManager("@py")
    if resource is None:
        resource = find_instrument(rm)
        if resource is None:
            available = rm.list_resources()
            raise RuntimeError(
                f"Could not auto-detect the HMC8012 over USB. "
                f"Available VISA resources: {available}. Pass --resource explicitly."
            )
    inst = rm.open_resource(resource)
    inst.timeout = 10000
    return inst


# IEC 60751 Callendar-Van Dusen coefficients (PT100/PT1000 platinum RTD curve)
CVD_A = 3.9083e-3
CVD_B = -5.7750e-7
CVD_C = -4.183e-12  # only used below 0 C


def resistance_to_celsius(r_ohms, r0=1000.0):
    """Convert a PT1000 resistance reading to temperature in Celsius."""
    if r_ohms >= r0:
        # T >= 0 C: R = R0*(1 + A*T + B*T^2), solve the quadratic for T
        discriminant = CVD_A ** 2 - 4 * CVD_B * (1 - r_ohms / r0)
        return (-CVD_A + discriminant ** 0.5) / (2 * CVD_B)
    else:
        # T < 0 C: R = R0*(1 + A*T + B*T^2 + C*(T-100)*T^3), solve via Newton's method
        t = (r_ohms / r0 - 1) / CVD_A
        for _ in range(10):
            f = r0 * (1 + CVD_A * t + CVD_B * t ** 2 + CVD_C * (t - 100) * t ** 3) - r_ohms
            fprime = r0 * (CVD_A + 2 * CVD_B * t + CVD_C * (3 * t ** 2 * (t - 100) + t ** 3))
            t -= f / fprime
        return t


def write_cmd(inst, cmd, delay=0.2):
    inst.write(cmd)
    time.sleep(delay)


def query_safe(inst, cmd, delay=0.3, retries=3):
    """Write cmd, wait, and read the response, retrying on transient USBTMC errors."""
    last_err = None
    for _ in range(retries):
        try:
            inst.write(cmd)
            time.sleep(delay)
            return inst.read_raw().decode("ascii").strip()
        except Exception as e:  # VisaIOError, UnicodeDecodeError, etc.
            last_err = e
            time.sleep(0.3)
    raise RuntimeError(f"Query {cmd!r} failed after {retries} attempts: {last_err}")


def main():
    parser = argparse.ArgumentParser(description="Log resistance readings from an HMC8012 DMM.")
    parser.add_argument(
        "-o", "--output", default=None,
        help="Output CSV path (default: resistance_log_<timestamp>.csv)",
    )
    parser.add_argument(
        "-i", "--interval", type=float, default=1.0,
        help="Target seconds between samples (default: 1.0)",
    )
    parser.add_argument(
        "-r", "--resource", default=None,
        help="VISA resource string (default: auto-detect the first USB instrument)",
    )
    parser.add_argument(
        "-y", "--yes", action="store_true",
        help="Skip the 'press Enter to start' prompt and start immediately",
    )
    parser.add_argument(
        "-t", "--threshold", type=float, default=60.0,
        help="Temperature in Celsius above which 'OVERHEAT' is written instead of "
             "the value (default: 100.0)",
    )
    parser.add_argument(
        "--r0", type=float, default=1000.0,
        help="PT1000 resistance in Ohms at 0 C, for the temperature conversion "
             "(default: 1000.0)",
    )
    args = parser.parse_args()

    output_path = args.output or f"resistance_log_{dt.datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    file_is_new = not os.path.exists(output_path) or os.path.getsize(output_path) == 0

    print("Connecting to HMC8012...")
    inst = open_instrument(args.resource)
    idn = query_safe(inst, "*IDN?", delay=0.2)
    print(f"Connected: {idn}")

    write_cmd(inst, "*CLS", delay=0.1)
    write_cmd(inst, "CONF:RES", delay=0.3)  # 2-wire resistance measurement

    print(f"Logging to: {os.path.abspath(output_path)}")
    print(f"Interval:   {args.interval} s")
    print(f"Threshold:  {args.threshold} C (writes 'OVERHEAT' above this)")

    if not args.yes:
        input("Press Enter to start logging (Ctrl+C to stop)... ")
    else:
        print("Starting logging (Ctrl+C to stop)...")

    sample_count = 0
    try:
        with open(output_path, "a", newline="") as f:
            writer = csv.writer(f)
            if file_is_new:
                writer.writerow(["timestamp_iso", "unix_time", "resistance_ohms", "temperature_c", "overheat"])
                f.flush()
                os.fsync(f.fileno())

            while True:
                loop_start = time.time()
                now = dt.datetime.now()

                try:
                    raw = query_safe(inst, "READ?", delay=0.8)
                    value = float(raw)
                    temp_c = resistance_to_celsius(value, r0=args.r0)
                except Exception as e:
                    writer.writerow([now.isoformat(timespec="milliseconds"), loop_start, "COMM_ERROR", "COMM_ERROR", ""])
                    f.flush()
                    os.fsync(f.fileno())
                    sample_count += 1
                    print(f"[{now.isoformat(timespec='seconds')}] #{sample_count}: COMM_ERROR ({e})", file=sys.stderr)
                else:
                    overheat = temp_c > args.threshold
                    writer.writerow([now.isoformat(timespec="milliseconds"), loop_start, value, temp_c, overheat])
                    f.flush()
                    os.fsync(f.fileno())
                    sample_count += 1
                    if overheat:
                        print(f"[{now.isoformat(timespec='seconds')}] #{sample_count}: "
                              f"OVERHEAT ({temp_c:.2f} C > {args.threshold} C, {value:.6g} Ohm)", file=sys.stderr)
                    else:
                        print(f"[{now.isoformat(timespec='seconds')}] #{sample_count}: {value:.6g} Ohm ({temp_c:.2f} C)")

                elapsed = time.time() - loop_start
                sleep_time = max(0.0, args.interval - elapsed)
                time.sleep(sleep_time)

    except KeyboardInterrupt:
        print(f"\nStopped. {sample_count} sample(s) saved to {os.path.abspath(output_path)}")
    finally:
        try:
            inst.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
