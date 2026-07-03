/*
 * 农眼卫士 - CO2传感器独立测试程序
 */

#include "stdio.h"
#include "soc_osal.h"
#include "cmsis_os2.h"
#include "app_init.h"
#include "co2/co2.h"

osThreadId_t task1_ID;

#define DELAY_TIME_MS 100

void task1(void)
{
    uint16_t co2_ppm = 0;
    co2_init();

    while (1) {
        if (co2_read_data(&co2_ppm) == 0) {
            printf("CO2 = %d ppm\r\n", co2_ppm);
        } else {
            printf("CO2 read fail\r\n");
        }
        osDelay(DELAY_TIME_MS);
    }
}

static void co2_demo(void)
{
    printf("Enter CO2 demo!\r\n");

    osThreadAttr_t attr;
    attr.name       = "co2_task";
    attr.attr_bits  = 0U;
    attr.cb_mem     = NULL;
    attr.cb_size    = 0U;
    attr.stack_mem  = NULL;
    attr.stack_size = 0x1000;
    attr.priority   = osPriorityNormal;

    task1_ID = osThreadNew((osThreadFunc_t)task1, NULL, &attr);
    if (task1_ID != NULL) {
        printf("ID = %d, Create co2_task OK!\r\n", task1_ID);
    }
}

app_run(co2_demo);
