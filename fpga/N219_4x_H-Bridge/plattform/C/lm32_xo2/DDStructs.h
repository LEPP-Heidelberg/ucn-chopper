#ifndef LATTICE_DDINIT_HEADER_FILE
#define LATTICE_DDINIT_HEADER_FILE
#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

#include "LookupServices.h"
/* platform frequency in MHz */
#define MICO32_CPU_CLOCK_MHZ (36000000)

/*Device-driver structure for lm32_top*/
#define LatticeMico32Ctx_t_DEFINED (1)
typedef struct st_LatticeMico32Ctx_t {
    const char*   name;
} LatticeMico32Ctx_t;


/* lm32_top instance LM32*/
extern struct st_LatticeMico32Ctx_t lm32_top_LM32;

/* declare LM32 instance of lm32_top */
extern void LatticeMico32Init(struct st_LatticeMico32Ctx_t*);


/*Device-driver structure for slave_passthru*/
#define MicoPassthruCtx_t_DEFINED (1)
typedef struct st_MicoPassthruCtx_t {
    const char*   name;
    unsigned int   base;
    unsigned int   intrLevel;
    DeviceReg_t   lookupReg;
    void *   prev;
    void *   next;
} MicoPassthruCtx_t;


/* slave_passthru instance slave_passthru*/
extern struct st_MicoPassthruCtx_t slave_passthru_slave_passthru;

/* declare slave_passthru instance of slave_passthru */
extern void MicoPassthruInit(struct st_MicoPassthruCtx_t*);

extern int main();



#ifdef __cplusplus
}
#endif /* __cplusplus */
#endif
