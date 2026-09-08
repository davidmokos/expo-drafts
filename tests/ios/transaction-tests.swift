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

  static func fixture() throws -> (UpdatesDatabase, EnabledAppController) {
    UserDefaults.standard.removeObject(forKey: pendingKey)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("expo-drafts-transaction-\(UUID())")
    let db = UpdatesDatabase()
    try db.databaseQueue.sync {
      try db.openDatabase(inDirectory: directory, logger: UpdatesLogger())
      try insert(db, id: embeddedID, headers: ["expo-channel-name": "drafts", "expo-drafts-selection": "embedded"], time: 100_000)
      try insert(db, id: aID, headers: headersA, time: 200_000)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('manifestFilters', '{\"branch\":\"a\"}', 1, 'project');", withArgs: nil)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('serverDefinedHeaders', '{\"token\":\"a\"}', 1, 'project');", withArgs: nil)
      _ = try db.execute(sql: "INSERT INTO json_data VALUES ('manifestFilters', '{\"other\":true}', 1, 'other-project');", withArgs: nil)
    }
    UpdatesConfig.current.requestHeaders = headersA
    let controller = EnabledAppController(directory: directory, headers: headersA, embedded: Update(embeddedID, scopeKey: "project", runtimeVersion: "runtime", commitTime: Date(timeIntervalSince1970: 100)))
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
    print("4 iOS transaction tests passed using real SQLite")
  }
}
