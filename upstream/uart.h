#ifndef __UART_H__
#define __UART_H__
// $Id: uart.h 1125 2024-11-14 07:05:44Z angelov $:

#include <stdint.h>
#include <termios.h> /* POSIX terminal control definitions */
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>

#define MAX2READ 1

//#ifdef _WIN32
//#define B4000000 0
//#endif


//int32_t sign_ext24(uint32_t adc);

speed_t int2speed_t(uint32_t br);


class uart
{
public:
    // quiet = 1 to suppress more messages
    uart(const char * device, uint32_t brate);
    ~uart();

    void Debug(bool enable);

    // send a break in case of lost synchronization, duration = 1.
    void SendBreak (int duration);
    // read a Byte, returns EOF in case of error or the Byte
    int ReadSingleByte ();
    int ClearReadBuff (int debug = 0);
    int ReadBuffer (uint8_t * PByte, uint32_t nbytes);

    inline int BytesSent() const
    {
        return bytes_sent;
    };
    inline int BytesReceived() const
    {
        return bytes_received;
    };

    // write a Byte, returns false in case of error, otherwise true
    bool WriteSingleByte (uint8_t AByte);
    bool WriteBuffer (uint8_t * PByte, uint32_t nbytes);

        void uart_flush();

    int checkDevice();

    void setLogFile(FILE* pLogFile);
    FILE* m_pLogFile;

    void setLogFlag()
    {
        log_flag = 1;
    };
    void clrLogFlag()
    {
        log_flag = 0;
    };

protected:
    bool debug;
private:
    int log_flag;
    int UART_fd;            // File descriptor for serial device
    int bytes_sent;         // a counter for the bytes sent (with payload)
    int bytes_received;     // a counter for the bytes received (with payload)
};

#endif /* __UART_H__ */
