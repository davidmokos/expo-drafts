import Foundation
import CoreFoundation

/// Describes the launched JavaScript bundle, independently of which native builds
/// or channel heads are currently advertised in the catalog.
struct DraftBundleIdentity {
  let title: String
  let sourceLabel: String
  let updateID: String?
  let runtimeVersion: String?
  let createdAt: Date?
  let isEmbedded: Bool
  let nativeVersion: String?
  let nativeBuild: String?

  init(
    constants: [String: Any?],
    drafts: [DraftEntry],
    nativeVersion: String? = nil,
    nativeBuild: String? = nil
  ) {
    let updateID = (constants["updateId"] as? String)
      .flatMap(UUID.init(uuidString:))?.uuidString.lowercased()
    let runtimeVersion = Self.nonemptyString(constants["runtimeVersion"] as? String)
    let isEmbedded = constants["isEmbeddedLaunch"] as? Bool ?? false

    self.updateID = updateID
    self.runtimeVersion = runtimeVersion
    self.isEmbedded = isEmbedded
    self.nativeVersion = Self.nonemptyString(nativeVersion)
    self.nativeBuild = Self.nonemptyString(nativeBuild)
    self.createdAt = Self.date(milliseconds: constants["commitTime"] ?? nil)

    // SDK 57's embedded manifest contains a random ID, build timestamp, and
    // assets; it has no PR name, source commit, or EAS build ID. A shared runtime
    // and the request-header channel identify compatibility/routing, not source.
    let matches = drafts.filter { draft in
      guard let updateID, let runtimeVersion, let update = draft.iosUpdate else { return false }
      return UUID(uuidString: update.id)?.uuidString.lowercased() == updateID &&
        update.runtimeVersion == runtimeVersion
    }
    let matchedName = matches.count == 1 ? Self.nonemptyString(matches[0].name) : nil
    title = matchedName ?? (isEmbedded ? "Bundled in this build" : updateID != nil ? "Downloaded update" : "Current app")
    sourceLabel = isEmbedded ? "Native build" : updateID != nil ? "EAS Update" : "Source unavailable"
  }

  private static func nonemptyString(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return value
  }

  private static func date(milliseconds value: Any?) -> Date? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
    let seconds = number.doubleValue / 1000
    guard seconds.isFinite, seconds >= 0, seconds <= Date.distantFuture.timeIntervalSince1970 else { return nil }
    return Date(timeIntervalSince1970: seconds)
  }
}
