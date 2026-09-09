import Foundation
import EXUpdates

/// SDK 57 adapter. Expo's public database API stores one row per update UUID, including
/// the request headers that first fetched it. A rejected fetch also persists manifest
/// filters. Keep these changes transactional for the preview picker. This adapter uses
/// the SDK 57 `updates` and `json_data` columns and must be reviewed when upgrading Expo.
final class DraftsUpdateTransaction {
  private static let pendingKey = "expo-drafts.pending-selection-v1"
  private let db: UpdatesDatabase
  private let config: UpdatesConfig
  private let snapshot: Snapshot
  private let embeddedUpdate: Update?

  private struct Metadata: Codable {
    let key: String
    let value: String
    let lastUpdated: Int64
  }

  private struct Snapshot: Codable {
    let scopeKey: String
    let previousHeaders: [String: String]
    let nextHeaders: [String: String]
    let existingIDs: [String]
    let metadata: [Metadata]
    let expectedID: String
    let expectedOriginalURL: String?
    let expectedOriginalHeaders: String?
    let embeddedID: String?
    let embeddedCommitTime: Double?
  }

  private init(database: UpdatesDatabase, config: UpdatesConfig, snapshot: Snapshot, embeddedUpdate: Update?) {
    self.config = config
    self.snapshot = snapshot
    self.embeddedUpdate = embeddedUpdate
    // Keep the connection used to take the snapshot. Its queue serializes our reads/writes.
    self.db = database
  }

  static func begin(
    controller: EnabledAppController,
    expectedID: String,
    nextHeaders: [String: String],
    completion: @escaping (Result<DraftsUpdateTransaction, Error>) -> Void
  ) {
    guard UserDefaults.standard.data(forKey: pendingKey) == nil else {
      completion(.failure(DraftsError.message("A previous draft download needs recovery. Close and reopen the app before switching again.")))
      return
    }
    guard let directory = controller.updatesDirectory else {
      completion(.failure(DraftsError.message("The updates cache is unavailable.")))
      return
    }
    do {
      let config = try UpdatesConfig.configWithExpoPlist(mergingOtherDictionary: nil)
      let previousHeaders = controller.requestHeaders ?? [:]
      let embedded = controller.getEmbeddedUpdate()
      let database = UpdatesDatabase()
      database.databaseQueue.async {
        let result: Result<DraftsUpdateTransaction, Error> = Result {
          try database.openDatabase(inDirectory: directory, logger: UpdatesLogger())
          _ = try database.execute(sql: "PRAGMA busy_timeout = 5000;", withArgs: nil)
          _ = try database.execute(sql: "BEGIN IMMEDIATE;", withArgs: nil)
          do {
            let ids = try database.execute(sql: "SELECT lower(hex(id)) AS id_hex FROM updates WHERE scope_key = ?1;", withArgs: [config.scopeKey])
              .compactMap { $0["id_hex"] as? String }
            let metadata = try readMetadata(database, scopeKey: config.scopeKey)
            let expected = try database.execute(sql: "SELECT url, headers FROM updates WHERE id = ?1 AND scope_key = ?2;", withArgs: [UUID(uuidString: expectedID), config.scopeKey]).first
            let snapshot = Snapshot(
              scopeKey: config.scopeKey, previousHeaders: previousHeaders, nextHeaders: nextHeaders,
              existingIDs: ids, metadata: metadata, expectedID: expectedID,
              expectedOriginalURL: expected?["url"] as? String,
              expectedOriginalHeaders: expected?["headers"] as? String,
              embeddedID: embedded?.updateId.uuidString,
              embeddedCommitTime: embedded?.commitTime.timeIntervalSince1970
            )
            _ = try database.execute(sql: "COMMIT;", withArgs: nil)
            UserDefaults.standard.set(try JSONEncoder().encode(snapshot), forKey: pendingKey)
            return DraftsUpdateTransaction(database: database, config: config, snapshot: snapshot, embeddedUpdate: embedded)
          } catch {
            _ = try? database.execute(sql: "ROLLBACK;", withArgs: nil)
            throw error
          }
        }
        DispatchQueue.main.async { completion(result) }
      }
    } catch { completion(.failure(error)) }
  }

  /// Rebind a previously downloaded UUID to this selection, then ask Expo's actual
  /// launcher policy to verify it will choose precisely that UUID before reloading.
  func prepareLaunch(expectedID: String, completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      let launchConfig = try UpdatesConfig.configWithExpoPlist(mergingOtherDictionary: nil)
      let headers = String(data: try JSONSerialization.data(withJSONObject: snapshot.nextHeaders, options: .sortedKeys), encoding: .utf8)!
      db.databaseQueue.async {
        do {
          _ = try self.db.execute(sql: "BEGIN IMMEDIATE;", withArgs: nil)
          guard let update = try self.db.update(withId: UUID(uuidString: expectedID)!, config: launchConfig),
            update.runtimeVersion == launchConfig.runtimeVersion, update.scopeKey == launchConfig.scopeKey else {
            throw DraftsError.message("The downloaded update does not match this build's native runtime and project.")
          }
          _ = try self.db.execute(sql: "UPDATE updates SET url = ?1, headers = ?2 WHERE id = ?3 AND scope_key = ?4;", withArgs: [launchConfig.updateUrl.absoluteString, headers, update.updateId, launchConfig.scopeKey])
          _ = try self.db.execute(sql: "COMMIT;", withArgs: nil)
          AppLauncherWithDatabase.launchableUpdate(
            withConfig: launchConfig, database: self.db,
            selectionPolicy: SelectionPolicyFactory.filterAwarePolicy(withRuntimeVersion: launchConfig.runtimeVersion, config: launchConfig),
            completionQueue: .main
          ) { error, update in
            if let error { completion(.failure(error)); return }
            guard update?.updateId.uuidString.lowercased() == expectedID.lowercased() else {
              completion(.failure(DraftsError.message("Expo could not select this exact update safely. Refresh the catalog and try again.")))
              return
            }
            completion(.success(()))
          }
        } catch {
          _ = try? self.db.execute(sql: "ROLLBACK;", withArgs: nil)
          DispatchQueue.main.async { completion(.failure(error)) }
        }
      }
    } catch { completion(.failure(error)) }
  }

  /// Select the signed bundle without a network request. The caller first restores
  /// the original request headers; keeping that binding lets an older published
  /// draft load again when the user later selects its distinct request headers.
  func prepareEmbeddedLaunch(expectedID: String, completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      let launchConfig = try UpdatesConfig.configWithExpoPlist(mergingOtherDictionary: nil)
      guard let expectedUUID = UUID(uuidString: expectedID),
        UUID(uuidString: snapshot.expectedID) == expectedUUID,
        UUID(uuidString: snapshot.embeddedID ?? "") == expectedUUID,
        let embeddedUpdate, embeddedUpdate.updateId == expectedUUID,
        embeddedUpdate.scopeKey == launchConfig.scopeKey,
        snapshot.scopeKey == launchConfig.scopeKey,
        embeddedUpdate.runtimeVersion == launchConfig.runtimeVersion,
        embeddedUpdate.url == launchConfig.originalEmbeddedUpdateUrl,
        launchConfig.updateUrl == launchConfig.originalEmbeddedUpdateUrl else {
        throw DraftsError.message("The bundled update does not match this native build. Reopen the app and try again.")
      }
      guard snapshot.nextHeaders == launchConfig.originalEmbeddedRequestHeaders,
        launchConfig.requestHeaders == snapshot.nextHeaders,
        snapshot.nextHeaders["expo-drafts-selection"] == "embedded" else {
        throw DraftsError.message("Restore this build's bundled update headers before running its bundled version.")
      }
      let headers = String(data: try JSONSerialization.data(withJSONObject: snapshot.nextHeaders, options: .sortedKeys), encoding: .utf8)!
      db.databaseQueue.async {
        do {
          _ = try self.db.execute(sql: "BEGIN IMMEDIATE;", withArgs: nil)
          // Expo can reap the embedded row while a downloaded update is running.
          // Register only the signed bundle's actual UUID, never a catalog update.
          if try self.db.update(withId: expectedUUID, config: launchConfig) == nil {
            try self.db.addUpdate(embeddedUpdate, config: launchConfig)
          }
          // An embedded cache row can inherit a previous PR's persisted headers.
          // Bind registration atomically so interrupted recovery can remove it.
          _ = try self.db.execute(sql: "UPDATE updates SET url = ?1, headers = ?2 WHERE id = ?3 AND scope_key = ?4;", withArgs: [launchConfig.updateUrl.absoluteString, headers, expectedUUID, launchConfig.scopeKey])
          _ = try self.db.execute(sql: "DELETE FROM json_data WHERE scope_key = ?1 AND key IN ('manifestFilters', 'serverDefinedHeaders');", withArgs: [launchConfig.scopeKey])
          _ = try self.db.execute(sql: "COMMIT;", withArgs: nil)
          DispatchQueue.main.async {
            self.prepareLaunch(expectedID: expectedID, completion: completion)
          }
        } catch {
          _ = try? self.db.execute(sql: "ROLLBACK;", withArgs: nil)
          DispatchQueue.main.async { completion(.failure(error)) }
        }
      }
    } catch { completion(.failure(error)) }
  }

  func commit() {
    UserDefaults.standard.removeObject(forKey: Self.pendingKey)
  }

  func rollback(completion: @escaping (Error?) -> Void) {
    db.databaseQueue.async {
      var failure: Error?
      do { try Self.restoreDatabase(self.db, snapshot: self.snapshot) }
      catch { failure = error }
      DispatchQueue.main.async {
        if let timestamp = self.snapshot.embeddedCommitTime {
          self.embeddedUpdate?.commitTime = Date(timeIntervalSince1970: timestamp)
        }
        completion(failure)
      }
    }
  }

  /// Runs before Expo starts the update loader. A terminated download must not leave
  /// its pending headers or manifest filters active on the next application launch.
  static func recoverPendingSelection() {
    guard let data = UserDefaults.standard.data(forKey: pendingKey),
      let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
    AppController.initializeWithoutStarting()
    guard let controller = AppController.sharedInstance as? EnabledAppController,
      let directory = controller.updatesDirectory else { return }
    do {
      try controller.setUpdateRequestHeadersOverride(snapshot.previousHeaders)
      let database = UpdatesDatabase()
      try database.databaseQueue.sync {
        try database.openDatabase(inDirectory: directory, logger: UpdatesLogger())
        _ = try database.execute(sql: "PRAGMA busy_timeout = 5000;", withArgs: nil)
        try restoreDatabase(database, snapshot: snapshot)
      }
      if let timestamp = snapshot.embeddedCommitTime {
        controller.getEmbeddedUpdate()?.commitTime = Date(timeIntervalSince1970: timestamp)
      }
      UserDefaults.standard.removeObject(forKey: pendingKey)
    } catch {
      // Leave the marker to retry next launch. The safe previous headers are restored
      // before touching the database, so a pending remote selection stays isolated.
      NSLog("expo-drafts could not finish recovering a pending selection: %@", error.localizedDescription)
    }
  }

  private static func readMetadata(_ database: UpdatesDatabase, scopeKey: String) throws -> [Metadata] {
    try database.execute(sql: "SELECT key, value, last_updated FROM json_data WHERE scope_key = ?1 AND key IN ('manifestFilters', 'serverDefinedHeaders');", withArgs: [scopeKey]).compactMap { row in
      guard let key = row["key"] as? String, let value = row["value"] as? String,
        let updated = row["last_updated"] as? NSNumber else { return nil }
      return Metadata(key: key, value: value, lastUpdated: updated.int64Value)
    }
  }

  private static func restoreDatabase(_ database: UpdatesDatabase, snapshot: Snapshot) throws {
    _ = try database.execute(sql: "BEGIN IMMEDIATE;", withArgs: nil)
    do {
      _ = try database.execute(sql: "DELETE FROM json_data WHERE scope_key = ?1 AND key IN ('manifestFilters', 'serverDefinedHeaders');", withArgs: [snapshot.scopeKey])
      for row in snapshot.metadata {
        _ = try database.execute(sql: "INSERT INTO json_data (key, value, last_updated, scope_key) VALUES (?1, ?2, ?3, ?4);", withArgs: [row.key, row.value, row.lastUpdated, snapshot.scopeKey])
      }
      // Delete only rows created by this attempt. Never remove an update that was
      // already cached or running when the user began switching.
      let existing = Set(snapshot.existingIDs)
      let rows = try database.execute(sql: "SELECT id, lower(hex(id)) AS id_hex, headers FROM updates WHERE scope_key = ?1;", withArgs: [snapshot.scopeKey])
      for row in rows {
        guard let idHex = row["id_hex"] as? String, !existing.contains(idHex),
          let headersText = row["headers"] as? String, let data = headersText.data(using: .utf8),
          let headers = try? JSONDecoder().decode([String: String].self, from: data), headers == snapshot.nextHeaders else { continue }
        _ = try database.execute(sql: "DELETE FROM updates WHERE lower(hex(id)) = ?1 AND scope_key = ?2;", withArgs: [idHex, snapshot.scopeKey])
      }
      let expectedHex = snapshot.expectedID.replacingOccurrences(of: "-", with: "").lowercased()
      if existing.contains(expectedHex) {
        _ = try database.execute(sql: "UPDATE updates SET url = ?1, headers = ?2 WHERE id = ?3 AND scope_key = ?4;", withArgs: [snapshot.expectedOriginalURL, snapshot.expectedOriginalHeaders, UUID(uuidString: snapshot.expectedID), snapshot.scopeKey])
      }
      if let id = snapshot.embeddedID, let timestamp = snapshot.embeddedCommitTime {
        _ = try database.execute(sql: "UPDATE updates SET commit_time = ?1 WHERE id = ?2 AND scope_key = ?3;", withArgs: [Int64(timestamp * 1000), UUID(uuidString: id), snapshot.scopeKey])
      }
      _ = try database.execute(sql: "COMMIT;", withArgs: nil)
    } catch {
      _ = try? database.execute(sql: "ROLLBACK;", withArgs: nil)
      throw error
    }
  }
}
