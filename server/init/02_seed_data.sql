-- ============================================================
-- FarmEye Guard v1.0 — 种子数据：初始设备注册
-- 目标数据库：PostgreSQL 16（兼容 KingbaseES V8）
-- 幂等性：ON CONFLICT (device_id) DO NOTHING
-- ============================================================

INSERT INTO devices (device_id, device_name, mac_addr, online)
VALUES ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', FALSE)
ON CONFLICT (device_id) DO NOTHING;
