import Foundation
import EXUpdates

@main
struct TransactionTests {
  static let pendingKey = "expo-drafts.pending-selection-v1"
  static let embeddedID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
  static let aID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
  static let bID = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
  static let cID = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
  static let headersA = ["expo-channel-name": "pr-a", "expo-drafts-selection": aID.uuidString.lowercased()]
  static let headersB = ["expo-channel-name": "pr-b", "expo-drafts-selection": bID.uuidString.lowercased()]
  static let bundledHeaders = ["expo-channel-name": "drafts", "expo-drafts-selection": "embedded"]
  static let updateURL = URL(string: "https://u.expo.dev/project")!

  static func expect(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
  }
  static func wait<T>(_ start: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
    var result: Result<T, Error>?
    start { result = $0 }
    let deadline = Date().addingTimeInterval(8)
    while result == nil && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
    guard let result else { throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Async operation timed out"]) }
    return try result.get()
  }

  static func fixture(embeddedTime: Int64 = 100_000, embeddedMetadata: [String: String]? = nil) throws -> (UpdatesDatabase, EnabledAppController) {
    UserDefaults.standard.removeObject(forKey: pendingKey)
    UpdatesConfig.current = UpdatesConfig(scopeKey: "project", updateUrl: updateURL, runtimeVersion: "runtime", requestHeaders: headersA)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("expo-drafts-transaction-\(UUID())")
    let db = UpdatesDatabase()
    try db.databaseQueue.sync {
      try db.openDatabase(inDirectory: directory, logger: UpdatesLogger())
      try insert(db, id: embeddedID, headers: bundledHeaders, time: embeddedTime)
      let metadata = try embeddedMetadata.map { String(data: try JSONSerialization.data(withJSONObject: $0), encoding: .utf8)! }
      _ = try db.execute(sql: "UPDATE updates SET status = 5, metadata = ?1 WHERE id = ?2;", withArgs: [metadata, embeddedID])
      try insert(db, id: aID, headers: headersA, time: 200_000)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('manifestFilters', '{\"branch\":\"a\"}', 1, 'project');", withArgs: nil)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('serverDefinedHeaders', '{\"token\":\"a\"}', 1, 'project');", withArgs: nil)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('manifestFilters', '{\"other\":true}', 1, 'other-project');", withArgs: nil)
    }
    UpdatesConfig.current.requestHeaders = headersA
    let controller = EnabledAppController(directory: directory, headers: headersA, embedded: Update(embeddedID, scopeKey: "project", runtimeVersion: "runtime", commitTime: Date(timeIntervalSince1970: Double(embeddedTime) / 1000), url: updateURL, requestHeaders: bundledHeaders, metadata: embeddedMetadata))
    AppController.sharedInstance = controller
    return (db, controller)
  }

  static func insert(_ db: UpdatesDatabase, id: UUID, headers: [String: String], time: Int64) throws {
    let text = String(data: try JSONSerialization.data(withJSONObject: headers, options: .sortedKeys), encoding: .utf8)!
    _ = try db.execute(sql: "INSERT INTO updates (id, scope_key, runtime_version, commit_time, url, headers) VALUES (?1, 'project', 'runtime', ?2, 'https://u.expo.dev/project', ?3);", withArgs: [id, time, text])
  }
  static func begin(_ controller: EnabledAppController, expected: UUID = bID, headers: [String: String] = headersB) throws -> DraftsUpdateTransaction {
    try wait { DraftsUpdateTransaction.begin(controller: controller, expectedID: expected.uuidString.lowercased(), nextHeaders: headers, completion: $0) }
  }
  static func rollback(_ transaction: DraftsUpdateTransaction) throws {
    let _: Void = try wait { completion in transaction.rollback { error in
      if let error { completion(.failure(error)) } else { completion(.success(())) }
    } }
    transaction.commit()
  }
  static func selected(_ db: UpdatesDatabase) throws -> Update? {
    let config = UpdatesConfig.current
    return try wait { completion in
      AppLauncherWithDatabase.launchableUpdate(withConfig: config, database: db,
        selectionPolicy: SelectionPolicyFactory.filterAwarePolicy(withRuntimeVersion: config.runtimeVersion, config: config), completionQueue: .main
      ) { error, update in
        if let error { completion(.failure(error)) } else { completion(.success(update)) }
      }
    }
  }
  static func prepareBundled(_ transaction: DraftsUpdateTransaction, expectedID: String = embeddedID.uuidString) throws {
    let _: Void = try wait { transaction.prepareEmbeddedLaunch(expectedID: expectedID, completion: $0) }
  }
  static func expectFailure(_ operation: () throws -> Void, _ message: String) throws {
    var failed = false
    do { try operation() } catch { failed = true }
    try expect(failed, message)
  }
  static func assertOriginalMetadata(_ db: UpdatesDatabase) throws {
    try db.databaseQueue.sync {
      let rows = try db.execute(sql: "SELECT key, value FROM json_data WHERE scope_key = 'project';", withArgs: nil)
      try expect(rows.contains { $0["key"] as? String == "manifestFilters" && $0["value"] as? String == "{\"branch\":\"a\"}" }, "Original manifest filters must be restored")
      try expect(rows.contains { $0["key"] as? String == "serverDefinedHeaders" && $0["value"] as? String == "{\"token\":\"a\"}" }, "Original server headers must be restored")
    }
  }

  static func main() throws {
    defer { UserDefaults.standard.removeObject(forKey: pendingKey) }
    do {
      let (db, controller) = try fixture()
      let transaction = try begin(controller)
      try db.databaseQueue.sync {
        try insert(db, id: cID, headers: headersB, time: 300_000)
        _ = try db.execute(sql: "UPDATE json_data SET value = '{\"branch\":\"b\"}' WHERE scope_key = 'project';", withArgs: nil)
        _ = try db.execute(sql: "UPDATE updates SET commit_time = 999000 WHERE id = ?1;", withArgs: [embeddedID])
      }
      controller.embedded?.commitTime = Date(timeIntervalSince1970: 999)
      try rollback(transaction)
      try db.databaseQueue.sync {
        try expect(try db.execute(sql: "SELECT id FROM updates WHERE id = ?1;", withArgs: [cID]).isEmpty, "Rejected newly cached update must be removed")
        try expect(try db.execute(sql: "SELECT id FROM updates WHERE id = ?1;", withArgs: [aID]).count == 1, "Running update must remain cached")
        let metadata = try db.execute(sql: "SELECT value FROM json_data WHERE key = 'manifestFilters' AND scope_key = 'project';", withArgs: nil)
        try expect(metadata.first?["value"] as? String == "{\"branch\":\"a\"}", "Original branch filters must be restored")
        try expect(try db.execute(sql: "SELECT value FROM json_data WHERE scope_key = 'other-project';", withArgs: nil).count == 1, "Other project metadata must remain untouched")
        try expect((try db.execute(sql: "SELECT commit_time FROM updates WHERE id = ?1;", withArgs: [embeddedID]).first?["commit_time"] as? NSNumber)?.int64Value == 100000, "Embedded rollback timestamp must be restored")
      }
      try expect(controller.embedded?.commitTime.timeIntervalSince1970 == 100, "In-memory embedded timestamp must be restored")
      print("PASS stale fetch rollback preserves active update, filters, other scopes, and embedded timestamp")
    }
    do {
      let (db, controller) = try fixture()
      try db.databaseQueue.sync { try insert(db, id: cID, headers: headersB, time: 300_000) }
      let headersC = ["expo-channel-name": "pr-b", "expo-drafts-selection": cID.uuidString.lowercased()]
      let transaction = try begin(controller, expected: cID, headers: headersC)
      try controller.setUpdateRequestHeadersOverride(headersC)
      let _: Void = try wait { transaction.prepareLaunch(expectedID: cID.uuidString.lowercased(), completion: $0) }
      try db.databaseQueue.sync {
        let text = try db.execute(sql: "SELECT headers FROM updates WHERE id = ?1;", withArgs: [cID]).first?["headers"] as! String
        try expect(try JSONDecoder().decode([String: String].self, from: Data(text.utf8)) == headersC, "Accepted cached UUID must be rebound to selected headers")
      }
      try rollback(transaction)
      try db.databaseQueue.sync {
        let text = try db.execute(sql: "SELECT headers FROM updates WHERE id = ?1;", withArgs: [cID]).first?["headers"] as! String
        try expect(try JSONDecoder().decode([String: String].self, from: Data(text.utf8)) == headersB, "Failed relaunch must restore pre-existing cached binding")
      }
      print("PASS cached rejected UUID can be adopted later; rollback preserves original cache binding")
    }
    do {
      let (db, controller) = try fixture()
      _ = try begin(controller)
      try controller.setUpdateRequestHeadersOverride(headersB)
      try db.databaseQueue.sync {
        try insert(db, id: cID, headers: headersB, time: 300_000)
        _ = try db.execute(sql: "UPDATE json_data SET value = '{}' WHERE scope_key = 'project';", withArgs: nil)
      }
      DraftsUpdateTransaction.recoverPendingSelection()
      try expect(controller.requestHeaders == headersA, "Startup recovery must restore prior headers")
      try expect(UserDefaults.standard.data(forKey: pendingKey) == nil, "Successful recovery clears pending marker")
      try db.databaseQueue.sync {
        try expect(try db.execute(sql: "SELECT id FROM updates WHERE id = ?1;", withArgs: [cID]).isEmpty, "Interrupted unverified download must be removed")
      }
      print("PASS interrupted selection recovers before update startup")
    }
    do {
      let (_, controller) = try fixture()
      let transaction = try begin(controller)
      do {
        _ = try begin(controller)
        fatalError("A pending selection must block another transaction")
      } catch {}
      transaction.commit()
      try expect(UserDefaults.standard.data(forKey: pendingKey) == nil, "Commit removes pending marker")
      print("PASS pending transaction cannot be overwritten and successful commit clears it")
    }
    do {
      let (db, controller) = try fixture(embeddedMetadata: ["branch": "embedded"])
      try db.databaseQueue.sync {
        _ = try db.execute(sql: "INSERT INTO json_data VALUES ('unrelated', '{\"keep\":true}', 1, 'project');", withArgs: nil)
      }
      let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
      try controller.setUpdateRequestHeadersOverride(bundledHeaders)
      try expect(try selected(db) == nil, "The real Expo launcher must reject an embedded manifest excluded by stale branch filters")
      try prepareBundled(transaction)
      try expect(try selected(db)?.updateId == embeddedID, "Clearing stale metadata must allow exactly the signed embedded UUID")
      try db.databaseQueue.sync {
        try expect(try db.execute(sql: "SELECT key FROM json_data WHERE scope_key = 'project' AND key IN ('manifestFilters', 'serverDefinedHeaders');", withArgs: nil).isEmpty, "Bundled selection must clear current-scope server metadata")
        try expect(try db.execute(sql: "SELECT key FROM json_data WHERE scope_key = 'other-project' OR key = 'unrelated';", withArgs: nil).count == 2, "Other scopes and unrelated metadata must remain untouched")
        let embedded = try db.update(withId: embeddedID, config: UpdatesConfig.current)!
        try expect(embedded.commitTime.timeIntervalSince1970 == 100 && embedded.status == 5, "Bundled selection must not alter signed timestamp or embedded status")
        try expect(embedded.url == updateURL && embedded.requestHeaders == bundledHeaders, "Embedded binding must retain the original URL and bundled-only headers")
        try expect(try db.update(withId: aID, config: UpdatesConfig.current) != nil, "The transaction must preserve cached drafts")
      }
      transaction.commit()
      DraftsUpdateTransaction.recoverPendingSelection()
      try expect(controller.requestHeaders == bundledHeaders, "A committed bundled choice must not revert on startup recovery")
      let reopened = UpdatesDatabase()
      try reopened.databaseQueue.sync { try reopened.openDatabase(inDirectory: controller.updatesDirectory!, logger: UpdatesLogger()) }
      try expect(try selected(reopened)?.updateId == embeddedID, "Reopening the persistent cache must still select the exact embedded UUID without fetching")
      print("PASS bundled selection clears stale filters, keeps cache bindings, and survives database reopening")
    }
    do {
      let (db, controller) = try fixture(embeddedTime: 900_000)
      let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
      try controller.setUpdateRequestHeadersOverride(bundledHeaders)
      try prepareBundled(transaction)
      transaction.commit()
      let embedded = try db.databaseQueue.sync { try db.update(withId: embeddedID, config: UpdatesConfig.current)! }
      let remote = try db.databaseQueue.sync { try db.update(withId: aID, config: UpdatesConfig.current)! }
      try expect(remote.commitTime < embedded.commitTime, "The regression fixture must publish the remote draft before the embedded bundle")
      let returnToDraft = try begin(controller, expected: aID, headers: headersA)
      try controller.setUpdateRequestHeadersOverride(headersA)
      let loader = LoaderSelectionPolicyFilterAware(config: UpdatesConfig.current)
      try expect(loader.shouldLoadNewUpdate(remote, withLaunchedUpdate: embedded, filters: nil), "Expo's actual loader must permit an older remote update after the bundled header selection")
      let unboundEmbedded = Update(embeddedID, scopeKey: "project", runtimeVersion: "runtime", commitTime: embedded.commitTime)
      try expect(!loader.shouldLoadNewUpdate(remote, withLaunchedUpdate: unboundEmbedded, filters: nil), "The test must detect the legacy nil-header regression that blocks older updates")
      let _: Void = try wait { returnToDraft.prepareLaunch(expectedID: aID.uuidString.lowercased(), completion: $0) }
      try expect(try selected(db)?.updateId == aID, "Switching back must select the exact older cached draft")
      returnToDraft.commit()
      print("PASS Expo's real loader allows returning from a newer bundle to an older published draft")
    }
    do {
      for mismatch in ["uuid", "malformed-uuid", "runtime", "source", "headers"] {
        let (db, controller) = try fixture()
        if mismatch == "runtime" || mismatch == "source" {
          controller.embedded = Update(embeddedID, scopeKey: "project", runtimeVersion: mismatch == "runtime" ? "other-runtime" : "runtime", url: mismatch == "source" ? URL(string: "https://u.expo.dev/other-project")! : updateURL, requestHeaders: bundledHeaders)
        }
        let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
        if mismatch != "headers" { try controller.setUpdateRequestHeadersOverride(bundledHeaders) }
        let expected = mismatch == "uuid" ? aID.uuidString : mismatch == "malformed-uuid" ? "not-a-uuid" : embeddedID.uuidString
        try expectFailure({ try prepareBundled(transaction, expectedID: expected) }, "Bundled selection must reject \(mismatch) mismatch")
        try assertOriginalMetadata(db)
        try controller.setUpdateRequestHeadersOverride(headersA)
        try rollback(transaction)
        try expect(controller.requestHeaders == headersA, "A rejected bundled selection must leave the previous request headers active")
      }
      print("PASS embedded UUID, runtime, source URL, and original-header guards reject mismatched selections")
    }
    do {
      let (db, controller) = try fixture()
      try db.databaseQueue.sync {
        _ = try db.execute(sql: "DELETE FROM updates WHERE id = ?1;", withArgs: [embeddedID])
        try insert(db, id: cID, headers: bundledHeaders, time: 800_000)
      }
      let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
      try controller.setUpdateRequestHeadersOverride(bundledHeaders)
      try expectFailure({ try prepareBundled(transaction) }, "Preflight must reject a competing cached UUID selected by Expo")
      try controller.setUpdateRequestHeadersOverride(headersA)
      try rollback(transaction)
      try assertOriginalMetadata(db)
      try db.databaseQueue.sync {
        try expect(try db.update(withId: embeddedID, config: UpdatesConfig.current) == nil, "Rollback must remove only the newly registered embedded row")
        try expect(try db.update(withId: aID, config: UpdatesConfig.current) != nil, "Rollback must preserve the previously running draft")
        try expect(try db.update(withId: cID, config: UpdatesConfig.current) != nil, "Rollback must preserve a pre-existing competing cache row")
      }
      try expect(try selected(db)?.updateId == aID, "The previous header selection must remain launchable after failure rollback")
      print("PASS unexpected launcher candidate rolls back new embedded registration and restores prior selection")
    }
    do {
      let (db, controller) = try fixture()
      try db.databaseQueue.sync {
        _ = try db.execute(sql: "DELETE FROM updates WHERE id = ?1;", withArgs: [embeddedID])
        _ = try db.execute(sql: "CREATE TRIGGER reject_metadata_delete BEFORE DELETE ON json_data BEGIN SELECT RAISE(ABORT, 'injected failure'); END;", withArgs: nil)
      }
      let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
      try controller.setUpdateRequestHeadersOverride(bundledHeaders)
      try expectFailure({ try prepareBundled(transaction) }, "A database write failure must fail bundled preparation")
      try db.databaseQueue.sync {
        try expect(try db.update(withId: embeddedID, config: UpdatesConfig.current) == nil, "A failed metadata transaction must not retain the newly inserted embedded row")
        _ = try db.execute(sql: "DROP TRIGGER reject_metadata_delete;", withArgs: nil)
      }
      try assertOriginalMetadata(db)
      try controller.setUpdateRequestHeadersOverride(headersA)
      try rollback(transaction)
      try expect(try selected(db)?.updateId == aID, "A database failure must preserve a launchable prior draft")
      print("PASS embedded registration and metadata clearing roll back atomically on SQLite failure")
    }
    do {
      let (db, controller) = try fixture()
      try db.databaseQueue.sync { _ = try db.execute(sql: "DELETE FROM updates WHERE id = ?1;", withArgs: [embeddedID]) }
      let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
      try controller.setUpdateRequestHeadersOverride(bundledHeaders)
      try prepareBundled(transaction)
      try db.databaseQueue.sync {
        let registered = try db.update(withId: embeddedID, config: UpdatesConfig.current)!
        try expect(registered.status == 5 && registered.commitTime == controller.embedded?.commitTime, "A reaped embedded row must be registered with its actual signed status and timestamp")
      }
      // Simulate process termination after preparation, before a verified relaunch.
      DraftsUpdateTransaction.recoverPendingSelection()
      try expect(controller.requestHeaders == headersA, "Cold recovery must restore previous persisted request headers")
      try expect(UserDefaults.standard.data(forKey: pendingKey) == nil, "Completed cold recovery must clear the durable selection marker")
      try assertOriginalMetadata(db)
      try db.databaseQueue.sync {
        try expect(try db.update(withId: embeddedID, config: UpdatesConfig.current) == nil, "Cold recovery must remove the embedded row inserted by the interrupted attempt")
        try expect(try db.update(withId: aID, config: UpdatesConfig.current) != nil, "Cold recovery must preserve the previous cached draft")
      }
      try expect(try selected(db)?.updateId == aID, "Cold recovery must make the previous draft launchable again")
      print("PASS a missing embedded row is registered exactly, and interrupted bundled switching restores the prior cache")
    }
    do {
      for cachedEmbedded in [false, true] {
        let (db, controller) = try fixture()
        // Native startup may have registered this row under a persisted draft
        // selection. The exact signed object must still be accepted and rebound.
        controller.embedded = Update(embeddedID, scopeKey: "project", runtimeVersion: "runtime", url: updateURL, requestHeaders: headersA)
        try db.databaseQueue.sync {
          if cachedEmbedded {
            let inherited = String(data: try JSONSerialization.data(withJSONObject: headersA, options: .sortedKeys), encoding: .utf8)!
            _ = try db.execute(sql: "UPDATE updates SET headers = ?1 WHERE id = ?2;", withArgs: [inherited, embeddedID])
          } else {
            _ = try db.execute(sql: "DELETE FROM updates WHERE id = ?1;", withArgs: [embeddedID])
          }
          _ = try db.execute(sql: "CREATE TABLE binding_observations (headers TEXT, url TEXT);", withArgs: nil)
          // Observe inside the first transaction, before metadata disappears and
          // before prepareLaunch's later idempotent binding can hide a gap.
          _ = try db.execute(sql: """
            CREATE TRIGGER observe_embedded_binding BEFORE DELETE ON json_data
            WHEN OLD.scope_key = 'project' AND OLD.key IN ('manifestFilters', 'serverDefinedHeaders')
            BEGIN
              INSERT INTO binding_observations (headers, url)
                SELECT headers, url FROM updates WHERE lower(hex(id)) = '00000000000040008000000000000001';
              SELECT CASE WHEN NOT EXISTS (
                SELECT 1 FROM updates WHERE lower(hex(id)) = '00000000000040008000000000000001'
                  AND json_extract(headers, '$.expo-drafts-selection') = 'embedded'
                  AND url = 'https://u.expo.dev/project'
              ) THEN RAISE(ABORT, 'embedded row was not bound before clearing metadata') END;
            END;
            """, withArgs: nil)
        }
        let transaction = try begin(controller, expected: embeddedID, headers: bundledHeaders)
        try controller.setUpdateRequestHeadersOverride(bundledHeaders)
        try prepareBundled(transaction)
        try db.databaseQueue.sync {
          let observations = try db.execute(sql: "SELECT headers, url FROM binding_observations;", withArgs: nil)
          try expect(observations.count == 2, "Both metadata deletions must observe an already-bound embedded row in their transaction")
          for row in observations {
            let headers = try JSONDecoder().decode([String: String].self, from: Data((row["headers"] as! String).utf8))
            try expect(headers == bundledHeaders && row["url"] as? String == updateURL.absoluteString, "Metadata clearing must never commit alongside inherited draft headers")
          }
          _ = try db.execute(sql: "DROP TRIGGER observe_embedded_binding;", withArgs: nil)
        }
        DraftsUpdateTransaction.recoverPendingSelection()
        try assertOriginalMetadata(db)
        try expect(controller.requestHeaders == headersA, "Interrupted preparation must restore prior persisted headers")
        try db.databaseQueue.sync {
          let embedded = try db.update(withId: embeddedID, config: UpdatesConfig.current)
          if cachedEmbedded {
            try expect(embedded?.requestHeaders == headersA, "Recovery must restore a pre-existing embedded row's inherited binding")
          } else {
            try expect(embedded == nil, "Recovery must remove the embedded row registered by the interrupted attempt")
          }
          try expect(try db.update(withId: aID, config: UpdatesConfig.current) != nil, "Recovery must retain the pre-existing downloaded draft")
        }
      }
      print("PASS inherited embedded headers are rebound atomically with metadata clearing and recover correctly")
    }
    print("11 iOS transaction test groups passed using real SQLite and Expo selection policies")
  }
}
