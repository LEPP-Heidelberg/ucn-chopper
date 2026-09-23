/****************************************************************************
**
**  Description:
**        Implements functions for manipulating MachXO2 EFB
**
**  Disclaimer:
**   This source code is intended as a design reference which
**   illustrates how these types of functions can be implemented.  It
**   is the user's responsibility to verify their design for
**   consistency and functionality through the use of formal
**   verification methods.  Lattice Semiconductor provides no warranty
**   regarding the use or functionality of this code.
**
*****************************************************************************
**
**                     Lattice Semiconductor Corporation
**                     5555 NE Moore Court
**                     Hillsboro, OR 97214
**                     U.S.A
**
**                     TEL: 1-800-Lattice (USA and Canada)
**                          (503)268-8001 (other locations)
**
**                     web:   http://www.latticesemi.com
**                     email: techsupport@latticesemi.com
**
*****************************************************************************
**  Change History (Latest changes on top)
**
**  Ver    Date        Description
** --------------------------------------------------------------------------
**  1.0    09/05/2012  Initial Version
**
*****************************************************************************/
#ifndef MICOEFB_H_
#define MICOEFB_H_

#include "DDStructs.h"

#ifdef __cplusplus
extern "C" {
#endif

/***********************************************************************
 *                                                                     *
 * EFB DEVICE REGISTER MAP                                             *
 *                                                                     *
 ***********************************************************************/
typedef struct st_MicoEFB {
	volatile unsigned int  pad0;
	volatile unsigned int  pad1;
	volatile unsigned int  pad2;
	volatile unsigned int  pad3;
	volatile unsigned int  pad4;
	volatile unsigned int  pad5;
	volatile unsigned int  pad6;
	volatile unsigned int  pad7;
	volatile unsigned int  pad8;
	volatile unsigned int  pad9;
	volatile unsigned int  pad10;
	volatile unsigned int  pad11;
	volatile unsigned int  pad12;
	volatile unsigned int  pad13;
	volatile unsigned int  pad14;
	volatile unsigned int  pad15;
	
	volatile unsigned char i2c_1st_cr;
	volatile unsigned char i2c_1st_cmdr;
	volatile unsigned char i2c_1st_blor;
	volatile unsigned char i2c_1st_bhir;
	volatile unsigned char i2c_1st_txdr;
	volatile unsigned char i2c_1st_sr;
	volatile unsigned char i2c_1st_gcdr;
	volatile unsigned char i2c_1st_rxdr;
	volatile unsigned char i2c_1st_irqsr;
	volatile unsigned char i2c_1st_irqenr;
			
	volatile unsigned char i2c_2nd_cr;
	volatile unsigned char i2c_2nd_cmdr;
	volatile unsigned char i2c_2nd_blor;
	volatile unsigned char i2c_2nd_bhir;
	volatile unsigned char i2c_2nd_txdr;
	volatile unsigned char i2c_2nd_sr;
	volatile unsigned char i2c_2nd_gcdr;
	volatile unsigned char i2c_2nd_rxdr;
	volatile unsigned char i2c_2nd_irqsr;
	volatile unsigned char i2c_2nd_irqenr;
	
	volatile unsigned char spi_cr0;
	volatile unsigned char spi_cr1;
	volatile unsigned char spi_cr2;
	volatile unsigned char spi_br;
	volatile unsigned char spi_csr;
	volatile unsigned char spi_txdr;
	volatile unsigned char spi_sr;
	volatile unsigned char spi_rxdr;
	volatile unsigned char spi_irqsr;
	volatile unsigned char spi_irqenr;
	
	volatile unsigned char tc_cr0;
	volatile unsigned char tc_cr1;
	volatile unsigned char tc_top_set_lo;
	volatile unsigned char tc_top_set_hi;
	volatile unsigned char tc_ocr_set_lo;
	volatile unsigned char tc_ocr_set_hi;
	volatile unsigned char tc_cr2;
	volatile unsigned char tc_cnt_sr_lo;
	volatile unsigned char tc_cnt_sr_hi;
	volatile unsigned char tc_top_sr_lo;
	volatile unsigned char tc_top_sr_hi;
	volatile unsigned char tc_ocr_sr_lo;
	volatile unsigned char tc_ocr_sr_hi;
	volatile unsigned char tc_icr_sr_lo;
	volatile unsigned char tc_icr_sr_hi;
	volatile unsigned char tc_sr;
	volatile unsigned char tc_irqsr;
	volatile unsigned char tc_irqenr;
	
	volatile unsigned char wbcfg_cr;
	volatile unsigned char wbcfg_txdr;
	volatile unsigned char wbcfg_sr;
	volatile unsigned char wbcfg_rxdr;
	volatile unsigned char wbcfg_irqsr;
	volatile unsigned char wbcfg_irqenr;
	
	volatile unsigned char test_ctrl0;
	
	volatile unsigned char irq0;
} MicoEFB_t;

/***********************************************************************
 * I2C Interrupt Descriptors                                           *
 ***********************************************************************/
typedef struct st_I2CData_t {
	
	unsigned char i2c_idx ;
	unsigned char slv_xfer ;
	unsigned char *data ;
	unsigned char read ;
	unsigned char insert_stop ;
	unsigned int  buffersize ;
	unsigned int  idx ;
	unsigned int  done ;
	unsigned int  error ;
} I2CData_t ;

typedef struct st_I2CDesc_t I2CDesc_t ;
typedef void (*I2CCallback_t)(MicoEFBCtx_t *ctx) ;
struct st_I2CDesc_t {
	
	void *data ;
	I2CCallback_t onCompletion ;
} ;
void MicoEFB_RegisterI2C1ISR (MicoEFBCtx_t *ctx, I2CDesc_t *i2c) ;
void MicoEFB_RegisterI2C2ISR (MicoEFBCtx_t *ctx, I2CDesc_t *i2c) ;
void MicoEFB_I2C1ISR (MicoEFBCtx_t *ctx) ;
void MicoEFB_I2C2ISR (MicoEFBCtx_t *ctx) ;
void MicoEFB_I2CISR (MicoEFBCtx_t *ctx, unsigned char i2c_idx) ;
char MicoEFB_I2C1XferDone (MicoEFBCtx_t *ctx) ;
char MicoEFB_I2C2XferDone (MicoEFBCtx_t *ctx) ;

/***********************************************************************
 * SPI Interrupt Descriptor                                            *
 ***********************************************************************/
typedef struct st_SPIData_t {
	
	unsigned char *txBuffer ;
	unsigned char *rxBuffer ;
	unsigned int  stop ;
	unsigned int  size ;
	unsigned int  idx ;
	unsigned int  done ;

} SPIData_t ;

typedef struct st_SPIDesc_t SPIDesc_t ;
typedef void(*SPICallback_t)(MicoEFBCtx_t *ctx) ;
struct st_SPIDesc_t {
	
	void *data ;
	SPICallback_t onCompletion ;
};

void MicoEFB_SPIISR (MicoEFBCtx_t *ctx) ;
void MicoEFB_RegisterSPIISR (MicoEFBCtx_t *ctx, SPIDesc_t *spi) ;

/***********************************************************************
 * Timer/Counter Interrupt Descriptor                                  *
 ***********************************************************************/
typedef struct st_TCDesc_t TCDesc_t;
typedef void(*TCCallback_t)(MicoEFBCtx_t *ctx);
struct st_TCDesc_t {
	
	void *data;
	TCCallback_t onCompletion;
};

typedef struct st_WBCFGDesc_t WBCFGDesc_t;
typedef void(*WBCFGCallback_t)(MicoEFBCtx_t *ctx);
struct st_WBCFGDesc_t {
	
	void *data;
	WBCFGCallback_t	onCompletion;
};
void MicoEFB_RegisterWBCFGISR (MicoEFBCtx_t *ctx, WBCFGDesc_t *cfg) ;



/***********************************************************************
 *                                                                     *
 * FUNCTIONS                                                           *
 *                                                                     *
 ***********************************************************************/

void MicoEFBInit (MicoEFBCtx_t *ctx);

void MicoEFB_ISR (unsigned int intrLevel, void *ctx);

char MicoEFB_SPITransfer (MicoEFBCtx_t *ctx,
							unsigned char isMaster,
							unsigned char slvIndex,
							unsigned char insertStart,
							unsigned char insertStop,
							unsigned char *txBuffer,
							unsigned char *rxBuffer,
							unsigned int  bufferSize,
							unsigned int  irqmode);

char MicoEFB_SPITxData (MicoEFBCtx_t *ctx,
						unsigned char data);

char MicoEFB_SPIRxData (MicoEFBCtx_t *ctx,
						unsigned char *data);

char MicoEFB_I2CStart (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx,	// I2C 1 or 2
						unsigned char read,		// Write (0) or Read (1) 
						unsigned char address,	// Slave address
						unsigned char restart); // Repeated start (1)

char MicoEFB_I2CWrite (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx,        // I2C 1 or 2  
						unsigned char slv_xfer,       // Is I2C the master (0) or slave (1)
						unsigned int  buffersize,     // Number of bytes to be transfered (min 1 and max 256) 
						unsigned char *data,          // Buffer containing the data to be transferred
						unsigned char insert_start,   // Master: Insert Start (or repeated Start) prior to data transfer
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer 
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address, 	      // Slave address
						unsigned char irqmode); 	  // Interrupt driven (1) or polling mode (0)

char MicoEFB_I2CRead (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx,        // I2C 1 or 2  
						unsigned char slv_xfer,       // Is I2C the master (0) or slave (1)
						unsigned int  buffersize,     // Number of bytes to be received (min 1 and max 256) 
						unsigned char *data,          // Buffer to put received data in to
						unsigned char insert_start,   // Master: Insert Start (or repeated Start) prior to data transfer  
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address, 	      // Slave address
						unsigned char irqmode); 	  // Interrupt driven (1) or polling mode (0)

void MicoEFB_TimerStart (MicoEFBCtx_t *ctx,
							unsigned char mode,
							unsigned char ocmode,
							unsigned char sclk,
							unsigned char cclk,
							unsigned char interrupt,
							unsigned int timerCount,
							unsigned int compareCount);


char MicoEFB_UFMTxData (MicoEFBCtx_t *ctx,
						unsigned char *data,
						unsigned char buffersize) ;

char MicoEFB_UFMRxData (MicoEFBCtx_t *ctx,
						unsigned char *data,
						unsigned char buffersize) ;

char MicoEFB_UFMCmdCall (MicoEFBCtx_t *ctx,
							unsigned long opcode,
							unsigned char enable) ;

char MicoEFB_UFMErase (MicoEFBCtx_t *ctx) ;

char MicoEFB_UFMSetAddr (MicoEFBCtx_t *ctx,
							unsigned int address) ;

char MicoEFB_UFMRead (MicoEFBCtx_t *ctx,
					  	unsigned char *data,
						unsigned char pagesize) ;

char MicoEFB_UFMWrite (MicoEFBCtx_t *ctx,
						unsigned char *data) ;

/***********************************************************************
 *                                                                     *
 * EFB SPI CONTROLLER PHYSICAL DEVICE SPECIFIC INFORMATION             *
 *                                                                     *
 ***********************************************************************/

// Control Register 1 Bit Masks
#define MICO_EFB_SPI_CR1_SPE				(0x80)
#define MICO_EFB_SPI_CR1_WKUPEN				(0x40)
// Control Register 2 Bit Masks
#define MICO_EFB_SPI_CR2_LSBF				(0x01)
#define MICO_EFB_SPI_CR2_CPHA				(0x02)
#define MICO_EFB_SPI_CR2_CPOL				(0x04)
#define MICO_EFB_SPI_CR2_SFSEL_NORMAL		(0x00)
#define MICO_EFB_SPI_CR2_SFSEL_LATTICE		(0x08)
#define MICO_EFB_SPI_CR2_SRME				(0x20)
#define MICO_EFB_SPI_CR2_MCSH				(0x40)
#define MICO_EFB_SPI_CR2_MSTR				(0x80)
// Status Register Bit Masks
#define MICO_EFB_SPI_SR_TIP					(0x80)
#define MICO_EFB_SPI_SR_TRDY				(0x10)
#define MICO_EFB_SPI_SR_RRDY				(0x08)
#define MICO_EFB_SPI_SR_TOE					(0x04)
#define MICO_EFB_SPI_SR_ROE					(0x02)
#define MICO_EFB_SPI_SR_MDF					(0x01)

/***********************************************************************
 *                                                                     *
 * EFB I2C CONTROLLER PHYSICAL DEVICE SPECIFIC INFORMATION             *
 *                                                                     *
 ***********************************************************************/

// Control Register Bit Masks
#define MICO_EFB_I2C_CR_I2CEN				(0x80)
#define MICO_EFB_I2C_CR_GCEN				(0x40)
#define MICO_EFB_I2C_CR_WKUPEN				(0x20)
// Status Register Bit Masks
#define MICO_EFB_I2C_SR_TIP					(0x80)
#define MICO_EFB_I2C_SR_BUSY				(0x40)
#define MICO_EFB_I2C_SR_RARC				(0x20)
#define MICO_EFB_I2C_SR_SRW					(0x10)
#define MICO_EFB_I2C_SR_ARBL				(0x08)
#define MICO_EFB_I2C_SR_TRRDY				(0x04)
#define MICO_EFB_I2C_SR_TROE				(0x02)
#define MICO_EFB_I2C_SR_HGC					(0x01)
// Command Register Bit Masks 
#define MICO_EFB_I2C_CMDR_STA				(0x80)
#define MICO_EFB_I2C_CMDR_STO				(0x40)
#define MICO_EFB_I2C_CMDR_RD				(0x20)
#define MICO_EFB_I2C_CMDR_WR				(0x10)
#define MICO_EFB_I2C_CMDR_NACK				(0x08)
#define MICO_EFB_I2C_CMDR_CKSDIS			(0x04)

/***********************************************************************
 *                                                                     *
 * EFB I2C USER DEFINE                                                 *
 *                                                                     *
 ***********************************************************************/
#define MICO_EFB_I2C_WR_SEQUENCE			(0)
#define MICO_EFB_I2C_RD_SEQUENCE			(1)
#define MICO_EFB_I2C_TRANSMISSION_DONE		(0x00)
#define MICO_EFB_I2C_TRANSMISSION_ONGOING	(0x80)
#define MICO_EFB_I2C_FREE                   (0x00)
#define MICO_EFB_I2C_BUSY                   (0x40)
#define MICO_EFB_I2C_ACK_NOT_RCVD			(0x20)
#define MICO_EFB_I2C_ACK_RCVD				(0x00)
#define MICO_EFB_I2C_ARB_LOST				(0x08)
#define MICO_EFB_I2C_ARB_NOT_LOST			(0x00)
#define MICO_EFB_I2C_DATA_READY				(0x04)

/***********************************************************************
 *                                                                     *
 * EFB TIMER PHYSICAL DEVICE SPECIFIC INFORMATION                      *
 *                                                                     *
 ***********************************************************************/
// Control Register 0
#define MICO_EFB_TIMER_RSTN_MASK			(0x80)
#define MICO_EFB_TIMER_GSRN_MASK			(0x40)
#define MICO_EFB_TIMER_GSRN_ENABLE			(0x40)
#define MICO_EFB_TIMER_GSRN_DISABLE			(0x00)
#define MICO_EFB_TIMER_CCLK_MASK			(0x38)
#define MICO_EFB_TIMER_CCLK_DIV_0			(0x00)
#define MICO_EFB_TIMER_CCLK_DIV_1			(0x08)
#define MICO_EFB_TIMER_CCLK_DIV_8			(0x10)
#define MICO_EFB_TIMER_CCLK_DIV_64			(0x18)
#define MICO_EFB_TIMER_CCLK_DIV_256			(0x20)
#define MICO_EFB_TIMER_CCLK_DIV_1024		(0x28)
#define MICO_EFB_TIMER_SCLK_MASK			(0x07)
#define MICO_EFB_TIMER_SCLK_CIB_RE			(0x00)
#define MICO_EFB_TIMER_SCLK_OSC_RE			(0x02)
#define MICO_EFB_TIMER_SCLK_CIB_FE			(0x04)
#define MICO_EFB_TIMER_SCLK_OSC_FE			(0x06)
// Control Register 1
#define MICO_EFB_TIMER_TOP_SEL_MASK			(0x80)
#define MICO_EFB_TIMER_TOP_MAX				(0x00)
#define MICO_EFB_TIMER_TOP_USER_SELECT		(0x10)
#define MICO_EFB_TIMER_OC_MODE_MASK			(0x0C)
#define MICO_EFB_TIMER_OC_MODE_STATIC_ZERO	(0x00)
#define MICO_EFB_TIMER_OC_MODE_TOGGLE		(0x04)
#define MICO_EFB_TIMER_OC_MODE_CLEAR		(0x08)
#define MICO_EFB_TIMER_OC_MODE_SET			(0x0C)
#define MICO_EFB_TIMER_MODE_MASK			(0x03)
#define MICO_EFB_TIMER_MODE_WATCHDOG		(0x00)
#define MICO_EFB_TIMER_MODE_CTC				(0x01)
#define MICO_EFB_TIMER_MODE_FAST_PWM		(0x02)
#define MICO_EFB_TIMER_MODE_TRUE_PWM		(0x03)
// Control Register 2
#define MICO_EFB_TIMER_OC_FORCE				(0x04)
#define MICO_EFB_TIMER_CNT_RESET			(0x02)
#define MICO_EFB_TIMER_CNT_PAUSE			(0x01)
// Status Register
#define MICO_EFB_TIMER_SR_OVERFLOW			(0x01)
#define MICO_EFB_TIMER_SR_COMPARE_MATCH		(0x02)
#define MICO_EFB_TIMER_SR_CAPTURE			(0x04)

/***********************************************************************
 *                                                                     *
 * EFB UFMCFG CONTROLLER PHYSICAL DEVICE SPECIFIC INFORMATION             *
 *                                                                     *
 ***********************************************************************/
#define MICO_EFB_UFM_CR						(0x70)
#define MICO_EFB_UFM_TXDR					(0x71)
#define MICO_EFB_UFM_SR						(0x72)
#define MICO_EFB_UFM_RXDR					(0x73)
#define MICO_EFB_UFM_IRQSR					(0x74)
#define MICO_EFB_UFM_IRQENR					(0x75)

// Control Register Bit Masks
#define MICO_EFB_UFM_CR_WBCE				(0x80)
#define MICO_EFB_UFM_CR_RSTE				(0x40)
// Status Register Bit Masks
#define MICO_EFB_UFM_SR_WBCACT				(0x80)
#define MICO_EFB_UFM_SR_TXFE				(0x20)
#define MICO_EFB_UFM_SR_TXFF				(0x10)
#define MICO_EFB_UFM_SR_RXFE				(0x08)
#define MICO_EFB_UFM_SR_RXFF				(0x04)
#define MICO_EFB_UFM_SR_SSPIACT				(0x02)
#define MICO_EFB_UFM_SR_I2CACT				(0x01)

/***********************************************************************
 *                                                                     *
 * EFB UFM USER DEFINE                                                 *
 *                                                                     *
 ***********************************************************************/
//UFM Status
#define MICO_EFB_UFM_WBCE_ENABLE			(0x80)
#define MICO_EFB_UFM_WBCE_DISABLE			(0x00)
#define MICO_EFB_UFM_TX_EMPTY				(0x20)
#define MICO_EFB_UFM_TX_FULL				(0x10)
#define MICO_EFB_UFM_RX_EMPTY				(0x08)
#define MICO_EFB_UFM_RX_FULL				(0x04)
#define MICO_EFB_UFM_PORT_INACTIVE			(0x00)

//UFM command opcode
//#define MICO_EFB_UFM_RD_SR				(0x0000003C)
//#define MICO_EFB_UFM_RD_BUSY				(0x000000F0)
//#define MICO_EFB_UFM_ENABLE				(0x00000874)
//#define MICO_EFB_UFM_DISABLE				(0x00000026)
//#define MICO_EFB_UFM_SET_ADDRESS			(0x000000B4)
//#define MICO_EFB_UFM_INIT_ADDRESS			(0x00000047)
//#define MICO_EFB_UFM_RD_DATA				(0x000000CA)
//#define MICO_EFB_UFM_ERASE_DATA			(0x000000CB)
//#define MICO_EFB_UFM_WR_DATA				(0x010000C9)

#define MICO_EFB_UFM_RD_SR					(0x3C000000)
#define MICO_EFB_UFM_RD_BUSY				(0xF0000000)
#define MICO_EFB_UFM_ENABLE					(0x74080000)
#define MICO_EFB_UFM_DISABLE				(0x26000000)
#define MICO_EFB_UFM_SET_ADDRESS			(0xB4000000)
#define MICO_EFB_UFM_INIT_ADDRESS			(0x47000000)
#define MICO_EFB_UFM_RD_DATA				(0xCA000000)
#define MICO_EFB_UFM_ERASE_DATA				(0xCB000000)
#define MICO_EFB_UFM_WR_DATA				(0xC9000001)

//UFM Command Call Bit Masks
#define UFM_PAGE_BYTE						(16)
#define MICO_EFB_UFM_CLOSE_FRAME_DISABLE	(0x0)
#define MICO_EFB_UFM_CLOSE_FRAME_ENABLE		(0x1)
#define MICO_EFB_UFM_ENABLE_CONFIG			(0x01)
#define MICO_EFB_UFM_DISABLE_CONFIG			(0x02)

//UFM Read Status Register
//#define MICO_EFB_UFM_SR_DONE				(0x00010000)
//#define MICO_EFB_UFM_SR_BUSY				(0x00100000)
//#define MICO_EFB_UFM_SR_FAIL				(0x00200000)
//#define MICO_EFB_UFM_SR_ERROR				(0x00008003)

#define MICO_EFB_UFM_SR_DONE				(0x00000100)
#define MICO_EFB_UFM_SR_BUSY				(0x00001000)
#define MICO_EFB_UFM_SR_FAIL				(0x00002000)
#define MICO_EFB_UFM_SR_ERROR				(0x03800000)

//UFM Check Busy Flag
#define MICO_EFB_UFM_BUSY					(0x01)

//UFM Set Address
//#define MICO_EFB_UFM_SET_UFM_SECTOR		(0x40)
#define MICO_EFB_UFM_SET_UFM_SECTOR			(0x40000000)

//UFM Read Data
//#define MICOEFB_UFM_DUMMY_SETTING			(0x10)
#define MICOEFB_UFM_DUMMY_SETTING			(0x00100000)
#ifdef __cplusplus
}
#endif


#endif /*MICOEFB_H_*/
