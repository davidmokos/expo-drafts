import Foundation

enum DraftEASError: LocalizedError {
  case authenticationRequired
  case accessDenied
  case rateLimited(until: Date?)
  case unavailable
  case invalidResponse
  case unsupportedChannel(String)
  case paginationLimit

  var requiresSignIn: Bool {
    if case .authenticationRequired = self { return true }
    return false
  }

  var invalidatesCachedData: Bool {
    switch self {
    case .authenticationRequired, .accessDenied: return true
    default: return false
    }
  }

  var errorDescription: String? {
    switch self {
    case .authenticationRequired: return "Your Expo session has expired. Sign in to Expo again."
    case .accessDenied: return "This Expo account cannot read this project. Check its project access or sign in with another account."
    case .rateLimited(let until):
      guard let until else { return "Expo is receiving too many requests. Wait a moment, then refresh." }
      let formatter = DateFormatter()
      formatter.timeStyle = .medium
      return "Expo has limited requests. Try refreshing after \(formatter.string(from: until))."
    case .unavailable: return "EAS could not be reached. Check your connection and try again."
    case .invalidResponse: return "EAS returned incomplete or inconsistent project information. Refresh and try again."
    case .unsupportedChannel(let channel): return "The channel \"\(channel)\" is paused or uses a rollout that Expo Drafts cannot select exactly. Use an active channel with one branch and a fully published update."
    case .paginationLimit: return "This EAS project has more history than Expo Drafts can load safely. Narrow its preview channels or build history before refreshing."
    }
  }
}

/// Read-only discovery through the same EAS GraphQL API used by Expo's developer
/// launcher and CLI. Credentials come from the user's Expo session, never the build.
final class DraftsEASClient {
  private let configuration: URLSessionConfiguration
  private let expectedBundleIdentifier: String?
  private var retryUntil: Date?
  private var catalogOperation: DraftEASPagedOperation<DraftCatalog>?
  private var buildOperation: DraftEASPagedOperation<DraftBuildCatalog>?
  private var catalogGeneration = 0
  private var buildGeneration = 0

  init(configuration: URLSessionConfiguration = .ephemeral, expectedBundleIdentifier: String? = Bundle.main.bundleIdentifier) {
    self.configuration = configuration
    self.expectedBundleIdentifier = expectedBundleIdentifier
  }

  private func noteRateLimit<T>(_ result: Result<T, Error>) {
    if case .failure(let error) = result, case .rateLimited(let until) = error as? DraftEASError {
      retryUntil = max(retryUntil ?? .distantPast, until ?? Date().addingTimeInterval(30))
    }
  }

  func fetchCatalog(projectID: String, sessionSecret: String, completion: @escaping (Result<DraftCatalog, Error>) -> Void) {
    precondition(Thread.isMainThread)
    if let retryUntil, retryUntil > Date() { completion(.failure(DraftEASError.rateLimited(until: retryUntil))); return }
    catalogGeneration += 1
    let generation = catalogGeneration
    catalogOperation?.cancel()
    let operation = DraftEASPagedOperation<DraftCatalog>(
      query: DraftEASMapping.catalogQuery, variables: ["appId": projectID],
      sessionSecret: sessionSecret, configuration: configuration,
      count: { try DraftEASMapping.channels(from: $0, projectID: projectID).count },
      map: { try DraftEASMapping.catalog(from: $0, projectID: projectID) }
    ) { [weak self] result in
      self?.noteRateLimit(result)
      if self?.catalogGeneration == generation { self?.catalogOperation = nil }
      completion(result)
    }
    catalogOperation = operation
    operation.start()
  }

  func fetchBuildCatalog(projectID: String, profile: String, sessionSecret: String, completion: @escaping (Result<DraftBuildCatalog, Error>) -> Void) {
    precondition(Thread.isMainThread)
    if let retryUntil, retryUntil > Date() { completion(.failure(DraftEASError.rateLimited(until: retryUntil))); return }
    buildGeneration += 1
    let generation = buildGeneration
    buildOperation?.cancel()
    let operation = DraftEASPagedOperation<DraftBuildCatalog>(
      query: DraftEASMapping.buildQuery, variables: ["appId": projectID, "profile": profile],
      sessionSecret: sessionSecret, configuration: configuration,
      count: { try DraftEASMapping.builds(from: $0, projectID: projectID).count },
      map: { [expectedBundleIdentifier] in try DraftEASMapping.buildCatalog(from: $0, projectID: projectID, profile: profile, expectedBundleIdentifier: expectedBundleIdentifier) }
    ) { [weak self] result in
      self?.noteRateLimit(result)
      if self?.buildGeneration == generation { self?.buildOperation = nil }
      completion(result)
    }
    buildOperation = operation
    operation.start()
  }

  func cancel() {
    precondition(Thread.isMainThread)
    catalogGeneration += 1
    buildGeneration += 1
    let catalog = catalogOperation
    let builds = buildOperation
    catalogOperation = nil
    buildOperation = nil
    catalog?.cancel()
    builds?.cancel()
  }
}

/// Pure, fail-closed mapping kept separate from transport for fixture testing.
enum DraftEASMapping {
  static let catalogQuery = """
    query ExpoDraftsChannels($appId: String!, $offset: Int!, $limit: Int!) {
      app { byId(appId: $appId) {
        id
        updateChannels(offset: $offset, limit: $limit) {
          id name isPaused branchMapping
          updateBranches(offset: 0, limit: 2) {
            id name
            updates(offset: 0, limit: 1, filter: { platform: IOS }) {
              id group platform message runtime { version } createdAt gitCommitHash
              isRollBackToEmbedded rolloutPercentage rolloutControlUpdate { id }
            }
          }
        }
      } }
    }
    """

  static let buildQuery = """
    query ExpoDraftsBuilds($appId: String!, $offset: Int!, $limit: Int!, $profile: String!) {
      app { byId(appId: $appId) {
        id slug ownerAccount { name }
        builds(offset: $offset, limit: $limit, filter: {
          platform: IOS, buildProfile: $profile, distribution: INTERNAL,
          simulator: false, developmentClient: false
        }) {
          id status platform distribution buildProfile isForIosSimulator developmentClient
          runtime { version } app { id } appIdentifier gitCommitHash
          createdAt updatedAt expirationDate
        }
      } }
    }
    """

  static func channels(from data: Data, projectID: String) throws -> [Channel] {
    guard let channels = try project(from: data, projectID: projectID).updateChannels else { throw DraftEASError.invalidResponse }
    return channels
  }

  static func builds(from data: Data, projectID: String) throws -> [Build] {
    guard let builds = try project(from: data, projectID: projectID).builds else { throw DraftEASError.invalidResponse }
    return builds
  }

  static func catalog(from pages: [Data], projectID: String) throws -> DraftCatalog {
    var entries: [DraftEntry] = []
    var channelIDs = Set<String>()
    var channelNames = Set<String>()
    for data in pages {
      for channel in try channels(from: data, projectID: projectID) {
        let channelID = try uuid(channel.id)
        guard channelIDs.insert(channelID).inserted, channelNames.insert(channel.name).inserted,
          validText(channel.name, maximum: 1000) else { throw DraftEASError.invalidResponse }
        guard !channel.isPaused, let mappingData = channel.branchMapping.data(using: .utf8),
          let mapping = try? JSONDecoder().decode(BranchMapping.self, from: mappingData),
          mapping.version == 0, mapping.data.count == 1,
          mapping.data[0].branchMappingLogic == "true", channel.updateBranches.count == 1,
          try uuid(mapping.data[0].branchId) == uuid(channel.updateBranches[0].id) else {
          throw DraftEASError.unsupportedChannel(channel.name)
        }
        let branch = channel.updateBranches[0]
        guard validText(branch.name, maximum: 1000), branch.updates.count <= 1 else { throw DraftEASError.invalidResponse }
        guard let update = branch.updates.first else { continue }
        guard !update.isRollBackToEmbedded, update.rolloutControlUpdate == nil,
          update.rolloutPercentage == nil || update.rolloutPercentage == 100 else {
          throw DraftEASError.unsupportedChannel(channel.name)
        }
        let updateID = try uuid(update.id)
        _ = try uuid(update.group)
        guard update.platform.lowercased() == "ios", let runtime = update.runtime?.version,
          validText(runtime, maximum: 512), date(update.createdAt) != nil,
          update.gitCommitHash == nil || isCommit(update.gitCommitHash!) else { throw DraftEASError.invalidResponse }
        let message = update.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message == nil || message!.count <= 10_000 else { throw DraftEASError.invalidResponse }
        entries.append(DraftEntry(
          id: channelID, name: message?.isEmpty == false ? message! : channel.name,
          channel: channel.name, branch: branch.name, message: update.message,
          createdAt: update.createdAt, gitCommitHash: update.gitCommitHash,
          pullRequest: nil, buildUrl: nil,
          updates: [DraftUpdate(id: updateID, platform: "ios", runtimeVersion: runtime)]
        ))
      }
    }
    guard channelIDs.count <= 1000 else { throw DraftEASError.paginationLimit }
    entries.sort { (date($0.createdAt) ?? .distantPast) > (date($1.createdAt) ?? .distantPast) }
    return DraftCatalog(schemaVersion: 1, projectId: try uuid(projectID), generatedAt: ISO8601DateFormatter().string(from: Date()), drafts: entries)
  }

  static func buildCatalog(from pages: [Data], projectID: String, profile: String, expectedBundleIdentifier: String? = nil, now: Date = Date()) throws -> DraftBuildCatalog {
    guard validText(profile, maximum: 100) else { throw DraftEASError.invalidResponse }
    var entries: [DraftBuildEntry] = []
    var ids = Set<String>()
    var projectPath: String?
    for data in pages {
      let project = try project(from: data, projectID: projectID)
      guard let slug = project.slug, let owner = project.ownerAccount?.name,
        validPathSegment(slug), validPathSegment(owner), let builds = project.builds else { throw DraftEASError.invalidResponse }
      let path = "https://expo.dev/accounts/\(owner)/projects/\(slug)/builds/"
      guard projectPath == nil || projectPath == path else { throw DraftEASError.invalidResponse }
      projectPath = path
      for build in builds {
        let id = try uuid(build.id)
        guard ids.insert(id).inserted, try uuid(build.app.id) == uuid(projectID) else { throw DraftEASError.invalidResponse }
        // Repeat the server filter locally. A simulator or development client must
        // never become an installation candidate in an updates-only native app.
        guard build.platform == "IOS", build.distribution == "INTERNAL", build.buildProfile == profile,
          !build.isForIosSimulator, build.developmentClient == false,
          expectedBundleIdentifier == nil || build.appIdentifier == expectedBundleIdentifier else { continue }
        guard let runtime = build.runtime?.version else { continue } // EAS may still be assigning it.
        guard validText(runtime, maximum: 512), date(build.createdAt) != nil,
          date(build.updatedAt) != nil,
          build.gitCommitHash == nil || isCommit(build.gitCommitHash!) else { throw DraftEASError.invalidResponse }
        let state: String
        switch build.status {
        case "NEW", "IN_QUEUE": state = "queued"
        case "IN_PROGRESS", "PENDING_CANCEL": state = "building"
        case "ERRORED", "CANCELED": state = "failed"
        case "FINISHED":
          guard let expiration = build.expirationDate, let expires = date(expiration), expires > now else { continue }
          state = "ready"
        default: throw DraftEASError.invalidResponse
        }
        let url = path + id
        entries.append(DraftBuildEntry(runtimeVersion: runtime, platform: "ios", profile: profile,
          state: state, buildId: id, installUrl: state == "ready" ? url : nil,
          requestUrl: nil, statusUrl: url, gitCommitHash: build.gitCommitHash, updatedAt: build.updatedAt))
      }
    }
    guard ids.count <= 1000 else { throw DraftEASError.paginationLimit }
    return DraftBuildCatalog(schemaVersion: 1, projectId: try uuid(projectID), generatedAt: ISO8601DateFormatter().string(from: now), builds: entries)
  }

  static func project(from data: Data, projectID: String) throws -> Project {
    guard data.count <= DraftEASRequest.maximumBytes else { throw DraftEASError.invalidResponse }
    let response: Response
    do { response = try JSONDecoder().decode(Response.self, from: data) }
    catch { throw DraftEASError.invalidResponse }
    if let errors = response.errors, !errors.isEmpty {
      let codes = Set(errors.flatMap { [$0.extensions?.code, $0.extensions?.errorCode].compactMap { $0 } })
      if codes.contains("UNAUTHENTICATED") { throw DraftEASError.authenticationRequired }
      if !codes.isDisjoint(with: ["UNAUTHORIZED_ERROR", "FORBIDDEN"]) { throw DraftEASError.accessDenied }
      if !codes.isDisjoint(with: ["RATE_LIMITED", "RATE_LIMIT_EXCEEDED", "TOO_MANY_REQUESTS"]) { throw DraftEASError.rateLimited(until: nil) }
      throw DraftEASError.unavailable
    }
    guard let project = response.data?.app?.byId, try uuid(project.id) == uuid(projectID) else { throw DraftEASError.invalidResponse }
    return project
  }

  private static func uuid(_ value: String) throws -> String {
    guard let id = UUID(uuidString: value) else { throw DraftEASError.invalidResponse }
    return id.uuidString.lowercased()
  }
  private static func validText(_ text: String, maximum: Int) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= maximum &&
      !text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
  }
  private static func validPathSegment(_ text: String) -> Bool {
    validText(text, maximum: 100) && text != "." && text != ".." &&
      text.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-").contains($0) }
  }
  private static func isCommit(_ text: String) -> Bool {
    [40, 64].contains(text.count) && text.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }
  }
  static func date(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = formatter.date(from: text) { return value }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
  }

  struct Response: Decodable { let data: Root?; let errors: [GraphQLError]? }
  struct Root: Decodable { let app: AppLookup? }
  struct AppLookup: Decodable { let byId: Project? }
  struct GraphQLError: Decodable { let extensions: ErrorExtensions? }
  struct ErrorExtensions: Decodable { let code: String?; let errorCode: String? }
  struct Project: Decodable {
    let id: String; let slug: String?; let ownerAccount: Owner?
    let updateChannels: [Channel]?; let builds: [Build]?
  }
  struct Owner: Decodable { let name: String }
  struct Channel: Decodable {
    let id: String; let name: String; let isPaused: Bool; let branchMapping: String
    let updateBranches: [Branch]
  }
  struct Branch: Decodable { let id: String; let name: String; let updates: [Update] }
  struct BranchMapping: Decodable { let version: Int; let data: [BranchRule] }
  struct BranchRule: Decodable { let branchId: String; let branchMappingLogic: String }
  struct Identity: Decodable { let id: String }
  struct Runtime: Decodable { let version: String }
  struct Update: Decodable {
    let id: String; let group: String; let platform: String; let message: String?
    let runtime: Runtime?; let createdAt: String; let gitCommitHash: String?
    let isRollBackToEmbedded: Bool; let rolloutPercentage: Double?; let rolloutControlUpdate: Identity?
  }
  struct Build: Decodable {
    let id: String; let status: String; let platform: String; let distribution: String?
    let buildProfile: String?; let isForIosSimulator: Bool; let developmentClient: Bool?
    let runtime: Runtime?; let app: Identity; let appIdentifier: String?
    let gitCommitHash: String?; let createdAt: String; let updatedAt: String; let expirationDate: String?
  }
}

private final class DraftEASPagedOperation<Value> {
  private let query: String
  private let variables: [String: Any]
  private var sessionSecret: String
  private let configuration: URLSessionConfiguration
  private let count: (Data) throws -> Int
  private let map: ([Data]) throws -> Value
  private var completion: ((Result<Value, Error>) -> Void)?
  private var request: DraftEASRequest?
  private var pages: [Data] = []
  private var rowCount = 0
  private var byteCount = 0
  private let deadline = Date().addingTimeInterval(120)

  init(query: String, variables: [String: Any], sessionSecret: String, configuration: URLSessionConfiguration,
    count: @escaping (Data) throws -> Int, map: @escaping ([Data]) throws -> Value,
    completion: @escaping (Result<Value, Error>) -> Void) {
    self.query = query; self.variables = variables; self.sessionSecret = sessionSecret
    self.configuration = configuration; self.count = count; self.map = map; self.completion = completion
  }

  func start() {
    guard !sessionSecret.isEmpty, sessionSecret.count < 20_000,
      !sessionSecret.contains("\n"), !sessionSecret.contains("\r") else {
      finish(.failure(DraftEASError.authenticationRequired)); return
    }
    next()
  }

  func cancel() { finish(.failure(URLError(.cancelled))) }

  private func next() {
    guard completion != nil else { return }
    guard Date() < deadline else { finish(.failure(DraftEASError.unavailable)); return }
    var variables = variables
    variables["offset"] = rowCount
    variables["limit"] = 50
    let request = DraftEASRequest(query: query, variables: variables, sessionSecret: sessionSecret, configuration: configuration) { [weak self] result in
      guard let self, self.completion != nil else { return }
      self.request = nil
      do {
        let data = try result.get()
        let count = try self.count(data)
        self.rowCount += count
        self.byteCount += data.count
        guard count <= 50, self.rowCount <= 1000, self.byteCount <= 20_000_000 else { throw DraftEASError.paginationLimit }
        self.pages.append(data)
        if count < 50 { self.finish(Result { try self.map(self.pages) }) }
        else { self.next() }
      } catch { self.finish(.failure(error)) }
    }
    self.request = request
    request.start()
  }

  private func finish(_ result: Result<Value, Error>) {
    guard let completion else { return }
    self.completion = nil
    let request = request
    self.request = nil
    request?.cancel()
    sessionSecret = ""
    pages.removeAll()
    completion(result)
  }
}

/// Delegate streaming enforces a body cap before allocation and refuses all
/// redirects, so an Expo session is sent only to the fixed GraphQL origin.
final class DraftEASRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  static let endpoint = URL(string: "https://api.expo.dev/graphql")!
  static let maximumBytes = 5_000_000
  private let query: String
  private let variables: [String: Any]
  private var sessionSecret: String
  private let configuration: URLSessionConfiguration
  private var completion: ((Result<Data, Error>) -> Void)?
  private var session: URLSession?
  private var data = Data()

  init(query: String, variables: [String: Any], sessionSecret: String, configuration: URLSessionConfiguration = .ephemeral, completion: @escaping (Result<Data, Error>) -> Void) {
    self.query = query; self.variables = variables; self.sessionSecret = sessionSecret
    self.configuration = configuration; self.completion = completion
  }

  func start() {
    precondition(Thread.isMainThread)
    let configuration = configuration.copy() as! URLSessionConfiguration
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 25
    configuration.timeoutIntervalForResource = 25
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    self.session = session
    var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 25)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(sessionSecret, forHTTPHeaderField: "expo-session")
    do { request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables]) }
    catch { finish(.failure(DraftEASError.invalidResponse)); return }
    session.dataTask(with: request).resume()
  }

  static func retryDate(_ value: String?, now: Date = Date()) -> Date? {
    guard let value else { return nil }
    if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0, seconds <= 31_536_000 {
      return now.addingTimeInterval(seconds)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    return formatter.date(from: value)
  }

  func cancel() { finish(.failure(URLError(.cancelled))) }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let http = response as? HTTPURLResponse, response.url == Self.endpoint else {
      completionHandler(.cancel); finish(.failure(DraftEASError.invalidResponse)); return
    }
    guard http.statusCode == 200 else {
      completionHandler(.cancel)
      let error: DraftEASError
      switch http.statusCode {
      case 401: error = .authenticationRequired
      case 403: error = .accessDenied
      case 429: error = .rateLimited(until: Self.retryDate(http.value(forHTTPHeaderField: "Retry-After")))
      default: error = .unavailable
      }
      finish(.failure(error)); return
    }
    guard response.expectedContentLength <= Int64(Self.maximumBytes) else {
      completionHandler(.cancel); finish(.failure(DraftEASError.invalidResponse)); return
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
    guard completion != nil else { return }
    guard data.count + chunk.count <= Self.maximumBytes else { finish(.failure(DraftEASError.invalidResponse)); return }
    data.append(chunk)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard completion != nil else { return }
    if let error { finish(.failure((error as NSError).code == NSURLErrorCancelled ? URLError(.cancelled) : DraftEASError.unavailable)); return }
    finish(.success(data))
  }

  private func finish(_ result: Result<Data, Error>) {
    guard let completion else { return }
    self.completion = nil
    session?.invalidateAndCancel()
    session = nil
    sessionSecret = ""
    data.removeAll()
    completion(result)
  }
}
