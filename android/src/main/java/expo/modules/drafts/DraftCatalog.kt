package expo.modules.drafts

import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.text.ParsePosition
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID

internal data class DraftUpdate(val id: String, val platform: String, val runtimeVersion: String)

internal data class Draft(
  val id: String,
  val name: String,
  val channel: String,
  val message: String?,
  val createdAt: String,
  val timestamp: Long,
  val buildUrl: String?,
  val pullRequestNumber: Int?,
  val updates: List<DraftUpdate>
) {
  val androidUpdate: DraftUpdate? get() = updates.firstOrNull { it.platform == "android" }
}

internal data class DraftCatalog(val generatedAt: String, val drafts: List<Draft>) {
  companion object {
    private const val MAX_BYTES = 2 * 1024 * 1024

    fun load(catalogUrl: String, projectId: String): DraftCatalog {
      var url = requireHttpsUrl(catalogUrl)
      repeat(4) { redirectCount ->
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
          connection.connectTimeout = 15_000
          connection.readTimeout = 20_000
          connection.instanceFollowRedirects = false
          connection.useCaches = false
          connection.setRequestProperty("Accept", "application/json")
          connection.setRequestProperty("Cache-Control", "no-cache")
          val status = connection.responseCode
          if (status in listOf(301, 302, 303, 307, 308)) {
            check(redirectCount < 3) { "The draft catalog redirected too many times." }
            val location = connection.getHeaderField("Location")
              ?: error("The draft catalog returned an invalid redirect.")
            url = requireHttpsUrl(URI(url).resolve(location).toString())
          } else {
            check(status == 200) { "Could not load the draft catalog (HTTP $status)." }
            check(connection.contentLengthLong <= MAX_BYTES) { "The draft catalog is too large." }
            val data = ByteArrayOutputStream()
            connection.inputStream.use { input ->
              val buffer = ByteArray(8192)
              while (true) {
                val count = input.read(buffer)
                if (count == -1) break
                check(data.size() + count <= MAX_BYTES) { "The draft catalog is too large." }
                data.write(buffer, 0, count)
              }
            }
            return parse(data.toString("UTF-8"), projectId)
          }
        } finally {
          connection.disconnect()
        }
      }
      error("Could not load the draft catalog.")
    }

    fun parse(source: String, projectId: String): DraftCatalog {
      val json = JSONObject(source)
      check(json.opt("schemaVersion") == 1) { "This catalog needs a newer version of expo-drafts." }
      check(uuid(json.text("projectId")) == uuid(projectId)) { "This catalog belongs to a different EAS project." }
      val generatedAt = json.text("generatedAt")
      timestamp(generatedAt)
      val entries = json.getJSONArray("drafts")
      check(entries.length() <= 1000) { "The catalog has too many drafts." }
      val drafts = (0 until entries.length()).map { index ->
        val row = entries.getJSONObject(index)
        val updates = row.getJSONArray("updates")
        check(updates.length() in 1..2) { "A draft must contain one update per supported platform." }
        val parsedUpdates = (0 until updates.length()).map { updateIndex ->
          val update = updates.getJSONObject(updateIndex)
          val platform = update.text("platform")
          check(platform == "android" || platform == "ios") { "Unknown update platform." }
          DraftUpdate(uuid(update.text("id")), platform, update.text("runtimeVersion"))
        }
        check(parsedUpdates.map { it.platform }.distinct().size == parsedUpdates.size) { "A draft contains duplicate platforms." }
        val channel = row.text("channel", 200)
        check(channel.none { it.isISOControl() }) { "Invalid channel name." }
        val createdAt = row.text("createdAt")
        val pullRequest = row.opt("pullRequest")?.takeUnless { it == JSONObject.NULL }?.let {
          check(it is JSONObject) { "Invalid pull request." }
          it.optionalText("url")?.let(::requireHttpsUrl)
          val number = it.opt("number")
          check(number is Int && number > 0) { "Invalid pull request number." }
          number
        }
        Draft(
          id = uuid(row.text("id")),
          name = row.text("name", 300),
          channel = channel,
          message = row.optionalText("message", 2000),
          createdAt = createdAt,
          timestamp = timestamp(createdAt),
          buildUrl = row.optionalText("buildUrl")?.let(::requireHttpsUrl),
          pullRequestNumber = pullRequest,
          updates = parsedUpdates
        )
      }
      check(drafts.map { it.id }.distinct().size == drafts.size) { "The catalog contains duplicate draft IDs." }
      return DraftCatalog(generatedAt, drafts.sortedByDescending { it.timestamp }.distinctBy { it.channel })
    }

    fun requireHttpsUrl(value: String): String {
      val uri = URI(value)
      check(uri.scheme?.lowercase(Locale.ROOT) == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null) {
        "Draft catalog and build links must use HTTPS without embedded credentials."
      }
      return value
    }

    private fun uuid(value: String): String {
      check(value.matches(Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"))) {
        "The catalog contains an invalid update or project ID."
      }
      return UUID.fromString(value).toString()
    }

    private fun timestamp(value: String): Long {
      for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", "yyyy-MM-dd'T'HH:mm:ssXXX")) {
        val format = SimpleDateFormat(pattern, Locale.US).apply { isLenient = false }
        val position = ParsePosition(0)
        val date = format.parse(value, position)
        if (date != null && position.index == value.length) return date.time
      }
      error("The draft catalog contains an invalid date.")
    }
  }
}

private fun JSONObject.text(key: String, maxLength: Int = 1000): String {
  val value = opt(key)
  check(value is String && value.isNotBlank() && value.length <= maxLength) { "Invalid catalog field: $key." }
  return value
}

private fun JSONObject.optionalText(key: String, maxLength: Int = 1000): String? {
  if (!has(key) || isNull(key)) return null
  val value = opt(key)
  check(value is String && value.length <= maxLength) { "Invalid catalog field: $key." }
  return value.takeIf { it.isNotBlank() }
}
