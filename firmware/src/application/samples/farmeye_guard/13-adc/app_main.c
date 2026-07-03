#include "adc/ldr.h"
#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "stdio.h"

uint16_t ldr_value=0;
static void *LdrTest_task(const char *arg)
{
    unused(arg);
    adc_init();

    while(1)
    {
        ldr_value = get_adc_value();

        printf("ldr_result = %d\n",ldr_value);

        osal_msleep(1000);
    }
    return NULL;
}


static void Ldr_entry(void)
{
    osal_task *task_handle = NULL;
    osal_kthread_lock();
    task_handle = osal_kthread_create((osal_kthread_handler)LdrTest_task,
                                      0,
                                      "LdrTestTask",
                                      0x500);
    if (task_handle != NULL)
    {
        osal_kthread_set_priority(task_handle, 28);
    }
    osal_kthread_unlock();
}

app_run(Ldr_entry);
