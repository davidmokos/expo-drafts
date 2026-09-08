package expo.modules.drafts

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.functions.Queues

class ExpoDraftsModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("ExpoDrafts")

    AsyncFunction("open") {
      DraftsController.open(appContext.throwingActivity)
    }.runOnQueue(Queues.MAIN)

    AsyncFunction("setVisible") { visible: Boolean ->
      DraftsController.setVisible(appContext.throwingActivity, visible)
    }.runOnQueue(Queues.MAIN)

    Function("getState") {
      DraftsController.getState(appContext.throwingActivity)
    }
  }
}
