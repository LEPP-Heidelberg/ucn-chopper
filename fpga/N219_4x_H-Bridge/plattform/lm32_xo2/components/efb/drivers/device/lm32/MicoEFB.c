/****************************************************************************
**
**  Description:
**        Implements functions for manipulating MachXO2 EFB.
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
#include "stdlib.h"
#include "DDStructs.h"
#include "MicoEFB.h"
#include "MicoMacros.h"
#include "MicoUtils.h"
#include "LatticeMico32.h"
#include "LookupServices.h"
#include "MicoInterrupts.h"

#ifdef __cplusplus
extern "C" {
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
void MicoEFB_ISR (unsigned int intrLevel, void *ctx)
{
	MicoEFBCtx_t *efb = (MicoEFBCtx_t *) ctx ;
	MicoEFB_t *device = (MicoEFB_t *) (efb->base) ;
	
	volatile unsigned char irq0 ;
	irq0 = device->irq0 ;
	if (irq0 & 0x01) {
		I2CDesc_t *desc = (I2CDesc_t *)efb->desc_i2c1 ;
		desc->onCompletion(efb) ;
		device->irq0 = 0x01 ;
	}
	if (irq0 & 0x02) {
		I2CDesc_t *desc = (I2CDesc_t *)efb->desc_i2c2 ;
		if ((desc != 0) && (desc->onCompletion != 0))
			desc->onCompletion(efb) ;
		device->irq0 = 0x02 ;
	}
	if (irq0 & 0x04) {
		SPIDesc_t *desc = (SPIDesc_t *)efb->desc_spi ;
		if ((desc != 0) && (desc->onCompletion != 0))
			desc->onCompletion(efb) ;
		device->irq0 = 0x04 ;
	}
	if (irq0 & 0x08) {
		TCDesc_t *desc = (TCDesc_t *)efb->desc_tc ;
		if ((desc != 0) && (desc->onCompletion != 0))
			desc->onCompletion(efb) ;
		device->irq0 = 0x08 ;
	}
	if (irq0 & 0x10) {
		WBCFGDesc_t *desc = (WBCFGDesc_t *)efb->desc_wbcfg ;
		if ((desc != 0) && (desc->onCompletion != 0))
			desc->onCompletion(efb) ;
		device->irq0 = 0x10 ;
	}
}


#ifdef __cplusplus
}
#endif

/*
 *****************************************************************************
 * EFB initialization.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 *****************************************************************************
 */
void MicoEFBInit (MicoEFBCtx_t *ctx)
{
	MicoEFB_t *device = (MicoEFB_t *)(ctx->base) ;
	
	// Disable and clear all interrupts (should be enabled by user as required)
	device->i2c_1st_irqenr = 0x0 ;
	device->i2c_1st_irqsr = 0xF ;
	
	device->i2c_2nd_irqenr = 0x0 ;
	device->i2c_2nd_irqsr = 0xF ;
	
	device->spi_irqenr = 0x0 ;
	device->spi_irqsr = 0xF ;
	
	device->tc_cr2 = MICO_EFB_TIMER_CNT_RESET|MICO_EFB_TIMER_CNT_PAUSE ;
	device->tc_irqenr = 0x0 ;
	device->tc_irqsr = 0x7 ;  
	
	device->irq0 = 0x1F ;
	
	// Initialize descriptors to null
	
	// Initialize I2C 1 descriptor
	I2CDesc_t *i2c1 = (I2CDesc_t *) malloc (sizeof (I2CDesc_t)) ;
	I2CData_t *i2c1_data = (I2CData_t *) malloc (sizeof (I2CData_t)) ;
	i2c1->data = i2c1_data ;
	i2c1->onCompletion = MicoEFB_I2C1ISR ;
	ctx->desc_i2c1 = i2c1 ;
	ctx->user_i2c1 = 0 ;
	
	// Initialize I2C 2 descriptor
	I2CDesc_t *i2c2 = (I2CDesc_t *) malloc (sizeof (I2CDesc_t)) ;
	I2CData_t *i2c2_data = (I2CData_t *) malloc (sizeof (I2CData_t)) ;
	i2c2->data = i2c2_data ;
	i2c2->onCompletion = MicoEFB_I2C2ISR ;
	ctx->desc_i2c2 = i2c2 ;
	ctx->user_i2c2 = 0 ;
	
	// Initialize SPI descriptor
	SPIDesc_t *spi = (SPIDesc_t *) malloc (sizeof (SPIDesc_t)) ;
	SPIData_t *spi_data = (SPIData_t *) malloc (sizeof (SPIData_t)) ;
	spi->data = spi_data ;
	spi->onCompletion = MicoEFB_SPIISR ;
	ctx->desc_spi = spi ;
	ctx->user_spi = 0 ;
	
	ctx->desc_tc = 0 ;
	ctx->desc_wbcfg = 0 ;
	
    // Register ISR for this EFB 
    MicoRegisterISR(ctx->intrLevel, ctx, MicoEFB_ISR) ;
	
    // Register this instance of EFB 
    ctx->lookupReg.name = ctx->name ;
    ctx->lookupReg.deviceType = "EFBDevice" ;
    ctx->lookupReg.priv = ctx ;
	MicoRegisterDevice( &(ctx->lookupReg) ) ;
    return ;
}

/*
 *****************************************************************************
 * Mapping I2C 1 interrupt descriptor to the current instance of EFB
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    I2CDesc_t *i2c            : I2C descriptor
 *
 *****************************************************************************
 */
void MicoEFB_RegisterI2C1ISR (MicoEFBCtx_t *ctx, I2CDesc_t *i2c)
{
	ctx->desc_i2c1 = i2c ;
	ctx->user_i2c1 = 1 ;
}

/*
 *****************************************************************************
 * Mapping I2C 2 interrupt descriptor to the current instance of EFB
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    I2CDesc_t *i2c            : I2C descriptor
 *
 *****************************************************************************
 */
void MicoEFB_RegisterI2C2ISR (MicoEFBCtx_t *ctx, I2CDesc_t *i2c)
{
	ctx->desc_i2c2 = i2c ;
	ctx->user_i2c2 = 1 ;
}

/*
 *****************************************************************************
 * Mapping SPI interrupt descriptor to the current instance of EFB
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    SPIDesc_t *spi            : SPI descriptor
 *
 *****************************************************************************
 */
void MicoEFB_RegisterSPIISR (MicoEFBCtx_t *ctx, SPIDesc_t *spi)
{
	ctx->desc_spi = spi ;
	ctx->user_spi = 1 ;
}

/*
 *****************************************************************************
 * Mapping Timer/Counter interrupt descriptor to the current instance of EFB
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    TCDesc_t *tc              : Timer/Counter descriptor
 *
 *****************************************************************************
 */
void MicoEFB_RegisterTimerISR (MicoEFBCtx_t *ctx, TCDesc_t *tc)
{
	ctx->desc_tc = tc ;
}

/*
 *****************************************************************************
 * Mapping Configuration interrupt descriptor to the current instance of EFB
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    WBCFGDesc_t *cfg          : Configuration descriptor
 *
 *****************************************************************************
 */
void MicoEFB_RegisterWBCFGISR (MicoEFBCtx_t *ctx, WBCFGDesc_t *cfg)
{
	ctx->desc_wbcfg = cfg ;
}

/*
 *****************************************************************************
 * Implementation of default SPI Interrupt Handler. It can be overridden by
 * the customer by invoking MicoEFB_RegisterSPIISR() function. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    TCDesc_t *tc              : Timer/Counter descriptor
 *
 *****************************************************************************
 */
void MicoEFB_SPIISR (MicoEFBCtx_t *ctx)
{
	MicoEFB_t *device = (MicoEFB_t *)(ctx->base) ;
	SPIDesc_t *desc   = (SPIDesc_t *)(ctx->desc_spi) ;
	SPIData_t *data   = (SPIData_t *)(desc->data) ;
	
	// Release interrupt request
	device->spi_irqsr = 0x08 ;
	
	// Capture received byte and store in RX buffer
	*((unsigned char *)data->rxBuffer) = device->spi_rxdr ;
	
	data->idx++ ;
	if (data->idx == data->size) {
		// Reached end of transfer. Disable interrupts.
		device->spi_irqenr = 0x00 ;
		if (data->stop) {
			// Disable SPI clock.
			device->spi_cr2 = MICO_EFB_SPI_CR2_MSTR ;
		}
		// Indicate to application that transfer is complete.
		data->done = 1 ;
	} else {
		// Increment TX/RX buffer pointers and transmit next byte of transfer.
		data->rxBuffer++ ;
		data->txBuffer++ ;
		device->spi_txdr = *((unsigned char *) data->txBuffer) ;
	}
}

/*
 *****************************************************************************
 * Check if the SPI transfer has been completed. This function should only be
 * used when the Lattice-provided SPI interrupt handler is used. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 * Returns:
 *    0                         : Transfer is in progress
 *    1                         : Transfer is complete
 *   -1                         : Error. Cannot determine completion of 
 *                                transfer for a user SPI interrupt handler.
 *
 *****************************************************************************
 */
char MicoEFB_SPIXferDone (MicoEFBCtx_t *ctx) 
{
	if (ctx->user_spi)
		return -1 ;
	SPIDesc_t *desc = (SPIDesc_t *)(ctx->desc_spi) ;
	SPIData_t *data = (SPIData_t *)(desc->data) ;
	return data->done ;
}

/*
 *****************************************************************************
 * Initiate a SPI transfer that receives and transmits a configurable number 
 * of bytes.
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char isMaster	: Master (1) or Slave (0)
 *    unsigned char insertStart	: Assert chip select at start of transfer
 *    unsigned char insertStop	: Deassert chip select at enf of transfer
 *    unsigned char *txBuffer	: Bytes to be transmitted
 *    unsigned char *rxBuffer	: Bytes received
 *    unsigned int  bufferSize	: Number of bytes to transfer.
 *    unsigned int  irqmode     : Interrupt-driven (1) or Polling (0) 
 *    unsigned int  userirq     : User-implemented IRQ routine
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
							unsigned int  bufferSize,
							unsigned int  irqmode)
{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
	// Is SPI busy?
	unsigned char sts ;
	do {
		sts = device->spi_sr ;
		if ((sts & MICO_EFB_SPI_SR_TIP) == 0)
			break ;
	} while (1) ;
	
	// Set SPI mode (master or slave)
	if (isMaster) {
		if (insertStart) {
			// Modify baudrate to atleast 6x slower that WISHBONE clock (ECP4 limitation)
			device->spi_br = 0x6 ;
			// Set up SPI in master mode and turn on clock disable
			device->spi_csr = ~(0x1<<slvIndex) ;
			device->spi_cr2 = MICO_EFB_SPI_CR2_MSTR | MICO_EFB_SPI_CR2_MCSH ;
		}
	} else {
		device->spi_cr2 = 0x00 ;
	} 
	
	if (irqmode) {
		if (ctx->user_spi == 0) {
			// Set up SPI Interrupt Descriptor
			SPIDesc_t *desc = (SPIDesc_t *)(ctx->desc_spi) ;
			SPIData_t *data = (SPIData_t *)(desc->data) ;
			data->rxBuffer = rxBuffer ;
			data->txBuffer = txBuffer ;
			data->size = bufferSize ;
			data->stop = insertStop ;
			data->done = 0 ;
			data->idx = 1 ;
		}
		// Clear existing interrupts prior to enabling interrupts
		device->spi_irqsr = 0x1f ;
		device->spi_irqenr = 0x08 ;
		// Is the controller ready to transmit another byte
		do {
			sts = device->spi_sr ;
			 if (sts & MICO_EFB_SPI_SR_TRDY)
			 	break ;
		} while (1) ;
		// Transmit first byte
		device->spi_txdr = *txBuffer ;
	} else {
		unsigned int xferCount = 1 ;
		do {
			// Is the controller ready to transmit another byte
			do {
				sts = device->spi_sr ;
				if (sts & MICO_EFB_SPI_SR_TRDY)
					break ;
			} while (1) ;
			// Transmit byte
			device->spi_txdr = *txBuffer ;
			// Is the controller ready with received byte
			do {
				sts = device->spi_sr;
				if (sts & MICO_EFB_SPI_SR_RRDY)
					break ;
			} while (1) ;
			// Get received byte
			*rxBuffer = device->spi_rxdr ;
			
			if (xferCount == bufferSize)
				break ;
			
			txBuffer++ ;
			rxBuffer++ ;
			xferCount++ ;
		} while (1) ;
		
		// End transaction
		if (isMaster && insertStop) {
			device->spi_cr2 = MICO_EFB_SPI_CR2_MSTR ;
		}
	}	
	return (0) ;
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
    volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
    // Check if transmit register is empty?
    volatile unsigned char sts ;
    do {
        sts = device->spi_sr ;
        if ((sts & MICO_EFB_SPI_SR_TRDY) != 0) 
        	break ;
    } while (1) ;
    
    // Write byte to transmit register
    device->spi_txdr = data ;
    
    return sts ;
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
    volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
    // Check if receive register is full?
    volatile unsigned char sts ;
    do {
        sts = device->spi_sr ;
        if ((sts & MICO_EFB_SPI_SR_RRDY) != 0) 
        	break ;
    } while (1) ;
    
    // Get byte from receive register
    *data = device->spi_rxdr ;
    
    return sts ;
}

/*
 *****************************************************************************
 * Implementation of default I2C Interrupt Handler. The default implementation
 * can be overridden by the customer by invoking MicoEFB_RegisterI2C1ISR() 
 * function. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 *****************************************************************************
 */
void MicoEFB_I2C1ISR (MicoEFBCtx_t *ctx) 
{
	MicoEFB_I2CISR (ctx, 1) ;
}

/*
 *****************************************************************************
 * Implementation of default I2C Interrupt Handler. The default implementation
 * can be overridden by the customer by invoking MicoEFB_RegisterI2C2ISR() 
 * function. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 *****************************************************************************
 */
void MicoEFB_I2C2ISR (MicoEFBCtx_t *ctx) 
{
	MicoEFB_I2CISR (ctx, 2) ;
}

/*
 *****************************************************************************
 * Implementation of default I2C Interrupt Handler.  
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char i2c_idx     : I2C 1 or 2
 *
 *****************************************************************************
 */
void MicoEFB_I2CISR (MicoEFBCtx_t *ctx, unsigned char i2c_idx)
{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
	I2CDesc_t *desc = (i2c_idx == 1) ? (I2CDesc_t *)(ctx->desc_i2c1) : (I2CDesc_t *)(ctx->desc_i2c2) ;
	I2CData_t *data = (I2CData_t *)(desc->data) ;
	
	// Clear interrupts
	if (i2c_idx == 1) 
		device->i2c_1st_irqsr = 0x0F ;
	else
		device->i2c_2nd_irqsr = 0x0F ;
		
	if (data->read) {
		
//		// Check if arbitration was lost
//		sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
//		if ((data->slv_xfer == 0) && ((sts & MICO_EFB_I2C_SR_ARBL) == MICO_EFB_I2C_ARB_LOST)) {
//			data->done = 1 ;
//			data->error = 0 ;
//		}
		
		// Read incoming data byte
		*data->data = (i2c_idx == 2) ? device->i2c_2nd_rxdr : device->i2c_1st_rxdr ;
		
		if (data->idx == data->buffersize) {
			data->done = 1 ;
			data->error = 0 ;
		} else {
			data->idx++ ;
			data->data++ ;
			
			// Handling for last byte
			if (data->idx == data->buffersize) {
				if (data->insert_stop && (data->slv_xfer == 0)) {
					// I2C Master: Issue NACK, CKSDIS, and STO command
					if (i2c_idx == 2) {
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_STO | MICO_EFB_I2C_CMDR_CKSDIS | MICO_EFB_I2C_CMDR_NACK ;
					} else {
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_STO | MICO_EFB_I2C_CMDR_CKSDIS | MICO_EFB_I2C_CMDR_NACK ;
					}
				}
				if ((data->insert_stop == 0) && data->slv_xfer) {
					// I2C Slave: Issue CKSDIS
					if (i2c_idx == 2) {
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					} else {
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					}
				}
			}
		}
				
	} else {
//		// Check if acknowledge is rcvd
//		if (data->slv_xfer && (data->insert_stop == 0) && (data->idx == data->buffersize)) {
//			// If I2C is slave, it does not expect an acknowledge on the last transfer.
//			;
//		} else {
//			if ((sts & MICO_EFB_I2C_SR_RARC) == MICO_EFB_I2C_ACK_NOT_RCVD) {
//				data->done = 1 ;
//				data->error = 1 ;
//			}
//		}
//		
//		// Check if arbitration was lost
//		if ((data->slv_xfer == 0) && ((sts & MICO_EFB_I2C_SR_ARBL) == MICO_EFB_I2C_ARB_LOST)) {
//			data->done = 1 ;
//			data->error = 1 ;
//		}
		
		if (data->idx > data->buffersize) {
			if (data->insert_stop && (data->slv_xfer == 0)) {
				// Issue STOP command for a I2C master
				if (i2c_idx == 2)
					device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_STO ;
				else
					device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_STO ;
			}
			if ((data->insert_stop == 0) && data->slv_xfer) {
				// Disable clock stretching for a I2C slave
				if (i2c_idx == 2)
					device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
				else
					device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
				// MicoSleepMicroSecs(50) ;
			}
			
			// Indicate that transfer is complete and successful 
			data->done = 1 ;
			data->error = 0 ;
		} else {
			if (i2c_idx == 2) {
				device->i2c_2nd_txdr = *data->data ;
				device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_WR ;
			} else {
				device->i2c_1st_txdr = *data->data ;
				device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_WR ;
			}
			data->idx++ ;
			data->data++ ;
		}
	}
	
	// Disable interrupts when all bytes have been transferred
	if (data->done) {
		if (i2c_idx == 1) 
			device->i2c_1st_irqenr = 0x0 ;
		else
			device->i2c_2nd_irqenr = 0x0 ;
	}
}

/*
 *****************************************************************************
 * Check if the I2C transfer has been completed. This function should only be
 * used when the Lattice-provided I2C interrupt handler is used. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 * Returns:
 *    0                         : Transfer is in progress
 *    1                         : Transfer is complete
 *   -1                         : Error. Cannot determine completion of 
 *                                transfer for a user I2C interrupt handler.
 *
 *****************************************************************************
 */
char MicoEFB_I2C1XferDone (MicoEFBCtx_t *ctx) 
{
	if (ctx->user_i2c1)
		return -1 ;
	I2CDesc_t *desc = (I2CDesc_t *)(ctx->desc_i2c1) ;
	I2CData_t *data = (I2CData_t *)(desc->data) ;
	return data->done ;
}

/*
 *****************************************************************************
 * Check if the I2C transfer has been completed. This function should only be
 * used when the Lattice-provided I2C interrupt handler is used. 
 *
 * Arguments:
 *    MicoEFBCtx_t *ctx			: EFB context
 *
 * Returns:
 *    0                         : Transfer is in progress
 *    1                         : Transfer is complete
 *   -1                         : Error. Cannot determine completion of 
 *                                transfer for a user I2C interrupt handler.
 *
 *****************************************************************************
 */
char MicoEFB_I2C2XferDone (MicoEFBCtx_t *ctx) 
{
	if (ctx->user_i2c2)
		return -1 ;
	I2CDesc_t *desc = (I2CDesc_t *)(ctx->desc_i2c2) ;
	I2CData_t *data = (I2CData_t *)(desc->data) ;
	return data->done ;
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
						unsigned char i2c_idx,	// I2C 1 or 2
						unsigned char read,		// Write (0) or Read (1) 
						unsigned char address,	// Slave address
						unsigned char restart)  // Repeated start (1)
{
    volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
    
	// Check if I2C is busy with another transaction?
	volatile unsigned char sts ;
	if (restart == 0) {
		do {
			sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
			if ((sts & MICO_EFB_I2C_SR_BUSY) == MICO_EFB_I2C_FREE)
				break ;
		} while (1) ;
	}
	
	// Load slave address and setup write to transmit the address
	if (i2c_idx == 2) {
		device->i2c_2nd_txdr = (address << 1) | read ;
		device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_STA | MICO_EFB_I2C_CMDR_WR ;
	} else {
		device->i2c_1st_txdr = (address << 1) | read ;
		device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_STA | MICO_EFB_I2C_CMDR_WR ;
	}
	MicoSleepMicroSecs(50) ;
	
//	// Check if transmission is in progress?
//	do {
//		sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
//		if ((sts & MICO_EFB_I2C_SR_TIP) == MICO_EFB_I2C_TRANSMISSION_DONE)
//			break ; 
//	} while (1) ;
//	
//	// Check if acknowledge is rcvd
//	if ((sts & MICO_EFB_I2C_SR_RARC) == MICO_EFB_I2C_ACK_NOT_RCVD) {
//		return (-1) ;
//	}
//	
//	// Check if arbitration was lost
//	if ((sts & MICO_EFB_I2C_SR_ARBL) == MICO_EFB_I2C_ARB_LOST) {
//		return (-2) ;
//	}
	
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
 *    MicoEFBCtx_t *ctx			: EFB context
 *    unsigned char i2c_idx		: I2C 1 (1) or 2 (2)
 *    unsigned char slv_xfer	: I2C Master (0) or I2C Slave (1)
 *    unsigned int  buffersize  : Number of bytes to be transferred. 
 *    unsigned char *data		: Pointer to bytes to write
 *    unsigned char address		: Slave device address
 *    unsigned char insert_start: Insert START command prior to block transfer
 *    unsigned char insert_stop : Insert STOP command after the block transfer 
 *                                for I2C Master. Enable clock stretching 
 *                                after the block transfer for I2C Slave.
 *    unsigned char irqmode     : Use interrupt-driven (1) or polling (0) mode
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
						unsigned int  buffersize,     // Number of bytes to be transfered (min 1 and max 256) 
						unsigned char *buffer,        // Buffer containing the data to be transferred
						unsigned char insert_start,   // Master: Insert Start (or repeated Start) prior to data transfer
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer 
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address,		  // Slave address
						unsigned char irqmode)        // Use interrupts
{
    volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base);
	
	unsigned char sts ;
	if ((slv_xfer == 0) && insert_start) {
		sts = MicoEFB_I2CStart (ctx, i2c_idx, MICO_EFB_I2C_WR_SEQUENCE, address, insert_restart);
		if (sts != 0)
			return sts ;
	}
	
	if (irqmode) {
		// If the customer is using Lattice-provided interrupt handler, then
		// set up the interrupt descriptor
		if (((i2c_idx == 1) && (ctx->user_i2c1 == 0))
			|| ((i2c_idx == 2) && (ctx->user_i2c2 == 0))) {
			
			I2CDesc_t *desc = (i2c_idx == 1) ? (I2CDesc_t *)(ctx->desc_i2c1) : (I2CDesc_t *)(ctx->desc_i2c2) ;
			I2CData_t *data = (I2CData_t *)(desc->data) ;
			data->i2c_idx = i2c_idx ;
			data->slv_xfer = slv_xfer ;
			data->data = buffer ;
			data->read = 0 ;
			data->buffersize = buffersize ;
			data->insert_stop = insert_stop ;
			data->idx = 1 ;
			data->done = 0 ;
			data->error = 0 ;
		}
		// Enabling interrupts
		device->i2c_2nd_irqenr = 0x0F ;
		
	} else {
		// Main loop to perform transfers
		unsigned int i = 1 ;
		do {
			// Wait until transmit buffer can accept another byte
			do {
				sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
				if ((sts & MICO_EFB_I2C_SR_TRRDY) == MICO_EFB_I2C_DATA_READY)
					break ;
			} while (1) ;
			
//			// Check if acknowledge is rcvd
//			if (slv_xfer && (insert_stop == 0) && (i == buffersize)) {
//				// If I2C is slave, it does not expect an acknowledge on the last transfer.
//				;
//			} else {
//				if ((sts & MICO_EFB_I2C_SR_RARC) == MICO_EFB_I2C_ACK_NOT_RCVD) {
//					return (-1) ;
//				}
//			}
//			
//			// Check if arbitration was lost
//			if ((slv_xfer == 0) && ((sts & MICO_EFB_I2C_SR_ARBL) == MICO_EFB_I2C_ARB_LOST)) {
//				return (-2) ;
//			}
			
			// Transmit a byte
			if (i2c_idx == 2) {
				device->i2c_2nd_txdr = *buffer ;
				device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_WR ;
			} else {
				device->i2c_1st_txdr = *buffer ;
				device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_WR ;
			}
			// MicoSleepMicroSecs(50) ;
			
			if (i == buffersize) {
				do {
					sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
					if ((sts & MICO_EFB_I2C_SR_TRRDY) == MICO_EFB_I2C_DATA_READY)
						break ;
				} while (1) ;
				if (insert_stop && (slv_xfer == 0)) {
					// Issue STOP command for a I2C master
					if (i2c_idx == 2)
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_STO ;
					else
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_STO ;
					// MicoSleepMicroSecs(50) ;
				}
				
				if ((insert_stop == 0) && slv_xfer) {
					// Disable clock stretching for a I2C slave
					if (i2c_idx == 2)
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					else
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					// MicoSleepMicroSecs(50) ;
				}
				break ;
			}
			i++ ;
			buffer++ ;
		} while (1) ;	
	}
	return (0) ;
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
 *    unsigned int  buffersize     : Number of bytes to be transferred. 
 *    unsigned char *data		   : Pointer to buffer in which rcvd bytes are put
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
						unsigned int  buffersize,     // Number of bytes to be received (min 1 and max 256) 
						unsigned char *buffer,        // Buffer to put received data in to
						unsigned char insert_start,   // Master: Insert Start (or repeated Start) prior to data transfer  
						unsigned char insert_restart, // Master: Insert Repeated Start prior to data transfer
						unsigned char insert_stop,    // Master: Insert Stop at end of data transfer. Slave: Stretch clock at end of transfer.
						unsigned char address,		  // Slave address
						unsigned char irqmode)		  // Interrupt driven (1) or polling (0)
						
{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
	unsigned char sts ;
	if ((slv_xfer == 0) && insert_start) {
		sts = MicoEFB_I2CStart (ctx, i2c_idx, MICO_EFB_I2C_RD_SEQUENCE, address, insert_restart) ;
		if (sts != 0)
			return sts ;
		
		// Wait for SRW
		do {
			sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
			if ((sts & MICO_EFB_I2C_SR_SRW) == MICO_EFB_I2C_SR_SRW) {
				break ;
			}
		} while (1) ;
	}
	
	// Set up for a Read
	if (slv_xfer) {
		// I2C is in slave mode; enable clock stretching
		if (i2c_idx == 2) {
			device->i2c_2nd_cmdr =  0x00;
		} else {
			device->i2c_1st_cmdr =  0x00;
		}
	} else {
		// I2C is in master mode; set up in read mode
		if (i2c_idx == 2) {
			device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_RD ;
		} else {
			device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_RD ;
		}
	}
		
	if (irqmode) {
		// If the customer is using Lattice-provided interrupt handler,
		// then set up the interrupt descriptor
		if (((i2c_idx == 1) && (ctx->user_i2c1 == 0))
			|| ((i2c_idx == 2) && (ctx->user_i2c2 == 0))) {
			
			I2CDesc_t *desc = (i2c_idx == 1) ? (I2CDesc_t *)(ctx->desc_i2c1) : (I2CDesc_t *)(ctx->desc_i2c2) ;
			I2CData_t *data = (I2CData_t *)(desc->data) ;
			data->i2c_idx = i2c_idx ;
			data->slv_xfer = slv_xfer ;
			data->data = buffer ;
			data->read = 1 ;
			data->buffersize = buffersize ;
			data->insert_stop = insert_stop ;
			data->idx = 1 ;
			data->done = 0 ;
			data->error = 0 ;
		}
		// Enabling interrupts
		device->i2c_2nd_irqenr = 0x0F ;
		
	} else {
		
		unsigned int idx = 1 ;
		do {
			// Special handling for last byte of data to read
			if (idx == buffersize) {
				if (insert_stop && (slv_xfer == 0)) {
					// I2C Master: Issue NACK, CKSDIS, and STO command
					if (i2c_idx == 2) {
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_STO | MICO_EFB_I2C_CMDR_CKSDIS | MICO_EFB_I2C_CMDR_NACK ;
					} else {
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_STO | MICO_EFB_I2C_CMDR_CKSDIS | MICO_EFB_I2C_CMDR_NACK ;
					}
				}
				if ((insert_stop == 0) && slv_xfer) {
					// I2C Slave: Issue CKSDIS
					if (i2c_idx == 2) {
						device->i2c_2nd_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					} else {
						device->i2c_1st_cmdr = MICO_EFB_I2C_CMDR_CKSDIS ;
					}
				}
			}
			do {
				sts = (i2c_idx == 2) ? device->i2c_2nd_sr : device->i2c_1st_sr ;
				if ((sts & MICO_EFB_I2C_SR_TRRDY) == MICO_EFB_I2C_DATA_READY)
					break ;
			} while (1) ;
			
//			// Check if arbitration was lost
//			if ((slv_xfer == 0) && ((sts & MICO_EFB_I2C_SR_ARBL) == MICO_EFB_I2C_ARB_LOST)) {
//				return (-2) ;
//			}
			
			// Read incoming data byte
			*buffer = (i2c_idx == 2) ? device->i2c_2nd_rxdr : device->i2c_1st_rxdr ;
			
			if (idx == buffersize) 
				break ;
			
			// Increment buffer pointer and loop iterator
			idx++ ; 
			buffer++ ;
		} while (1) ;
	}
	
    return (0) ;
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
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	
	// Stop Timer
	device->tc_cr2 = MICO_EFB_TIMER_CNT_RESET|MICO_EFB_TIMER_CNT_PAUSE ;
	
	// Disable and clear interrupts
	device->tc_irqenr = 0x00 ;
	device->tc_irqsr = 0x0F ;
	
	// Set up timer configuration
	device->tc_cr0 = MICO_EFB_TIMER_GSRN_ENABLE | (cclk<<3) | sclk ;
	device->tc_cr1 = MICO_EFB_TIMER_TOP_USER_SELECT | (ocmode<<2) | mode ;
	device->tc_top_set_lo = (unsigned char) timerCount ;
	device->tc_top_set_hi = (unsigned char) (timerCount>>8) ;
	device->tc_ocr_set_lo = (unsigned char) compareCount ;
	device->tc_ocr_set_hi = (unsigned char) (compareCount>>8) ;
	if (interrupt)
		device->tc_irqenr = 0x0F ;
	
	// Start timer
	device->tc_cr2 = 0x00 ;
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


char MicoEFB_UFMTxData (MicoEFBCtx_t *ctx,			// EFB context
						unsigned char *data,		// Data byte to transfer
						unsigned char buffersize)	// Number of bytes to be transfered
{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned char status ;
	// Transfer bytes from buffer
	unsigned char i = 0 ;
	do {
		// Wait until the Transmit FIFO is NOT full
		do {
			status = device->wbcfg_sr ;
			status = status & MICO_EFB_UFM_SR_TXFF ;
			if (status != MICO_EFB_UFM_TX_FULL)
				break ;
		} while (1) ;

		// Transfer byte
		device->wbcfg_txdr = *data ;
		if (i != buffersize) {
			// Increment buffer pointer and loop iterator
			data++ ;
			i++ ;
		} else {
			// Wait until the Transmit FIFO is empty before exit
			do {
				status = device->wbcfg_sr ;
				status = status & MICO_EFB_UFM_SR_TXFE ;
				if (status == MICO_EFB_UFM_TX_EMPTY)
					break ;
			} while (1) ;
			// Exit if done
			break ;
		}
	} while (1) ;

	return (0) ;
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

char MicoEFB_UFMRxData (MicoEFBCtx_t *ctx,			// EFB context
						unsigned char *data,		// Data byte to receive
						unsigned char buffersize)	// Number of bytes to be received (0 refers to 1 byte)
{

	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned char status ;
	// Receive bytes from buffer
	unsigned char i = 0 ;
	do {
		// Wait until the Receive FIFO is NOT empty
		do {
			status = device->wbcfg_sr ;
			status = status & MICO_EFB_UFM_SR_RXFE ;
			if (status != MICO_EFB_UFM_RX_EMPTY)
				break ;
		} while (1) ;

		// Receive bytes
		*data = device->wbcfg_rxdr ;
		if (i != buffersize) {
			// Increment buffer pointer and loop iterator
			data++ ;
			i++ ;
		} else {
			// Exit if done
			break ;
		}
	} while(1) ;

	return (0) ;
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

char MicoEFB_UFMCmdCall (MicoEFBCtx_t *ctx,				// EFB context
							unsigned long opcode,		// UFM 4 bytes opcode
							unsigned char enable)		// Enable the WISHBONE close frame signal

{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned char status ;

	// Initiate a open Frame signal
	device->wbcfg_cr = MICO_EFB_UFM_WBCE_ENABLE ;

	// wait until SPI and I2C are inactive
	do {
		status = device->wbcfg_sr ;
		if ((status & (MICO_EFB_UFM_SR_SSPIACT | MICO_EFB_UFM_SR_I2CACT)) == MICO_EFB_UFM_PORT_INACTIVE)
			break ;
	} while (1) ;

	// Transfer opcode
	MicoEFB_UFMTxData (ctx, (unsigned char *) &opcode, 3) ; //4 bytes opcode

	// Initiate a close frame signal
	if (enable) {
		device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;
	}
	return (0) ;

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
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned int ufm_addr = ctx->ufm_addr ;
	unsigned int ufm_mem = ctx->ufm_mem ;

	MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_ERASE_DATA, MICO_EFB_UFM_CLOSE_FRAME_ENABLE) ; // Open and Close the frame with Erase UFM opcode

	//Wait until the UFM is NOT busy and Check if Erase operation fails
	unsigned int status ;
	do {
		MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_RD_SR, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read config. status opcode
		MicoEFB_UFMRxData(ctx, (unsigned char *) &status, 3) ;	// Receive the configuration status
		device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;	// Close the frame to terminate the command

		if (!(status & 0x1000)) {
			if (status & 0x2000) {
				return (-1) ;
			} else {
				// Reset UFM address and exit
				ctx->ufm_addr = 0x0 ;
				ctx->ufm_mem = ufm_addr + ufm_mem ;
				return (0) ;
			}
		}
	} while (1) ;
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
							unsigned int address)	// 14 bits UFM Page address
{
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned int ufm_addr = ctx->ufm_addr;
	unsigned int ufm_mem = ctx->ufm_mem;

	// Check if the new address is valid
	if (address > (ufm_addr + ufm_mem - 1))
		return (-1) ;

	// Covert 14 bits page address of the UFM to 4 byte address
	// unsigned char *p_addr = (unsigned char *) &address;
	//unsigned char addr[] = {MICO_EFB_UFM_SET_UFM_SECTOR, 0x00, *(p_addr+1), *p_addr};
	unsigned int addr = MICO_EFB_UFM_SET_UFM_SECTOR + address;

	MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_SET_ADDRESS, MICO_EFB_UFM_CLOSE_FRAME_DISABLE); // Open the frame with set address opcode
	MicoEFB_UFMTxData(ctx, (unsigned char *) &addr, 3);	// Transfer the 4 bytes address data
	device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;	// Close the frame to terminate the command

	// Set UFM address and exit
	ctx->ufm_addr = address;
	ctx->ufm_mem = ufm_addr + ufm_mem - address;
	return (0);
}

/*
 *****************************************************************************
 * Performs UFM sector reads, up to 256 pages at a time (Each page contains
 * 16 bytes)
 * 1. Reads 1 page of dummy (this function will discard this page)
 * 2. Reads the actual data, up to 256 pages
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
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;
	unsigned int ufm_addr = ctx->ufm_addr;
	unsigned int ufm_mem = ctx->ufm_mem;

	// Receive data from buffer
	unsigned int num_page = (unsigned int) pagesize + 1;
	unsigned int num_byte = (num_page << 4) - 1;

	// Check if address is valid
	if (num_page > ufm_mem)
		return (-2);

	// Read data opcode generation
	num_page = num_page + 1;																// Add an extra dummy page
	//unsigned char *p_page = (unsigned char *) &num_page;
	//unsigned char opcode[] = {(unsigned char) MICO_EFB_UFM_RD_DATA, MICOEFB_UFM_DUMMY_SETTING, *(p_page+1), *p_page};
	unsigned int opcode = MICO_EFB_UFM_RD_DATA + MICOEFB_UFM_DUMMY_SETTING + num_page;

	// Read data
	MicoEFB_UFMCmdCall(ctx, *(unsigned long*) &opcode, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read data opcode
	MicoEFB_UFMRxData (ctx, data, (UFM_PAGE_BYTE - 1));	// Receive the 1 page dummy data
	MicoEFB_UFMRxData (ctx, data, num_byte);	// Receive the actual data
	device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;	// Close the frame to terminate the command

	// Update UFM address and exit
	ctx->ufm_addr = ufm_addr + num_page;
	ctx->ufm_mem = ufm_mem - num_page;
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
	volatile MicoEFB_t *device = (volatile MicoEFB_t *)(ctx->base) ;

	// Check if the address is valid
	if (ctx->ufm_mem > 0) {
		// Write the new data
		MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_WR_DATA, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read data opcode
		MicoEFB_UFMTxData (ctx, data, (UFM_PAGE_BYTE - 1));	// Transfer one page data
		device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;	// Close the frame to terminate the command

		//Wait until the UFM is NOT busy and Check if Write operation fails
		unsigned int status;
		do {
			MicoEFB_UFMCmdCall(ctx, MICO_EFB_UFM_RD_SR, MICO_EFB_UFM_CLOSE_FRAME_DISABLE);	// Open the frame with read config. status opcode
			MicoEFB_UFMRxData (ctx, (unsigned char *) &status, 3);	// Receive the configuration status
			device->wbcfg_cr = MICO_EFB_UFM_WBCE_DISABLE ;	// Close the frame to terminate the command

			if (!(status & 0x1000)) {
				if (status & 0x2000) {
					return (-1);
				} else {
					// Update UFM address and exit
					ctx->ufm_addr++;
					ctx->ufm_mem--;
					return (0);
				}
			}
		} while (1);
	}
	else{
		return (-1);
	}
}

