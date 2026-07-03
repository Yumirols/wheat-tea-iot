/*
 * 农眼卫士 - CO2传感器驱动实现
 * 适配 MH-Z19C (UART 9600bps 8N1)
 * 命令帧: FF 01 86 00 00 00 00 00 79
 * 响应帧: FF 86 [CO2_H] [CO2_L] ... [CHK]
 * CO2 ppm = byte[2]*256 + byte[3]
 */

#include "co2.h"
#include "securec.h"

static uint16_t g_co2_value = 0;
static uint8_t  g_co2_initialized = 0;

static uint8_t g_co2_rx_buf[CO2_RECV_BUF_SIZE] = {0};
static uint8_t g_co2_rx_flag = 0;

static uart_buffer_config_t g_co2_uart_cfg = {
    .rx_buffer      = g_co2_rx_buf,
    .rx_buffer_size = CO2_RECV_BUF_SIZE
};

static const uint8_t g_co2_cmd[CO2_CMD_LEN] = {
    0xFF, 0x01, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x79
};

static uint8_t co2_checksum(const uint8_t *data, uint8_t len)
{
    uint8_t sum = 0;
    for (uint8_t i = 1; i < len - 1; i++) {
        sum += data[i];
    }
    return (0xFF - sum + 1);
}

static void co2_uart_rx_cb(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    if (buffer == NULL || length < CO2_RESP_LEN) {
        return;
    }
    if (memcpy_s(g_co2_rx_buf, CO2_RECV_BUF_SIZE, buffer, length) != EOK) {
        return;
    }
    g_co2_rx_flag = 1;
}

int co2_init(void)
{
    if (g_co2_initialized) {
        printf("CO2 already initialized\r\n");
        return 0;
    }

    uapi_pin_set_mode(CO2_UART_TX_PIN, PIN_MODE_1);
    uapi_pin_set_mode(CO2_UART_RX_PIN, PIN_MODE_1);

    uart_attr_t attr = {
        .baud_rate = CO2_UART_BAUDRATE,
        .data_bits = UART_DATA_BIT_8,
        .stop_bits = UART_STOP_BIT_1,
        .parity    = UART_PARITY_NONE
    };

    uart_pin_config_t pin_config = {
        .tx_pin  = S_MGPIO0,
        .rx_pin  = S_MGPIO1,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };

    uapi_uart_deinit(CO2_UART_BUS);
    int ret = uapi_uart_init(CO2_UART_BUS, &pin_config, &attr, NULL, &g_co2_uart_cfg);
    if (ret != 0) {
        printf("CO2 UART init fail: 0x%x\r\n", ret);
        return -1;
    }

    if (uapi_uart_register_rx_callback(CO2_UART_BUS, UART_RX_CONDITION_MASK_IDLE, 1, co2_uart_rx_cb) != ERRCODE_SUCC) {
        printf("CO2 RX callback register fail\r\n");
        return -1;
    }

    g_co2_initialized = 1;
    printf("CO2 sensor init OK (UART%d)\r\n", CO2_UART_BUS);
    return 0;
}

int co2_read_data(uint16_t *co2_ppm)
{
    if (!g_co2_initialized) {
        printf("CO2 not initialized\r\n");
        return -1;
    }
    if (co2_ppm == NULL) {
        return -1;
    }

    g_co2_rx_flag = 0;

    uapi_uart_write(CO2_UART_BUS, (uint8_t *)g_co2_cmd, CO2_CMD_LEN, 0);

    uint32_t timeout = 0;
    while (!g_co2_rx_flag && timeout < 200) {
        osal_msleep(10);
        timeout++;
    }

    if (!g_co2_rx_flag) {
        printf("CO2 sensor no response\r\n");
        return -1;
    }

    if (g_co2_rx_buf[0] != 0xFF || g_co2_rx_buf[1] != 0x86) {
        printf("CO2 response header error: %02X %02X\r\n", g_co2_rx_buf[0], g_co2_rx_buf[1]);
        return -1;
    }

    uint8_t chk = co2_checksum(g_co2_rx_buf, CO2_RESP_LEN);
    if (chk != g_co2_rx_buf[CO2_RESP_LEN - 1]) {
        printf("CO2 checksum error: calc=%02X recv=%02X\r\n", chk, g_co2_rx_buf[CO2_RESP_LEN - 1]);
        return -1;
    }

    *co2_ppm = ((uint16_t)g_co2_rx_buf[2] << 8) | g_co2_rx_buf[3];
    g_co2_value = *co2_ppm;
    memset_s(g_co2_rx_buf, CO2_RECV_BUF_SIZE, 0, CO2_RECV_BUF_SIZE);

    return 0;
}

uint16_t co2_get_value(void)
{
    return g_co2_value;
}

void co2_deinit(void)
{
    if (g_co2_initialized) {
        uapi_uart_deinit(CO2_UART_BUS);
        g_co2_initialized = 0;
        printf("CO2 sensor deinited\r\n");
    }
}
