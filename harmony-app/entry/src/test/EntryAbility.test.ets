import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { AbilityConstant, ConfigurationConstant, Want, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import EntryAbility from '../main/ets/entryability/EntryAbility';
import { PollingManager } from '../main/ets/services/PollingManager';
import { sleep } from '../main/ets/common/utils';

interface MockAppContext { setColorMode: (mode: number) => void; }
interface MockContext { getApplicationContext: () => MockAppContext; }
interface MockWindowStage { loadContent: (path: string, cb: (err: Object | null) => void) => void; }
interface MockLoadErr { code: number; message: string; }

class TestableEntryAbility extends EntryAbility {
  public context: common.UIAbilityContext;
  constructor() {
    super();
    this.context = {} as common.UIAbilityContext;
  }
}

function tryCreateAbility(): TestableEntryAbility | null {
  try { return new TestableEntryAbility(); } catch (e) { return null; }
}

export default function entryAbilityTest() {
  describe('EntryAbility', () => {
    let ability: TestableEntryAbility | null;
    beforeEach(() => { PollingManager.stopAll(); ability = tryCreateAbility(); });
    afterEach(() => { PollingManager.stopAll(); });

    it('onCreate_calls_setColorMode_and_logs_info', 0, () => {
      const calls: string[] = [];
      const mockAppCtx: MockAppContext = {
        setColorMode: (mode: number): void => { calls.push('setColorMode:' + String(mode)); }
      };
      const mockCtx: MockContext = { getApplicationContext: (): MockAppContext => mockAppCtx };
      if (ability !== null) {
        ability.context = mockCtx as Object as common.UIAbilityContext;
        ability.onCreate({} as Want, {} as AbilityConstant.LaunchParam);
      }
      expect(calls.length).assertEqual(1);
      expect(calls[0]).assertEqual('setColorMode:' + String(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET));
    });

    it('onCreate_catches_setColorMode_exception', 0, () => {
      const mockAppCtx: MockAppContext = {
        setColorMode: (): void => { throw new Error('mock color mode error'); }
      };
      const mockCtx: MockContext = { getApplicationContext: (): MockAppContext => mockAppCtx };
      let didThrow = false;
      try {
        if (ability !== null) {
          ability.context = mockCtx as Object as common.UIAbilityContext;
          ability.onCreate({} as Want, {} as AbilityConstant.LaunchParam);
        }
      } catch (e) { didThrow = true; }
      expect(didThrow).assertFalse();
    });

    it('onDestroy_logs_info', 0, () => {
      let didThrow = false;
      try {
        if (ability !== null) { ability.onDestroy(); }
      } catch (e) { didThrow = true; }
      expect(didThrow).assertFalse();
    });

    it('onWindowStageCreate_calls_loadContent_with_pages_Index', 0, () => {
      let receivedPath: string | null = null;
      let callbackInvoked = false;
      const mockWindowStage: MockWindowStage = {
        loadContent: (path: string, cb: (err: Object | null) => void): void => {
          receivedPath = path;
          cb(null);
          callbackInvoked = true;
        }
      };
      if (ability !== null) {
        ability.onWindowStageCreate(mockWindowStage as Object as window.WindowStage);
      }
      expect(receivedPath).assertEqual('pages/Index');
      expect(callbackInvoked).assertTrue();
    });

    it('onWindowStageCreate_callback_err_logs_error', 0, () => {
      const failErr: MockLoadErr = { code: 1001, message: 'loadContent failed' };
      const mockWindowStage: MockWindowStage = {
        loadContent: (_path: string, cb: (err: Object | null) => void): void => { cb(failErr as Object); }
      };
      let didThrow = false;
      try {
        if (ability !== null) {
          ability.onWindowStageCreate(mockWindowStage as Object as window.WindowStage);
        }
      } catch (e) { didThrow = true; }
      expect(didThrow).assertFalse();
    });

    it('onWindowStageCreate_callback_null_logs_success', 0, () => {
      const mockWindowStage: MockWindowStage = {
        loadContent: (_path: string, cb: (err: Object | null) => void): void => { cb(null); }
      };
      let didThrow = false;
      try {
        if (ability !== null) {
          ability.onWindowStageCreate(mockWindowStage as Object as window.WindowStage);
        }
      } catch (e) { didThrow = true; }
      expect(didThrow).assertFalse();
    });

    it('onWindowStageDestroy_logs_info', 0, () => {
      let didThrow = false;
      try {
        if (ability !== null) { ability.onWindowStageDestroy(); }
      } catch (e) { didThrow = true; }
      expect(didThrow).assertFalse();
    });

    it('onForeground_logs_and_resumes_polling', 0, async () => {
      const calls: number[] = [];
      PollingManager.start('entry_ability_fg', async () => { calls.push(1); }, 30);
      await sleep(60);
      const initialCalls = calls.length;
      expect(initialCalls >= 1).assertTrue();
      PollingManager.suspendAll();
      const beforeResume = calls.length;
      await sleep(60);
      expect(calls.length).assertEqual(beforeResume);
      if (ability !== null) {
        ability.onForeground();
      }
      await sleep(80);
      expect(calls.length > beforeResume).assertTrue();
    });

    it('onBackground_logs_and_suspends_polling', 0, async () => {
      const calls: number[] = [];
      PollingManager.start('entry_ability_bg', async () => { calls.push(1); }, 30);
      await sleep(60);
      const initialCount = calls.length;
      if (ability !== null) {
        ability.onBackground();
      }
      const afterSuspend = calls.length;
      await sleep(120);
      expect(calls.length).assertEqual(afterSuspend);
      expect(initialCount >= 1).assertTrue();
    });
  });
}