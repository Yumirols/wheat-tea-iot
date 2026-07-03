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
#include "uart.h"

//定义接受缓冲区
static uint8_t uart_rx_buff[1024] = {0};
//定义接受配置结构体
static uart_buffer_config_t uart_buffer_config = {
    .rx_buffer = uart_rx_buff,
    .rx_buffer_size = 1024
};

//UART接收回调函数
void uart_rx_callback(const void *buffer, uint16_t length, bool error)
{
    unused(error);

    if (buffer == NULL || length == 0)
    {
        return;
    }

    osal_printk("[UART_TASK] uart_rx: ");
    for(uint16_t i = 0; i < length; i++)
    {
        osal_printk("%c", ((uint8_t *)buffer)[i]);
    }    
    osal_printk("\n");

}


static void *UartTest_task(const char *arg)
{
    unused(arg);

    uart_bus_t uart_bus = CONFIG_UART_BUS;

    //定义串口配置参数
    uart_attr_t attr = {
        .baud_rate = 115200,            // 波特率
        .data_bits = UART_DATA_BIT_8,   // 8位数据位
        .stop_bits = UART_STOP_BIT_1,   // 1位停止位
        .parity = UART_PARITY_NONE       // 无校验位
    };

    //由IO复用关系表可知,设置模式2时,IO7和IO8是串口功能。
    uapi_pin_set_mode(GPIO_07, PIN_MODE_2);
    uapi_pin_set_mode(GPIO_08, PIN_MODE_2);

     //定义串口引脚配置参数， 无cts和trs流控, 
    uart_pin_config_t pin_config = {
        .rx_pin  = GPIO_07,
        .tx_pin  = GPIO_08,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };

    //清除串口配置信息
    uapi_uart_deinit(uart_bus);

    //初始化串口
    errcode_t ret = uapi_uart_init(uart_bus, &pin_config, &attr, NULL, &uart_buffer_config);
    if (ret != ERRCODE_SUCC)
    {
        osal_printk("uapi_uart_init failed");
    }

    // 注销串口接收处理函数，防止重复注册。
    uapi_uart_unregister_rx_callback(uart_bus);

    //注册串口接受回调函数
    uapi_uart_register_rx_callback(uart_bus, UART_RX_CONDITION_FULL_OR_IDLE, 1, uart_rx_callback);

    while (1)
    {
        osal_msleep(1000);

        uapi_uart_write(uart_bus, (uint8_t *)"Hello UART\n", sizeof("Hello UART\n"), 0);
    }

    return NULL;
}

static void Uart_entry(void)
{
    osal_task *task_handle = NULL;
    osal_kthread_lock();
    task_handle = osal_kthread_create((osal_kthread_handler)UartTest_task,
                                      0,
                                      "UartTestTask",
                                      0x500);
    if (task_handle != NULL)
    {
        osal_kthread_set_priority(task_handle, 28);
    }
    osal_kthread_unlock();
}

app_run(Uart_entry);