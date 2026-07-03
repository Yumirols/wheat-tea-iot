/*
 * 农眼卫士 - 继电器控制驱动 (农药喷洒 + 灌溉)
 */

#ifndef __RELAY_H__
#define __RELAY_H__

#include "common_def.h"
#include "pinctrl.h"
#include "gpio.h"

#define RELAY_SPRAY_PIN  GPIO_10
#define RELAY_IRRIG_PIN  GPIO_13

int  relay_init(void);
void relay_spray_on(void);
void relay_spray_off(void);
void relay_irrig_on(void);
void relay_irrig_off(void);

#endif
