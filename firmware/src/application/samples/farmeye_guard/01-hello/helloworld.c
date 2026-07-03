/*****************************************************************************************/
/*                                                                                       */
/*                  Hello World sample program for WS63 embedded firmware                 */
/*                                                                                       */
/*****************************************************************************************/

#include "common_def.h"
#include "osal_debug.h"
#include "soc_osal.h"
#include "cmsis_os2.h"
#include "app_init.h"
#include "stdio.h"

#define HELLOWORLD_MSG "Hello World"
#define TASKS_TEST_TASK_STACK_SIZE    0x1000
#define TASKS_TEST_TASK_PRIO          (osPriority_t)(17)

static void tasks_test_entry(void);
static void show_welcome_ad(void);
static void show_system_ready(void);
static void show_progress_bar(int progress, int total);

static void show_welcome_ad(void)
{
    printf("\r\n");
    printf("===============================================\r\n");
    printf("=                                             =\r\n");
    printf("=              Hello World                    =\r\n");
    printf("=                                             =\r\n");
    printf("=          System starting, please wait...    =\r\n");
    printf("=                                             =\r\n");
    printf("===============================================\r\n");
    printf("\r\n");
}

static void show_system_ready(void)
{
    printf("\r\n");
    printf("===============================================\r\n");
    printf("=              System Ready!                  =\r\n");
    printf("=              Starting main task...          =\r\n");
    printf("===============================================\r\n");
    printf("\r\n");
}

static void show_progress_bar(int progress, int total)
{
    int i;
    int percent = progress * 100 / total;
    printf("\rSystem initializing...\r\n");
    printf("[");
    for (i = 0; i < 50; i++) {
        if (i < percent / 2) {
            printf("=");
        } else if (i == percent / 2) {
            printf(">");
        } else {
            printf(" ");
        }
    }
    printf("] %d%%\r\n", percent);
}

static int g_helloworld_cnt = 0;

static void tasks_test_entry(void)
{
    while (1) {
        osal_kthread_lock();
        printf("[%d]: %s\r\n", g_helloworld_cnt++, HELLOWORLD_MSG);
        osal_kthread_unlock();
        osal_msleep(1000);
    }
}

static void hello_world_entry(void)
{
    osal_task *task_handle = NULL;
    show_welcome_ad();
    show_progress_bar(50, 50);
    show_progress_bar(100, 100);
    show_system_ready();
    task_handle = osal_kthread_create((osal_kthread_handler)tasks_test_entry, NULL,
                                       "tasks_test", TASKS_TEST_TASK_STACK_SIZE);
    if (task_handle) {
        osal_kthread_set_priority(task_handle, TASKS_TEST_TASK_PRIO);
    }
}

app_run(hello_world_entry);
