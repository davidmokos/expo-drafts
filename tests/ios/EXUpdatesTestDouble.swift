// A small EXUpdates API double backed by real SQLite. Tests execute the production
// transaction adapter's SQL; only Expo's platform-specific controller is substituted.
import Foundation
import SQLite3

public final class UpdatesLogger { public init() {} }
public final class UpdatesConfig: NSObject {
  public var scopeKey: String
  public var updateUrl: URL
  public var runtimeVersion: String
  public var requestHeaders: [String: String]
  public let originalEmbeddedUpdateUrl: URL
  public let originalEmbeddedRequestHeaders: [String: String]
  public init(scopeKey: String, updateUrl: URL, runtimeVersion: String, requestHeaders: [String: String]) {
    self.scopeKey = scopeKey; self.updateUrl = updateUrl; self.runtimeVersion = runtimeVersion; self.requestHeaders = requestHeaders
    originalEmbeddedUpdateUrl = updateUrl
    originalEmbeddedRequestHeaders = ["expo-channel-name": "drafts", "expo-drafts-selection": "embedded"]
  }
  public static var current = UpdatesConfig(scopeKey: "project", updateUrl: URL(string: "https://u.expo.dev/project")!, runtimeVersion: "runtime", requestHeaders: [:])
  public static func configWithExpoPlist(mergingOtherDictionary: [String: Any]?) throws -> UpdatesConfig { current }
}
public final class TestManifest {
  public let metadata: [String: Any]?
  public init(_ metadata: [String: Any]?) { self.metadata = metadata }
  public func getMetadata() -> [String: Any]? { metadata }
}
public final class RollBackToEmbeddedUpdateDirective: NSObject {
  public var commitTime = Date()
}
public final class Update: NSObject {
  public let updateId: UUID
  public let scopeKey: String?
  public let runtimeVersion: String
  public var commitTime: Date
  public let url: URL?
  public let requestHeaders: [String: String]?
  public let manifest: TestManifest
  public let status: Int
  public init(_ id: UUID, scopeKey: String, runtimeVersion: String, commitTime: Date = Date(timeIntervalSince1970: 100), url: URL? = nil, requestHeaders: [String: String]? = nil, metadata: [String: Any]? = nil, status: Int = 5) {
    updateId = id; self.scopeKey = scopeKey; self.runtimeVersion = runtimeVersion; self.commitTime = commitTime
    self.url = url; self.requestHeaders = requestHeaders; self.manifest = TestManifest(metadata); self.status = status
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
    _ = try execute(sql: "CREATE TABLE IF NOT EXISTS updates (id BLOB PRIMARY KEY, scope_key TEXT, runtime_version TEXT, commit_time INTEGER, url TEXT, headers TEXT, status INTEGER DEFAULT 1, metadata TEXT);", withArgs: nil)
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
    guard let row = try execute(sql: "SELECT * FROM updates WHERE id = ?1;", withArgs: [id]).first,
      let scope = row["scope_key"] as? String, let runtime = row["runtime_version"] as? String else { return nil }
    let headers = (row["headers"] as? String).flatMap { try? JSONDecoder().decode([String: String].self, from: Data($0.utf8)) }
    let metadata = (row["metadata"] as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
    return Update(id, scopeKey: scope, runtimeVersion: runtime, commitTime: Date(timeIntervalSince1970: ((row["commit_time"] as? NSNumber)?.doubleValue ?? 0) / 1000), url: (row["url"] as? String).flatMap(URL.init(string:)), requestHeaders: headers, metadata: metadata, status: (row["status"] as? NSNumber)?.intValue ?? 1)
  }
  public func addUpdate(_ update: Update, config: UpdatesConfig) throws {
    let headers = String(data: try JSONSerialization.data(withJSONObject: config.requestHeaders, options: .sortedKeys), encoding: .utf8)!
    let metadata = try update.manifest.metadata.map { String(data: try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys), encoding: .utf8)! }
    _ = try execute(sql: "INSERT INTO updates (id, scope_key, runtime_version, commit_time, url, headers, status, metadata) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);", withArgs: [update.updateId, update.scopeKey, update.runtimeVersion, Int64(update.commitTime.timeIntervalSince1970 * 1000), config.updateUrl.absoluteString, headers, update.status, metadata])
  }
}
public enum SelectionPolicyFactory {
  public static func filterAwarePolicy(withRuntimeVersion runtimeVersion: String, config: UpdatesConfig) -> LauncherSelectionPolicy {
    LauncherSelectionPolicyFilterAware(runtimeVersion: runtimeVersion, config: config)
  }
}
public enum AppLauncherWithDatabase {
  public static func launchableUpdate(withConfig config: UpdatesConfig, database: UpdatesDatabase, selectionPolicy: LauncherSelectionPolicy, completionQueue: DispatchQueue, completion: @escaping (Error?, Update?) -> Void) {
    database.databaseQueue.async {
      do {
        let rows = try database.execute(sql: "SELECT lower(hex(id)) AS id_hex FROM updates WHERE scope_key = ?1 AND status IN (1, 5, 6);", withArgs: [config.scopeKey])
        let updates: [Update] = try rows.compactMap { row in
          guard let hex = row["id_hex"] as? String else { return nil }
          let chars = Array(hex)
          let id = [String(chars[0..<8]), String(chars[8..<12]), String(chars[12..<16]), String(chars[16..<20]), String(chars[20..<32])].joined(separator: "-")
          return try database.update(withId: UUID(uuidString: id)!, config: config)
        }
        let text = try database.execute(sql: "SELECT value FROM json_data WHERE scope_key = ?1 AND key = 'manifestFilters';", withArgs: [config.scopeKey]).first?["value"] as? String
        let filters = try text.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? nil
        // Compile the installed SDK's actual policies, including header and filter
        // matching; this test double supplies only database/model integration.
        let selected = selectionPolicy.launchableUpdate(fromUpdates: updates, filters: filters)
        completionQueue.async { completion(nil, selected) }
      } catch { completionQueue.async { completion(error, nil) } }
    }
  }
}
