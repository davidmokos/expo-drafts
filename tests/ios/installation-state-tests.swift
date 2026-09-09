import Foundation
import Darwin

@main
struct InstallationStateTests {
  static let projectID = "a1111111-b222-4333-8444-c55555555555"
  static let buildID = "33333333-4444-4555-8666-777777777777"
  static let draftID = "44444444-5555-4666-8777-888888888888"
  static let otherProjectID = "55555555-6666-4777-8888-999999999999"
  static let updateID = "66666666-7777-4888-8999-aaaaaaaaaaaa"
  static let otherUpdateID = "77777777-8888-4999-8aaa-bbbbbbbbbbbb"
  static let now = Date(timeIntervalSince1970: 1_789_000_000)
  static let key = "installation-test"

  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain: "installation-state-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }

  static func expectFailure(_ message: String, _ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw NSError(domain: "installation-state-test", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }

  static func request(project: String = projectID, source: String = "runtime-source", target: String = "runtime-target", build: String = buildID, draft: String = draftID, name: String = "Café \"Draft\"\n第二", at: Date = now, update: String? = nil, channel: String? = nil) -> DraftInstallationRequest {
    DraftInstallationRequest(projectID: project, sourceRuntime: source, targetRuntime: target, buildID: build, draftID: draft, name: name, requestedAt: at, updateID: update, channel: channel)
  }

  static func main() throws {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--interrupt-resume" {
      let childDefaults = UserDefaults(suiteName: CommandLine.arguments[2])!
      let childStore = DraftInstallationStateStore(defaults: childDefaults, key: key)
      let intent = request(update: updateID, channel: "draft-pr-23")
      try childStore.save(intent)
      guard try childStore.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) else { _exit(2) }
      // Skip normal teardown immediately after claiming, as with an interrupted reload.
      _exit(0)
    }
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
    envelope["schemaVersion"] = 3
    defaults.set(try JSONSerialization.data(withJSONObject: envelope), forKey: key)
    try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
      "An unknown storage schema must be rejected")
    print("PASS invalid identities, project isolation, corrupt data, and schema validation")

    let intent = request(update: updateID, channel: "draft-pr-23")
    do {
      try store.save(intent)
      try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now.addingTimeInterval(899)) == intent,
        "The original installation status remains visible for 15 minutes")
      try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now.addingTimeInterval(900)) == nil,
        "The short installation spinner must expire independently of the resume intent")
      try expect(defaults.data(forKey: key) != nil, "Status expiry must not delete the exact selected update")
      let waiting = store.pendingResume(projectID: projectID, currentRuntime: "runtime-source", now: now.addingTimeInterval(2 * 24 * 3600))
      try expect(waiting?.request == intent && waiting?.phase == .pending && waiting?.isTargetRuntime == false,
        "Retain the name, channel, exact platform UUID, project, and target beyond the spinner lifetime")
      try expect(waiting?.canResumeAutomatically == false, "The source build cannot launch the incompatible requested update")
      try expect(store.resume(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
        "The target-only convenience accessor must not offer a source-runtime resume")
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-source", now: now) == false,
        "An automatic claim must reject the wrong native runtime")
      print("PASS durable exact resume identity outlives the installation spinner without launching on the source build")
    }

    do {
      try store.save(intent)
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "", now: now) == nil,
        "An uninitialized updates controller cannot produce an eligible resume")
      try expect(defaults.data(forKey: key) != nil, "Unknown startup runtime must retain the durable intent")
      try expect(store.active(projectID: projectID, currentRuntime: "runtime-target", now: now) == nil,
        "The source-build spinner must not claim progress on the target build")
      let target = reopened.resume(projectID: projectID.uppercased(), currentRuntime: "runtime-target", now: now.addingTimeInterval(20))
      try expect(target?.request == intent && target?.phase == .pending && target?.canResumeAutomatically == true,
        "Target runtime arrival makes the exact intent eligible without deleting it")
      try expect(defaults.data(forKey: key) != nil, "Target runtime arrival alone must never mark the selected update completed")
      print("PASS target runtime arrival preserves an eligible exact intent across store reopening")
    }

    do {
      try store.save(intent)
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now),
        "The first eligible automatic attempt must be claimed")
      let afterInterruption = DraftInstallationStateStore(defaults: UserDefaults(suiteName: suite)!, key: key)
      let attempting = afterInterruption.resume(projectID: projectID, currentRuntime: "runtime-target", now: now)
      try expect(attempting?.phase == .attempting && attempting?.canResumeAutomatically == false,
        "A reopened store must retain the claimed attempt instead of creating a reload loop")
      try expect(try afterInterruption.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "Repeated automatic callbacks and process restarts must not reclaim an attempt")
      try expect(try afterInterruption.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", explicitRetry: true, now: now),
        "The user may explicitly retry an interrupted attempt")
      print("PASS claimed attempts survive interruption and cannot automatically loop")
    }

    do {
      let interruptedSuite = "expo-drafts-resume-interruption.\(UUID().uuidString)"
      let child = Process()
      child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      child.arguments = ["--interrupt-resume", interruptedSuite]
      try child.run()
      child.waitUntilExit()
      let persistedDefaults = UserDefaults(suiteName: interruptedSuite)!
      defer { persistedDefaults.removePersistentDomain(forName: interruptedSuite) }
      let persisted = DraftInstallationStateStore(defaults: persistedDefaults, key: key)
      try expect(child.terminationStatus == 0, "The child must claim the resume before immediately exiting")
      let interrupted = persisted.resume(projectID: projectID, currentRuntime: "runtime-target", now: now)
      try expect(interrupted?.request == intent && interrupted?.phase == .attempting && interrupted?.canResumeAutomatically == false,
        "The attempt marker must survive actual process exit without normal teardown")
      try expect(try persisted.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "A newly created process must not automatically launch the interrupted attempt again")
      print("PASS an attempt survives immediate separate-process exit without an automatic retry")
    }

    do {
      try store.save(intent)
      try expect(try store.recordResumeFailure(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "A readiness or sign-in wait before claiming must not manufacture a failed attempt")
      try expect(store.resume(projectID: projectID, currentRuntime: "runtime-target", now: now)?.canResumeAutomatically == true,
        "Waiting for authentication or app readiness leaves the initial attempt eligible")
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now), "Claim the network attempt")
      try expect(try store.recordResumeFailure(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now),
        "Offline, authentication, or stale-channel failures after claiming must require explicit retry")
      let failed = reopened.resume(projectID: projectID, currentRuntime: "runtime-target", now: now)
      try expect(failed?.request == intent && failed?.phase == .retryRequired && failed?.canResumeAutomatically == false,
        "A failed attempt keeps the exact identity while blocking automatic retries")
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "A foreground or network event must not automatically retry a failure")
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", explicitRetry: true, now: now),
        "Explicit retry must permit the same selected update after recovery")
      print("PASS readiness waits and failed downloads retain intent with explicit retry semantics")
    }

    do {
      try store.save(intent)
      _ = try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now)
      for actual in [nil, "", "not-a-uuid", otherUpdateID] as [String?] {
        try expect(!store.finishResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", launchedUpdateID: actual, now: now),
          "An absent or different launched update must not complete the selected draft")
      }
      try expect(!store.finishResume(expected: intent, projectID: projectID, currentRuntime: "runtime-source", launchedUpdateID: updateID, now: now),
        "Even the requested UUID cannot complete against a different native runtime")
      try expect(defaults.data(forKey: key) != nil, "Failed identity verification must retain the requested update for recovery")
      try expect(reopened.finishResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", launchedUpdateID: updateID.uppercased(), now: now),
        "Only the actual exact UUID and target runtime complete a claimed or interrupted attempt")
      try expect(defaults.object(forKey: key) == nil, "Verified completion must clear the durable request")
      try store.save(intent)
      try expect(store.finishResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", launchedUpdateID: updateID, now: now),
        "An already-running exact update can complete without another fetch or reload")
      print("PASS only verified launched UUID and target runtime complete a resume")
    }

    do {
      let newer = request(project: otherProjectID, source: "other-source", target: "other-target", name: "New selection",
        at: now.addingTimeInterval(10), update: otherUpdateID, channel: "new-channel")
      try store.save(newer)
      try expect(try store.beginResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now.addingTimeInterval(8 * 24 * 3600)) == false,
        "A stale claim must not invalidate a newer request using its old project or clock")
      try expect(try store.recordResumeFailure(expected: intent, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "A stale failure callback cannot alter a newer selection")
      try expect(!store.finishResume(expected: intent, projectID: projectID, currentRuntime: "runtime-target", launchedUpdateID: updateID, now: now),
        "A stale successful launch cannot clear another selected update")
      try expect(!store.clear(expected: intent), "A rejected old installer handoff cannot erase a newer request")
      try expect(store.pendingResume(projectID: otherProjectID, currentRuntime: "other-target", now: now.addingTimeInterval(10))?.request == newer,
        "All stale callbacks must preserve the newer exact request")
      try expect(store.clear(expected: newer), "A rejected installer can clear its own exact request")
      try expect(defaults.object(forKey: key) == nil, "Matching handoff cancellation persists")
      try store.save(intent)
      store.clear()
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-target", now: now) == nil,
        "Explicit cancel must remove both status and durable resume intent")
      print("PASS request identity guards protect newer selections from stale handoff and launch callbacks")
    }

    do {
      try store.save(intent)
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-target", now: now.addingTimeInterval(DraftInstallationStateStore.resumeLifetime - 1)) != nil,
        "The selected update remains resumable for up to seven days")
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-target", now: now.addingTimeInterval(DraftInstallationStateStore.resumeLifetime)) == nil,
        "The durable intent expires at the exact seven-day boundary")
      try expect(defaults.object(forKey: key) == nil, "Durable expiry must be persisted")
      for runtime in ["unrelated-native-build", "runtime-target"] {
        try store.save(intent)
        let project = runtime == "runtime-target" ? otherProjectID : projectID
        try expect(store.pendingResume(projectID: project, currentRuntime: runtime, now: now) == nil,
          "An unrelated native build or project must not inherit the exact resume intent")
        try expect(defaults.object(forKey: key) == nil, "Unrelated build or project cleanup must persist")
      }
      try store.save(request(at: now.addingTimeInterval(61), update: updateID, channel: "draft-pr-23"))
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-target", now: now) == nil,
        "Durable intents must reject far-future timestamps too")
      print("PASS durable intent expiry, clock validation, and unrelated native build isolation")
    }

    do {
      try store.save(pending)
      var legacy = try JSONSerialization.jsonObject(with: defaults.data(forKey: key)!) as! [String: Any]
      legacy["schemaVersion"] = 1
      defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: key)
      try expect(store.active(projectID: projectID, currentRuntime: "runtime-source", now: now) == pending,
        "Existing v1 records must remain safe installation status records")
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-source", now: now) == nil,
        "A legacy group ID must never be guessed to be a platform update ID")
      try expect(try store.beginResume(expected: pending, projectID: projectID, currentRuntime: "runtime-target", now: now) == false,
        "Legacy status cannot become an automatic launch on the target build")
      try expect(defaults.object(forKey: key) == nil, "Legacy target-runtime status cleanup remains bounded")
      for invalid in [
        request(update: updateID), request(channel: "draft-pr-23"), request(update: "invalid", channel: "draft-pr-23"),
        request(update: updateID, channel: ""), request(update: updateID, channel: " draft-pr-23"),
        request(update: updateID, channel: "draft\r\nchannel"), request(update: updateID, channel: String(repeating: "a", count: 1001))
      ] {
        try expectFailure("Invalid or incomplete exact resume identities must not be persisted") { try store.save(invalid) }
      }
      try store.save(intent)
      var badPhase = try JSONSerialization.jsonObject(with: defaults.data(forKey: key)!) as! [String: Any]
      badPhase["phase"] = "unknown-phase"
      defaults.set(try JSONSerialization.data(withJSONObject: badPhase), forKey: key)
      try expect(store.pendingResume(projectID: projectID, currentRuntime: "runtime-target", now: now) == nil,
        "An unknown attempt phase must not become eligible for automatic launch")
      try expect(defaults.object(forKey: key) == nil, "Invalid durable phase cleanup must persist")
      print("PASS legacy status-only migration and strict exact-resume identity/phase validation")
    }
    print("13 iOS installation state test groups passed")
  }
}
