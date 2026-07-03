"""
API 客户端 — 对接 VPS 后端（/api/v1/）
"""
import requests

from config import api_base


class ApiClient:
    def __init__(self, cfg):
        self.cfg = cfg
        self._base = api_base(cfg)
        self._headers = {}
        if cfg.get("server_api_key"):
            self._headers["X-Api-Key"] = cfg["server_api_key"]

    def _process_response(self, r):
        try:
            data = r.json()
            if isinstance(data, dict):
                if "message" in data and "msg" not in data:
                    data["msg"] = data["message"]
                elif "msg" in data and "message" not in data:
                    data["message"] = data["msg"]
                if "code" not in data:
                    data["code"] = 0 if r.ok else r.status_code
                return data
        except Exception:
            pass
        msg = r.reason or f"HTTP {r.status_code}"
        return {"code": r.status_code, "msg": msg, "message": msg}

    def _get(self, path, params=None):
        try:
            r = requests.get(self._base + path, headers=self._headers,
                             params=params, timeout=5)
            return self._process_response(r)
        except Exception as e:
            return {"code": -1, "msg": str(e), "message": str(e)}

    def _post(self, path, json=None, params=None):
        try:
            r = requests.post(self._base + path, headers=self._headers,
                              json=json, params=params, timeout=5)
            return self._process_response(r)
        except Exception as e:
            return {"code": -1, "msg": str(e), "message": str(e)}

    # ---------- 环境数据 ----------

    def latest(self, device_id=None):
        params = {}
        if device_id:
            params["device_id"] = device_id
        return self._get("/sensor/latest", params)

    def history(self, device_id, start="", end="", page=1, page_size=100):
        params = {"device_id": device_id, "page": page, "page_size": page_size}
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        return self._get("/sensor/history", params)

    # ---------- 告警管理 ----------

    def alarm_list(self, page=1, page_size=20, device_id=None, severity=None,
                   start=None, end=None, crop_type=None, disease_type=None):
        params = {"page": page, "page_size": page_size}
        if device_id:
            params["device_id"] = device_id
        if severity:
            params["severity"] = severity
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        if crop_type:
            params["crop_type"] = crop_type
        if disease_type:
            params["disease_type"] = disease_type
        return self._get("/disease/list", params)

    def alarm_stats(self, start=None, end=None):
        params = {}
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        return self._get("/disease/stats", params)

    # ---------- 设备控制 ----------

    def device_list(self, device_id=None):
        params = {}
        if device_id:
            params["device_id"] = device_id
        return self._get("/device/list", params)

    def device_control(self, device_id, command, source="manual_pc", operator=None):
        body = {"device_id": device_id, "command": command, "source": source}
        if operator:
            body["operator"] = operator
        return self._post("/command/send", json=body)

    def command_logs(self, device_id=None, page=1, page_size=20, source=None, start=None, end=None):
        params = {"page": page, "page_size": page_size}
        if device_id:
            params["device_id"] = device_id
        if source:
            params["source"] = source
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        return self._get("/command/logs", params)

    # ---------- 防治建议 ----------

    def advisory(self, device_id=None, start=None, end=None, window_minutes=60):
        params = {"window_minutes": window_minutes}
        if device_id:
            params["device_id"] = device_id
        if start:
            params["start"] = start
        if end:
            params["end"] = end
        return self._get("/advisory", params)
