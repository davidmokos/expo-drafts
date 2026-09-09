import ExpoModulesCore
import UIKit

public class ExpoDraftsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoDrafts")

    AsyncFunction("open") {
      ExpoDraftsManager.shared.open()
    }.runOnQueue(.main)

    AsyncFunction("setVisible") { (visible: Bool) in
      ExpoDraftsManager.shared.setVisible(visible)
    }.runOnQueue(.main)

    Function("getState") {
      ExpoDraftsManager.shared.state()
    }
  }
}

public class ExpoDraftsAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func subscriberDidRegister() {
    if ExpoDraftsManager.shared.enabled {
      DraftsUpdateTransaction.recoverPendingSelection()
      ExpoDraftsManager.shared.observeUpdatesStartup()
    }
  }

  public func applicationDidBecomeActive(_ application: UIApplication) {
    ExpoDraftsManager.shared.install()
  }

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DispatchQueue.main.async {
      ExpoDraftsManager.shared.install()
    }
    return false
  }
}
