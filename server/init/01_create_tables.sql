-- ============================================================
-- FarmEye Guard v1.0 — 数据库初始化 DDL
-- 目标数据库：PostgreSQL 16（兼容 KingbaseES V8）
-- ============================================================

-- 表 1：环境数据快照
CREATE TABLE IF NOT EXISTS sensor_snapshot (
    id          BIGSERIAL PRIMARY KEY,
    device_id   VARCHAR(64) NOT NULL,
    mac_addr    VARCHAR(17),
    timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    temperature DECIMAL(4,1),
    humidity    DECIMAL(4,1),
    light       INT,
    co2         INT,
    soil_n      DECIMAL(5,1),
    soil_p      DECIMAL(5,1),
    soil_k      DECIMAL(5,1),
    distance    INT,
    rssi        SMALLINT,
    ip_addr     VARCHAR(16),
    alarm_flag  INT,

    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sensor_device_time
    ON sensor_snapshot (device_id, timestamp);


-- 表 2：病虫害识别记录
CREATE TABLE IF NOT EXISTS disease_records (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    crop_type       VARCHAR(32) NOT NULL,
    disease_type    VARCHAR(64) NOT NULL,
    confidence      DECIMAL(4,3),
    severity        VARCHAR(16) NOT NULL,
    severity_code   SMALLINT NOT NULL,  -- 1=Mild, 2=Moderate, 3=Severe

    linkage_risk_level  VARCHAR(16),    -- 联动风险等级: low / medium / high
    linkage_detail      VARCHAR(512),   -- 联动分析详情

    image_path      VARCHAR(512),
    action_taken    VARCHAR(128),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_disease_device_time
    ON disease_records (device_id, timestamp, disease_type);


-- 表 3：设备控制日志
CREATE TABLE IF NOT EXISTS control_logs (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    command_id      VARCHAR(64),               -- IoTDA 命令 ID
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    command         VARCHAR(64) NOT NULL,
    source          VARCHAR(32) NOT NULL,       -- 'auto' / 'manual_app' / 'manual_pc'
    operator        VARCHAR(64),
    result_code     INT,
    result_msg      VARCHAR(255),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_control_command_id
    ON control_logs (command_id) WHERE command_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_control_device_time
    ON control_logs (device_id, timestamp);


-- 表 4：设备注册信息
CREATE TABLE IF NOT EXISTS devices (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL UNIQUE,
    device_name     VARCHAR(128),
    mac_addr        VARCHAR(17),
    ip_addr         VARCHAR(16),
    registered_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen       TIMESTAMP,
    online          BOOLEAN DEFAULT FALSE,

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_device_id
    ON devices (device_id);


-- 表 5：环境数据日聚合
CREATE TABLE IF NOT EXISTS sensor_daily_aggregation (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    agg_date        DATE NOT NULL,

    avg_temperature DECIMAL(4,1),
    max_temperature DECIMAL(4,1),
    min_temperature DECIMAL(4,1),
    avg_humidity    DECIMAL(4,1),
    max_humidity    DECIMAL(4,1),
    min_humidity    DECIMAL(4,1),
    avg_light       DECIMAL(5,1),
    max_light       INT,
    min_light       INT,
    avg_co2         DECIMAL(6,1),
    max_co2         INT,
    min_co2         INT,

    record_count    INT,

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (device_id, agg_date)
);

CREATE INDEX IF NOT EXISTS idx_agg_device_date
    ON sensor_daily_aggregation (device_id, agg_date);
