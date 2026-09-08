import { NativeModule, requireNativeModule } from 'expo';

import type { DraftsState } from './ExpoDrafts.types';

declare class ExpoDraftsModule extends NativeModule {
  open(): Promise<void>;
  setVisible(visible: boolean): Promise<void>;
  getState(): DraftsState;
}

export default requireNativeModule<ExpoDraftsModule>('ExpoDrafts');
