import advisoryServiceTest from './AdvisoryService.test';
import commandServiceTest from './CommandService.test';
import deviceServiceTest from './DeviceService.test';
import localUnitTest from './LocalUnit.test';
import pollingManagerTest from './PollingManager.test';
import sensorServiceTest from './SensorService.test';
import servicesTestSuite from './Services.test';
import utilsTest from './Utils.test';
import cacheManagerTest from './CacheManager.test';
import httpClientTest from './HttpClient.test';
import entryAbilityTest from './EntryAbility.test';
import entryBackupAbilityTest from './EntryBackupAbility.test';

export default function testsuite() {
  advisoryServiceTest();
  commandServiceTest();
  deviceServiceTest();
  localUnitTest();
  pollingManagerTest();
  sensorServiceTest();
  servicesTestSuite();
  utilsTest();
  cacheManagerTest();
  httpClientTest();
  entryAbilityTest();
  entryBackupAbilityTest();
}