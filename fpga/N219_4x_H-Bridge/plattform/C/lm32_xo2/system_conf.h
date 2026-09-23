#ifndef __SYSTEM_CONFIG_H_
#define __SYSTEM_CONFIG_H_


#define FPGA_DEVICE_FAMILY    "MachXO3D"
#define PLATFORM_NAME         "lm32_xo2"
#define USE_PLL               (0)
#define CPU_FREQUENCY         (49152000)


/* FOUND 1 CPU UNIT(S) */

/*
 * CPU Instance LM32 component configuration
 */
#define CPU_NAME "LM32"
#define CPU_EBA (0x00000000)
#define CPU_DIVIDE_ENABLED (0)
#define CPU_SIGN_EXTEND_ENABLED (1)
#define CPU_MULTIPLIER_ENABLED (0)
#define CPU_SHIFT_ENABLED (1)
#define CPU_DEBUG_ENABLED (0)
#define CPU_HW_BREAKPOINTS_ENABLED (0)
#define CPU_NUM_HW_BREAKPOINTS (0)
#define CPU_NUM_WATCHPOINTS (0)
#define CPU_ICACHE_ENABLED (0)
#define CPU_ICACHE_SETS (512)
#define CPU_ICACHE_ASSOC (1)
#define CPU_ICACHE_BYTES_PER_LINE (16)
#define CPU_DCACHE_ENABLED (0)
#define CPU_DCACHE_SETS (512)
#define CPU_DCACHE_ASSOC (1)
#define CPU_DCACHE_BYTES_PER_LINE (16)
#define CPU_DEBA (0x00000000)
#define CPU_CHARIO_IN        (0)
#define CPU_CHARIO_OUT       (0)
#define CPU_CHARIO_TYPE      "JTAG UART"

/*
 * IM_ebr component configuration
 */
#define IM_EBR_NAME  "IM_ebr"
#define IM_EBR_BASE_ADDRESS  (0x00000000)
#define IM_EBR_SIZE  (8192)
#define IM_EBR_IS_READABLE   (1)
#define IM_EBR_IS_WRITABLE   (1)
#define IM_EBR_ADDRESS_LOCK  (1)
#define IM_EBR_DISABLE  (0)
#define IM_EBR_WB_DAT_WIDTH  (32)
#define IM_EBR_INIT_FILE_NAME  "none"
#define IM_EBR_INIT_FILE_FORMAT  "hex"

/*
 * slave_passthru component configuration
 */
#define SLAVE_PASSTHRU_NAME  "slave_passthru"
#define SLAVE_PASSTHRU_BASE_ADDRESS  (0x80000000)
#define SLAVE_PASSTHRU_SIZE  (262144)
#define SLAVE_PASSTHRU_IRQ (0)
#define SLAVE_PASSTHRU_CHARIO_IN        (0)
#define SLAVE_PASSTHRU_CHARIO_OUT       (0)
#define SLAVE_PASSTHRU_ADDRESS_LOCK  (1)
#define SLAVE_PASSTHRU_DISABLE  (0)
#define SLAVE_PASSTHRU_WB_DAT_WIDTH  (32)
#define SLAVE_PASSTHRU_WB_SEL_WIDTH  (4)
#define SLAVE_PASSTHRU_WB_ADR_WIDTH  (32)

/*
 * master_passthru component configuration
 */
#define MASTER_PASSTHRU_NAME  "master_passthru"
#define MASTER_PASSTHRU_BASE_ADDRESS  (0x00000000)
#define MASTER_PASSTHRU_SIZE  (32)
#define MASTER_PASSTHRU_CHARIO_IN        (0)
#define MASTER_PASSTHRU_CHARIO_OUT       (0)
#define MASTER_PASSTHRU_BASE_ADDRESS  (0x00000000)
#define MASTER_PASSTHRU_SIZE  (32)
#define MASTER_PASSTHRU_DISABLE  (0)
#define MASTER_PASSTHRU_WB_DAT_WIDTH  (32)
#define MASTER_PASSTHRU_WB_SEL_WIDTH  (4)
#define MASTER_PASSTHRU_WB_ADR_WIDTH  (32)


#endif /* __SYSTEM_CONFIG_H_ */
