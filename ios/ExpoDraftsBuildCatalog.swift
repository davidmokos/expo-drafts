import Foundation

struct DraftBuildCatalog: Decodable {
  let schemaVersion: Int
  let projectId: String
  let generatedAt: String?
  let builds: [DraftBuildEntry]

  static func decode(_ data: Data, projectID: String) throws -> DraftBuildCatalog {
    guard data.count <= 5_000_000 else { throw DraftsError.message("The build catalog is too large.") }
    let catalog = try JSONDecoder().decode(Self.self, from: data)
    guard catalog.schemaVersion == 1 else { throw DraftsError.message("This build catalog requires a newer version of Expo Drafts.") }
    guard UUID(uuidString: projectID) != nil, catalog.projectId.lowercased() == projectID.lowercased() else {
      throw DraftsError.message("The build catalog belongs to another EAS project.")
    }
    guard catalog.builds.count <= 1000, catalog.builds.allSatisfy({
      !$0.runtimeVersion.isEmpty && $0.runtimeVersion.count <= 512 &&
        ["ios", "android"].contains($0.platform) && !$0.profile.isEmpty &&
        $0.profile.count <= 100 && ["queued", "building", "ready", "failed"].contains($0.state)
    }) else { throw DraftsError.message("The build catalog contains invalid build information.") }
    return catalog
  }

  func build(runtimeVersion: String, platform: String, profile: String) -> DraftBuildEntry? {
    let matching = builds.filter {
      $0.runtimeVersion == runtimeVersion && $0.platform == platform && $0.profile == profile
    }.sorted { $0.updatedDate > $1.updatedDate }
    // An existing installable build is sufficient, even if another build of the same
    // native runtime is in progress. Never substitute a different runtime or profile.
    return matching.first { $0.state == "ready" && $0.verifiedInstallURL != nil } ??
      matching.first { $0.isInProgress } ?? matching.first
  }
}

struct DraftBuildEntry: Decodable {
  let runtimeVersion: String
  let platform: String
  let profile: String
  let state: String
  let buildId: String?
  let installUrl: String?
  let requestUrl: String?
  let statusUrl: String?
  let gitCommitHash: String?
  let updatedAt: String?

  var isInProgress: Bool { state == "queued" || state == "building" }

  var verifiedInstallURL: URL? {
    guard state == "ready", let buildId, UUID(uuidString: buildId) != nil,
      let installUrl, let url = URL(string: installUrl), url.isDraftsSecureWebURL,
      url.host?.lowercased() == "expo.dev" else { return nil }
    let path = url.path.split(separator: "/").map(String.init)
    guard path.count == 6, path[0] == "accounts", path[2] == "projects", path[4] == "builds",
      path[5].lowercased() == buildId.lowercased(), url.query == nil, url.fragment == nil else { return nil }
    return url
  }

  var verifiedStatusURL: URL? {
    for raw in [statusUrl, requestUrl] {
      guard let raw, let url = URL(string: raw), url.isDraftsSecureWebURL,
        let host = url.host?.lowercased(), ["expo.dev", "github.com"].contains(host) else { continue }
      return url
    }
    return nil
  }

  fileprivate var updatedDate: Date {
    guard let updatedAt else { return .distantPast }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: updatedAt) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: updatedAt) ?? .distantPast
  }
}

struct DraftBuildRequest: Encodable {
  let schemaVersion = 1
  let projectId: String
  let updateId: String
  let channel: String
  let runtimeVersion: String
  let gitCommitHash: String?
  let name: String

  static func url(for draft: DraftEntry, projectID: String, baseURL: String?) throws -> URL {
    guard let update = draft.iosUpdate, UUID(uuidString: update.id) != nil,
      UUID(uuidString: projectID) != nil, !update.runtimeVersion.isEmpty else {
      throw DraftsError.message("Publish an iOS update for this draft before requesting a build.")
    }
    guard let baseURL, let base = URL(string: baseURL), base.isDraftsSecureWebURL,
      base.host?.lowercased() == "github.com", base.query == nil, base.fragment == nil,
      var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
      throw DraftsError.message("This app has no valid GitHub build request URL. Configure buildRequestUrl and create a new native build.")
    }
    let path = base.path.split(separator: "/").map(String.init)
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    guard path.count == 4, path[2] == "issues", path[3] == "new",
      path[0] != ".", path[0] != "..", path[1] != ".", path[1] != "..",
      path[0].unicodeScalars.allSatisfy({ allowed.contains($0) }),
      path[1].unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
      throw DraftsError.message("The build request URL must point to a GitHub repository's new issue page.")
    }
    let request = DraftBuildRequest(
      projectId: projectID, updateId: update.id, channel: draft.channel,
      runtimeVersion: update.runtimeVersion, gitCommitHash: draft.gitCommitHash, name: draft.name
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(request)
    guard let json = String(data: data, encoding: .utf8) else {
      throw DraftsError.message("Could not prepare the build request.")
    }
    components.queryItems = [
      URLQueryItem(name: "title", value: "Build draft: \(draft.name)"),
      URLQueryItem(name: "body", value: "Request a compatible iOS device build for this draft.\n\n```expo-drafts-build-request\n\(json)\n```")
    ]
    // URLComponents treats '+' as legal in a URL query, but browser form decoding
    // interprets it as a space. Escape it to preserve the title and JSON exactly.
    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    guard let url = components.url, url.absoluteString.count <= 12_000 else {
      throw DraftsError.message("This draft's build request is too large to open in the browser.")
    }
    return url
  }
}

extension URL {
  var isDraftsSecureWebURL: Bool {
    scheme?.lowercased() == "https" && host?.isEmpty == false && user == nil && password == nil && (port == nil || port == 443)
  }
}
