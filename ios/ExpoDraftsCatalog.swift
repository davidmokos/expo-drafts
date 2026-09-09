import Foundation

struct DraftCatalog: Decodable {
  let schemaVersion: Int
  let projectId: String
  let generatedAt: String?
  let drafts: [DraftEntry]
}

struct DraftEntry: Decodable {
  let id: String
  let name: String
  let channel: String
  let branch: String?
  let message: String?
  let createdAt: String
  let gitCommitHash: String?
  let pullRequest: DraftPullRequest?
  let buildUrl: String?
  let updates: [DraftUpdate]

  var iosUpdate: DraftUpdate? { updates.first { $0.platform == "ios" } }

  var publicationDate: Date? { Self.parsePublicationDate(createdAt) }

  static func parsePublicationDate(_ text: String) -> Date? {
    if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
    return try? Date.ISO8601FormatStyle().parse(text)
  }

  static func newestFirst(_ entries: [DraftEntry]) -> [DraftEntry] {
    entries.enumerated().map { (entry: $0.element, date: $0.element.publicationDate, index: $0.offset) }
      .sorted { lhs, rhs in
        if lhs.date != rhs.date {
          guard let left = lhs.date else { return false }
          guard let right = rhs.date else { return true }
          return left > right
        }
        if lhs.entry.channel != rhs.entry.channel { return lhs.entry.channel < rhs.entry.channel }
        if lhs.entry.id != rhs.entry.id { return lhs.entry.id < rhs.entry.id }
        return lhs.index < rhs.index
      }
      .map(\.entry)
  }
}

struct DraftPullRequest: Decodable {
  let number: Int
  let url: String?
}

struct DraftUpdate: Decodable {
  let id: String
  let platform: String
  let runtimeVersion: String
}

enum DraftsError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self {
    case .message(let text): return text
    }
  }
}

extension URL {
  var isDraftsTrustedURL: Bool {
    guard let host, !host.isEmpty, user == nil, password == nil else { return false }
    if scheme == "https" { return true }
    #if targetEnvironment(simulator)
    return scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)
    #else
    return false
    #endif
  }
}
