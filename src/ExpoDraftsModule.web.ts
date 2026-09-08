export default {
  async open() {
    throw new Error('expo-drafts requires an iOS preview build.');
  },
  async setVisible(_visible: boolean) {},
  getState() {
    return { enabled: false, runtimeVersion: null, updateId: null, channel: null };
  },
};
