import Foundation

@main
struct BuildCatalogTests {
  static let projectID = "a1111111-b222-4333-8444-c55555555555"
  static let updateID = "22222222-3333-4444-8555-666666666666"
  static let buildID = "33333333-4444-4555-8666-777777777777"
  static let otherID = "44444444-5555-4666-8777-888888888888"
  static let commit = String(repeating: "a", count: 40)
  static let base = "https://github.com/owner/repository/issues/new"

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: "build-catalog-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }

  static func expectFailure(_ message: String, _ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw NSError(domain: "build-catalog-test", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }

  static func record(_ overrides: [String: Any] = [:]) -> [String: Any] {
    [
      "runtimeVersion": "runtime-one", "platform": "ios", "profile": "drafts-device", "state": "ready",
      "buildId": buildID, "installUrl": "https://expo.dev/accounts/owner/projects/project/builds/\(buildID)",
      "updatedAt": "2026-09-09T10:00:00.000Z", "gitCommitHash": commit,
      "requestId": "request-123", "requestedAt": "2026-09-09T09:00:00Z"
    ].merging(overrides) { _, replacement in replacement }
  }

  static func entry(_ overrides: [String: Any] = [:]) throws -> DraftBuildEntry {
    try JSONDecoder().decode(DraftBuildEntry.self, from: JSONSerialization.data(withJSONObject: record(overrides)))
  }

  static func catalog(_ records: [[String: Any]], project: String = projectID, schema: Int = 1) throws -> DraftBuildCatalog {
    try DraftBuildCatalog.decode(JSONSerialization.data(withJSONObject: [
      "schemaVersion": schema, "projectId": project, "generatedAt": "2026-09-09T10:00:00Z", "builds": records
    ]), projectID: projectID)
  }

  static func draft(name: String, withCommit: Bool = true) throws -> DraftEntry {
    var value: [String: Any] = [
      "id": otherID, "name": name, "channel": "draft-pr-23", "createdAt": "2026-09-09T10:00:00Z",
      "updates": [["id": updateID, "platform": "ios", "runtimeVersion": "runtime-one"]]
    ]
    if withCommit { value["gitCommitHash"] = commit }
    return try JSONDecoder().decode(DraftEntry.self, from: JSONSerialization.data(withJSONObject: value))
  }

  static func main() throws {
    let exact = try catalog([
      record(["runtimeVersion": "runtime-two", "buildId": otherID, "updatedAt": "2026-09-10T10:00:00Z"]),
      record(["profile": "drafts-simulator", "updatedAt": "2026-09-10T10:00:00Z"]),
      record(["platform": "android", "updatedAt": "2026-09-10T10:00:00Z"]),
      record()
    ])
    try expect(exact.build(runtimeVersion: "runtime-one", platform: "ios", profile: "drafts-device")?.buildId == buildID,
      "Must select the exact runtime/platform/profile, never a newer incompatible build")
    try expect(exact.build(runtimeVersion: "missing-runtime", platform: "ios", profile: "drafts-device") == nil,
      "Missing runtime must not fall back to an available build")
    try expect(exact.build(runtimeVersion: "Runtime-one", platform: "ios", profile: "drafts-device") == nil,
      "Runtime identity is case-sensitive")
    try expect(exact.build(runtimeVersion: "runtime-one", platform: "ios", profile: "production") == nil,
      "A device preview must not use a different profile")
    try expect(try catalog([record(["platform": "android"])]).build(runtimeVersion: "runtime-one", platform: "ios", profile: "drafts-device") == nil,
      "Android builds must not satisfy an iOS draft")
    print("PASS exact runtime, platform, and profile matching")

    let concurrent = try catalog([
      record(["state": "building", "buildId": otherID, "updatedAt": "2026-09-10T10:00:00Z"]), record()
    ])
    try expect(concurrent.build(runtimeVersion: "runtime-one", platform: "ios", profile: "drafts-device")?.state == "ready",
      "An existing installable build remains useful while another matching build runs")
    let progress = try catalog([
      record(["state": "queued", "updatedAt": "2026-09-09T10:00:00Z"]),
      record(["state": "building", "updatedAt": "2026-09-09T11:00:00.001Z"])
    ])
    try expect(progress.build(runtimeVersion: "runtime-one", platform: "ios", profile: "drafts-device")?.state == "building",
      "Use the newest in-progress entry when no build is ready")
    try expect(try entry(["state": "queued"]).isInProgress && entry(["state": "building"]).isInProgress,
      "Queued and building states report actual progress")
    try expect(try !entry(["state": "failed"]).isInProgress && !entry().isInProgress,
      "Failed and ready states must not show a build in progress")
    print("PASS ready/progress state selection and ISO date ordering")

    try expect(try entry().verifiedInstallURL != nil, "The matching expo.dev build page must be accepted")
    let invalidInstallURLs = [
      "http://expo.dev/accounts/owner/projects/project/builds/\(buildID)",
      "https://expo.dev.evil.example/accounts/owner/projects/project/builds/\(buildID)",
      "https://user:password@expo.dev/accounts/owner/projects/project/builds/\(buildID)",
      "https://expo.dev:444/accounts/owner/projects/project/builds/\(buildID)",
      "https://expo.dev/accounts/owner/projects/project/builds/\(otherID)",
      "https://expo.dev/artifacts/eas/preview.ipa",
      "https://expo.dev/accounts/owner/projects/project/builds/\(buildID)?token=secret",
      "https://expo.dev/accounts/owner/projects/project/builds/\(buildID)#fragment"
    ]
    for url in invalidInstallURLs {
      try expect(try entry(["installUrl": url]).verifiedInstallURL == nil, "Unsafe or mismatched installation link must be rejected: \(url)")
    }
    try expect(try entry(["buildId": "not-a-uuid"]).verifiedInstallURL == nil, "Build identity must be a UUID")
    try expect(try entry(["state": "building"]).verifiedInstallURL == nil, "A build cannot be installable before it is ready")
    try expect(try entry(["statusUrl": "https://github.com/owner/repository/actions/runs/123"]).verifiedStatusURL != nil,
      "GitHub build status links must work")
    try expect(try entry(["statusUrl": "https://evil.example/status"]).verifiedStatusURL == nil,
      "Unknown build status hosts must be rejected")
    print("PASS installation URL host, scheme, credentials, ID, and state checks")

    try expectFailure("A catalog from another project must be rejected") { _ = try catalog([], project: otherID) }
    try expectFailure("Unknown catalog schemas must be rejected") { _ = try catalog([], schema: 2) }
    try expectFailure("Invalid build state must be rejected") { _ = try catalog([record(["state": "publishing"])] ) }
    try expectFailure("Empty runtime must be rejected") { _ = try catalog([record(["runtimeVersion": ""])] ) }
    try expect(try catalog([], project: projectID.uppercased()).builds.isEmpty, "Project UUID comparison is case-insensitive")
    print("PASS catalog validation and additive metadata compatibility")

    let name = "Café \"Reading\"\n第2章 + notes & questions? #23"
    let requestDraft = try draft(name: name)
    let requestURL = try DraftBuildRequest.url(for: requestDraft, projectID: projectID, baseURL: base)
    let query = try requestQuery(requestURL)
    try expect(query["title"] == "Build draft: \(name)", "Issue title must preserve Unicode, quotes, and newlines")
    let body = query["body"]!
    let fence = try NSRegularExpression(pattern: "```expo-drafts-build-request\\s*\\n([\\s\\S]*?)\\n```")
    let matches = fence.matches(in: body, range: NSRange(body.startIndex..., in: body))
    try expect(matches.count == 1, "The issue body must contain exactly one agreed request fence")
    let jsonRange = Range(matches[0].range(at: 1), in: body)!
    let parsed = try JSONSerialization.jsonObject(with: Data(body[jsonRange].utf8)) as! [String: Any]
    let expected: [String: Any] = [
      "schemaVersion": 1, "projectId": projectID, "updateId": updateID, "channel": "draft-pr-23",
      "runtimeVersion": "runtime-one", "gitCommitHash": commit, "name": name
    ]
    try expect(NSDictionary(dictionary: parsed).isEqual(to: expected), "The request body must preserve all machine-readable identity fields")
    let withoutCommit = try DraftBuildRequest.url(for: draft(name: "No commit", withCommit: false), projectID: projectID, baseURL: base)
    try expect(try requestQuery(withoutCommit)["body"]?.contains("gitCommitHash") == false,
      "Absent optional commit must be omitted rather than serialized as null")
    if CommandLine.arguments.count > 1 {
      let fixture: [String: Any] = ["url": requestURL.absoluteString, "body": body, "title": "Build draft: \(name)", "expected": expected]
      try JSONSerialization.data(withJSONObject: fixture, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
    print("PASS encoded GitHub title and machine-readable request body")

    let invalidBases: [String?] = [
      nil, "", "http://github.com/owner/repository/issues/new", "https://github.com.evil.example/owner/repository/issues/new",
      "https://user:password@github.com/owner/repository/issues/new", "https://github.com:444/owner/repository/issues/new",
      "https://github.com/owner/repository", "https://github.com/owner/repository/issues/123",
      "https://github.com/owner/repository/issues/new?title=another", "https://github.com/owner/repository/issues/new#fragment",
      "https://example.com/owner/repository/issues/new", "https://github.com/owner/repository/pulls/new"
    ]
    for url in invalidBases {
      try expectFailure("Invalid request destination must be rejected: \(url ?? "nil")") {
        _ = try DraftBuildRequest.url(for: requestDraft, projectID: projectID, baseURL: url)
      }
    }
    print("PASS request URL rejects credentials, alternate hosts, and non-issue destinations")
    print("6 iOS build catalog test groups passed")
  }

  static func requestQuery(_ url: URL) throws -> [String: String] {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let items = components.queryItems ?? []
    try expect(items.count == 2 && Set(items.map(\.name)) == Set(["title", "body"]), "Only title and body query fields may be generated")
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }
}
