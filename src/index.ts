import ExpoDrafts from './ExpoDraftsModule';

/** Open the native draft picker. The floating button is installed automatically. */
export function openDrafts(): Promise<void> {
  return ExpoDrafts.open();
}
/** Show or hide the native floating button for this app session. */
export function setDraftsVisible(visible: boolean): Promise<void> {
  return ExpoDrafts.setVisible(visible);
}
/** Read the installed native runtime and running EAS update. */
export function getDraftsState() {
  return ExpoDrafts.getState();
}

export default ExpoDrafts;
export * from './ExpoDrafts.types';
