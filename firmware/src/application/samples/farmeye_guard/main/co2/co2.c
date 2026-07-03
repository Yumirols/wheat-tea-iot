/*
 * 农眼卫士 - CO2传感器驱动 (MH-Z19C)
 * 命令: FF 01 86 00 00 00 00 00 79
 * 响应: FF 86 [H] [L] ... [CHK], CO2 = H*256+L
 */

#include "co2.h"
#include "securec.h"

static uint16_t g_co2_value = 0;
static uint8_t  g_co2_init = 0;
static uint8_t  g_co2_rx_buf[32] = {0};
static uint8_t  g_co2_rx_flag = 0;

static uart_buffer_config_t g_co2_uart_cfg = {
    .rx_buffer = g_co2_rx_buf, .rx_buffer_size = sizeof(g_co2_rx_buf)
};

static const uint8_t g_co2_cmd[9] = {
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

static void co2_rx_cb(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    if (buffer == NULL || length < 9) return;
    memcpy_s(g_co2_rx_buf, sizeof(g_co2_rx_buf), buffer, length);
    g_co2_rx_flag = 1;
}

int co2_init(void)
{
    if (g_co2_init) return 0;
    uapi_pin_set_mode(CO2_UART_TX_PIN, PIN_MODE_1);
    uapi_pin_set_mode(CO2_UART_RX_PIN, PIN_MODE_1);

    uart_attr_t attr = {.baud_rate = CO2_UART_BAUDRATE, .data_bits = UART_DATA_BIT_8, .stop_bits = UART_STOP_BIT_1, .parity = UART_PARITY_NONE};
    uart_pin_config_t pin = {.tx_pin = S_MGPIO0, .rx_pin = S_MGPIO1, .cts_pin = PIN_NONE, .rts_pin = PIN_NONE};

    uapi_uart_deinit(CO2_UART_BUS);
    if (uapi_uart_init(CO2_UART_BUS, &pin, &attr, NULL, &g_co2_uart_cfg) != 0) { printf("CO2 UART init fail\r\n"); return -1; }
    uapi_uart_register_rx_callback(CO2_UART_BUS, UART_RX_CONDITION_MASK_IDLE, 1, co2_rx_cb);
    g_co2_init = 1;
    printf("CO2 init OK\r\n");
    return 0;
}

int co2_read_data(uint16_t *co2_ppm)
{
    if (!g_co2_init || !co2_ppm) return -1;
    g_co2_rx_flag = 0;
    memset_s(g_co2_rx_buf, sizeof(g_co2_rx_buf), 0, sizeof(g_co2_rx_buf));
    uapi_uart_write(CO2_UART_BUS, (uint8_t *)g_co2_cmd, 9, 0);

    uint32_t to = 0;
    while (!g_co2_rx_flag && to < 200) { osal_msleep(10); to++; }
    if (!g_co2_rx_flag) { printf("CO2 timeout\r\n"); return -1; }
    if (g_co2_rx_buf[0] != 0xFF || g_co2_rx_buf[1] != 0x86) { printf("CO2 hdr err\r\n"); return -1; }

    uint8_t chk = co2_checksum(g_co2_rx_buf, 9);
    if (chk != g_co2_rx_buf[8]) {
        printf("CO2 chk err: calc=%02X recv=%02X\r\n", chk, g_co2_rx_buf[8]);
        return -1;
    }

    *co2_ppm = ((uint16_t)g_co2_rx_buf[2] << 8) | g_co2_rx_buf[3];
    g_co2_value = *co2_ppm;
    return 0;
}

uint16_t co2_get_value(void) { return g_co2_value; }
