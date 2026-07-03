#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "stdio.h"
#include "beep.h"  // 包含蜂鸣器驱动头文件

/**
 * @brief 蜂鸣器任务入口函数
 * 
 * 功能：创建并启动蜂鸣器测试任务
 *      设置任务优先级和栈大小
 */
static void beep_task_entry(void)
{
    osal_task *task_handle = NULL;
    
    // 获取内核线程锁，确保任务创建安全
    osal_kthread_lock();
    
    // 创建蜂鸣器测试任务
    task_handle = osal_kthread_create((osal_kthread_handler)beep_test_task,
                                      0,
                                      "BeepTestTask",
                                      0x500);
    // 设置任务优先级
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, 28);
        printf("蜂鸣器测试任务创建成功\n");
    } else {
        printf("蜂鸣器测试任务创建失败\n");
    }
    
    // 释放内核线程锁
    osal_kthread_unlock();
    
    printf("应用程序启动完成\n");
}

/* 使用app_run宏注册应用程序入口 */
app_run(beep_task_entry);