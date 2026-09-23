/****************************************************************************
**
**  Description:
**        Implements functions for manipulating LatticeMico32 EFB
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
**  1.0    12/16/2010  Initial Version
**	1.1    05/23/2012  UFM drivers and I2C restart mode support
**	1.2	   06/26/2012  Timer Reset User Mode and __MICO_NO_INIT__optimization
*****************************************************************************/
#include "stddef.h"
#include "MicoEFB.h"
#include "MicoUtils.h"

/* *****************************************************************************
 * EFB initialization.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 *****************************************************************************
 */
#ifndef __MICO_NO_INIT__
void MicoEFBInit (MicoEFBCtx_t *ctx)
{
	size_t efb_address = (size_t) ctx->base;
	
	// Disable all interrupts (should be enabled by user as reqd)
	if (ctx->i2c1_en == 1) {
		// Disable and clear interrupts
		MICO_EFB_I2C_WRITE_IRQENR (efb_address, 0x0); // I2C 1
		MICO_EFB_I2C_WRITE_IRQSR (efb_address, 0xF);
	}
	if (ctx->i2c2_en == 1) {
		// Disable and clear interrupts
		MICO_EFB_I2C_WRITE_IRQENR (efb_address+0xA, 0x0); // I2C 2
		MICO_EFB_I2C_WRITE_IRQSR (efb_address+0xA, 0xF);
	}
	if (ctx->spi_en == 1) {
		// Disable and clear interrupts
		MICO_EFB_SPI_WRITE_IRQENR (efb_address, 0x0); // SPI
		MICO_EFB_SPI_WRITE_IRQSR (efb_address, 0x1F);
	}
	if (ctx->timer_en == 1) {
		// Stop Timer
		MICO_EFB_TIMER_WRITE_CR2 (efb_address, (MICO_EFB_TIMER_CNT_RESET|MICO_EFB_TIMER_CNT_PAUSE));
		// Disable and clear interrupts
		MICO_EFB_TIMER_WRITE_IRQENR (efb_address, 0x0); // Timer
		MICO_EFB_TIMER_WRITE_IRQSR (efb_address, 0xF);
	}
	if (ctx->ufm_en == 1) {
		// Disable and clear interrupts
		MICO_EFB_UFM_WRITE_IRQENR (efb_address, 0x0); // UFM
		MICO_EFB_UFM_WRITE_IRQSR (efb_address, 0x2F);
	}
}
#endif

/*
 *****************************************************************************
 * Interrupt handler. Each EFB component has it's own reset handler and must
 * be implemented by the developers in user code to reflect their application
 * behavior.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 *****************************************************************************
 */
#ifndef __MICO_NO_INTERRUPTS__
void MicoEFBISR (MicoEFBCtx_t *ctx)
{
	unsigned int irq_source;
	
	MICO_EFB_READ_IRQR((size_t)(ctx->base), irq_source);
	switch (irq_source) 
	{
#ifndef __MICOEFB_NO_I2C_INTERRUPT__
		case 1: MicoEFB_I2C1ISR(ctx); MICO_EFB_WRITE_IRQR((size_t)(ctx->base), 0x01); break;
		case 2: MicoEFB_I2C2ISR(ctx); MICO_EFB_WRITE_IRQR((size_t)(ctx->base), 0x02); break;
#endif
#ifndef __MICOEFB_NO_SPI_INTERRUPT__
		case 4: MicoEFB_SPIISR(ctx); MICO_EFB_WRITE_IRQR((size_t)(ctx->base), 0x04); break;
#endif
#ifndef __MICOEFB_NO_TC_INTERRUPT__
		case 8: MicoEFB_TimerISR(ctx); MICO_EFB_WRITE_IRQR((size_t)(ctx->base), 0x08); break;
#endif
#ifndef __MICOEFB_NO_UFM_INTERRUPT__
		case 16: MicoEFB_UFMISR(ctx); MICO_EFB_WRITE_IRQR((size_t)(ctx->base), 0x10); break;
#endif
		default: break;
	}
}
#endif

/*
 *****************************************************************************
 * Initiate a SPI transfer that receives and transmits a configurable number 
 * of bytes.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char isMaster	: Master (1) or Slave (0)
 *    unsigned char insertStart	: Assert chip select at start of transfer
 *    unsigned char insertStop	: Desert chip select at end of transfer
 *    unsigned char *txBuffer	: Bytes to be transmitted
 *    unsigned char *rxBuffer	: Bytes received
 *    unsigned char bufferSize	: Number of bytes to transfer. 0 refers to 1
 * 								  byte. 255 refers to 256 bytes.
 *
 * Return Value:
 *    char:
 *         0 => successful writes
 *
 *****************************************************************************
 */
char MicoEFB_SPITransfer (MicoEFBCtx_t *ctx,
							unsigned char isMaster,
							unsigned char slvIndex,
							unsigned char insertStart,
							unsigned char insertStop,
							unsigned char *txBuffer,
							unsigned char *rxBuffer,
							unsigned char bufferSize)
{
	size_t efb_address = (size_t)(ctx->base);

	// Is SPI busy?
	if ((isMaster && insertStart) ||  (isMaster == 0)){
		unsigned char sts1, sts2;
		do {
			MICO_EFB_SPI_READ_SR (efb_address, sts1);
			sts2 = sts1 & MICO_EFB_SPI_SR_TIP;
			if (sts2 == 0)
				break;
		} while (1);

	}

	// Set SPI mode (master or slave)
	if (isMaster) {
		if (insertStart) {
			// Modify baud rate to at least 6x slower that WISHBONE clock (XO2 limitation)
			MICO_EFB_SPI_WRITE_BR (efb_address, 0x6);
			unsigned char csr_value;
			csr_value = __MicoEFB_ASHLHI3(1, slvIndex);
			MICO_EFB_SPI_WRITE_CSR (efb_address, ~csr_value);
//			MICO_EFB_SPI_WRITE_CSR (efb_address, ~(0x1<<slvIndex));
			MICO_EFB_SPI_WRITE_CR2 (efb_address, (MICO_EFB_SPI_CR2_MSTR | MICO_EFB_SPI_CR2_MCSH /*| MICO_EFB_SPI_CR2_CPOL | MICO_EFB_SPI_CR2_CPHA */));
		}
	} else {
		MICO_EFB_SPI_WRITE_CR2 (efb_address, 0x00);
	} 

#ifdef __01A__	
	// Due to a flaw in silicon  A dummy byte will be read on the first byte
	
	// An extra dummy byte will be transmitted 
	MICO_EFB_SPI_WRITE_TXDR (efb_address, *txBuffer);
	txBuffer++;

	unsigned char sts7, sts8;
	do {
		MICO_EFB_SPI_READ_SR (efb_address, sts7);
		sts8 = sts7 & MICO_EFB_SPI_SR_RRDY;
		if (sts8 == MICO_EFB_SPI_SR_RRDY)
			break;
	} while (1);
	
	// Receive the dummy byte
	MICO_EFB_SPI_READ_RXDR (efb_address, *rxBuffer);
#endif

	unsigned char xferCount = 0;
	do {

		// Is controller ready to transmit another byte?
		unsigned char sts3, sts4;
		do {
			MICO_EFB_SPI_READ_SR (efb_address, sts3);
			sts4 = sts3 & MICO_EFB_SPI_SR_TRDY;
			if (sts4 == MICO_EFB_SPI_SR_TRDY)
				break;
		} while (1);

		// Transmit byte
		MICO_EFB_SPI_WRITE_TXDR (efb_address, *txBuffer);

		// Is controller ready with received byte?
		unsigned char sts5, sts6;
		do {
			MICO_EFB_SPI_READ_SR (efb_address, sts5);
			sts6 = sts5 & MICO_EFB_SPI_SR_RRDY;
			if (sts6 == MICO_EFB_SPI_SR_RRDY)
				break;
		} while (1);

		// Receive byte
		MICO_EFB_SPI_READ_RXDR (efb_address, *rxBuffer);

		// Exit if done
		if (xferCount == bufferSize){
			break;
		}else{
			txBuffer++;
			rxBuffer++;
			xferCount++;
		}
	} while (1); 

	// End transaction
	if (insertStop)
		MICO_EFB_SPI_WRITE_CR2 (efb_address, MICO_EFB_SPI_CR2_MSTR);

	return (0);
}

/*
 *****************************************************************************
 * Initiate a byte transmit
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char data		: Data byte to transfer
 *
 * Return Value:
 *    char:
 *         0 => status register contents prior to transmit of data
 *
 *****************************************************************************
 */
char MicoEFB_SPITxData (MicoEFBCtx_t *ctx, 
						unsigned char data)
{
    size_t efb_address = (size_t)(ctx->base);
	volatile unsigned char sts;
    
    // Check if transmit register is empty?
    do {
        MICO_EFB_SPI_READ_SR (efb_address, sts);
        if ((sts & MICO_EFB_SPI_SR_TRDY) != 0) 
        	break;
    } while (1);
    
    // Write byte to transmit register
    MICO_EFB_SPI_WRITE_TXDR (efb_address, data);
    
    return sts;
}

/*
 *****************************************************************************
 * Initiate a byte receive
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char data		: Data byte received
 *
 * Return Value:
 *    char:
 *         0 => status register contents after receive of data
 *
 *****************************************************************************
 */
char MicoEFB_SPIRxData (MicoEFBCtx_t *ctx,
						unsigned char *data)
{
    size_t efb_address = (size_t)(ctx->base);
	volatile unsigned char sts;
    
    // Check if receive register is full?
    do {
        MICO_EFB_SPI_READ_SR (efb_address, sts);
        if ((sts & MICO_EFB_SPI_SR_RRDY) != 0) 
        	break;
    } while (1);
    
    // Get byte from receive register
    MICO_EFB_SPI_READ_RXDR (efb_address, *data);
    
    return sts;
}
/*
 *****************************************************************************
 * Initiate a START command provided the I2C master can get control of the bus
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char i2c_idx		: I2C 1 (1) or 2 (2)
 *    unsigned char address		: Slave device address
 *    unsigned char read		: Read (1) or Write (0)
 *    unsigned char restart     : Repeated Start (1) or Start (0)
 *
 * Return Value:
 *    char:
 *         0 => successful writes
 *        -1 => failed to receive ack during addressing
 *        -2 => failed to receive ack when writing data
 *        -3 => arbitration lost during the operation
 *
 *****************************************************************************
 */
char MicoEFB_I2CStart (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx, // I2C 1 or 2
						unsigned char read,	   // Write (0) or Read (1) 
						unsigned char address, // Slave address
						unsigned char restart) // Repeated Start (1)
{
	size_t efb_address = (size_t)(ctx->base);
	if (i2c_idx == 2) {
		efb_address += 10;
	}
	
	// Check if I2C is busy with another transaction?
	volatile unsigned char sts1, sts2;
	do {
		MICO_EFB_I2C_READ_SR (efb_address, sts1);
		sts2 = sts1 & MICO_EFB_I2C_SR_BUSY;
		if ((restart == 0) && (sts2 == MICO_EFB_I2C_FREE))
			break;
		if ((restart == 1) && (sts1 & MICO_EFB_I2C_SR_TRRDY))
			break;
	} while (1);
		
	// Load slave address and setup write to transmit the address

//	MICO_EFB_I2C_WRITE_TXDR (efb_address, ((address << 1)|read));
	unsigned char shifted_address;
	shifted_address = __MicoEFB_ASHLHI3 (address, 1);
	MICO_EFB_I2C_WRITE_TXDR (efb_address, shifted_address|read);
	MICO_EFB_I2C_WRITE_CMDR (efb_address, (MICO_EFB_I2C_CMDR_STA | MICO_EFB_I2C_CMDR_WR));
	
#ifndef __01A__
	// Check if transmission is in progress?
	unsigned char sts3, sts4, sts5, sts6;
	do {
		MICO_EFB_I2C_READ_SR (efb_address, sts3);
		sts4 = sts3 & MICO_EFB_I2C_SR_TIP;
		if (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE)
			break; 
	} while (1);
	
	// Check if acknowledge is rcvd
	sts5 = sts3 & MICO_EFB_I2C_SR_RARC;
	if (sts5 == MICO_EFB_I2C_ACK_NOT_RCVD) {
		return (-1);
	}
	
	// Check if arbitration was lost
	sts6 = sts3 & MICO_EFB_I2C_SR_ARBL;
	if (sts6 == MICO_EFB_I2C_ARB_LOST) {
		return (-2);
	}
#endif
	
	return (0);
}


/*
 *****************************************************************************
 * Performs block writes. In addition it also allows the user to optionally:
 * 1. Initiate a START command prior to performing the block writes if the I2C
 *    is an I2C Master.
 * 2. Initiate a STOP command after performing the block writes if the I2C is 
 *    an I2C Master.
 * 3. Hold the SCL line low (i.e., clock stretching) after performing the 
 *    block writes if the I2C is an I2C Slave.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			   : EFB context
 *    unsigned char i2c_idx		   : I2C 1 (1) or 2 (2)
 *    unsigned char slv_xfer	   : I2C Master (0) or I2C Slave (1)
 *    unsigned char buffersize     : Number of bytes to be transferred. 0 refers
 *                                   to 1 byte. 255 refers to 256 bytes.
 *    unsigned char *data		   : Pointer to bytes to write
 *    unsigned char address		   : Slave device address
 *    unsigned char insert_start   : Insert START command prior to block transfer
 *    unsigned char insert_restart : Insert Repeated START command prior to 
 *                                   block transfer
 *    unsigned char insert_stop    : Insert STOP command after the block transfer 
 *                                   for I2C Master. Enable clock stretching 
 *                                   after the block transfer for I2C Slave.
 *
 * Return Value:
 *    char:
 *         0 => successful writes
 *        -1 => failed to receive ack during addressing
 *        -2 => failed to receive ack when writing data
 *        -3 => arbitration lost during the operation
 *
 *****************************************************************************
 */
char MicoEFB_I2CWrite (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx,        // I2C 1 or 2  
						unsigned char slv_xfer,       // Is I2C the master (0) or slave (1)
						unsigned char buffersize,     // Number of bytes to be transfered (min 1 and max 256) 
						unsigned char *data,          // Buffer containing the data to be transferred
						unsigned char insert_start,   // Master: Insert Start (or repeated Start) prior to data transfer  
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address)	  	  // Slave address
{
	size_t efb_address = (size_t)(ctx->base);
	if (i2c_idx == 2) {
		efb_address += 10;
	}
	
	unsigned char sts1;
	if ((slv_xfer == 0) && insert_start) {
		sts1 = MicoEFB_I2CStart (ctx, i2c_idx, MICO_EFB_I2C_WR_SEQUENCE, address, insert_restart);
		if (sts1 != 0)
			return sts1;
	}
	
	// Wait until previous byte transfer is done
	unsigned char sts2, sts3, sts4;
	do {
		MICO_EFB_I2C_READ_SR (efb_address, sts2);
#ifndef __01A__
		sts3 = sts2 & MICO_EFB_I2C_SR_SRW;
		sts4 = sts2 & MICO_EFB_I2C_SR_TIP;
		//If I2C is restart mode
		if (insert_restart == 1){
			// Master I2C expects Master Transfer Slave Receive
			if ((slv_xfer == 0) && (sts3 == MICO_EFB_I2C_MASTER_TX_SLAVE_RX) && (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE))
				break;
			// Slave I2C expects Master Receive Slave Transfer
			if ((slv_xfer == 1) && (sts3 == MICO_EFB_I2C_MASTER_RX_SLAVE_TX) && (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE))
				break;
		}else{
			if (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE)
				break;
		}
#else
		sts3 = sts2 & MICO_EFB_I2C_SR_TRRDY;
		if (sts3 == MICO_EFB_I2C_DATA_READY)
#endif
			break;
	} while (1);
	
	// Transfer bytes from buffer
	unsigned char i = 0;
	do {
		
		// Transfer byte
		MICO_EFB_I2C_WRITE_TXDR (efb_address, *data);
		MICO_EFB_I2C_WRITE_CMDR (efb_address, MICO_EFB_I2C_CMDR_WR);

		// Wait until transfer is complete
		unsigned char sts5, sts6;
		do {
			MICO_EFB_I2C_READ_SR (efb_address, sts5);
#ifndef __01A__
			sts6 = sts5 & MICO_EFB_I2C_SR_TIP;
			if (sts6 == MICO_EFB_I2C_TRANSMISSION_DONE)
#else
			sts6 = sts5 & MICO_EFB_I2C_SR_TRRDY;
			if (sts6 == MICO_EFB_I2C_DATA_READY)
#endif
				break;
		} while (1);

		// Check if acknowledge is rcvd
		unsigned char sts7;
		if (slv_xfer && (insert_stop == 0) && (i == buffersize)) {
			// If I2C is slave, it does not expect an acknowledge on the last transfer.
			;
		} else {
			sts7 = sts5 & MICO_EFB_I2C_SR_RARC;
			if (sts7 == MICO_EFB_I2C_ACK_NOT_RCVD) {
				return (-1);
			}
		}
		
		// Check if arbitration was lost
		unsigned char sts8;
		sts8 = sts5 & MICO_EFB_I2C_SR_ARBL;
		if ((slv_xfer == 0) && (sts8 == MICO_EFB_I2C_ARB_LOST)) {
			return (-2);
		}
		
		// Exit if done
		if (i == buffersize) {
			if (insert_stop && (slv_xfer == 0)) {
				// Issue STOP command for a I2C master
				MICO_EFB_I2C_WRITE_CMDR (efb_address, MICO_EFB_I2C_CMDR_STO);
			}
				
			if ((insert_stop == 0) && slv_xfer) {
				// Disable clock stretching for a I2C slave
				MICO_EFB_I2C_WRITE_CMDR (efb_address, MICO_EFB_I2C_CMDR_CKSDIS);
			}
		  
			break;
		}
		
		// Increment buffer pointer and loop iterator
		i++;
		data++;
		
	} while (1);
	
	return (0);
}


/*
 *****************************************************************************
 * Performs block reads. In addition it also allows the user to optionally:
 * 1. Initiate a START command prior to performing the block reads if the I2C
 *    is an I2C Master.
 * 2. Initiate a STOP command after performing the block reads if the I2C is 
 *    an I2C Master.
 * 3. Hold the SCL line low (i.e., clock stretching) after performing the 
 *    block reads if the I2C is an I2C Slave.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			   : EFB context
 *    unsigned char i2c_idx		   : I2C 1 (1) or 2 (2)
 *    unsigned char slv_xfer	   : I2C Master (0) or I2C Slave (1)
 *    unsigned char buffersize     : Number of bytes to be transferred. 0 
 *                                   refers to 1 byte. 255 refers to 256 bytes.
 *    unsigned char *data		   : Pointer to buffer in which rcvd bytes are put
 *    unsigned char address		   : Slave device address
 *    unsigned char insert_start   : Insert START command prior to block transfer
 *    unsigned char insert_restart : Insert Repeated START command prior to 
 *                                   block transfer
 *    unsigned char insert_stop    : Insert STOP command after the block  
 *                                   transfer for I2C Master. Enable clock 
 *                                   stretching after the block transfer for 
 *                                   I2C Slave.
 *
 * Return Value:
 *    char:
 *         0 => successful reads
 *        -1 => failed to receive ack during addressing
 *        -2 => failed to receive ack when writing data
 *        -3 => arbitration lost during the operation
 *
 *****************************************************************************
 */
char MicoEFB_I2CRead (MicoEFBCtx_t *ctx, 
						unsigned char i2c_idx,        // I2C 1 or 2  
						unsigned char slv_xfer,       // Is I2C the master (0) or slave (1)
						unsigned char buffersize,     // Number of bytes to be received (min 1 and max 256) 
						unsigned char *data,          // Buffer to put received data in to
						unsigned char insert_start,   // Master: Insert Start (or restart) prior to data transfer
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address)		  // Slave address
{
	size_t efb_address = (size_t)(ctx->base);
	if (i2c_idx == 2) {
		efb_address += 10;
	}

	unsigned char sts1;
	if ((slv_xfer == 0) && insert_start) {
		sts1 = MicoEFB_I2CStart (ctx, i2c_idx, MICO_EFB_I2C_RD_SEQUENCE, address, insert_restart);
		if (sts1 != 0)
			return sts1;
	}

#ifndef __01A__
	// Wait until previous byte transfer is done
	unsigned char sts2, sts3, sts4;
	do {
		MICO_EFB_I2C_READ_SR (efb_address, sts2);
		sts3 = sts2 & MICO_EFB_I2C_SR_SRW;
		sts4 = sts2 & MICO_EFB_I2C_SR_TIP;
		//If I2C is restart mode
		if (insert_restart == 1){
			// Master I2C expects Master Receive Slave Transfer
			if ((slv_xfer == 0) && (sts3 == MICO_EFB_I2C_MASTER_RX_SLAVE_TX) && (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE))
				break;
			// Slave I2C expects Master Transfer Slave Receive
			if ((slv_xfer == 1) && (sts3 == MICO_EFB_I2C_MASTER_TX_SLAVE_RX) && (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE))
				break;
		}else{
			if (sts4 == MICO_EFB_I2C_TRANSMISSION_DONE)
				break;
		}
	} while (1);
#endif

	// Transfer bytes from buffer
	unsigned char i = 0;
	do {
		// Initiate transfer
		if (i == buffersize) {
			// Check if Last Read
			if (insert_stop && (slv_xfer == 0)) {
				// Issue STOP command for a I2C master
				MICO_EFB_I2C_WRITE_CMDR (efb_address, (MICO_EFB_I2C_CMDR_STO | MICO_EFB_I2C_CMDR_NACK | MICO_EFB_I2C_CMDR_RD));
			}
			if ((insert_stop == 0) && slv_xfer) {
				// Disable clock stretching for a I2C slave
				MICO_EFB_I2C_WRITE_CMDR (efb_address, MICO_EFB_I2C_CMDR_CKSDIS | MICO_EFB_I2C_CMDR_RD);
			}
		}else{
			MICO_EFB_I2C_WRITE_CMDR (efb_address, MICO_EFB_I2C_CMDR_RD);
		}
			
		// Wait until transfer is complete
		unsigned char sts5, sts6;
		do {
			MICO_EFB_I2C_READ_SR (efb_address, sts5);
			sts6 = sts5 & MICO_EFB_I2C_SR_TRRDY;
			if (sts6 == MICO_EFB_I2C_DATA_READY)
				break;
		} while (1);
		
		// Check if arbitration was lost
		unsigned char sts7;
		sts7 = sts5 & MICO_EFB_I2C_SR_ARBL;
		if ((slv_xfer == 0) && (sts7 == MICO_EFB_I2C_ARB_LOST)) {
			return (-2);
		}
		
		// Read incoming data byte
		MICO_EFB_I2C_READ_RXDR (efb_address, *data);
		
		if (i != buffersize){
			// Increment buffer pointer and loop iterator
			data++;
			i++;
		}else{
			// Exit when done
			break;
		}
	} while (1);
	
    return (0);
}

/*
 *****************************************************************************
 * Sets up timer configuration and starts timer.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char mode        : Timer mode
 *                                0 - Watchdog
 *                                1 - Clear Timer on Compare (CTC) Match
 *                                2 - Fast PWM
 *                                3 - Correct PWM
 *    unsigned char ocmode      : Timer counter output signal's mode
 *                                0 - Always zero
 *                                1 - Toggle on TOP match (non-PWM modes)
 *                                    Toggle on OCR match (Fast PWM mode)
 *                                    Toggle on OCR match (Correct PWM mode)
 *                                2 - Clear on TOP match (non-PWM modes)
 *                                    Clear on TOP match, set on OCR match (Fast PWM mode)
 *                                    Clear on OCR match when CNT incrementing, set on OCR match when CNT decrementing (Correct PWM mode)
 *                                3 - Set on TOP match (non-PWM modes)
 *                                    Set on TOP match, clear on OCR match (Fast PWM mode)
 *                                    Set on OCR match when CNT incrementing, clear on OCR match when CNT decrementing (Correct PWM mode)
 *    unsigned char sclk        : Clock source selection
 *                                0 - WISHBONE clock (rising edge)
 *                                2 - On-chip oscillator (rising edge)
 *                                4 - WISHBONE clock (falling edge)
 *                                6 - On-chip oscillator (falling edge)
 *    unsigned char cclk        : Divider selection
 *                                0 - Static 0
 *                                1 - sclk/1
 *                                1 - sclk/8
 *                                1 - sclk/64
 *                                1 - sclk/256
 *                                1 - sclk/1024
 *    unsigned char interrupt   : Enable (1) / Disable (0) interrupts
 *    unsigned int timerCount   : Timer TOP value (maximum 0xFFFF)
 *    unsigned int compareCount : Timer OCR (compare) value (maximum 0xFFFF)
 * 
 *****************************************************************************
 */
void MicoEFB_TimerStart (MicoEFBCtx_t *ctx,
							unsigned char mode,
							unsigned char ocmode,
							unsigned char sclk,
							unsigned char cclk,
							unsigned char interrupt,
							unsigned int timerCount,
							unsigned int compareCount)
{
	size_t efb_address = (size_t)(ctx->base);
	
	// Stop Timer
	MICO_EFB_TIMER_WRITE_CR2 (efb_address, (MICO_EFB_TIMER_CNT_RESET|MICO_EFB_TIMER_CNT_PAUSE));
	
	// Disable and clear interrupts
	MICO_EFB_TIMER_WRITE_IRQENR (efb_address, 0x00);
	MICO_EFB_TIMER_WRITE_IRQSR (efb_address, 0x0F);
	
	// Set up timer configuration
	MICO_EFB_TIMER_WRITE_CR0 (efb_address, (MICO_EFB_TIMER_GSRN_ENABLE | (cclk<<3) | sclk));
	MICO_EFB_TIMER_WRITE_CR1 (efb_address, (MICO_EFB_TIMER_TOP_USER_SELECT | (ocmode<<2) | mode));
	MICO_EFB_TIMER_SET_TOP (efb_address, timerCount);
	MICO_EFB_TIMER_SET_OCR (efb_address, compareCount);
	if (interrupt)
		MICO_EFB_TIMER_WRITE_IRQENR (efb_address, 0x0F);
	
	// Start timer
	MICO_EFB_TIMER_WRITE_CR2 (efb_address, 0x00);
}
/*
 *****************************************************************************
 * Initiate a byte transfer
 *
 * Arguments:
 *    size_t efb_address		 : EFB address
 *    unsigned char buffersize   : Number of bytes to be transfered. 
 *                                 (0 refers to 1 byte, 255 refers to 256 bytes) 
 *    unsigned char *data        : Data byte to transfer 
 *
 * Return Value:
 *    char:
 *         0 => status register contents after transfer of data
 *
 *****************************************************************************
 */


char MicoEFB_UFMTxData (size_t efb_address,			// EFB context
						unsigned char *data,		// Data byte to transfer
						unsigned char buffersize)	// Number of bytes to be transfered 
{
	volatile unsigned char sts1, sts2, sts3, sts4;

	// Transfer bytes from buffer
	unsigned char i = 0;
	do {
		// Wait until the Transmit FIFO is NOT full
		do {
			MICO_EFB_UFM_READ_SR(efb_address, sts1);
			sts2 = sts1 & MICO_EFB_UFM_SR_TXFF;
			if (sts2 != MICO_EFB_UFM_TX_FULL)
				break;
		} while (1);

		// Transfer byte
		MICO_EFB_UFM_WRITE_TXDR(efb_address, *data);
						
		if (i != buffersize){
			// Increment buffer pointer and loop iterator
			data++;
			i++;
		}else{
			// Wait until the Transmit FIFO is empty before exit
			do {
				MICO_EFB_UFM_READ_SR(efb_address, sts3);
				sts4 = sts3 & MICO_EFB_UFM_SR_TXFE;
				if (sts4 == MICO_EFB_UFM_TX_EMPTY)
					break;
			} while (1);
			// Exit if done
			break;
		}
	} while (1);
	return (0);
}

/*
 *****************************************************************************
 * Initiate a byte receive
 *
 * Arguments:
 *    size_t efb_address		 : EFB address
 *    unsigned char buffersize   : Number of bytes to be received. 
 *                                 (0 refers to 1 byte)
 *    unsigned char *data        : Data byte to receive (Not used in dummy mode)
 *
 * Return Value:
 *    char:
 *         0 => status register contents after receive of data
 *
 *****************************************************************************
 */

char MicoEFB_UFMRxData (size_t efb_address,			// EFB context
						unsigned char *data,		// Data byte to receive
						unsigned char buffersize)	// Number of bytes to be received (0 refers to 1 byte) 
{
	volatile unsigned char sts1, sts2;
	// Receive bytes from buffer
	unsigned char i = 0;
	do {
		// Wait until the Receive FIFO is NOT empty
		do {
			MICO_EFB_UFM_READ_SR(efb_address, sts1);
			sts2 = sts1 & MICO_EFB_UFM_SR_RXFE;
			if (sts2 != MICO_EFB_UFM_RX_EMPTY)
				break;
		} while (1);

		// Receive bytes
		MICO_EFB_UFM_READ_RXDR(efb_address, *data);

		if (i != buffersize){
			// Increment buffer pointer and loop iterator
			data++;
			i++;
		}else{
			// Exit if done
			break;
		}
	} while(1);
	return (0);
}

/*
 *****************************************************************************
 * Performs UFM Command Calls. (Only supports via WISHBONE)
 * 1. Initiate a open Frame signal prior to sending a new command
 * 2. Transfer the command (4 bytes opcode)
 * 3. Initiate a close frame signal and terminate the command  (optionally)
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			    : EFB context
 *    unsigned long opcode          : UFM 4 bytes opcode
 *    unsigned char enable          : Enable the WISHBONE close frame signal
 *
 * Return Value:
 *    char:
 *         0 => successful command calls
 *
 *****************************************************************************
 */

char MicoEFB_UFMCmdCall(MicoEFBCtx_t *ctx,			// EFB context
						unsigned long opcode,		// UFM 4 bytes opcode
						unsigned char enable)		// Enable the WISHBONE close frame signal
						
{
	size_t efb_address = (size_t)(ctx->base);
	volatile unsigned char sts;

	// Initiate a open Frame signal
	MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_ENABLE);

	// wait until SPI and I2C are inactive
	do {
		MICO_EFB_UFM_READ_SR(efb_address, sts);
		if ((sts & (MICO_EFB_UFM_SR_SSPIACT | MICO_EFB_UFM_SR_I2CACT)) == MICO_EFB_UFM_PORT_INACTIVE)
			break;
	} while (1);

	// Transfer opcode
	MicoEFB_UFMTxData (efb_address, (unsigned char *) &opcode, 3); //4 bytes opcode

	// Initiate a close frame signal
	if(enable){
		MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);
	}
	return (0);

}
/*
 *****************************************************************************
 * Erase the entire UFM sector
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx          : EFB context
 *
 * Return Value:
 *    char:
 *         0 => success
 *        -1 => Erase fails
 *****************************************************************************
 */
char MicoEFB_UFMErase (MicoEFBCtx_t *ctx)			// EFB context
{
	size_t efb_address = (size_t)(ctx->base);
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	unsigned int ufm_addr = ctx->ufm_addr;
	unsigned int ufm_mem = ctx->ufm_mem;
	#endif

	MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_ERASE_DATA, MICO_EFB_UFM_CLOSE_FRAME_ENABLE); // Open and Close the frame with Erase UFM opcode

	//Wait until the UFM is NOT busy and Check if Erase operation fails
	volatile unsigned long sts;
	do {
		MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_RD_SR, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read config. status opcode
		MicoEFB_UFMRxData (efb_address, (unsigned char *) &sts, 3);						// Receive the configuration status
		MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);					// Close the frame to terminate the command

		unsigned char status1 = __MicoEFB_HIGHER (sts);
		unsigned char status2 = status1 & 0x10;
		if (!(status2)) {																// Wait for Erase operation
			unsigned char status3 = __MicoEFB_HIGHER (sts);
			unsigned char status4 = status3 & 0x20;
			if (status4) {																// Check if Fail after Erase
				return (-1);
			} else {
				// Reset UFM address and exit
				#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
				ctx->ufm_addr = 0x0;
				ctx->ufm_mem = ufm_addr + ufm_mem;
				#endif
				return (0);
			}
		}

	} while (1);
}

/*
 *****************************************************************************
 * Set UFM sector to a specific address.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx          : EFB context
 *    unsigned int address       : 14 bits UFM Page address
 *
 * Return Value:
 *    char:
 *         0 => success
 *		  -1 => Invalid address
 *****************************************************************************
 */
char MicoEFB_UFMSetAddr (MicoEFBCtx_t *ctx,			// EFB context
						unsigned int address)		// 14 bits UFM Page address
{
	size_t efb_address = (size_t)(ctx->base);
	
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	unsigned int ufm_addr = ctx->ufm_addr;
	unsigned int ufm_mem = ctx->ufm_mem;

	// Check if the new address is valid
	unsigned char status = __MicoEFB_GT (address, (ufm_addr + ufm_mem - 1));
	if (status == 1)
		return (-1);
	#endif
	
	// Covert 14 bits page address of the UFM to 4 byte address
	unsigned char * p_addr = (unsigned char *) &address;
	unsigned char addr[] = {MICO_EFB_UFM_SET_UFM_SECTOR, 0x00, *(p_addr+1), *p_addr};

	MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_SET_ADDRESS, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);// Open the frame with set address opcode
	MicoEFB_UFMTxData (efb_address, (unsigned char *) &addr, 3);						// Transfer the 4 bytes address data
	MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);						// Close the frame to terminate the command
	
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	// Set UFM address and exit
	ctx->ufm_addr = address;
	ctx->ufm_mem = ufm_addr + ufm_mem - address;
	#endif
	
	return (0);
}

/*
 *****************************************************************************
 * Performs UFM sector reads, up to 16 pages at a time (Each page contains 16 bytes)
 * 1. Reads 1 page of dummy (this function will discard this page)
 * 2. Reads the actual data, up to 16 pages
 * Note: UFM only supports reading a full page (the received buffer must be a multiple of 16)
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx          : EFB context
 *    unsigned char *data        : Data byte to receive
 *    unsigned char pagesize     : Number of pages to be received. 
 *                                (0 refers to 1 page)
 *
 * Return Value:
 *    char:
 *         0 => read successfully
 *        -1 => invalid page size 
 *        -2 => read from invalid memory
 *****************************************************************************
 */
char MicoEFB_UFMRead (MicoEFBCtx_t *ctx,			// EFB context
					  	unsigned char *data,        // Buffer to put received data into
						unsigned char pagesize)     // Number of page to be received (0 refers to 1 byte) 
{
	size_t efb_address = (size_t)(ctx->base);
	
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	unsigned int ufm_addr = ctx->ufm_addr;
	unsigned int ufm_mem = ctx->ufm_mem;
	#endif
	
	// Check if page size is valid
	if (pagesize > 15){
		return (-1);
	}

	// Receive data from buffer 
	unsigned int num_page = (unsigned int) pagesize + 1;
//	unsigned int num_byte = (num_page << 4) - 1;
	unsigned int num_byte = __MicoEFB_ASHLHI3(num_page,4) - 1;								// Each Page has 16 bytes
	
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	// Check if address is valid
	if ((unsigned char)__MicoEFB_GT(num_page, ufm_mem)) {
		return (-2);
	}
	#endif
	
	// Read data opcode generation
	num_page = num_page + 1;																// Add an extra dummy page
	unsigned char * p_page = (unsigned char *) &num_page;
	unsigned char opcode[] = {(unsigned char) MICO_EFB_UFM_RD_DATA, MICOEFB_UFM_DUMMY_SETTING, *(p_page+1), *p_page};

	// Read data
	MicoEFB_UFMCmdCall(ctx, *(unsigned long*) &opcode, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read data opcode
	MicoEFB_UFMRxData (efb_address, data, (UFM_PAGE_BYTE - 1));								// Receive the 1 page dummy data
	MicoEFB_UFMRxData (efb_address, data, num_byte);										// Receive the actual data
	MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);							// Close the frame to terminate the command
	
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	// Update UFM address and exit
	ctx->ufm_addr = ufm_addr + num_page;
	ctx->ufm_mem = ufm_mem - num_page;
	#endif 
	
	return (0);
}

/*****************************************************************************
 * Performs UFM one page writes.(Each page contains 16 bytes)
 * Note: UFM only supports reading a full page (the transmit buffer must be a size of 16)
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx          : EFB context
 *    unsigned char *data        : Data byte to receive
 *
 * Return Value:
 *    char:
 *         0 => write successfully
 *        -1 => write to invalid memory  
 *****************************************************************************
 */

char MicoEFB_UFMWrite (MicoEFBCtx_t *ctx,			// EFB context
						unsigned char *data)        // Buffer containing the data to be transferred
{
	size_t efb_address = (size_t)(ctx->base);
	unsigned char status1, status2;
	
	// Check if the address is valid
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	if (__MicoEFB_GT(ctx->ufm_mem, 0)){
	#endif
		// Write the new data
		MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_WR_DATA, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read data opcode
		MicoEFB_UFMTxData (efb_address, data, (UFM_PAGE_BYTE - 1));							// Transfer one page data
		MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);						// Close the frame to terminate the command

		//Wait until the UFM is NOT busy and Check if Write operation fails
		volatile unsigned long sts;
		do {
			MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_RD_SR, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read config. status opcode
			MicoEFB_UFMRxData (efb_address, (unsigned char *) &sts, 3);						// Receive the configuration status
			MICO_EFB_UFM_WRITE_CR(efb_address, MICO_EFB_UFM_WBCE_DISABLE);					// Close the frame to terminate the command

			status1 = __MicoEFB_HIGHER (sts);
			if (!(status1 & 0x10)) {
				status2 = __MicoEFB_HIGHER (sts);
				if (status2 & 0x20) {
					return (-1);
				}else {
					#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
					// Update UFM address and exit
					ctx->ufm_addr++;
					ctx->ufm_mem--;
					#endif
					return (0);
				}
			}
		} while (1);
	#ifndef __MICOEFB_NO_UFM_ADDR_CHECK__
	}
	else{
		return (-1);
	}
	#endif
}
