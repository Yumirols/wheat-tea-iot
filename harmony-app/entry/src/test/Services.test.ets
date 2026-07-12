import pollingManagerTest from './PollingManager.test';
import deviceServiceTest from './DeviceService.test';
import sensorServiceTest from './SensorService.test';
import diseaseServiceTest from './DiseaseService.test';
import commandServiceTest from './CommandService.test';
import advisoryServiceTest from './AdvisoryService.test';
import httpClientTest from './HttpClient.test';

/**
 * R2 服务层单元测试套件。
 *
 * 覆盖：
 * - PollingManager（生命周期：start/stop/stopAll/suspendAll/resumeAll）
 * - DeviceService（缓存过滤逻辑、缓存 key 格式）
 * - SensorService（缓存命中路径）
 * - DiseaseService（缓存命中路径、key 隔离）
 * - CommandService（前置校验放行路径）
 * - AdvisoryService（缓存命中路径、key 构造）
 * - HttpClient（配置与网络失败抛错路径）
 *
 * 注：ImageService 强依赖 @kit.AbilityKit 的 UIAbilityContext 与 api.uploadFile
 * 的实际网络栈，本轮不编写测试（依赖注入缺失，需后续轮次配合 mock 框架）。
 */
export default function servicesTestSuite() {
  pollingManagerTest();
  deviceServiceTest();
  sensorServiceTest();
  diseaseServiceTest();
  commandServiceTest();
  advisoryServiceTest();
  httpClientTest();
}