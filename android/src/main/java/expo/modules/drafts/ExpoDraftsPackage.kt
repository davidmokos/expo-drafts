package expo.modules.drafts

import android.app.Activity
import android.content.Context
import android.os.Bundle
import expo.modules.core.interfaces.Package
import expo.modules.core.interfaces.ReactActivityLifecycleListener

/** Discovered by Expo autolinking, so the launcher does not depend on a JS import. */
class ExpoDraftsPackage : Package {
  override fun createReactActivityLifecycleListeners(activityContext: Context): List<ReactActivityLifecycleListener> =
    listOf(object : ReactActivityLifecycleListener {
      override fun onCreate(activity: Activity, savedInstanceState: Bundle?) {
        activity.window.decorView.post { DraftsController.attach(activity) }
      }

      override fun onResume(activity: Activity) {
        DraftsController.attach(activity)
      }

      override fun onContentChanged(activity: Activity) {
        activity.window.decorView.post { DraftsController.attach(activity) }
      }

      override fun onDestroy(activity: Activity) {
        DraftsController.detach(activity)
      }
    })
}
