#include "uart.h"
#include <sys/ioctl.h>

#include <cstdio>    /* Standard input/output definitions, for perror() */
#include <unistd.h>  /* UNIX standard function definitions, for close() */
#include <fcntl.h>   /* File control definitions, for open() */

// https://blog.mbedded.ninja/programming/operating-systems/linux/linux-serial-ports-using-c-cpp/


speed_t int2speed_t(uint32_t br)
{
//    printf("Converting bit rate %d to speed_t type\n", br);
#ifndef _WIN32
    #ifndef __CYGWIN__
    if (br==4000000)
        return B4000000;
    #endif
#endif
    if (br==3000000)
        return B3000000;
    if (br==2500000)
        return B2500000;
    if (br==2000000)
        return B2000000;
    if (br==1500000)
        return B1500000;
    if (br==1152000)
        return B1152000;
    if (br==1000000)
        return B1000000;
    if (br== 921600)
        return  B921600;
    if (br== 576000)
        return  B576000;
    if (br== 500000)
        return  B500000;
    if (br== 460800)
        return  B460800;
    if (br== 230400)
        return  B230400;
    if (br== 115200)
        return  B115200;
    if (br==  57600)
        return   B57600;
    if (br==  38400)
        return   B38400;
    if (br==  19200)
        return   B19200;
    if (br==   9600)
        return    B9600;
    if (br==   4800)
        return    B4800;
    if (br==   2400)
        return    B2400;
    if (br==   1200)
        return    B1200;

    printf("unknown bitrate %d, using 2000000\n",br);

    return B2000000;
}

//bool uart::init (const char * device, speed_t brate, int quiet)
uart::uart(const char * device, uint32_t brate) : debug(false)
{
    struct termios options;

    m_pLogFile = stdout;
    log_flag = 0;

    bytes_sent = 0;
    bytes_received = 0;
    if(debug)
        printf("Opening the device %s\n", device);



//  if (UART_fd != 0)
//    return true;

    /* open the serial device */
    if ((UART_fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY)) < 0)
    {
        perror(device);
    }

    /* restore normal (blocking) behavior */
    fcntl(UART_fd, F_SETFL, 0);

    /* get the current options for the port... */
    tcgetattr(UART_fd, &options);

    /* see /usr/include/sys/termios.h */

    /*
            B1200
            B1800
            B2400
            B4800
            B9600
            B19200
            B38400
            B57600
            B115200
            B128000
            B230400
            B256000
            B460800
            B500000
            B576000
            B921600
            B1000000
            B1152000
            B1500000
            B2000000
            B2500000
            B3000000
    */
    speed_t br = int2speed_t(brate);
    /* set the baud rates - doesn't work with setispeed for Windows, setspeed works*/
    cfsetspeed(&options, br);
    // set separately for input and output, when necessary
    //  cfsetispeed(&options, brate);
    //  cfsetospeed(&options, brate);

    /* enable the receiver and set local mode... */
    options.c_cflag |= (CLOCAL | CREAD);

    /* set parity checking... */
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;

    /* set the character size... */
    options.c_cflag &= ~CSIZE; /* mask the character size bits */
    options.c_cflag |= CS8;    /* select 8 data bits */

    /* disable hardware flow control... */
    options.c_cflag &= ~CRTSCTS;

    /* disable software flow control... */
    options.c_iflag &= ~(IXON | IXOFF | IXANY);

    /* choose raw input... */
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_iflag &= ~(INLCR | ICRNL);

    /* choose raw output... */
    options.c_oflag &= ~OPOST;

    /* set timeout... */
    options.c_cc[VMIN] = 0;
    //options.c_cc[VTIME] = 25; /* tenths of seconds */
    options.c_cc[VTIME] = 1; /* tenths of seconds */

    /* set the new options for the port... */
    tcsetattr(UART_fd, TCSANOW, &options);

}


//void uart::Exit ()
uart::~uart()
{
    /* close serial device */
    if (UART_fd != 0)
    {
        if (close(UART_fd) < 0)
        {
            perror(NULL);
        }
        UART_fd = 0;
    }
}

void uart::Debug(bool enable)
{
    debug = enable;
}


void uart::SendBreak (int duration)
{
    tcsendbreak(UART_fd, duration);
}


bool uart::WriteSingleByte (uint8_t AByte)
{
    bytes_sent++;
    if(debug)
        printf("writebyte 0x%02x\n",AByte);

    if(log_flag)
    {
        fprintf(m_pLogFile, "%5d single write byte 0x%02x\n", bytes_sent, AByte);
        fflush(m_pLogFile);
    }

    if ( write(UART_fd, & AByte, 1 ) != 1 )
        return false;
    return true;
}

bool uart::WriteBuffer (uint8_t *PByte, uint32_t nbytes)
{
    int cnt;

    if(debug)
        for (uint16_t i=0; i<nbytes; i++)
            printf("writeburst 0x%02x\n",PByte[i]);

    if(log_flag)
    {
        cnt = bytes_sent;
        for (uint16_t i=0; i<nbytes; i++)
            fprintf(m_pLogFile, "%5d burst write byte 0x%02x\n", ++cnt, PByte[i]);
        fflush(m_pLogFile);
    }

    bytes_sent+= write(UART_fd, PByte, nbytes );
    return true;
}

void uart::uart_flush()
{
        usleep(30000); // 10 000 was not enough, 20 000 was ok, we make 30 000
//      int retval, bytes_available;
// TCIFLUSH - Flushes/Discards received data, but not read
// TCOFLUSH - Flushes/Discards written data, but not transmitted
// TCIOFLUSH - Flushes/Discards both
//      tcflush(UART_fd, TCOFLUSH);
// this checks the bytes avaialble as input!?!?
//      retval = ioctl(UART_fd, FIONREAD, &bytes_available);
//      printf("Bytes av. %d\n", bytes_available);
//      if (retval < 0) {
//              printf("FIONREAD ioctl failed\n");
//      }
}


int uart::ReadSingleByte ()
{
    uint8_t AByte;

    bytes_received++;
#ifdef EMULATION
    return EOF;
#else
    if ( read( UART_fd, &AByte, 1 ) != 1 )
    {
      //  printf("EOF when ReadByte!\n");
        return EOF;
    }

    if(log_flag)
    {
        fprintf(m_pLogFile, "%5d single read byte 0x%02x\n", bytes_received, AByte);
        fflush(m_pLogFile);
    }

    if(debug)
        printf("Rx data: %02X\n", AByte);

    return AByte;
#endif
}

int uart::ClearReadBuff (int debug)
{
    uint32_t cnt=0;
    uint8_t AByte;
    if (debug)
        printf("CLEAR UART BUFFER ...\n");
    while (( read( UART_fd, &AByte, 1 ) == 1 ) && (cnt < 0x1000) )
    {
        cnt++;
        //printf(" 0x%02x", AByte);
    }
    if (debug)
    {
        printf("\n");
        printf("Clear buffer cnt is %d\n", cnt);
    }
    return cnt;
}

int uart::ReadBuffer(uint8_t *PByte, uint32_t nbytes)
{
    uint32_t read_now, rest2read, r_now, cnt;
    uint8_t *pData;
    pData = PByte;

    rest2read = nbytes;
    while (rest2read > 0)
    {
//        printf("rest2read = 0x%04x, ", rest2read);
        if (rest2read > MAX2READ)
        {
            //     usleep(10000);
            read_now = MAX2READ;
        }
        else
        {
            read_now = rest2read;
        }
        rest2read -= read_now;
//        printf("-> read_now = %d, rest2read = 0x%04x \n", read_now, rest2read);

        r_now = read( UART_fd, PByte, read_now );
        if (r_now  != read_now )
        {
            printf("ReadBuffer : r_now is %d, requested %d\n", r_now, read_now);
          //  return EOF;
        r_now = read( UART_fd, PByte, read_now );
        }
        PByte += read_now;
    }


    if(log_flag)
    {
        cnt = bytes_received;
        for(uint32_t i=0; i < nbytes; i++)
            fprintf(m_pLogFile, "%5d burst read byte 0x%02x\n", ++cnt, pData[i]);
        fflush(m_pLogFile);
     }

    if(debug)
    {
      for(uint32_t i=0; i < nbytes; i++)
        printf("Rx data: %02X\n", pData[i]);
     }

    bytes_received += nbytes;

    return 0;
}

int uart::checkDevice() {

  struct stat statusBuffer;
  fstat(UART_fd, &statusBuffer);

  return statusBuffer.st_nlink;
}

void uart::setLogFile(FILE* pLogFile)
{

   m_pLogFile = pLogFile;
}

/* END OF uart CLASS */

