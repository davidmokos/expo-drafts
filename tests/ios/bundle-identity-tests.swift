import Foundation

@main
struct BundleIdentityTests {
  static let currentID = "a1111111-b222-4333-8444-c55555555555"
  static let otherID = "d1111111-e222-4333-8444-f55555555555"
  static let runtime = "runtime-one"
  static let timestamp: UInt64 = 1_788_960_429_174

  static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
      throw NSError(domain: "bundle-identity-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
  }

  static func draft(
    name: String = "Reading list", id: String = currentID,
    runtimeVersion: String = runtime, platform: String = "ios"
  ) -> DraftEntry {
    DraftEntry(
      id: otherID, name: name, channel: "draft-pr-2", branch: nil, message: nil,
      createdAt: "2026-09-09T13:27:09.174Z", gitCommitHash: String(repeating: "a", count: 40),
      pullRequest: nil, buildUrl: nil,
      updates: [DraftUpdate(id: id, platform: platform, runtimeVersion: runtimeVersion)]
    )
  }

  static func constants(embedded: Bool = false) -> [String: Any?] {
    [
      "updateId": currentID.uppercased(), "runtimeVersion": runtime,
      "isEmbeddedLaunch": embedded, "commitTime": timestamp, "channel": "draft-pr-2"
    ]
  }

  static func main() throws {
    let embedded = DraftBundleIdentity(
      constants: constants(embedded: true), drafts: [draft(id: otherID)],
      nativeVersion: "1.0.0", nativeBuild: "1"
    )
    try expect(embedded.title == "Bundled in this build", "A shared runtime/channel must not name the embedded bundle after a PR")
    try expect(embedded.sourceLabel == "Native build" && embedded.isEmbedded, "Embedded source comes from Expo's launch classification")
    try expect(embedded.updateID == currentID && embedded.runtimeVersion == runtime, "Preserve the actual embedded UUID and runtime")
    try expect(embedded.nativeVersion == "1.0.0" && embedded.nativeBuild == "1", "Expose the installed native version separately")
    try expect(embedded.createdAt?.timeIntervalSince1970 == Double(timestamp) / 1000, "Expo commitTime is milliseconds, not seconds or a Git commit")
    print("PASS embedded bundle identity remains truthful without a catalog match")

    let exact = DraftBundleIdentity(constants: constants(), drafts: [draft(id: otherID), draft()])
    try expect(exact.title == "Reading list" && exact.sourceLabel == "EAS Update", "An exact iOS UUID/runtime match supplies the catalog name")
    try expect(!exact.isEmbedded && exact.updateID == currentID, "Case normalization must preserve actual update identity")
    let matchedEmbedded = DraftBundleIdentity(constants: constants(embedded: true), drafts: [draft()])
    try expect(matchedEmbedded.title == "Reading list" && matchedEmbedded.sourceLabel == "Native build", "Matching metadata cannot change the actual launch source")
    print("PASS exact catalog identification and independent source classification")

    for entries in [
      [draft(runtimeVersion: "runtime-two")],
      [draft(runtimeVersion: "RUNTIME-ONE")],
      [draft(platform: "android")],
      [draft(id: otherID)],
      [draft(), draft(name: "Another name")]
    ] {
      let identity = DraftBundleIdentity(constants: constants(), drafts: entries)
      try expect(identity.title == "Downloaded update", "Mismatched or ambiguous catalog entries must not identify the current bundle")
    }
    var missingRuntime = constants()
    missingRuntime["runtimeVersion"] = ""
    try expect(DraftBundleIdentity(constants: missingRuntime, drafts: [draft()]).title == "Downloaded update", "ID alone is not the agreed catalog match")
    var embeddedAssets = constants()
    embeddedAssets["isUsingEmbeddedAssets"] = true
    try expect(!DraftBundleIdentity(constants: embeddedAssets, drafts: []).isEmbedded, "Asset reuse does not mean an embedded launch")
    print("PASS runtime, platform, ambiguity, and embedded-asset false-match protection")

    let uncataloged = DraftBundleIdentity(constants: constants(), drafts: [])
    try expect(uncataloged.title == "Downloaded update" && uncataloged.updateID == currentID, "A downloaded update remains identifiable after its channel head leaves the catalog")
    try expect(uncataloged.createdAt == exact.createdAt, "Unavailable catalog metadata must not hide Expo's actual timestamp")
    let unknown = DraftBundleIdentity(constants: [:], drafts: [draft(id: "")], nativeVersion: " ", nativeBuild: "")
    try expect(unknown.title == "Current app" && unknown.sourceLabel == "Source unavailable", "Missing native launch information must not invent a source")
    try expect(unknown.updateID == nil && unknown.runtimeVersion == nil && unknown.createdAt == nil, "Unknown identity stays absent rather than becoming an empty current ID")
    try expect(unknown.nativeVersion == nil && unknown.nativeBuild == nil, "Blank version fields remain unavailable")
    for id in ["", "not-a-uuid", "\(currentID) "] {
      var invalid = constants()
      invalid["updateId"] = id
      let identity = DraftBundleIdentity(constants: invalid, drafts: [draft(id: id)])
      try expect(identity.updateID == nil && identity.title == "Current app", "Malformed UUIDs cannot produce a current draft match")
    }
    print("PASS offline, removed catalog entry, and missing identity fallbacks")

    for value: Any in [true, "1788960429174", Double.nan, Double.infinity, -1, Double.greatestFiniteMagnitude] {
      var invalid = constants()
      invalid["commitTime"] = value
      try expect(DraftBundleIdentity(constants: invalid, drafts: []).createdAt == nil, "Invalid timestamps must not render invented dates")
    }
    var epoch = constants()
    epoch["commitTime"] = UInt64(0)
    try expect(DraftBundleIdentity(constants: epoch, drafts: []).createdAt == Date(timeIntervalSince1970: 0), "A numeric Unix epoch is a valid timestamp")
    print("PASS timestamp conversion and malformed timestamp rejection")
    print("5 iOS bundle identity test groups passed")
  }
}
