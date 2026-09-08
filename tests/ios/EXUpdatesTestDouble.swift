// A small EXUpdates API double backed by real SQLite. Tests execute the production
// transaction adapter's SQL; only Expo's platform-specific controller is substituted.
import Foundation
import SQLite3

public final class UpdatesLogger { public init() {} }
public struct UpdatesConfig {
  public var scopeKey: String
  public var updateUrl: URL
  public var runtimeVersion: String
  public var requestHeaders: [String: String]
  public static var current = UpdatesConfig(scopeKey: "project", updateUrl: URL(string: "https://u.expo.dev/project")!, runtimeVersion: "runtime", requestHeaders: [:])
  public static func configWithExpoPlist(mergingOtherDictionary: [String: Any]?) throws -> UpdatesConfig { current }
}
public final class Update {
  public let updateId: UUID
  public let scopeKey: String?
  public let runtimeVersion: String
  public var commitTime: Date
  public init(_ id: UUID, scopeKey: String, runtimeVersion: String, commitTime: Date = Date(timeIntervalSince1970: 100)) {
    updateId = id; self.scopeKey = scopeKey; self.runtimeVersion = runtimeVersion; self.commitTime = commitTime
  }
}
public final class EnabledAppController {
  public var updatesDirectory: URL?
  public var requestHeaders: [String: String]?
  public var embedded: Update?
  public init(directory: URL, headers: [String: String], embedded: Update?) {
    updatesDirectory = directory; requestHeaders = headers; self.embedded = embedded
  }
  public func getEmbeddedUpdate() -> Update? { embedded }
  public func setUpdateRequestHeadersOverride(_ headers: [String: String]?) throws {
    requestHeaders = headers; UpdatesConfig.current.requestHeaders = headers ?? [:]
  }
}
public enum AppController {
  public static var sharedInstance: AnyObject = NSObject()
  public static var initialized = false
  public static func initializeWithoutStarting() { initialized = true }
}

public final class UpdatesDatabase {
  public let databaseQueue = DispatchQueue(label: "drafts.test.database")
  private var handle: OpaquePointer?
  public init() {}
  deinit { sqlite3_close(handle) }
  public func openDatabase(inDirectory directory: URL, logger: UpdatesLogger) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard sqlite3_open(directory.appendingPathComponent("test.sqlite").path, &handle) == SQLITE_OK else { throw dbError() }
    _ = try execute(sql: "CREATE TABLE IF NOT EXISTS updates (id BLOB PRIMARY KEY, scope_key TEXT, runtime_version TEXT, commit_time INTEGER, url TEXT, headers TEXT, status INTEGER DEFAULT 1);", withArgs: nil)
    _ = try execute(sql: "CREATE TABLE IF NOT EXISTS json_data (key TEXT, value TEXT, last_updated INTEGER, scope_key TEXT);", withArgs: nil)
  }
  private func dbError() -> NSError { NSError(domain: "sqlite", code: Int(sqlite3_errcode(handle)), userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(handle))]) }
  public func execute(sql: String, withArgs args: [Any?]?) throws -> [[String: Any?]] {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw dbError() }
    defer { sqlite3_finalize(statement) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    for (offset, value) in (args ?? []).enumerated() {
      let index = Int32(offset + 1)
      if let id = value as? UUID {
        var bytes = id.uuid
        _ = withUnsafeBytes(of: &bytes) { sqlite3_bind_blob(statement, index, $0.baseAddress, 16, transient) }
      } else if let text = value as? String {
        sqlite3_bind_text(statement, index, text, -1, transient)
      } else if let number = value as? NSNumber {
        sqlite3_bind_int64(statement, index, number.int64Value)
      } else { sqlite3_bind_null(statement, index) }
    }
    var rows: [[String: Any?]] = []
    while true {
      let status = sqlite3_step(statement)
      if status == SQLITE_DONE { return rows }
      guard status == SQLITE_ROW else { throw dbError() }
      var row: [String: Any?] = [:]
      for index in 0..<sqlite3_column_count(statement) {
        let name = String(cString: sqlite3_column_name(statement, index))
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: row[name] = NSNumber(value: sqlite3_column_int64(statement, index))
        case SQLITE_TEXT: row[name] = String(cString: sqlite3_column_text(statement, index))
        case SQLITE_BLOB: row[name] = Data(bytes: sqlite3_column_blob(statement, index)!, count: Int(sqlite3_column_bytes(statement, index)))
        default: row[name] = NSNull()
        }
      }
      rows.append(row)
    }
  }
  public func update(withId id: UUID, config: UpdatesConfig) throws -> Update? {
    guard let row = try execute(sql: "SELECT scope_key, runtime_version, commit_time FROM updates WHERE id = ?1;", withArgs: [id]).first,
      let scope = row["scope_key"] as? String, let runtime = row["runtime_version"] as? String else { return nil }
    return Update(id, scopeKey: scope, runtimeVersion: runtime, commitTime: Date(timeIntervalSince1970: ((row["commit_time"] as? NSNumber)?.doubleValue ?? 0) / 1000))
  }
}
public enum SelectionPolicyFactory {
  public static func filterAwarePolicy(withRuntimeVersion runtimeVersion: String, config: UpdatesConfig) -> String { runtimeVersion }
}
public enum AppLauncherWithDatabase {
  public static func launchableUpdate(withConfig config: UpdatesConfig, database: UpdatesDatabase, selectionPolicy: String, completionQueue: DispatchQueue, completion: @escaping (Error?, Update?) -> Void) {
    database.databaseQueue.async {
      do {
        let rows = try database.execute(sql: "SELECT lower(hex(id)) AS id_hex, headers, url FROM updates WHERE scope_key = ?1 AND runtime_version = ?2 AND status = 1 ORDER BY commit_time DESC;", withArgs: [config.scopeKey, config.runtimeVersion])
        let row = rows.first {
          guard let text = $0["headers"] as? String,
            let headers = try? JSONDecoder().decode([String: String].self, from: Data(text.utf8)) else { return false }
          return headers == config.requestHeaders && $0["url"] as? String == config.updateUrl.absoluteString
        }
        let selected: Update?
        if let hex = row?["id_hex"] as? String {
          let chars = Array(hex)
          let id = [String(chars[0..<8]), String(chars[8..<12]), String(chars[12..<16]), String(chars[16..<20]), String(chars[20..<32])].joined(separator: "-")
          selected = Update(UUID(uuidString: id)!, scopeKey: config.scopeKey, runtimeVersion: config.runtimeVersion)
        } else { selected = nil }
        completionQueue.async { completion(nil, selected) }
      } catch { completionQueue.async { completion(error, nil) } }
    }
  }
}
