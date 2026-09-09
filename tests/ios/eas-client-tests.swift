import Foundation

private final class EASProtocol: URLProtocol, @unchecked Sendable {
  static var handler: ((URLRequest) throws -> (Int, Data, TimeInterval))?
  static var responseHeaders = ["Content-Type": "application/json"]
  private var stopped = false
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    DispatchQueue.main.async {
      do {
        guard let handler = Self.handler else { throw URLError(.badServerResponse) }
        let (status, data, delay) = try handler(self.request)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          guard !self.stopped else { return }
          self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: nil, headerFields: Self.responseHeaders)!, cacheStoragePolicy: .notAllowed)
          self.client?.urlProtocol(self, didLoad: data)
          self.client?.urlProtocolDidFinishLoading(self)
        }
      } catch { self.client?.urlProtocol(self, didFailWithError: error) }
    }
  }
  override func stopLoading() { DispatchQueue.main.async { self.stopped = true } }
}

@main
struct EASClientTests {
  static let projectID = "11111111-2222-4333-8444-555555555555"
  static let otherID = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
  static let commit = String(repeating: "a", count: 40)
  static let now = ISO8601DateFormatter().date(from: "2026-09-09T16:00:00Z")!

  static func id(_ n: Int) -> String { "00000000-0000-4000-8000-" + String(format: "%012x", n) }
  static func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: .sortedKeys) }
  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: "eas-client-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }
  static func failure(_ message: String, _ operation: () throws -> Void) throws {
    do { try operation() } catch { return }
    throw NSError(domain: "eas-client-test", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }
  static func spin(until condition: () -> Bool, seconds: TimeInterval = 8) throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
    try expect(condition(), "Asynchronous completion must arrive within the test deadline")
  }
  static func awaitResult<T>(_ start: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
    var result: Result<T, Error>?
    start { result = $0 }
    try spin { result != nil }
    return try result!.get()
  }
  static func update(_ n: Int = 1) -> [String: Any] {
    ["id": id(30_000+n), "group": id(40_000+n), "platform": "ios", "message": "Preview \(n)",
     "runtime": ["version": "native-\(n)"], "createdAt": "2026-09-09T12:00:00.000Z", "gitCommitHash": commit,
     "isRollBackToEmbedded": false, "rolloutPercentage": NSNull(), "rolloutControlUpdate": NSNull()]
  }
  static func channel(_ n: Int = 1, mutate: ((inout [String: Any], inout [String: Any], inout [String: Any]) -> Void)? = nil) throws -> [String: Any] {
    var update = update(n)
    var branch: [String: Any] = ["id": id(20_000+n), "name": "branch-\(n)"]
    let mapping: [String: Any] = ["version": 0, "data": [["branchId": id(20_000+n), "branchMappingLogic": "true"]]]
    var channel: [String: Any] = ["id": id(10_000+n), "name": "channel-\(n)", "isPaused": false,
      "branchMapping": String(data: try json(mapping), encoding: .utf8)!]
    mutate?(&channel, &branch, &update)
    branch["updates"] = branch["updates"] ?? [update]
    channel["updateBranches"] = channel["updateBranches"] ?? [branch]
    return channel
  }
  static func build(_ n: Int = 1, status: String = "FINISHED") -> [String: Any] {
    ["id": id(50_000+n), "status": status, "platform": "IOS", "distribution": "INTERNAL",
     "buildProfile": "drafts-device", "isForIosSimulator": false, "developmentClient": false,
     "runtime": ["version": "native-\(n)"], "app": ["id": projectID], "appIdentifier": "dev.example.drafts",
     "gitCommitHash": commit, "createdAt": "2026-09-09T12:00:00Z", "updatedAt": "2026-09-09T12:01:00Z",
     "expirationDate": "2099-09-09T12:00:00Z"]
  }
  static func page(channels: [[String: Any]] = [], builds: [[String: Any]] = [], project: String = projectID, owner: String = "owner") throws -> Data {
    try json(["data": ["app": ["byId": ["id": project, "slug": "test-app", "ownerAccount": ["name": owner], "updateChannels": channels, "builds": builds]]]])
  }
  static func body(_ request: URLRequest) throws -> [String: Any] {
    let data: Data
    if let value = request.httpBody { data = value }
    else if let stream = request.httpBodyStream {
      stream.open(); defer { stream.close() }
      var value = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; value.append(contentsOf: buffer.prefix(count)) }
      data = value
    } else { throw URLError(.badURL) }
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
  }
  static func client() -> DraftsEASClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [EASProtocol.self]
    return DraftsEASClient(configuration: configuration, expectedBundleIdentifier: "dev.example.drafts")
  }

  static func live(projectID: String) throws {
    let secret = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
    let client = DraftsEASClient(expectedBundleIdentifier: "dev.davidmokos.draftslab")
    var catalog: Result<DraftCatalog, Error>?
    var builds: Result<DraftBuildCatalog, Error>?
    client.fetchCatalog(projectID: projectID, sessionSecret: secret) { catalog = $0 }
    client.fetchBuildCatalog(projectID: projectID, profile: "drafts-device", sessionSecret: secret) { builds = $0 }
    try spin(until: { catalog != nil && builds != nil }, seconds: 135)
    let drafts = try catalog!.get(); let nativeBuilds = try builds!.get()
    let proof: [String: Any] = ["verifiedAt": ISO8601DateFormatter().string(from: Date()), "status": "passed",
      "client": "Swift DraftsEASClient", "endpoint": DraftEASRequest.endpoint.absoluteString, "authentication": "existing per-user Expo session supplied over stdin; not saved",
      "projectID": drafts.projectId, "drafts": drafts.drafts.map { ["channel": $0.channel, "name": $0.name, "id": $0.iosUpdate!.id, "catalogEntryID": $0.id, "runtimeVersion": $0.iosUpdate!.runtimeVersion, "gitCommitHash": $0.gitCommitHash ?? ""] },
      "builds": nativeBuilds.builds.map { ["id": $0.buildId ?? "", "runtimeVersion": $0.runtimeVersion, "state": $0.state, "gitCommitHash": $0.gitCommitHash ?? ""] }]
    print(String(data: try json(proof), encoding: .utf8)!)
  }

  static func main() throws {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--live" {
      try live(projectID: CommandLine.arguments[2]); return
    }
    defer { EASProtocol.handler = nil }
    do {
      let first = try channel(1)
      let second = try channel(2) { _, _, update in update["message"] = "   " }
      let empty = try channel(3) { _, branch, _ in branch["updates"] = [] }
      let catalog = try DraftEASMapping.catalog(from: [page(channels: [first]), page(channels: [second, empty])], projectID: projectID.uppercased())
      try expect(catalog.drafts.count == 2 && catalog.projectId == projectID, "Merge pages and omit only channels without an iOS update")
      let named = catalog.drafts.first { $0.channel == "channel-1" }!
      try expect(named.name == "Preview 1" && named.iosUpdate?.runtimeVersion == "native-1" && named.iosUpdate?.id == id(30_001), "Use EAS message and exact latest iOS identity regardless of installed runtime")
      try expect(catalog.drafts.first { $0.channel == "channel-2" }?.name == "channel-2", "Empty update messages fall back to actual channel name")
      try expect(named.pullRequest == nil, "Do not invent GitHub identity from EAS metadata")
      var alias = first
      alias["id"] = id(10_004); alias["name"] = "alias-channel"
      let aliases = try DraftEASMapping.catalog(from: [page(channels: [first, alias])], projectID: projectID)
      try expect(Set(aliases.drafts.map(\.id)).count == 2 && Set(aliases.drafts.map { $0.iosUpdate!.id }).count == 1,
        "Two channels targeting one update must retain distinct catalog row identities")
      print("PASS EAS channels map exact latest iOS updates, names, incompatible runtimes, and empty branches")
    }
    do {
      let offset = try channel(1) { _, _, update in update["createdAt"] = "2026-09-09T14:00:00+02:00" }
      let fractional = try channel(2) { _, _, update in update["createdAt"] = "2026-09-09T12:00:00.001Z" }
      let newest = try channel(3) { _, _, update in update["createdAt"] = "2026-09-09T07:00:01-05:00" }
      let equivalent = try channel(4) { _, _, update in update["createdAt"] = "2026-09-09T12:00:00.000Z" }
      let pages = [try page(channels: [equivalent, offset]), try page(channels: [newest, fractional])]
      let catalog = try DraftEASMapping.catalog(from: pages, projectID: projectID)
      try expect(catalog.drafts.map(\.channel) == ["channel-3", "channel-2", "channel-1", "channel-4"],
        "EAS channel pages must use actual publication dates and deterministic equal-instant ties")
      try expect(DraftEntry.newestFirst(catalog.drafts).map(\.id) == catalog.drafts.map(\.id),
        "Sorting a freshly mapped or cached EAS catalog must preserve its exact publication order")
      let malformed = try channel { _, _, update in update["createdAt"] = "not-a-date" }
      try failure("EAS dates remain validated before returning the catalog") {
        _ = try DraftEASMapping.catalog(from: [page(channels: [malformed])], projectID: projectID)
      }
      print("PASS EAS publications sort newest first across pages using parsed dates and stable ties")
    }
    do {
      for kind in ["paused", "mapping", "branch", "partial-rollout", "control", "rollback", "platform", "uuid", "runtime"] {
        let bad = try channel { channel, branch, update in
          switch kind {
          case "paused": channel["isPaused"] = true
          case "mapping": channel["branchMapping"] = "{\"version\":0,\"data\":[{\"branchId\":\"\(id(20_001))\",\"branchMappingLogic\":\"hash_lt\"}]}"
          case "branch": branch["id"] = otherID
          case "partial-rollout": update["rolloutPercentage"] = 20
          case "control": update["rolloutControlUpdate"] = ["id": otherID]
          case "rollback": update["isRollBackToEmbedded"] = true
          case "platform": update["platform"] = "ANDROID"
          case "uuid": update["id"] = ""
          default: update["runtime"] = ["version": ""]
          }
        }
        try failure("Reject \(kind) before selecting any draft") { _ = try DraftEASMapping.catalog(from: [page(channels: [bad])], projectID: projectID) }
      }
      let good = try channel()
      try failure("Reject duplicated pagination rows") { _ = try DraftEASMapping.catalog(from: [page(channels: [good]), page(channels: [good])], projectID: projectID) }
      try failure("Reject another project's response") { _ = try DraftEASMapping.catalog(from: [page(channels: [good], project: otherID)], projectID: projectID) }
      print("PASS channel routing, rollout, project identity, UUID/runtime, and duplicate-page guards")
    }
    do {
      var rows = [build(1), build(2, status: "IN_QUEUE"), build(3, status: "IN_PROGRESS"), build(4, status: "ERRORED")]
      for (n, field, value) in [(5,"isForIosSimulator",true as Any),(6,"developmentClient",true as Any),(7,"buildProfile","other" as Any),(8,"distribution","STORE" as Any),(9,"platform","ANDROID" as Any),(10,"runtime",NSNull()),(11,"expirationDate","2020-01-01T00:00:00Z" as Any)] {
        var row = build(n); row[field] = value; rows.append(row)
      }
      var wrongIdentifier = build(12); wrongIdentifier["appIdentifier"] = "dev.other.app"; rows.append(wrongIdentifier)
      let mapped = try DraftEASMapping.buildCatalog(from: [page(builds: rows)], projectID: projectID, profile: "drafts-device", expectedBundleIdentifier: "dev.example.drafts", now: now)
      try expect(mapped.builds.count == 4 && Set(mapped.builds.map(\.state)) == ["ready", "queued", "building", "failed"], "Map actual states while excluding incompatible build types, unassigned runtimes and expired archives")
      let ready = mapped.builds.first { $0.state == "ready" }!
      try expect(ready.verifiedInstallURL?.absoluteString == "https://expo.dev/accounts/owner/projects/test-app/builds/\(id(50_001))", "Build only the canonical project/build installation page, without artifact signatures")
      var wrong = build(); wrong["app"] = ["id": otherID]
      try failure("Reject a build attributed to another project") { _ = try DraftEASMapping.buildCatalog(from: [page(builds: [wrong])], projectID: projectID, profile: "drafts-device", now: now) }
      try failure("Reject unsafe project path segments") { _ = try DraftEASMapping.buildCatalog(from: [page(builds: [build()], owner: "owner/evil")], projectID: projectID, profile: "drafts-device", now: now) }
      print("PASS device build matching, ready/progress/failure states, expiry, and canonical installation URLs")
    }
    do {
      for (code, signin, invalidates) in [("UNAUTHENTICATED",true,true),("UNAUTHORIZED_ERROR",false,true),("FORBIDDEN",false,true),("RATE_LIMITED",false,false),("INTERNAL_SERVER_ERROR",false,false)] {
        let data = try json(["errors": [["message": "do not display secret server details", "extensions": ["code": code]]]])
        do { _ = try DraftEASMapping.catalog(from: [data], projectID: projectID); throw URLError(.unknown) }
        catch let error as DraftEASError {
          try expect(error.requiresSignIn == signin && error.invalidatesCachedData == invalidates, "Only definite authentication failures require sign-in")
          try expect(!error.localizedDescription.contains("secret server"), "Do not expose raw GraphQL error details")
        }
      }
      print("PASS typed authentication/access/rate errors preserve valid sessions and hide server internals")
    }
    do {
      let client = client()
      var offsets: [Int] = []
      EASProtocol.handler = { request in
        try expect(request.url == DraftEASRequest.endpoint && request.httpMethod == "POST", "Use only the fixed EAS GraphQL endpoint")
        try expect(request.value(forHTTPHeaderField: "expo-session") == "fixture-session", "Send the current user's session in the supported header")
        let body = try body(request); let variables = body["variables"] as! [String: Any]
        let offset = variables["offset"] as! Int; offsets.append(offset)
        let indices = offset == 0 ? Array(1...50) : [51]
        return (200, try page(channels: indices.map { try channel($0) }), 0)
      }
      let catalog: DraftCatalog = try awaitResult { client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session", completion: $0) }
      try expect(catalog.drafts.count == 51 && offsets == [0,50], "Fetch every channel page until an explicitly short final page")
      EASProtocol.handler = { request in
        let offset = (try body(request)["variables"] as! [String: Any])["offset"] as! Int
        return (200, try page(channels: (1...50).map { try channel(offset+$0) }), 0)
      }
      try failure("A full history beyond the safety limit must fail instead of silently truncating") {
        let _: DraftCatalog = try awaitResult { client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session", completion: $0) }
      }
      print("PASS transport paginates all channels and reports bounded-history truncation explicitly")
    }
    do {
      let client = client()
      var callbacks: [String] = []
      EASProtocol.handler = { request in
        let query = try body(request)["query"] as! String
        return (200, try page(channels: [channel()], builds: [build()]), query.contains("ExpoDraftsBuilds") ? 0.03 : 0.02)
      }
      client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session") { result in
        if case .failure(let error) = result, (error as NSError).code == NSURLErrorCancelled { callbacks.append("old-cancelled") }
      }
      client.fetchBuildCatalog(projectID: projectID, profile: "drafts-device", sessionSecret: "fixture-session") { result in
        if case .success = result { callbacks.append("build-success") }
      }
      client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session") { result in
        if case .success = result { callbacks.append("new-success") }
      }
      try spin { callbacks.count == 3 }
      try expect(Set(callbacks) == ["old-cancelled", "build-success", "new-success"], "Replacing catalog fetch must cancel only its predecessor and preserve concurrent build discovery")
      var cancelled = 0
      client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session") { result in if case .failure = result { cancelled += 1 } }
      client.fetchBuildCatalog(projectID: projectID, profile: "drafts-device", sessionSecret: "fixture-session") { result in if case .failure = result { cancelled += 1 } }
      client.cancel()
      try expect(cancelled == 2, "Sign-out cancellation must complete both operations exactly once")
      print("PASS concurrent catalog/build requests and independent replacement/sign-out cancellation")
    }
    do {
      for (status, signin, invalidates) in [(401,true,true),(403,false,true),(429,false,false),(503,false,false)] {
        let client = client()
        EASProtocol.handler = { _ in (status, Data(), 0) }
        do {
          let _: DraftCatalog = try awaitResult { client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session", completion: $0) }
          throw URLError(.unknown)
        } catch let error as DraftEASError {
          try expect(error.requiresSignIn == signin && error.invalidatesCachedData == invalidates, "HTTP \(status) must map to the correct retry/sign-in behavior")
        }
      }
      let session = URLSession(configuration: .ephemeral)
      let task = session.dataTask(with: DraftEASRequest.endpoint)
      var completions = 0
      let request = DraftEASRequest(query: "query { meActor { id } }", variables: [:], sessionSecret: "fixture-session") { _ in completions += 1 }
      let redirect = HTTPURLResponse(url: DraftEASRequest.endpoint, statusCode: 302, httpVersion: nil, headerFields: ["Location": "https://other.example/graphql"])!
      var followed: URLRequest?
      request.urlSession(session, task: task, willPerformHTTPRedirection: redirect, newRequest: URLRequest(url: URL(string: "https://other.example/graphql")!)) { followed = $0 }
      try expect(followed == nil, "Never forward the Expo session on a redirect")
      request.urlSession(session, dataTask: task, didReceive: Data(repeating: 0, count: DraftEASRequest.maximumBytes))
      request.urlSession(session, dataTask: task, didReceive: Data([1]))
      request.urlSession(session, task: task, didCompleteWithError: URLError(.cancelled))
      request.cancel()
      try expect(completions == 1, "Streamed body overflow and later cancellation must complete only once")
      session.invalidateAndCancel()
      print("PASS HTTP failure classification, redirect refusal, streamed byte cap, and single completion")
    }
    do {
      let client = client()
      var requests = 0
      EASProtocol.responseHeaders["Retry-After"] = "60"
      EASProtocol.handler = { _ in requests += 1; return (429, Data(), 0) }
      try failure("The first 429 must report its retry delay") {
        let _: DraftCatalog = try awaitResult { client.fetchCatalog(projectID: projectID, sessionSecret: "fixture-session", completion: $0) }
      }
      try failure("Refreshing builds during the backoff must report the wait instead of another request") {
        let _: DraftBuildCatalog = try awaitResult { client.fetchBuildCatalog(projectID: projectID, profile: "drafts-device", sessionSecret: "fixture-session", completion: $0) }
      }
      try expect(requests == 1, "Honor EAS Retry-After across catalog and build refreshes")
      try expect(DraftEASRequest.retryDate("60", now: now) == now.addingTimeInterval(60), "Parse delta-seconds Retry-After")
      try expect(DraftEASRequest.retryDate("Wed, 09 Sep 2026 16:01:00 GMT", now: now) == now.addingTimeInterval(60), "Parse HTTP-date Retry-After")
      EASProtocol.responseHeaders.removeValue(forKey: "Retry-After")
      print("PASS server Retry-After backoff is shared across refreshes without extra network calls")
    }
    print("9 iOS EAS discovery test groups passed")
  }
}
