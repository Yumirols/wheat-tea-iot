#include "uart2.h"

static unsigned char g_uart2_initialized = 0;
static uint8_t g_uart2_rx_buffer[UART2_RX_BUFFER_SIZE] = {0};
static uart_buffer_config_t g_uart2_buffer_config = {
    .rx_buffer = g_uart2_rx_buffer,
    .rx_buffer_size = UART2_RX_BUFFER_SIZE
};

/**
 * @brief UART2接收回调函数
 */
static void uart2_rx_callback(const void *buffer, uint16_t length, bool error)
{
    unused(error);

    if (buffer == NULL || length == 0) {
        return;
    }

    printf("[UART2] Received %d bytes: ", length);
    for(uint16_t i = 0; i < length; i++) {
        printf("%c", ((uint8_t *)buffer)[i]);
    }    
    printf("\n");
}

/**
 * @brief UART2初始化函数
 */
int uart2_init(uint32_t baud_rate)
{
    if (g_uart2_initialized) {
        printf("UART2 already initialized \r\n");
        return 0;
    }

    printf("Initializing UART2... \r\n");

    // 配置UART引脚模式
    uapi_pin_set_mode(UART2_RX_PIN, UART2_RX_PIN_MODE);
    uapi_pin_set_mode(UART2_TX_PIN, UART2_TX_PIN_MODE);

    // 定义串口配置参数
    uart_attr_t attr = {
        .baud_rate = baud_rate,
        .data_bits = UART_DATA_BIT_8,
        .stop_bits = UART_STOP_BIT_1,
        .parity = UART_PARITY_NONE
    };

    // 定义串口引脚配置参数
    uart_pin_config_t pin_config = {
        .rx_pin  = UART2_RX_PIN,
        .tx_pin  = UART2_TX_PIN,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };

    // 清除串口配置信息
    uapi_uart_deinit(UART2_BUS);

    // 初始化串口
    errcode_t ret = uapi_uart_init(UART2_BUS, &pin_config, &attr, NULL, &g_uart2_buffer_config);
    if (ret != ERRCODE_SUCC) {
        printf("UART2 initialization failed: %d \r\n", ret);
        return -1;
    }

    // 注销串口接收处理函数，防止重复注册
    uapi_uart_unregister_rx_callback(UART2_BUS);

    // 注册串口接收回调函数
    uapi_uart_register_rx_callback(UART2_BUS, UART_RX_CONDITION_FULL_OR_IDLE, 1, uart2_rx_callback);

    g_uart2_initialized = 1;
    printf("UART2 initialization successful, baud rate: %d \r\n", baud_rate);
    printf("RX: GPIO_%d, TX: GPIO_%d \r\n", UART2_RX_PIN, UART2_TX_PIN);
    
    return 0;
}

/**
 * @brief UART2发送数据
 */
int uart2_send(const uint8_t *data, uint16_t length)
{
    if (!g_uart2_initialized) {
        printf("Error: UART2 not initialized \r\n");
        return -1;
    }

    if (data == NULL || length == 0) {
        printf("Error: Invalid data or length \r\n");
        return -1;
    }

    errcode_t ret = uapi_uart_write(UART2_BUS, data, length, 0);
    if (ret != ERRCODE_SUCC) {
        printf("UART2 send failed: %d \r\n", ret);
        return -1;
    }

    printf("UART2 sent %d bytes \r\n", length);
    return 0;
}

/**
 * @brief UART2发送字符串
 */
int uart2_send_string(const char *str)
{
    if (str == NULL) {
        printf("Error: Invalid string \r\n");
        return -1;
    }

    uint16_t length = 0;
    while (str[length] != '\0') {
        length++;
    }

    return uart2_send((const uint8_t *)str, length);
}

/**
 * @brief UART2接收数据
 */
int uart2_receive(uint8_t *buffer, uint16_t buffer_size, uint32_t timeout_ms)
{
    if (!g_uart2_initialized) {
        printf("Error: UART2 not initialized \r\n");
        return -1;
    }

    if (buffer == NULL || buffer_size == 0) {
        printf("Error: Invalid buffer \r\n");
        return -1;
    }

    // 注意：这里使用简单的延时等待，实际应用中可能需要更复杂的接收逻辑
    printf("UART2 receive waiting for data... \r\n");
    osal_msleep(timeout_ms);
    
    // 在实际应用中，这里应该实现真正的数据接收逻辑
    // 当前版本主要依赖回调函数处理接收数据
    
    return 0;
}

/**
 * @brief UART2反初始化
 */
void uart2_deinit(void)
{
    if (g_uart2_initialized) {
        uapi_uart_unregister_rx_callback(UART2_BUS);
        uapi_uart_deinit(UART2_BUS);
        g_uart2_initialized = 0;
        printf("UART2 deinitialized \r\n");
    }
}

/**
 * @brief UART2演示任务
 */
void uart2_demo_task(void)
{
    printf("\r\n=== UART2 Communication Demo === \r\n");

    if (uart2_init(115200) != 0) {
        printf("UART2 demo initialization failed \r\n");
        return;
    }

    // 发送测试数据
    const char *test_messages[] = {
        "Hello UART2!",
        "This is UART2 test message",
        "Dual UART communication",
        "UART2 demo completed"
    };
    
    uint8_t message_count = sizeof(test_messages) / sizeof(test_messages[0]);
    
    for (int i = 0; i < message_count; i++) {
        printf("UART2 Sending: %s \r\n", test_messages[i]);
        uart2_send_string(test_messages[i]);
        uart2_send_string("\r\n");
        osal_msleep(1000);
    }

    printf("UART2 demo completed \r\n");
}
