#ifndef _MY_LDR_H_
#define _MY_LDR_H_
#endif

#include "pinctrl.h"
#include "common_def.h"
#include "soc_osal.h"
#include "osal_wait.h"
#include "app_init.h"
#include "gpio.h"
#include "adc.h"
#include "adc_porting.h"
#include "stdio.h"
#include "hal_gpio.h"

int adc_init(void);
void ldr_callback(uint8_t ch, uint32_t *buffer, uint32_t length, bool *next);
int get_adc_value(void);
