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

  fileprivate var isValid: Bool {
    UUID(uuidString: projectID) != nil && UUID(uuidString: buildID) != nil && UUID(uuidString: draftID) != nil &&
      !sourceRuntime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sourceRuntime.count <= 512 &&
      !targetRuntime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && targetRuntime.count <= 512 &&
      sourceRuntime != targetRuntime &&
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 4096 &&
      requestedAt.timeIntervalSince1970.isFinite
  }
}

struct DraftInstallationStateStore {
  static let defaultKey = "expo.modules.drafts.installation-request.v1"
  static let lifetime: TimeInterval = 15 * 60
  private static let maximumDataBytes = 32_768
  private let defaults: UserDefaults
  private let key: String

  private struct StoredRequest: Codable {
    let schemaVersion: Int
    let request: DraftInstallationRequest
  }

  init(defaults: UserDefaults = .standard, key: String = Self.defaultKey) {
    self.defaults = defaults
    self.key = key
  }

  func save(_ request: DraftInstallationRequest) throws {
    guard request.isValid else { throw StateError.invalidRequest }
    let data = try JSONEncoder().encode(StoredRequest(schemaVersion: 1, request: request))
    guard data.count <= Self.maximumDataBytes else { throw StateError.invalidRequest }
    defaults.set(data, forKey: key)
  }

  /// A nil result means there is no pending request to display. Observing the
  /// target runtime clears the record without manufacturing an install callback.
  func active(projectID: String, currentRuntime: String, now: Date = Date()) -> DraftInstallationRequest? {
    guard let stored = defaults.object(forKey: key) else { return nil }
    guard let data = stored as? Data, data.count <= Self.maximumDataBytes,
      let envelope = try? JSONDecoder().decode(StoredRequest.self, from: data),
      envelope.schemaVersion == 1, envelope.request.isValid,
      let project = UUID(uuidString: projectID), UUID(uuidString: envelope.request.projectID) == project else {
      clear()
      return nil
    }
    let request = envelope.request
    let age = now.timeIntervalSince(request.requestedAt)
    // Tolerate a small clock adjustment, but never retain a far-future timestamp.
    guard age.isFinite, age >= -60, age < Self.lifetime else {
      clear()
      return nil
    }
    // Updates may not be initialized when the native picker first becomes available.
    guard !currentRuntime.isEmpty else { return nil }
    guard currentRuntime == request.sourceRuntime else {
      clear()
      return nil
    }
    return request
  }

  func clear() {
    defaults.removeObject(forKey: key)
  }

  private enum StateError: LocalizedError {
    case invalidRequest

    var errorDescription: String? { "The installation request could not be saved because its identity is invalid." }
  }
}
