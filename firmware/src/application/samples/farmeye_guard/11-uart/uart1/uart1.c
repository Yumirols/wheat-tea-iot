#include "uart1.h"

static unsigned char g_uart1_initialized = 0;
static uint8_t g_uart1_rx_buffer[UART1_RX_BUFFER_SIZE] = {0};
static uart_buffer_config_t g_uart1_buffer_config = {
    .rx_buffer = g_uart1_rx_buffer,
    .rx_buffer_size = UART1_RX_BUFFER_SIZE
};

/**
 * @brief UART1接收回调函数
 */
static void uart1_rx_callback(const void *buffer, uint16_t length, bool error)
{
    unused(error);

    if (buffer == NULL || length == 0) {
        return;
    }

    printf("[UART1] Received %d bytes: ", length);
    for(uint16_t i = 0; i < length; i++) {
        printf("%c", ((uint8_t *)buffer)[i]);
    }    
    printf("\n");
}

/**
 * @brief UART1初始化函数
 */
int uart1_init(uint32_t baud_rate)
{
    if (g_uart1_initialized) {
        printf("UART1 already initialized \r\n");
        return 0;
    }

    printf("Initializing UART1... \r\n");

    // 配置UART引脚模式
    uapi_pin_set_mode(UART1_RX_PIN, UART1_RX_PIN_MODE);
    uapi_pin_set_mode(UART1_TX_PIN, UART1_TX_PIN_MODE);

    // 定义串口配置参数
    uart_attr_t attr = {
        .baud_rate = baud_rate,
        .data_bits = UART_DATA_BIT_8,
        .stop_bits = UART_STOP_BIT_1,
        .parity = UART_PARITY_NONE
    };

    // 定义串口引脚配置参数
    uart_pin_config_t pin_config = {
        .rx_pin  = UART1_RX_PIN,
        .tx_pin  = UART1_TX_PIN,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };

    // 清除串口配置信息
    uapi_uart_deinit(UART1_BUS);

    // 初始化串口
    errcode_t ret = uapi_uart_init(UART1_BUS, &pin_config, &attr, NULL, &g_uart1_buffer_config);
    if (ret != ERRCODE_SUCC) {
        printf("UART1 initialization failed: %d \r\n", ret);
        return -1;
    }

    // 注销串口接收处理函数，防止重复注册
    uapi_uart_unregister_rx_callback(UART1_BUS);

    // 注册串口接收回调函数
    uapi_uart_register_rx_callback(UART1_BUS, UART_RX_CONDITION_FULL_OR_IDLE, 1, uart1_rx_callback);

    g_uart1_initialized = 1;
    printf("UART1 initialization successful, baud rate: %d \r\n", baud_rate);
    printf("RX: GPIO_%d, TX: GPIO_%d \r\n", UART1_RX_PIN, UART1_TX_PIN);
    
    return 0;
}

/**
 * @brief UART1发送数据
 */
int uart1_send(const uint8_t *data, uint16_t length)
{
    if (!g_uart1_initialized) {
        printf("Error: UART1 not initialized \r\n");
        return -1;
    }

    if (data == NULL || length == 0) {
        printf("Error: Invalid data or length \r\n");
        return -1;
    }

    errcode_t ret = uapi_uart_write(UART1_BUS, data, length, 0);
    if (ret != ERRCODE_SUCC) {
        printf("UART1 send failed: %d \r\n", ret);
        return -1;
    }

    printf("UART1 sent %d bytes \r\n", length);
    return 0;
}

/**
 * @brief UART1发送字符串
 */
int uart1_send_string(const char *str)
{
    if (str == NULL) {
        printf("Error: Invalid string \r\n");
        return -1;
    }

    uint16_t length = 0;
    while (str[length] != '\0') {
        length++;
    }

    return uart1_send((const uint8_t *)str, length);
}

/**
 * @brief UART1接收数据
 */
int uart1_receive(uint8_t *buffer, uint16_t buffer_size, uint32_t timeout_ms)
{
    if (!g_uart1_initialized) {
        printf("Error: UART1 not initialized \r\n");
        return -1;
    }

    if (buffer == NULL || buffer_size == 0) {
        printf("Error: Invalid buffer \r\n");
        return -1;
    }

    // 注意：这里使用简单的延时等待，实际应用中可能需要更复杂的接收逻辑
    // 由于有回调函数，这里主要提供同步接收接口
    printf("UART1 receive waiting for data... \r\n");
    osal_msleep(timeout_ms);
    
    // 在实际应用中，这里应该实现真正的数据接收逻辑
    // 当前版本主要依赖回调函数处理接收数据
    
    return 0;
}

/**
 * @brief UART1反初始化
 */
void uart1_deinit(void)
{
    if (g_uart1_initialized) {
        uapi_uart_unregister_rx_callback(UART1_BUS);
        uapi_uart_deinit(UART1_BUS);
        g_uart1_initialized = 0;
        printf("UART1 deinitialized \r\n");
    }
}

/**
 * @brief UART1演示任务
 */
void uart1_demo_task(void)
{
    printf("\r\n=== UART1 Communication Demo === \r\n");

    if (uart1_init(115200) != 0) {
        printf("UART1 demo initialization failed \r\n");
        return;
    }

    // 发送测试数据
    const char *test_messages[] = {
        "Hello UART1!",
        "This is a test message",
        "UART communication demo",
        "End of test"
    };
    
    uint8_t message_count = sizeof(test_messages) / sizeof(test_messages[0]);
    
    for (int i = 0; i < message_count; i++) {
        printf("Sending: %s \r\n", test_messages[i]);
        uart1_send_string(test_messages[i]);
        uart1_send_string("\r\n");
        osal_msleep(1000);
    }

    printf("UART1 demo completed \r\n");
    
    // 注意：不要在这里反初始化，保持UART1运行以接收数据
}
