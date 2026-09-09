import Foundation

@main
struct BuildInstallationTests {
  static let projectID = "a1111111-b222-4333-8444-c55555555555"
  static let buildID = "33333333-4444-4555-8666-777777777777"
  static let otherID = "44444444-5555-4666-8777-888888888888"
  static let bundleID = "dev.example.drafts"
  static let packageURL = "https://wf-artifacts.eascdn.net/builds/example.ipa?signature=temporary"

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: "build-installation-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }

  static func expectFailure(_ message: String, _ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw NSError(domain: "build-installation-test", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }

  static func manifest(bundle: String = bundleID, kind: String = "software", version: String = "1.0", assets: [[String: String]]? = nil, count: Int = 1) throws -> Data {
    let item: [String: Any] = [
      "metadata": ["kind": kind, "bundle-identifier": bundle, "bundle-version": version, "title": "Drafts"],
      "assets": assets ?? [["kind": "software-package", "url": packageURL]]
    ]
    return try PropertyListSerialization.data(fromPropertyList: ["items": Array(repeating: item, count: count)], format: .xml, options: 0)
  }

  static func main() throws {
    let canonical = try DraftBuildInstallation.manifestURL(projectID: projectID, buildID: buildID)
    try expect(canonical.absoluteString == "https://api.expo.dev/v2/projects/\(projectID)/builds/\(buildID)/manifest.plist", "Derive only the EAS manifest endpoint from verified UUIDs")
    try expect(try DraftBuildInstallation.manifestURL(projectID: projectID.uppercased(), buildID: buildID) == canonical,
      "UUID normalization must produce one canonical destination")
    let install = try DraftBuildInstallation.installerURL(manifestURL: canonical, projectID: projectID, buildID: buildID)
    let components = URLComponents(url: install, resolvingAgainstBaseURL: false)!
    try expect(install.absoluteString.hasPrefix("itms-services://?"), "Open the native system installer scheme")
    let query = components.queryItems!
    try expect(query.count == 2 && query[0] == URLQueryItem(name: "action", value: "download-manifest") &&
      query[1] == URLQueryItem(name: "url", value: canonical.absoluteString), "The native installer must receive only its action and canonical manifest URL")
    try expect(!install.absoluteString.contains("signature"), "Temporary IPA signatures must not enter the installer URL")
    for raw in [
      canonical.absoluteString.replacingOccurrences(of: "https:", with: "http:"),
      canonical.absoluteString.replacingOccurrences(of: "api.expo.dev", with: "api.expo.dev.evil.example"),
      canonical.absoluteString.replacingOccurrences(of: "api.expo.dev", with: "user:password@api.expo.dev"),
      canonical.absoluteString.replacingOccurrences(of: "api.expo.dev", with: "api.expo.dev:444"),
      canonical.absoluteString.replacingOccurrences(of: projectID, with: otherID),
      canonical.absoluteString.replacingOccurrences(of: buildID, with: otherID),
      canonical.absoluteString + "?url=https://evil.example/app.plist", canonical.absoluteString + "#fragment",
      "https://expo.dev/accounts/owner/projects/project/builds/\(buildID)", packageURL
    ] {
      try expectFailure("Reject every noncanonical manifest destination") {
        _ = try DraftBuildInstallation.installerURL(manifestURL: URL(string: raw)!, projectID: projectID, buildID: buildID)
      }
    }
    try expectFailure("Reject malformed project identity") { _ = try DraftBuildInstallation.manifestURL(projectID: "not-a-uuid", buildID: buildID) }
    try expectFailure("Reject malformed build identity") { _ = try DraftBuildInstallation.manifestURL(projectID: projectID, buildID: "../another-build") }
    print("PASS canonical project/build manifest destination and system installer query")

    let validData = try manifest()
    try expect(try DraftBuildInstallation.validateManifest(validData, responseURL: canonical, projectID: projectID, buildID: buildID, bundleIdentifier: bundleID) == install,
      "A matching EAS software manifest must hand its canonical URL to iOS")
    let invalidData = try [
      manifest(bundle: "dev.other.app"), manifest(kind: "ebook"), manifest(version: ""), manifest(count: 0), manifest(count: 2),
      manifest(assets: []), manifest(assets: [["kind": "display-image", "url": packageURL]]),
      manifest(assets: [["kind": "software-package", "url": packageURL], ["kind": "software-package", "url": packageURL]]),
      manifest(assets: [["kind": "software-package", "url": "http://wf-artifacts.eascdn.net/app.ipa"]]),
      manifest(assets: [["kind": "software-package", "url": "https://user:password@wf-artifacts.eascdn.net/app.ipa"]]),
      manifest(assets: [["kind": "software-package", "url": "itms-services://?action=other"]]),
      manifest(assets: [["kind": "software-package", "url": packageURL], ["kind": "display-image", "url": "http://example.com/icon.png"]]),
      Data("<html>Sign in</html>".utf8), Data(repeating: 0, count: DraftBuildInstallation.maximumManifestBytes + 1)
    ]
    for data in invalidData {
      try expectFailure("Reject unavailable, mismatched, oversized, or unsafe software manifests") {
        _ = try DraftBuildInstallation.validateManifest(data, responseURL: canonical, projectID: projectID, buildID: buildID, bundleIdentifier: bundleID)
      }
    }
    try expectFailure("Reject a redirected manifest even if its body is valid") {
      _ = try DraftBuildInstallation.validateManifest(validData, responseURL: URL(string: "https://example.com/manifest.plist")!, projectID: projectID, buildID: buildID, bundleIdentifier: bundleID)
    }
    print("PASS manifest bundle identity, software package, HTTPS assets, and size checks")

    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let task = session.dataTask(with: canonical) // Never resumed; delegate behavior is tested without network access.
    for status in [302, 401, 403, 404, 500] {
      var results: [Result<URL, Error>] = []
      let request = try DraftBuildManifestRequest(projectID: projectID, buildID: buildID, bundleIdentifier: bundleID) { results.append($0) }
      var disposition: URLSession.ResponseDisposition?
      let response = HTTPURLResponse(url: canonical, statusCode: status, httpVersion: nil, headerFields: nil)!
      request.urlSession(session, dataTask: task, didReceive: response) { disposition = $0 }
      request.urlSession(session, task: task, didCompleteWithError: nil)
      try expect(disposition == .cancel && results.count == 1, "HTTP errors must cancel and complete exactly once")
      try expectFailure("HTTP errors must never hand off to iOS") { _ = try results[0].get() }
    }
    var results: [Result<URL, Error>] = []
    let request = try DraftBuildManifestRequest(projectID: projectID, buildID: buildID, bundleIdentifier: bundleID) { results.append($0) }
    var redirected: URLRequest? = URLRequest(url: canonical)
    request.urlSession(session, task: task, willPerformHTTPRedirection: HTTPURLResponse(url: canonical, statusCode: 302, httpVersion: nil, headerFields: nil)!, newRequest: URLRequest(url: URL(string: "https://example.com/login")!)) { redirected = $0 }
    try expect(redirected == nil, "Manifest preflight must not follow redirects to websites or artifacts")
    request.urlSession(session, dataTask: task, didReceive: Data(repeating: 0, count: DraftBuildInstallation.maximumManifestBytes))
    try expect(results.isEmpty, "The byte limit is inclusive")
    request.urlSession(session, dataTask: task, didReceive: Data([0]))
    request.urlSession(session, task: task, didCompleteWithError: nil)
    try expect(results.count == 1, "Crossing the streamed byte cap must terminate once")
    try expectFailure("An oversized streamed manifest cannot hand off") { _ = try results[0].get() }
    print("PASS redirect rejection, HTTP failure, streamed data cap, and single completion")
    print("3 iOS build installation test groups passed")
  }
}
