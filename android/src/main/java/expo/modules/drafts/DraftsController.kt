package expo.modules.drafts

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import expo.modules.updates.IUpdatesController
import expo.modules.updates.UpdatesController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference
import kotlin.math.abs
import kotlin.math.roundToInt

/** Process-owned native UI; React reloads and JS errors cannot remove the switcher. */
internal object DraftsController {
  private const val PREFIX = "expo.modules.drafts."
  private val background = Color.rgb(16, 19, 25)
  private val surface = Color.rgb(28, 33, 42)
  private val border = Color.rgb(47, 55, 69)
  private val foreground = Color.rgb(243, 246, 252)
  private val secondary = Color.rgb(162, 174, 194)
  private val accent = Color.rgb(157, 240, 193)
  private val warning = Color.rgb(255, 199, 128)
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private var activityRef = WeakReference<Activity>(null)
  private var bubble: View? = null
  private var dialog: Dialog? = null
  private var body: LinearLayout? = null
  @Volatile private var visible = true
  @Volatile private var loading = false
  @Volatile private var switching = false
  @Volatile private var catalog: DraftCatalog? = null
  @Volatile private var error: String? = null
  private var progress: String? = null
  private var catalogSource: String? = null

  private data class Configuration(
    val enabled: Boolean,
    val catalogUrl: String?,
    val projectId: String?,
    val buildUrl: String?
  )

  private fun configuration(context: Context): Configuration {
    val metadata = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA).metaData
    return Configuration(
      enabled = metadata?.getBoolean(PREFIX + "ENABLED", false) ?: false,
      catalogUrl = metadata?.getString(PREFIX + "CATALOG_URL"),
      projectId = metadata?.getString(PREFIX + "PROJECT_ID"),
      buildUrl = metadata?.getString(PREFIX + "BUILD_URL")
    )
  }

  private fun constants(): IUpdatesController.UpdatesModuleConstants? =
    runCatching { UpdatesController.instance.getConstantsForModule() }.getOrNull()

  fun attach(activity: Activity) {
    if (activity.isFinishing || activity.isDestroyed) return
    if (activityRef.get() !== activity) {
      bubble?.let { (it.parent as? ViewGroup)?.removeView(it) }
      bubble = null
      dialog?.dismiss()
      dialog = null
      body = null
      activityRef = WeakReference(activity)
    }
    if (!configuration(activity).enabled || !visible) {
      bubble?.visibility = View.GONE
      return
    }
    val decor = activity.window.decorView as? FrameLayout ?: return
    val existing = bubble
    if (existing != null && existing.parent === decor) {
      existing.visibility = View.VISIBLE
      existing.bringToFront()
      return
    }
    val button = button(activity, "◈  Drafts", accent, surface).apply {
      contentDescription = "Open Expo Drafts update picker"
      elevation = dp(activity, 10).toFloat()
      setOnClickListener { open(activity) }
    }
    val layout = FrameLayout.LayoutParams(dp(activity, 112), dp(activity, 48), Gravity.BOTTOM or Gravity.END).apply {
      setMargins(dp(activity, 16), dp(activity, 40), dp(activity, 16), dp(activity, 80))
    }
    // A small native drag target stays reachable while the React surface reloads.
    var startRawX = 0f
    var startRawY = 0f
    var startX = 0f
    var startY = 0f
    var dragging = false
    button.setOnTouchListener { view, event ->
      when (event.actionMasked) {
        MotionEvent.ACTION_DOWN -> {
          startRawX = event.rawX
          startRawY = event.rawY
          startX = view.translationX
          startY = view.translationY
          dragging = false
          true
        }
        MotionEvent.ACTION_MOVE -> {
          val deltaX = event.rawX - startRawX
          val deltaY = event.rawY - startRawY
          if (abs(deltaX) + abs(deltaY) > dp(activity, 8)) dragging = true
          if (dragging) {
            val margin = dp(activity, 12).toFloat()
            val minX = margin - view.left
            val maxX = decor.width - view.right - margin
            val minY = dp(activity, 40).toFloat() - view.top
            val maxY = decor.height - view.bottom - dp(activity, 40)
            view.translationX = (startX + deltaX).coerceIn(minX, maxX.coerceAtLeast(minX))
            view.translationY = (startY + deltaY).coerceIn(minY, maxY.coerceAtLeast(minY))
          }
          true
        }
        MotionEvent.ACTION_UP -> {
          if (!dragging) view.performClick()
          true
        }
        MotionEvent.ACTION_CANCEL -> true
        else -> false
      }
    }
    decor.addView(button, layout)
    bubble = button
  }

  fun detach(activity: Activity) {
    if (activityRef.get() !== activity) return
    dialog?.dismiss()
    dialog = null
    body = null
    bubble?.let { (it.parent as? ViewGroup)?.removeView(it) }
    bubble = null
    activityRef.clear()
  }

  fun setVisible(activity: Activity, value: Boolean) {
    visible = value
    attach(activity)
  }

  fun getState(activity: Activity): Map<String, Any?> {
    val config = configuration(activity)
    val updates = constants()
    val updateId = updates?.launchedUpdate?.id?.toString()
    return mapOf(
      "enabled" to config.enabled,
      "visible" to (visible && config.enabled),
      "isLoading" to (loading || switching),
      "runtimeVersion" to updates?.runtimeVersion,
      "channel" to updates?.requestHeaders?.get("expo-channel-name"),
      "updateId" to updateId,
      "selectedDraftId" to catalog?.drafts?.firstOrNull { it.androidUpdate?.id == updateId }?.id,
      "catalogUrl" to config.catalogUrl,
      "error" to error
    )
  }

  fun open(activity: Activity) {
    attach(activity)
    check(configuration(activity).enabled) { "Expo Drafts is not enabled in this native build." }
    if (dialog?.isShowing == true) return
    val picker = Dialog(activity)
    picker.requestWindowFeature(Window.FEATURE_NO_TITLE)
    val scroll = ScrollView(activity).apply {
      isFillViewport = true
      clipToPadding = false
      setPadding(dp(activity, 22), dp(activity, 18), dp(activity, 22), dp(activity, 30))
      background = rounded(DraftsController.background, 26, activity)
    }
    body = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
    scroll.addView(body, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    picker.setContentView(scroll)
    picker.setOnDismissListener {
      if (dialog === picker) {
        dialog = null
        body = null
      }
    }
    dialog = picker
    picker.show()
    picker.window?.apply {
      setBackgroundDrawableResource(android.R.color.transparent)
      addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
      setDimAmount(0.55f)
      setGravity(Gravity.BOTTOM)
      val width = activity.resources.displayMetrics.widthPixels
      val height = activity.resources.displayMetrics.heightPixels
      setLayout((width - dp(activity, 16)).coerceAtMost(dp(activity, 580)), (height * 0.84).roundToInt())
    }
    render()
    if (!switching && !loading) refresh()
  }

  private fun render() {
    val activity = activityRef.get() ?: return
    val root = body ?: return
    root.removeAllViews()
    val config = configuration(activity)
    val current = constants()
    val runtime = current?.runtimeVersion
    val updateId = current?.launchedUpdate?.id?.toString()
    val controls = LinearLayout(activity).apply { gravity = Gravity.CENTER_VERTICAL }
    controls.addView(label(activity, "EXPO DRAFTS", 12, accent, true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
    controls.addView(button(activity, "Close", secondary, background).apply {
      isEnabled = !switching
      setOnClickListener { dialog?.dismiss() }
    }, LinearLayout.LayoutParams(dp(activity, 72), dp(activity, 44)))
    root.addView(controls)
    root.addView(label(activity, "Choose a draft", 29, foreground, true))
    root.addView(label(activity, "Preview a pull request on this device.", 14, secondary), spaced(activity, 5, 16))

    val details = LinearLayout(activity).apply {
      orientation = LinearLayout.VERTICAL
      background = rounded(surface, 14, activity)
      setPadding(dp(activity, 14), dp(activity, 12), dp(activity, 14), dp(activity, 12))
    }
    details.addView(label(activity, "THIS NATIVE BUILD", 10, secondary, true))
    details.addView(label(activity, "Runtime  ${runtime ?: "unavailable"}", 12, foreground).apply {
      typeface = Typeface.MONOSPACE
      setTextIsSelectable(true)
    }, spaced(activity, 5, 4))
    val currentName = catalog?.drafts?.firstOrNull { it.androidUpdate?.id == updateId }?.name
    val currentChannel = current?.requestHeaders?.get("expo-channel-name")
    details.addView(label(activity, "Running  ${currentName ?: currentChannel ?: "embedded app"}", 12, secondary))
    root.addView(details, spaced(activity, 0, 15))

    if (current?.isEnabled != true) {
      root.addView(label(activity, "EAS Update is unavailable in this build. Install an EAS preview build with expo-drafts and expo-updates enabled.", 14, warning), spaced(activity, 0, 12))
    }
    progress?.let { root.addView(label(activity, it, 14, accent), spaced(activity, 0, 12)) }
    error?.let {
      root.addView(label(activity, it, 14, warning).apply { contentDescription = "Drafts error: $it" }, spaced(activity, 0, 12))
    }
    val refreshButton = button(activity, if (loading) "Refreshing…" else "Refresh drafts", foreground, surface).apply {
      isEnabled = !loading && !switching
      alpha = if (isEnabled) 1f else 0.55f
      setOnClickListener { refresh() }
    }
    root.addView(refreshButton, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(activity, 44)).apply { bottomMargin = dp(activity, 18) })
    val entries = catalog?.drafts.orEmpty()
    if (entries.isEmpty() && !loading && error == null) {
      root.addView(label(activity, "No drafts yet", 18, foreground, true), spaced(activity, 10, 5))
      root.addView(label(activity, "Publish an EAS Update from a pull request to see it here.", 14, secondary), spaced(activity, 0, 18))
    }
    for (draft in entries) {
      val update = draft.androidUpdate
      val compatible = current?.isEnabled == true && runtime != null && update?.runtimeVersion == runtime
      val running = update?.id == updateId
      val card = LinearLayout(activity).apply {
        orientation = LinearLayout.VERTICAL
        background = rounded(surface, 16, activity, if (running) accent else border)
        setPadding(dp(activity, 16), dp(activity, 15), dp(activity, 16), dp(activity, 15))
      }
      val status = when {
        running -> "RUNNING"
        update == null -> "NO ANDROID UPDATE"
        compatible -> "READY TO OPEN"
        else -> "NEW BUILD REQUIRED"
      }
      card.addView(label(activity, status, 10, if (compatible || running) accent else warning, true))
      card.addView(label(activity, draft.name, 19, foreground, true), spaced(activity, 7, 5))
      val pr = draft.pullRequestNumber?.let { "  ·  PR #$it" } ?: ""
      card.addView(label(activity, draft.channel + pr, 12, secondary))
      draft.message?.let { message ->
        card.addView(label(activity, message, 13, secondary).apply { maxLines = 3 }, spaced(activity, 7, 3))
      }
      if (!compatible && !running) {
        val explanation = if (update == null) {
          "This draft has no Android update. Publish it for Android to preview it here."
        } else if (current?.isEnabled != true) {
          "Install a preview build with EAS Update enabled."
        } else {
          "This draft needs a different native runtime. Install a new build from EAS to open it.\nRequired: ${update.runtimeVersion}"
        }
        card.addView(label(activity, explanation, 13, warning), spaced(activity, 11, 2))
        val buildUrl = draft.buildUrl ?: config.buildUrl
        if (buildUrl != null) {
          card.addView(button(activity, "Open EAS builds ↗", warning, surface).apply {
            setOnClickListener { openExternal(buildUrl) }
          }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(activity, 44)).apply { topMargin = dp(activity, 8) })
        }
      } else {
        card.addView(button(activity, if (running) "Currently running" else "Open draft  →", if (running) secondary else background, if (running) surface else accent).apply {
          isEnabled = compatible && !running && !switching && !loading && error == null
          alpha = if (isEnabled || running) 1f else 0.45f
          contentDescription = if (running) "${draft.name}, currently running" else "Open draft ${draft.name}"
          setOnClickListener { switchTo(draft) }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(activity, 46)).apply { topMargin = dp(activity, 13) })
      }
      root.addView(card, spaced(activity, 0, 12))
    }
    root.addView(label(activity, "Drafts run downloaded EAS Updates. Native changes require a new build.", 12, secondary), spaced(activity, 6, 0))
    dialog?.setCancelable(!switching)
    dialog?.setCanceledOnTouchOutside(!switching)
  }

  private fun refresh() {
    if (loading || switching) return
    val activity = activityRef.get() ?: return
    val config = configuration(activity)
    loading = true
    error = null
    progress = "Loading your published drafts…"
    if (catalogSource != config.catalogUrl) catalog = null
    render()
    scope.launch {
      try {
        val url = config.catalogUrl ?: error("Set catalogUrl in the expo-drafts config plugin and rebuild.")
        val projectId = config.projectId ?: error("Set projectId in the expo-drafts config plugin and rebuild.")
        catalog = withContext(Dispatchers.IO) { DraftCatalog.load(url, projectId) }
        catalogSource = url
      } catch (exception: Exception) {
        error = exception.message ?: "Could not load the catalog. Check your connection and refresh."
      } finally {
        loading = false
        progress = null
        render()
      }
    }
  }

  private fun switchTo(draft: Draft) {
    if (switching || loading) return
    val update = draft.androidUpdate ?: return
    val updates = constants() ?: return
    if (!updates.isEnabled || update.runtimeVersion != updates.runtimeVersion) return
    if (catalog?.drafts?.none { it.id == draft.id } != false) return
    switching = true
    error = null
    progress = "Downloading ${draft.name}…"
    render()
    val controller = UpdatesController.instance
    val previousHeaders = updates.requestHeaders.toMap()
    var headersChanged = false
    scope.launch {
      try {
        // Partition Expo's persisted cache by the exact selection. A catalog race may download
        // a different update before we can reject it; restoring this key also isolates that cache.
        controller.setUpdateRequestHeadersOverride(previousHeaders + mapOf(
          "expo-channel-name" to draft.channel,
          "expo-drafts-selection" to update.id
        ))
        headersChanged = true
        val fetched = controller.fetchUpdate()
        when (fetched) {
          is IUpdatesController.FetchUpdateResult.Success -> {
            check(fetched.update.id.toString().equals(update.id, ignoreCase = true)) {
              "This channel changed while the catalog was open. Refresh drafts to select its latest update."
            }
            check(fetched.update.runtimeVersion == updates.runtimeVersion) {
              "This draft needs a new native build. Install its matching EAS build."
            }
          }
          is IUpdatesController.FetchUpdateResult.ErrorResult -> throw fetched.error
          is IUpdatesController.FetchUpdateResult.RollBackToEmbedded -> error("This channel was rolled back. Refresh drafts before trying again.")
          is IUpdatesController.FetchUpdateResult.Failure -> error("The selected update is unavailable. Refresh drafts and try again.")
        }
        progress = "Opening ${draft.name}…"
        render()
        controller.relaunchReactApplicationForModule()
        dialog?.dismiss()
      } catch (exception: Exception) {
        val restoreError = if (headersChanged) {
          runCatching { controller.setUpdateRequestHeadersOverride(previousHeaders) }.exceptionOrNull()
        } else null
        error = if (restoreError == null) {
          exception.message ?: "The draft could not be opened. Refresh and try again."
        } else {
          "${exception.message ?: "The draft could not be opened."} Could not restore the previous channel; reopen the app before switching again."
        }
      } finally {
        switching = false
        progress = null
        render()
      }
    }
  }

  private fun openExternal(url: String) {
    val activity = activityRef.get() ?: return
    runCatching {
      DraftCatalog.requireHttpsUrl(url)
      activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addCategory(Intent.CATEGORY_BROWSABLE))
    }.onFailure {
      error = "Could not open the EAS build link. ${it.message ?: ""}".trim()
      render()
    }
  }

  private fun label(context: Context, value: String, size: Int, color: Int, bold: Boolean = false) = TextView(context).apply {
    text = value
    textSize = size.toFloat()
    setTextColor(color)
    typeface = if (bold) Typeface.create("sans-serif", Typeface.BOLD) else Typeface.create("sans-serif", Typeface.NORMAL)
    setLineSpacing(dp(context, 3).toFloat(), 1f)
    includeFontPadding = false
  }

  private fun button(context: Context, value: String, color: Int, fill: Int) = Button(context).apply {
    text = value
    textSize = 13f
    isAllCaps = false
    setTextColor(color)
    typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    background = rounded(fill, 12, context, if (fill == surface) border else null)
    backgroundTintList = ColorStateList.valueOf(fill)
    setPadding(dp(context, 10), 0, dp(context, 10), 0)
    minWidth = 0
    minimumWidth = 0
    minHeight = 0
    minimumHeight = 0
    stateListAnimator = null
  }

  private fun rounded(fill: Int, radius: Int, context: Context, stroke: Int? = null) = GradientDrawable().apply {
    setColor(fill)
    cornerRadius = dp(context, radius).toFloat()
    if (stroke != null) setStroke(dp(context, 1), stroke)
  }

  private fun spaced(context: Context, top: Int, bottom: Int) = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
    topMargin = dp(context, top)
    bottomMargin = dp(context, bottom)
  }

  private fun dp(context: Context, value: Int) = (context.resources.displayMetrics.density * value).roundToInt()
}
