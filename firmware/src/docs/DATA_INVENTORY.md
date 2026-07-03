# 农眼卫士 — 板端数据全景清单

**产品**: 农眼卫士 FarmEye Guard v1.0  
**平台**: WS63 (Hi3863) + LiteOS  
**云端**: 华为云 IoTDA  
**数据更新频率**: 传感器每 5s 采集，每 10s 上传云端

---

## 一、全部上报字段速查

| # | 字段 | 类型 | 单位 | 说明 | 来源 |
|---|------|------|------|------|------|
| 1 | `temperature` | `float` | ℃ | 环境温度 | DHT11 传感器 |
| 2 | `humidity` | `float` | % | 环境湿度 | DHT11 传感器 |
| 3 | `light` | `int` | 0-100 | 光照百分比 | LDR 光敏 (ADC CH5) |
| 4 | `co2` | `int` | ppm | CO2 浓度 | MH-Z19C (UART1) |
| 5 | `soil_n` | `float` | mg/kg | 土壤氮素 ⚠推导值 | `45.0 + temperature * 0.2` |
| 6 | `soil_p` | `float` | mg/kg | 土壤磷素 ⚠推导值 | `18.0 + humidity * 0.1` |
| 7 | `soil_k` | `float` | mg/kg | 土壤钾素 ⚠推导值 | `50.0 + light * 0.02` |
| 8 | `distance` | `int` | cm | 超声波测距 | HC-SR04 (GPIO_06/09) |
| 9 | `rssi` | `int` | dBm | WiFi 信号强度 | WiFi 协议栈回调 |
| 10 | `ip_addr` | `string` | — | 设备 IP 地址 | lwIP DHCP |
| 11 | `mac_addr` | `string` | — | 设备 MAC 地址 | eFuse 安全存储 |
| 12 | `alarm_flag` | `int` | bitmask | 报警状态位掩码 | 板端计算 |

---

## 二、各字段详细规格

### 2.1 temperature — 温度

| 属性 | 值 |
|---|---|
| 数据类型 | `float` (1 位小数) |
| 单位 | ℃ |
| 范围 | 0 ~ 50℃ |
| 报警 | > 38.0℃ (flag 0x01) / < -10.0℃ (flag 0x02) |

### 2.2 humidity — 湿度

| 属性 | 值 |
|---|---|
| 数据类型 | `float` (1 位小数) |
| 单位 | % RH |
| 范围 | 20 ~ 90% |
| 报警 | > 90.0% (flag 0x04) / < 15.0% (flag 0x08) |

### 2.3 light — 光照

| 属性 | 值 |
|---|---|
| 数据类型 | `int` |
| 单位 | 百分比 (0-100) |
| 转换 | `raw_adc * 100 / 3350` |
| 报警 | < 100 (flag 0x10) |

### 2.4 co2 — CO2 浓度

| 属性 | 值 |
|---|---|
| 数据类型 | `int` |
| 单位 | ppm |
| 范围 | 0 ~ 5000 |
| 报警 | > 2000 ppm (flag 0x20) |

### 2.5-2.7 soil_n / soil_p / soil_k — 土壤 NPK

> ⚠ **推导值**，非真实传感器。需接入 RS485 NPK 传感器。

| 字段 | 类型 | 公式 | 报警 |
|---|---|---|---|
| `soil_n` | `float` | `45.0 + temperature * 0.2` | < 30.0 (flag 0x40) |
| `soil_p` | `float` | `18.0 + humidity * 0.1` | < 10.0 (flag 0x80) |
| `soil_k` | `float` | `50.0 + light * 0.02` | 已定义未使用 |

### 2.8 distance — 超声波测距

| 属性 | 值 |
|---|---|
| 数据类型 | `int32_t` |
| 单位 | cm |
| 范围 | 0 ~ 800 (超时返回 -1) |
| 传感器 | HC-SR04 (TRIG=GPIO_06, ECHO=GPIO_09) |
| 换算 | `距离(cm) = 脉宽(μs) / 58` |

### 2.9 rssi — WiFi 信号强度

| 属性 | 值 |
|---|---|
| 数据类型 | `int8_t` |
| 单位 | dBm |
| 范围 | 通常 -30 ~ -90 (越接近 0 越强) |
| 来源 | WiFi 协议栈连接状态回调 `wifi_linked_info_stru.rssi` |

### 2.10 ip_addr — 设备 IP 地址

| 属性 | 值 |
|---|---|
| 数据类型 | `uint32_t` (网络字节序) |
| 格式 | 上报时转 `x.x.x.x` 点分十进制 |
| 来源 | lwIP `netif->ip_addr.u_addr.ip4.addr` (DHCP 获取) |

### 2.11 mac_addr — 设备 MAC 地址

| 属性 | 值 |
|---|---|
| 数据类型 | `char[18]` |
| 格式 | `XX:XX:XX:XX:XX:XX` (大写十六进制冒号分隔) |
| 来源 | eFuse 安全存储，通过 `get_dev_addr()` 读取 |

### 2.12 alarm_flag — 报警位掩码

| Bit | 含义 | 触发条件 | 动作 |
|---|---|---|---|
| 0x01 | 高温 | > 38.0℃ | LED + 蜂鸣 + 语音 |
| 0x02 | 低温 | < -10.0℃ | LED + 蜂鸣 + 语音 |
| 0x04 | 高湿 | > 90.0% | LED + 蜂鸣 + 语音 |
| 0x08 | 低湿 | < 15.0% | LED + 蜂鸣 + 语音 |
| 0x10 | 低光照 | < 100 | LED + 蜂鸣 + 语音 |
| 0x20 | 高 CO2 | > 2000 ppm | LED + 蜂鸣 + 语音 |
| 0x40 | 低氮 | soil_n < 30.0 | LED + 蜂鸣 + 喷淋 ON |
| 0x80 | 低磷 | soil_p < 10.0 | LED + 蜂鸣 + 灌溉 ON |

---

## 三、MQTT 云端数据格式

### 3.1 属性上报 (设备 → 云端)

**Topic**: `$oc/devices/farmeye_guard_ws63/sys/properties/report`  
**QoS**: 1 | **周期**: 10s

```json
{
  "services": [{
    "service_id": "farmeye_env",
    "properties": {
      "temperature": 25.5,
      "humidity": 60.2,
      "light": 85,
      "co2": 450,
      "soil_n": 50.1,
      "soil_p": 24.0,
      "soil_k": 51.7,
      "distance": 150,
      "rssi": -45,
      "ip_addr": "192.168.1.100",
      "mac_addr": "A1:B2:C3:D4:E5:F6",
      "alarm_flag": 0
    }
  }]
}
```

### 3.2 命令下发 (云端 → 设备)

**Topic**: `$oc/devices/farmeye_guard_ws63/sys/commands/#`

| payload 字符串 | 动作 |
|---|---|
| `"led ON"` / `"led OFF"` | LED 开关 |
| `"beep ON"` / `"beep OFF"` | 蜂鸣器 |
| `"spray ON"` / `"spray OFF"` | 喷淋继电器 |
| `"irrig ON"` / `"irrig OFF"` | 灌溉继电器 |

### 3.3 命令应答 (设备 → 云端)

**Topic**: `$oc/devices/farmeye_guard_ws63/sys/commands/response/request_id={request_id}`

```json
{
  "result_code": 0,
  "response_name": "farmeye_guard",
  "paras": { "result": "success" }
}
```

### 3.4 连接参数

| 参数 | 值 |
|---|---|
| Broker | `5b0d2d88ef.st1.iotda-device.cn-north-4.myhuaweicloud.com` |
| Port | 1883 (MQTT 明文) |
| Username | `farmeye_guard_ws63` |
| Keep-alive | 120s |
| Device ID | `farmeye_guard_ws63` |

---

## 四、GPIO 引脚布局

```
GPIO_02 ─── LED1 指示灯
GPIO_03 ─── LED2 指示灯
GPIO_04 ─── DHT11 温湿度传感器 (单总线)
GPIO_05 ─── LDR 光照传感器 (ADC CH5)
GPIO_06 ─── HC-SR04 超声波 TRIG
GPIO_07 ─── UART1 RX (CO2 传感器 MH-Z19C)
GPIO_08 ─── UART1 TX (CO2 传感器)
GPIO_09 ─── HC-SR04 超声波 ECHO
GPIO_10 ─── 继电器1: 喷淋/氮肥
GPIO_11 ─── 蜂鸣器
GPIO_13 ─── 继电器2: 灌溉/磷肥
GPIO_15 ─── I2C SDA (OLED SSD1306, 0x3C)
GPIO_16 ─── I2C SCL (OLED SSD1306)
GPIO_17 ─── UART0 TX (语音模块 su-03T)
GPIO_18 ─── UART0 RX (语音模块 su-03T)
```

---

## 五、数据库 Schema 建议

```sql
CREATE TABLE sensor_snapshot (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id   VARCHAR(64) NOT NULL,
    mac_addr    VARCHAR(17),
    timestamp   DATETIME NOT NULL,

    temperature DECIMAL(4,1) COMMENT '温度/℃',
    humidity    DECIMAL(4,1) COMMENT '湿度/%',
    light       INT           COMMENT '光照/0-100',
    co2         INT           COMMENT 'CO2/ppm',
    soil_n      DECIMAL(5,1)  COMMENT '土壤氮/mg/kg (推导)',
    soil_p      DECIMAL(5,1)  COMMENT '土壤磷/mg/kg (推导)',
    soil_k      DECIMAL(5,1)  COMMENT '土壤钾/mg/kg (推导)',
    distance    INT           COMMENT '超声波距离/cm',
    rssi        TINYINT       COMMENT 'WiFi信号/dBm',
    ip_addr     VARCHAR(16)   COMMENT '设备IP',
    alarm_flag  INT           COMMENT '报警位掩码',

    INDEX idx_device_time (device_id, timestamp)
);
```

---

## 六、待改进项

| # | 问题 | 建议 |
|---|---|---|
| 1 | 土壤 NPK 为推导值 | 接入 RS485 NPK 传感器 |
| 2 | MQTT 密码硬编码在头文件 | 生产环境改为 NV 存储 + 安全启动 |
| 3 | MQTT 明文无 TLS | 生产环境启用 TLS 加密 |
