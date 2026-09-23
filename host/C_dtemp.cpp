// $Id: C_dtemp.cpp 1222 2026-09-16 14:00:13Z  $:
//#include <unistd.h>  /* UNIX standard function definitions, usleep */
#include "../upstream/uart32.h"
#include "C_dtemp.h"

C_dtemp::C_dtemp(uart32* p_uart32, uint32_t new_base_addr)
{
    m_uart32 = p_uart32;
    base_addr = new_base_addr;
}

C_dtemp::~C_dtemp()
{
}

uint16_t C_dtemp::get_presence_mask()
{
    last_presence = m_uart32->ReadWord(OFFS_DTEMP_PRESENCE+base_addr);
    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, presence mask 0x%02x, design for %d expected sensors\n",
            last_presence & 0xFF, (last_presence >> BIT_DTEMP_PRES_NSENS) & 0xF );
    return last_presence;
}

int16_t C_dtemp::get_threshold()
{
    last_threshold = m_uart32->ReadWord(OFFS_DTEMP_THRESH+base_addr);
    if (last_threshold & 0x800) // negative
        last_threshold = -(last_threshold & 0x7FF);

    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, threshold 0x%03x or %0.1f C\n",
            last_threshold & 0xFFF, 1.0*last_threshold/DTEMP_STEPS_IN_GRAD);
    return last_threshold;
}

float C_dtemp::get_threshold_C()
{
    get_threshold();
    return 1.0*last_threshold/DTEMP_STEPS_IN_GRAD;
}

float C_dtemp::set_threshold(float new_thresh_C)
{
    int16_t i16;
    i16 = (int16_t) (new_thresh_C*16+0.5);
    set_threshold(i16);
    return 1.0*last_threshold/DTEMP_STEPS_IN_GRAD;
}

int16_t C_dtemp::set_threshold(int16_t new_thresh)
{
    if (new_thresh < 0) new_thresh = 0x800 | ((-new_thresh) & 0x7FF);
    else                new_thresh = new_thresh & 0x7FF;

    m_uart32->WriteWord(OFFS_DTEMP_THRESH+base_addr, new_thresh);
    get_threshold();
    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, set threshold 0x%03x or %0.1f C\n",
            last_threshold & 0xFFF, 1.0*last_threshold/DTEMP_STEPS_IN_GRAD);
    return last_threshold;
}

uint16_t C_dtemp::set_res_auto(uint8_t new_res)
{
    new_res    &= 3;
    last_res_auto = (new_res << BIT_DTEMP_CNF_RES) | (1 << BIT_DTEMP_CNF_AUTO);

    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, set resolution %d bits and auto read\n",
              9+new_res);

    m_uart32->WriteByte(OFFS_DTEMP_CONFIG+base_addr, last_res_auto);
    return last_res_auto;
}

uint16_t C_dtemp::set_res_trigg(uint8_t new_res)
{
    new_res    &= 3;
    last_res_auto = (new_res << BIT_DTEMP_CNF_RES) | (1 << BIT_DTEMP_CNF_START);

    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, set resolution %d bits and start a measurement\n",
              9+new_res);

    m_uart32->WriteByte(OFFS_DTEMP_CONFIG+base_addr, last_res_auto);
    return last_res_auto;
}

uint16_t C_dtemp::get_alarm_mask()
{
    last_alarm = m_uart32->ReadDWord(OFFS_DTEMP_ALARM+base_addr);
    if (DEBUG_DTEMP)
        logWrite("# Digital Temperatur Sensors, alarm mask: latched/current 0x%02x / 0x%02x\n",
            (last_alarm >> BIT_DTEMP_ALARM_LAT) & 0xFF, (last_alarm >> BIT_DTEMP_ALARM) & 0xFF );
    return last_alarm;
}

uint16_t C_dtemp::rep_temp()
{
    int16_t rd_temp[2];
    return get_temp(rd_temp, 2, 1);
}

uint16_t C_dtemp::get_temp(int16_t *rd_temp, uint8_t nsensors, int ldebug)
{
#if DEBUG_DTEMP==1
    int i;
#endif
    int err;
    uint16_t *u16_p;
    u16_p = (uint16_t*) rd_temp;

    err = m_uart32->RecvBurst(nsensors, 1, 1, OFFS_DTEMP_TEMP+base_addr, u16_p );

    for (i=0; i<nsensors; i++)
        if (u16_p[i] & 0x800) // sign bit, the code is NOT two's complement!
            rd_temp[i] = - (rd_temp[i] & 0x7FF);

    if ( (DEBUG_DTEMP) || (ldebug) )
        for (i=0; i<nsensors; i++)
        {
            switch(i)
            {
                case 0: logWrite("# Dig. temp. sensor on top of H-bridge returns "); break;
                case 1: logWrite("# Dig. temp. sensor on bottom of H-bridge returns "); break;
                case 2: logWrite("# Dig. temp. sensor 2 ?? returns "); break;
                case 3: logWrite("# Dig. temp. sensor 3 ?? returns "); break;
            }
            logWrite("0x%03x or %4.1f C\n",
                rd_temp[i], 1.0*rd_temp[i]/DTEMP_STEPS_IN_GRAD);
        }
    return err;
}
