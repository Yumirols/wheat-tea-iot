#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "stdio.h"
#include "led.h"  // 包含LED驱动头文件

/**
 * @brief LED任务入口函数
 * 
 * 功能：创建并启动LED测试任务
 *      设置任务优先级和栈大小
 */
static void led_task_entry(void)
{
    osal_task *task_handle = NULL;
    
    // 获取内核线程锁，确保任务创建安全
    osal_kthread_lock();
    
    // 创建LED测试任务
    task_handle = osal_kthread_create((osal_kthread_handler)led_test_task,
                                      0,
                                      "LedTestTask",
                                      0x500);
    // 设置任务优先级
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, 28);
        printf("LED test task success!\n");
    } else {
        printf("LED test task fail!\n");
    }
    
    // 释放内核线程锁
    osal_kthread_unlock();
    
    printf("application start success\n");
}

/* 使用app_run宏注册应用程序入口 */
app_run(led_task_entry);
