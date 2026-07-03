#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "stdio.h"
#include "uart1.h"
#include "uart2.h"

#define UART_TASK_PRIO             28
#define UART_TASK_STACK_SIZE       0x500

/**
 * @brief 双UART演示任务
 */
static void *dual_uart_demo_task(const char *arg)
{
    UNUSED(arg);

    printf("\r\n");
    printf("************************************************** \r\n");
    printf("*           Dual UART Communication Demo        * \r\n");
    printf("************************************************** \r\n");

    // 先运行UART1演示
    printf("\r\n--- Starting UART1 Demo --- \r\n");
    uart1_demo_task();
    
    osal_msleep(2000);
    
    // 再运行UART2演示
    printf("\r\n--- Starting UART2 Demo --- \r\n");
    uart2_demo_task();

    // 保持运行以接收数据
    printf("\r\n--- UARTs Running for Data Reception --- \r\n");
    while (1) {
        osal_msleep(1000);
        // 可以在这里添加其他逻辑
    }

    return NULL;
}

/**
 * @brief 应用入口函数
 */
static void uart_main_entry(void)
{
    osal_task *task_handle = NULL;
    
    osal_kthread_lock();
    
    printf("Starting Dual UART Communication Application \r\n");
    
    // 创建双UART演示任务
    task_handle = osal_kthread_create((osal_kthread_handler)dual_uart_demo_task,
                                    0, "DualUartDemoTask", UART_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, UART_TASK_PRIO);
        printf("Dual UART demo task created successfully \r\n");
    } else {
        printf("Failed to create UART task \r\n");
    }
    
    osal_kthread_unlock();
    
    printf("Application started successfully \r\n");
}

/* 运行双UART应用程序 */
app_run(uart_main_entry);
