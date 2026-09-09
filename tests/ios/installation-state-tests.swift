import Foundation

@main
struct InstallationStateTests {
  static let projectID = "a1111111-b222-4333-8444-c55555555555"
  static let buildID = "33333333-4444-4555-8666-777777777777"
  static let draftID = "44444444-5555-4666-8777-888888888888"
  static let otherProjectID = "55555555-6666-4777-8888-999999999999"
  static let now = Date(timeIntervalSince1970: 1_789_000_000)
  static let key = "installation-test"

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: "installation-state-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }

  static func expectFailure(_ message: String, _ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw NSError(domain: "installation-state-test", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }

  static func request(project: String = projectID, source: String = "runtime-source", target: String = "runtime-target", build: String = buildID, draft: String = draftID, name: String = "Café \"Draft\"\n第二", at: Date = now) -> DraftInstallationRequest {
    DraftInstallationRequest(projectID: project, sourceRuntime: source, targetRuntime: target, buildID: build, draftID: draft, name: name, requestedAt: at)
  }

  static func main() throws {
    let suite = "expo-drafts-installation-state-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = DraftInstallationStateStore(defaults: defaults, key: key)
    let pending = request()

    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil, "No pending state should be invented")
    try store.save(pending)
    let reopened = DraftInstallationStateStore(defaults: UserDefaults(suiteName: suite)!, key: key)
    try expect(reopened.active(projectID: projectID.uppercased(), currentRuntime: "runtime-source", now: now.addingTimeInterval(20)) == pending,
      "A reopened store must restore the pending identity and Unicode name")
    try expect(reopened.active(projectID: projectID, currentRuntime: "", now: now) == nil, "An unknown startup runtime must not report installed or pending UI")
    try expect(defaults.data(forKey: key) != nil, "An uninitialized update controller must not erase the persisted handoff")
    try expect(reopened.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == pending,
      "The request must become visible again when the source runtime initializes")
    print("PASS persisted installation request survives store reopening and update-controller startup")

    try expect(store.active(projectID: projectID, currentRuntime: "runtime-target", now: now) == nil,
      "Observing the target native runtime must clear the request")
    try expect(defaults.object(forKey: key) == nil, "Target-runtime cleanup must persist")
    try store.save(pending)
    try expect(store.active(projectID: projectID, currentRuntime: "a-different-native-build", now: now) == nil,
      "Installing another native build must not retain an unrelated request")
    try expect(defaults.object(forKey: key) == nil, "A different native runtime must persist cleanup")
    try store.save(pending)
    store.clear()
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
      "The user can dismiss a cancelled system installation request")
    print("PASS observed native runtime changes and explicit dismissal clear pending state")

    try store.save(pending)
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now.addingTimeInterval(899)) != nil,
      "A pending request remains visible before the 15-minute expiry")
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now.addingTimeInterval(900)) == nil,
      "The expiry boundary must not leave an indefinite pending state")
    try expect(defaults.object(forKey: key) == nil, "Expired records must be removed")
    try store.save(request(at: now.addingTimeInterval(30)))
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) != nil,
      "A small clock adjustment may be tolerated")
    try store.save(request(at: now.addingTimeInterval(61)))
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
      "A far-future timestamp must not prevent expiry")
    print("PASS bounded request expiry and clock-skew handling")

    for invalid in [
      request(project: "invalid"), request(build: "invalid"), request(draft: "invalid"),
      request(source: ""), request(target: " \n"), request(target: "runtime-source"),
      request(source: String(repeating: "x", count: 513)), request(name: " \n")
    ] {
      try expectFailure("Invalid identities must not be persisted") { try store.save(invalid) }
    }
    try store.save(pending)
    try expect(store.active(projectID: otherProjectID, currentRuntime: "runtime-source", now: now) == nil,
      "Another EAS project must never inherit the installation state")
    try expect(defaults.object(forKey: key) == nil, "Project mismatch must clear the record")
    for value: Any in ["not-data", Data("bad-json".utf8), Data(repeating: 0, count: 32_769)] {
      defaults.set(value, forKey: key)
      try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
        "Corrupt or oversized persisted state must be ignored")
      try expect(defaults.object(forKey: key) == nil, "Corrupt persisted state must be removed")
    }
    try store.save(pending)
    var envelope = try JSONSerialization.jsonObject(with: defaults.data(forKey: key)!) as! [String: Any]
    envelope["schemaVersion"] = 2
    defaults.set(try JSONSerialization.data(withJSONObject: envelope), forKey: key)
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
      "An unknown storage schema must be rejected")
    print("PASS invalid identities, project isolation, corrupt data, and schema validation")
    print("4 iOS installation state test groups passed")
  }
}
