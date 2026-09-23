// $Id: my_types.h 1055 2024-01-16 18:05:50Z angelov $:

// the standard integer types supported by the LM32 CPU

#ifndef _MY_INT_TYPES
#define _MY_INT_TYPES

typedef char                    int8_t;
typedef unsigned char           uint8_t;
typedef short int               int16_t;
typedef unsigned short int      uint16_t;
typedef int                     int32_t;
typedef unsigned int            uint32_t;
// emulated!
typedef long long int           int64_t;
typedef unsigned long long int  uint64_t;

// write and read to the I/O
#define IO_WRITE(addr, dat)   *( ( volatile uint32_t*)(addr) )=dat
#define IO_READ(addr)          ( *(volatile uint32_t*)(addr) )

#endif // _MY_INT_TYPES
