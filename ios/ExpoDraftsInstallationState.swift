import Foundation

/// An installer handoff was requested. This record never represents download
/// progress or proves that the user accepted the system installation prompt.
struct DraftInstallationRequest: Codable, Equatable {
  let projectID: String
  let sourceRuntime: String
  let targetRuntime: String
  let buildID: String
  let draftID: String
  let name: String
  let requestedAt: Date
  let updateID: String?
  let channel: String?

  init(projectID: String, sourceRuntime: String, targetRuntime: String, buildID: String,
    draftID: String, name: String, requestedAt: Date, updateID: String? = nil, channel: String? = nil) {
    self.projectID = projectID
    self.sourceRuntime = sourceRuntime
    self.targetRuntime = targetRuntime
    self.buildID = buildID
    self.draftID = draftID
    self.name = name
    self.requestedAt = requestedAt
    self.updateID = updateID
    self.channel = channel
  }

  var hasResumeIdentity: Bool { updateID != nil && channel != nil }

  fileprivate var isValid: Bool {
    UUID(uuidString: projectID) != nil && UUID(uuidString: buildID) != nil && UUID(uuidString: draftID) != nil &&
      !sourceRuntime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sourceRuntime.count <= 512 &&
      !targetRuntime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && targetRuntime.count <= 512 &&
      sourceRuntime != targetRuntime &&
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 4096 &&
      requestedAt.timeIntervalSince1970.isFinite &&
      ((updateID == nil && channel == nil) ||
        (updateID.flatMap(UUID.init(uuidString:)) != nil && channel.map {
          !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 1000 &&
            $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) &&
            $0.rangeOfCharacter(from: .controlCharacters) == nil
        } == true))
  }
}

struct DraftInstallationResume: Equatable {
  enum Phase: String, Codable {
    case pending
    case attempting
    case retryRequired
  }

  let request: DraftInstallationRequest
  let phase: Phase
  let isTargetRuntime: Bool

  var canResumeAutomatically: Bool { isTargetRuntime && phase == .pending }
}

/// Callers serialize access on the main queue. An automatic attempt is claimed
/// before launching; a persisted attempt after process interruption needs an
/// explicit retry instead of automatically starting another reload loop.
struct DraftInstallationStateStore {
  static let defaultKey = "expo.modules.drafts.installation-request.v1"
  static let lifetime: TimeInterval = 15 * 60
  static let resumeLifetime: TimeInterval = 7 * 24 * 60 * 60
  private static let maximumDataBytes = 32_768
  private let defaults: UserDefaults
  private let key: String

  private struct StoredRequest: Codable {
    let schemaVersion: Int
    let request: DraftInstallationRequest
    let phase: DraftInstallationResume.Phase?
  }

  init(defaults: UserDefaults = .standard, key: String = Self.defaultKey) {
    self.defaults = defaults
    self.key = key
  }

  func save(_ request: DraftInstallationRequest) throws {
    guard request.isValid else { throw StateError.invalidRequest }
    try write(StoredRequest(schemaVersion: 2, request: request, phase: request.hasResumeIdentity ? .pending : nil))
  }

  /// This short-lived source-build status never erases a durable resume intent.
  func active(projectID: String, currentRuntime: String, now: Date = Date()) -> DraftInstallationRequest? {
    guard let stored = load(projectID: projectID, currentRuntime: currentRuntime, now: now),
      currentRuntime == stored.request.sourceRuntime,
      now.timeIntervalSince(stored.request.requestedAt) < Self.lifetime else { return nil }
    return stored.request
  }

  /// Return the exact intent on either its source or target build. A target
  /// runtime alone proves neither installer completion nor the requested update.
  func pendingResume(projectID: String, currentRuntime: String, now: Date = Date()) -> DraftInstallationResume? {
    guard let stored = load(projectID: projectID, currentRuntime: currentRuntime, now: now),
      let phase = stored.phase else { return nil }
    return DraftInstallationResume(request: stored.request, phase: phase,
      isTargetRuntime: currentRuntime == stored.request.targetRuntime)
  }

  func resume(projectID: String, currentRuntime: String, now: Date = Date()) -> DraftInstallationResume? {
    guard let pending = pendingResume(projectID: projectID, currentRuntime: currentRuntime, now: now),
      pending.isTargetRuntime else { return nil }
    return pending
  }

  /// Persist the attempt before asking expo-updates to check, fetch, or reload.
  /// A retry of an interrupted attempt also requires the manager's in-flight guard.
  @discardableResult
  func beginResume(expected: DraftInstallationRequest, projectID: String, currentRuntime: String,
    explicitRetry: Bool = false, now: Date = Date()) throws -> Bool {
    guard let stored = load(projectID: projectID, currentRuntime: currentRuntime, now: now, expected: expected),
      let phase = stored.phase, currentRuntime == stored.request.targetRuntime,
      phase == .pending || explicitRetry else { return false }
    try write(StoredRequest(schemaVersion: 2, request: stored.request, phase: .attempting))
    return true
  }

  @discardableResult
  func recordResumeFailure(expected: DraftInstallationRequest, projectID: String, currentRuntime: String,
    now: Date = Date()) throws -> Bool {
    guard let stored = load(projectID: projectID, currentRuntime: currentRuntime, now: now, expected: expected),
      stored.phase == .attempting else { return false }
    try write(StoredRequest(schemaVersion: 2, request: stored.request, phase: .retryRequired))
    return true
  }

  /// Clear only after the caller observes the actual launched UUID and runtime.
  /// This also handles a launch that succeeded immediately before process death.
  @discardableResult
  func finishResume(expected: DraftInstallationRequest, projectID: String, currentRuntime: String,
    launchedUpdateID: String?, now: Date = Date()) -> Bool {
    guard let stored = load(projectID: projectID, currentRuntime: currentRuntime, now: now, expected: expected),
      stored.phase != nil, currentRuntime == stored.request.targetRuntime,
      let actual = launchedUpdateID.flatMap(UUID.init(uuidString:)),
      let intended = stored.request.updateID.flatMap(UUID.init(uuidString:)), actual == intended else { return false }
    clear()
    return true
  }

  @discardableResult
  func clear(expected: DraftInstallationRequest) -> Bool {
    guard let stored = read(), stored.request == expected else { return false }
    clear()
    return true
  }

  func clear() {
    defaults.removeObject(forKey: key)
  }

  private func write(_ stored: StoredRequest) throws {
    let data = try JSONEncoder().encode(stored)
    guard data.count <= Self.maximumDataBytes else { throw StateError.invalidRequest }
    defaults.set(data, forKey: key)
  }

  private func read() -> StoredRequest? {
    guard let stored = defaults.object(forKey: key) else { return nil }
    guard let data = stored as? Data, data.count <= Self.maximumDataBytes,
      let envelope = try? JSONDecoder().decode(StoredRequest.self, from: data),
      envelope.request.isValid,
      (envelope.schemaVersion == 1 && !envelope.request.hasResumeIdentity && envelope.phase == nil) ||
        (envelope.schemaVersion == 2 && envelope.request.hasResumeIdentity == (envelope.phase != nil)) else {
      clear()
      return nil
    }
    return envelope
  }

  private func load(projectID: String, currentRuntime: String, now: Date,
    expected: DraftInstallationRequest? = nil) -> StoredRequest? {
    guard let envelope = read() else { return nil }
    // Stale callbacks must not invalidate a newer request, even if the old
    // callback carries another project or an expired timestamp.
    if let expected, envelope.request != expected { return nil }
    guard let project = UUID(uuidString: projectID), UUID(uuidString: envelope.request.projectID) == project else {
      clear()
      return nil
    }
    let request = envelope.request
    let age = now.timeIntervalSince(request.requestedAt)
    // Tolerate a small clock adjustment, but never retain a far-future timestamp.
    let duration = envelope.phase == nil ? Self.lifetime : Self.resumeLifetime
    guard age.isFinite, age >= -60, age < duration else {
      clear()
      return nil
    }
    // Updates may not be initialized when the native picker first becomes available.
    guard !currentRuntime.isEmpty else { return nil }
    guard currentRuntime == request.sourceRuntime ||
      (envelope.phase != nil && currentRuntime == request.targetRuntime) else {
      clear()
      return nil
    }
    return envelope
  }

  private enum StateError: LocalizedError {
    case invalidRequest

    var errorDescription: String? { "The installation request could not be saved because its identity is invalid." }
  }
}
