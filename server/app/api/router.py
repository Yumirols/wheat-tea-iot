"""
FarmEye Guard v1.0 — 统一路由注册

集中管理所有 API 路由的注册，所有 v1 子路由在此统一挂载。
"""
from fastapi import APIRouter

from app.config import settings
from app.api.v1.iotda import router as iotda_router
from app.api.v1.sensor import router as sensor_router
from app.api.v1.disease import router as disease_router
from app.api.v1.device import router as device_router
from app.api.v1.command import router as command_router
from app.api.v1.advisory import router as advisory_router
from app.api.v1.image import router as image_router

api_router = APIRouter(prefix=settings.API_V1_PREFIX)

# v1 子路由注册
api_router.include_router(iotda_router)
api_router.include_router(sensor_router)
api_router.include_router(disease_router)
api_router.include_router(device_router)
api_router.include_router(command_router)
api_router.include_router(advisory_router)
api_router.include_router(image_router)
