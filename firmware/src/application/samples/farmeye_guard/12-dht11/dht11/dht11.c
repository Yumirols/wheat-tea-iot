#include "dht11.h"

static pin_t g_dht11_pin = 0;
static unsigned char g_dht11_initialized = 0;
static DHT11_Data_TypeDef g_dht11_data;

/**
 * @brief 微秒级延时
 */
static void dht11_udelay(uint16_t us)
{
    for (volatile uint16_t i = 0; i < us; i++)
    {
        volatile uint16_t j = 40;
        while (j--);
    }
}

/**
 * @brief 从DHT11读取8位数据
 */
static uint8_t dht11_read_byte(void)
{
    uint8_t i, temp = 0;
    uint16_t timeout = 0;

    for (i = 0; i < 8; i++)
    {
        // 等待低电平结束
        while (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_LOW);

        // 延时35us后判断电平
        dht11_udelay(35);

        // 如果是高电平，说明收到的是1
        if (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_HIGH)
        {
            // 等待高电平结束
            timeout = 0;
            while (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_HIGH)
            {
                timeout++;
                if (timeout > 200)
                {
                    osal_kthread_unlock();
                    return (uint8_t)ERRCODE_FAIL;
                }
                dht11_udelay(1);
            }

            // 高位先出
            temp |= (uint8_t)(0x01 << (7 - i));
        }
    }
    
    return temp;
}

/**
 * @brief DHT11初始化函数
 */
int dht11_init(uint8_t pin_num)
{
    if (g_dht11_initialized) {
        printf("DHT11 already initialized \r\n");
        return 0;
    }

    printf("Initializing DHT11 sensor... \r\n");

    g_dht11_pin = pin_num;

    // 设置引脚为普通IO模式
    uapi_pin_set_mode(g_dht11_pin, PIN_MODE_2);

    // 设置引脚为输出模式
    uapi_gpio_set_dir(g_dht11_pin, GPIO_DIRECTION_OUTPUT);

    // 设置引脚上拉
    uapi_pin_set_pull(g_dht11_pin, PIN_PULL_TYPE_UP);

    // 设置引脚为高电平
    uapi_gpio_set_val(g_dht11_pin, GPIO_LEVEL_HIGH);

    g_dht11_initialized = 1;
    printf("DHT11 initialization successful, pin: GPIO_%d \r\n", pin_num);
    
    return 0;
}

/**
 * @brief 读取DHT11温湿度数据
 */
int dht11_read_data(DHT11_Data_TypeDef *data)
{
    if (!g_dht11_initialized) {
        printf("Error: DHT11 not initialized \r\n");
        return -1;
    }

    if (data == NULL) {
        printf("Error: Invalid data pointer \r\n");
        return -1;
    }

    uint8_t temp;
    uint16_t humi_temp;
    uint16_t timeout = 0;
    int result;

    // 关闭任务调度，防止读取过程中被打断
    osal_kthread_lock();

    // 启动信号：拉低至少18ms
    uapi_gpio_set_dir(g_dht11_pin, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(g_dht11_pin, GPIO_LEVEL_LOW);
    osal_mdelay(18);
    uapi_gpio_set_val(g_dht11_pin, GPIO_LEVEL_HIGH);

    // 响应信号
    uapi_gpio_set_dir(g_dht11_pin, GPIO_DIRECTION_INPUT);
    uapi_pin_set_pull(g_dht11_pin, PIN_PULL_TYPE_STRONG_UP);

    // 等待DHT11将电平拉低
    timeout = 0;
    while (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_HIGH)
    {
        timeout++;
        if(timeout > 200)
        {
            printf("DHT11 response timeout 1 \r\n");
            osal_kthread_unlock();
            return -1;
        }
        dht11_udelay(1);
    }

    // 等待DHT11将电平拉高
    timeout = 0;
    while (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_LOW)
    {
        timeout++;
        if(timeout > 200)
        {
            printf("DHT11 response timeout 2 \r\n");
            osal_kthread_unlock();
            return -1;
        }
        dht11_udelay(1);
    }

    // 等待数据传输阶段的起始低电平
    timeout = 0;
    while (uapi_gpio_get_val(g_dht11_pin) == GPIO_LEVEL_HIGH)
    {
        timeout++;
        if(timeout > 200)
        {
            printf("DHT11 response timeout 3 \r\n");
            osal_kthread_unlock();
            return -1;
        }
        dht11_udelay(1);
    }

    // 开始接收数据
    data->humi_high8bit = dht11_read_byte();
    data->humi_low8bit = dht11_read_byte();
    data->temp_high8bit = dht11_read_byte();
    data->temp_low8bit = dht11_read_byte();
    data->check_sum = dht11_read_byte();

    // 读取结束，引脚改为输出模式
    uapi_gpio_set_dir(g_dht11_pin, GPIO_DIRECTION_OUTPUT);
    uapi_gpio_set_val(g_dht11_pin, GPIO_LEVEL_HIGH);

    // 计算湿度数据
    humi_temp = data->humi_high8bit * 100 + data->humi_low8bit;
    data->humidity = (float)humi_temp / 100;

    // 计算温度数据
    humi_temp = data->temp_high8bit * 100 + data->temp_low8bit;
    data->temperature = (float)humi_temp / 100;

    // 校验结果
    temp = data->humi_high8bit + data->humi_low8bit + data->temp_high8bit + data->temp_low8bit;
    if (temp == data->check_sum)
    {
        result = 0; // 成功
        // 更新全局数据
        g_dht11_data = *data;
    }
    else
    {
        result = -1; // 失败
        printf("DHT11 checksum error \r\n");
    }

    osal_kthread_unlock();
    return result;
}

/**
 * @brief 获取温度值
 */
float dht11_get_temperature(void)
{
    return g_dht11_data.temperature;
}

/**
 * @brief 获取湿度值
 */
float dht11_get_humidity(void)
{
    return g_dht11_data.humidity;
}

/**
 * @brief DHT11反初始化
 */
void dht11_deinit(void)
{
    if (g_dht11_initialized) {
        uapi_gpio_set_dir(g_dht11_pin, GPIO_DIRECTION_OUTPUT);
        uapi_gpio_set_val(g_dht11_pin, GPIO_LEVEL_LOW);
        g_dht11_initialized = 0;
        printf("DHT11 deinitialized \r\n");
    }
}
