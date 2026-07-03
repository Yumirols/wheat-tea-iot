# 农眼卫士 (FarmEye Guard) 固件架构

---

## 一、项目概述

本项目是基于**海思 HiSilicon WS63**（RISC-V 32位）芯片的 IoT 固件 SDK，运行 **Huawei LiteOS** 实时操作系统，支持 **Wi-Fi 6 / BLE 5.2 / SLE（星闪）/ 雷达感知**等多模无线协议，内置完整 FOTA 升级、安全启动、AT 命令、诊断日志等中间件。

---

## 二、主要目录结构

```
firmware/
├── src/                          # 固件源码根目录
│   ├── build.py                  # Python 构建入口
│   ├── CMakeLists.txt            # CMake 顶层构建文件
│   ├── config.in                 # Kconfig 顶层配置
│   │
│   ├── application/              # 应用层
│   │   ├── samples/              # 跨芯片示例代码
│   │   │   ├── bt/               # BLE/SLE 蓝牙示例
│   │   │   ├── peripheral/       # 外设驱动示例(15种)
│   │   │   ├── radar/            # 雷达感知示例
│   │   │   ├── wifi/             # WiFi 连接示例
│   │   │   └── farmeye_guard/    # 农眼卫士主应用
│   │   │       ├── main/         # ★ 主应用（传感器+WiFi+MQTT）
│   │   │       ├── co2/          # CO2 共享驱动
│   │   │       └── 01-hello/ ... 19-voice/  # 独立示例
│   │   └── ws63/                 # WS63 芯片应用
│   │       ├── ws63_liteos_application/  # 主应用固件入口
│   │       └── ws63_liteos_mfg/          # 工厂产测固件
│   │
│   ├── bootloader/               # 引导加载器
│   │   ├── commonboot/           # 公共 boot 组件(13源文件)
│   │   ├── flashboot_ws63/       # FlashBoot 二级引导
│   │   └── provision_ws63/       # LoaderBoot 烧录引导
│   │
│   ├── kernel/                   # 操作系统内核
│   │   ├── liteos/               # Huawei LiteOS (v208.5.0)
│   │   ├── non_os/               # 无 OS 模式
│   │   ├── osal/                 # OS 抽象层(20+ API)
│   │   └── osal_adapt/           # OSAL 适配层封装
│   │
│   ├── drivers/                  # 驱动层
│   │   ├── drivers/hal/          # HAL 寄存器操作层(23外设)
│   │   ├── drivers/driver/       # Driver 业务封装层
│   │   ├── chips/ws63/porting/   # 芯片移植层(29模块)
│   │   ├── boards/ws63/evb/      # 板级配置 + 链接脚本
│   │   └── adapter/ohos_3.2/     # OpenHarmony 适配层
│   │
│   ├── middleware/               # 中间件
│   │   ├── utils/                # 工具集
│   │   │   ├── at/               # AT 命令框架
│   │   │   ├── dfx/              # 诊断日志系统
│   │   │   ├── nv/               # NV 非易失存储
│   │   │   ├── partition/        # 分区管理
│   │   │   ├── update/           # FOTA 升级全套框架
│   │   │   ├── algorithm/        # 算法(CRC/SHA256/SRP)
│   │   │   └── app_init/         # 应用初始化框架
│   │   ├── services/             # 服务层(WiFi 服务)
│   │   └── chips/ws63/           # 芯片适配(DFX/NV/OTA等)
│   │
│   ├── protocol/                 # 无线协议栈
│   │   ├── wifi/                 # 802.11 MAC 层(79头文件)
│   │   ├── bt/                   # BLE Controller + Host
│   │   └── radar/                # 雷达感知协议
│   │
│   ├── open_source/              # 开源组件
│   │   ├── lwip/                 # TCP/IP 协议栈 v2.1.3
│   │   ├── mbedtls/              # 加密/TLS 库 v3.1.0
│   │   ├── mqtt/                 # MQTT 客户端(Paho)
│   │   ├── cjson/                # JSON 解析库
│   │   ├── littlefs/             # 嵌入式文件系统 v2.5.0
│   │   ├── wpa_supplicant/       # Wi-Fi 连接管理
│   │   ├── libcoap/              # CoAP 协议
│   │   ├── GmSSL3.0/             # 国密算法库
│   │   ├── libboundscheck/       # C 安全函数库
│   │   ├── 7-zip-lzma-sdk/       # LZMA 解压缩
│   │   └── nfc/                  # NT3H NFC 驱动
│   │
│   └── include/                  # 公共头文件
│       ├── middleware/utils/     # AT/NV/UPG/DIAG 接口
│       └── driver/               # 驱动接口
│
├── tools/                        # 开发工具
│   ├── pkg/                      # 固件打包工具(.fwpkg)
│   └── *.md                      # 开发环境文档
│
└── vendor/                       # 板级配置
    ├── BearPi-Pico_H3863/        # 小熊派 H3863
    ├── HiHope_NearLink_DK_WS63E_V03/  # HiHope WS63E
    ├── Hqyj_Ws63/                # 华清远见 WS63
    └── developers/               # 开发者模板
```

---

## 三、核心启动流程

```
[ROM Code] (芯片内部固化)
    │ 加载 flashboot 镜像到 SRAM
    ▼
[FlashBoot: riscv_init.S → start_fastboot()]
    ├── TCXO/FLASH/UART/PMP/malloc 初始化
    ├── FOTA 升级检查与执行
    ├── 应用镜像验签(ECC/RSA/SM2)
    ├── A/B 分区切换与 DMMU 重映射
    └── 安全跳转到应用 reset_vector
    ▼
[App Reset: reset_vector.S → HandleReset]
    ├── 设置 mtvec/FPU/GP/SP
    ├── 代码重定位(Flash→TCM/SRAM)
    └── tail runtime_init()
    ▼
[runtime_init() → do_relocation() → main()]
    ├── patch_init()               # RISC-V 补丁
    ├── uapi_partition_init()      # 分区初始化
    ├── pmp_enable()               # 物理内存保护
    ├── cpu_cache_init()           # ICache+DCache
    ├── LOS_PrepareMainTask()      # LiteOS 主任务
    ├── osKernelInitialize()       # 内核初始化
    ├── hw_init()                  # 硬件全初始化
    │   ├── RF 上电 / PLL 时钟
    │   ├── GPIO/UART/Timer/Systick/TCXO
    │   ├── Watchdog(15s)/eFuse/SFC Flash
    │   ├── NV 初始化 / 温度传感器
    │   └── 加密引擎 / MAC 地址
    ├── AT 命令 / 日志子系统初始化
    ├── main_initialise()          # 创建系统任务
    ├── app_tasks_init()           # 农眼卫士模块初始化
    └── osKernelStart()            # 启动调度器
    ▼
[多任务运行]
    app / wifi / bt* / at / log / farmeye_guard / cmd_loop
```

---

## 四、技术栈

| 层次 | 技术选型 |
|------|----------|
| **CPU 架构** | RISC-V 32bit (riscv31)，支持 FPU/PMP/压缩指令 |
| **主芯片** | HiSilicon WS63 / Hi3863，~240MHz |
| **无线能力** | Wi-Fi 6 (b/g/n/ax)、BLE 5.2、SLE 1.0（星闪）、雷达感知 |
| **RTOS** | LiteOS v208.5.0（CMSIS-RTOS v2 API） |
| **TCP/IP** | lwIP 2.1.3 |
| **加密** | mbedTLS 3.1.0 + GmSSL 3.0（国密 SM2/SM3/SM4） |
| **安全启动** | ECC/RSA3072/RSA4096/SM2 签名 + FAPC 在线加解密 |
| **IoT 协议** | MQTT (Paho)、CoAP (libcoap)、HTTP |
| **Wi-Fi 安全** | wpa_supplicant (WPA/WPA2/WPA3/WAPI) |
| **文件系统** | LittleFS v2.5.0 |
| **数据格式** | cJSON |
| **OTA 升级** | FOTA 全镜像/压缩(LZMA)/差分升级 + A/B 分区 |
| **构建系统** | Python(build.py) → CMake → Ninja/GCC |
| **编译器** | riscv32-linux-musl-gcc (musl libc) |
| **主机开发** | HiSparkStudio (Windows IDE) / WSL + VS Code |

---

## 五、驱动架构（四层分层）

```
┌─────────────────────────────────────────────┐
│  Adapter 层 (ohos_3.2/)                     │
│  IoT 标准接口: IoTGpio/IoWi2c/IoTPwm...     │
├─────────────────────────────────────────────┤
│  Driver 层 (drivers/driver/)                │
│  uapi_xxx API, 中断/DMA/LPM 管理            │
├─────────────────────────────────────────────┤
│  Chip Porting 层 (chips/ws63/porting/)      │
│  29个外设移植模块, 注册 HAL 函数表           │
├─────────────────────────────────────────────┤
│  HAL 层 (drivers/drivers/hal/)              │
│  23个外设: ADC/DMA/GPIO/I2C/PWM/UART...     │
│  接口模式: hal_xxx_funcs_t 函数表 + 版本变体 │
└─────────────────────────────────────────────┘
```

## 六、任务体系（LiteOS 主应用）

| 任务 | 优先级 | 栈大小 | 功能 |
|------|--------|--------|------|
| app | 27 | 2KB | 应用主循环（内存监控） |
| wifi | 25 | 8KB | Wi-Fi 协议栈主机 |
| log | 25 | 2KB | 日志后台任务 |
| appmain_start | 10 | 4KB | 农眼卫士主启动（WiFi+MQTT初始化） |
| sensor_task | 15 | 8KB | 传感器采集（DHT11/CO2/LDR/HC-SR04） |
| alarm_task | 12 | 4KB | 阈值告警+执行器联动 |
| voice_task | 10 | 4KB | 语音指令监听 |
| mqtt_init_task | — | 24KB | MQTT 上报+命令应答 |
| bt_sdk | 12 | 2KB | 蓝牙 SDK |
| bt_service | 12 | 4KB | 蓝牙服务 |
| recvBthDataTask | 10 | 2KB | BTH 数据接收 |
| bth_sdk | 13 | 0.5KB | BTH SDK 消息 |
| bt | 1 | ~3.5KB | 蓝牙基础任务 |
| at | 1 | 8KB | AT 命令处理 |
| cmd_loop | 1 | 4KB | 测试命令行 |

## 七、FOTA 升级架构

```
升级包存储(storage/upg_storage.c)
    ↓ 写入/读取
升级流程管理(local_update/upg_process.c)
    ├── 签名校验 → 哈希校验 → 镜像解析
    ├── 全镜像升级: 逐页拷贝
    ├── 压缩升级: LZMA 解压后写入
    └── 差分升级: 二进制 patch 应用
    ↓
芯片适配(chips/ws63/update/)
    ├── A/B 分区无缝切换
    └── 加密算法移植 + 备份恢复
```

## 八、开发板支持

| 开发板 | 芯片 | 示例数 | 特色 |
|--------|------|--------|------|
| BearPi-Pico H3863 | Hi3863 | 24 | Wi-Fi 6 + BLE 5.2 + SLE |
| HiHope NearLink DK WS63E V03 | WS63E | 26 | 雷达感知、MQTT 华为云 |
| 华清远见 WS63 | WS63 | 22 | 外设/BLE/SLE/Wi-Fi/华为云 |
| developers | WS63 | 2 | 开发者模板 |

## 九、构建与烧录

```bash
# 编译 LiteOS 主应用
python build.py ws63-liteos-app -j8 -release

# 编译 FlashBoot
python build.py ws63-flashboot -j4

# 编译 LoaderBoot
python build.py ws63-loaderboot

# 菜单配置
python build.py ws63-liteos-app menuconfig

# 输出固件
output/ws63/fwpkg/ws63-liteos-app/ws63-liteos-app_all.fwpkg
```
