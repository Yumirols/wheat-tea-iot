#include "common_def.h"
#include "soc_osal.h"
#include "app_init.h"
#include "stdio.h"
#include "dht11.h"

#define DHT11_TASK_PRIO            28
#define DHT11_TASK_STACK_SIZE      0x500
#define DHT11_DATA_PIN             4       // DHT11数据引脚号

/**
 * @brief DHT11温湿度读取任务
 */
static void *dht11_read_task(const char *arg)
{
    unused(arg);

    printf("\r\n");
    printf("************************************************** \r\n");
    printf("*           DHT11 Temperature & Humidity         * \r\n");
    printf("************************************************** \r\n");

    // 初始化DHT11传感器
    if (dht11_init(DHT11_DATA_PIN) != 0) {
        printf("DHT11 initialization failed \r\n");
        return NULL;
    }

    printf("DHT11 sensor started, reading data every 3 seconds... \r\n");
    printf("================================================== \r\n");

    while (1)
    {
        DHT11_Data_TypeDef sensor_data;
        
        // 读取温湿度数据
        if (dht11_read_data(&sensor_data) == 0)
        {
            // 读取成功，打印数据
            printf("Temperature: %d.%d°C, Humidity: %d.%d%% \r\n", 
                   sensor_data.temp_high8bit, sensor_data.temp_low8bit,
                   sensor_data.humi_high8bit, sensor_data.humi_low8bit);     
        }
        else
        {
            printf("Read DHT11 data failed \r\n");
        }
        
        printf("------------------------------------------ \r\n");
        
        // 延时3秒
        osal_msleep(3000);
    }

    return NULL;
}

/**
 * @brief 应用入口函数
 */
static void dht11_main_entry(void)
{
    osal_task *task_handle = NULL;
    
    osal_kthread_lock();
    
    printf("Starting DHT11 Temperature & Humidity Application \r\n");
    
    // 创建DHT11读取任务
    task_handle = osal_kthread_create((osal_kthread_handler)dht11_read_task,
                                    0, "DHT11ReadTask", DHT11_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, DHT11_TASK_PRIO);
        printf("DHT11 read task created successfully \r\n");
    } else {
        printf("Failed to create DHT11 task \r\n");
    }
    
    osal_kthread_unlock();
    
    printf("Application started successfully \r\n");
}

/* 运行DHT11应用程序 */
app_run(dht11_main_entry);