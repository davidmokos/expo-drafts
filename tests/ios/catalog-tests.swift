import Foundation

@main
struct CatalogTests {
  static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() {
      throw NSError(domain: "catalog-test", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
  }

  static func entry(_ id: String, channel: String? = nil, at: String, name: String? = nil, runtime: String = "runtime") -> DraftEntry {
    DraftEntry(
      id: id, name: name ?? id, channel: channel ?? id, branch: nil, message: nil,
      createdAt: at, gitCommitHash: nil, pullRequest: nil, buildUrl: nil,
      updates: [DraftUpdate(id: id, platform: "ios", runtimeVersion: runtime)]
    )
  }

  static func ids(_ entries: [DraftEntry]) -> [String] {
    DraftEntry.newestFirst(entries).map(\.id)
  }

  static func main() throws {
    do {
      let whole = DraftEntry.parsePublicationDate("2026-09-09T12:00:00Z")
      try expect(whole != nil, "A UTC timestamp without fractional seconds must parse")
      try expect(whole == DraftEntry.parsePublicationDate("2026-09-09T14:00:00+02:00"), "Positive offsets must identify the same instant")
      try expect(whole == DraftEntry.parsePublicationDate("2026-09-09T07:00:00-05:00"), "Negative offsets must identify the same instant")
      try expect(whole == DraftEntry.parsePublicationDate("2026-09-09T12:00:00.000Z"), "Zero fractional seconds must equal whole seconds")
      try expect(DraftEntry.parsePublicationDate("2026-09-09T12:00:00.1Z") == DraftEntry.parsePublicationDate("2026-09-09T12:00:00.100Z"), "Equivalent fractional widths must identify the same instant")
      let fraction = entry("fraction", at: "2026-09-09T12:00:00.001Z").publicationDate
      try expect(fraction != nil && fraction! > whole!, "A millisecond publication must be newer than the whole second")
      print("PASS publication dates normalize time zones and fractional seconds")
    }

    do {
      let offset = entry("offset", at: "2026-09-09T14:00:00+02:00")
      let fraction = entry("fraction", at: "2026-09-09T12:00:00.001Z")
      let oldest = entry("oldest", at: "2026-09-09T11:59:59Z")
      let newest = entry("newest", at: "2026-09-09T07:00:01-05:00")
      try expect(ids([offset, oldest, newest, fraction]) == ["newest", "fraction", "offset", "oldest"], "Sort actual instants, not timestamp text")
      try expect(ids([fraction, newest, oldest, offset]) == ["newest", "fraction", "offset", "oldest"], "Input order must not affect unequal publication dates")
      let submillisecond = entry("submillisecond", at: "2026-09-09T12:00:00.0001Z")
      try expect(ids([offset, submillisecond, fraction]) == ["fraction", "submillisecond", "offset"], "Do not discard the fractional precision that determines publication order")
      print("PASS newest-first ordering uses actual publication instants across offsets and subsecond precision")
    }

    do {
      let a = entry("a", channel: "alpha", at: "2026-09-09T12:00:00Z")
      let b = entry("b", channel: "alpha", at: "2026-09-09T14:00:00.000+02:00")
      let c = entry("c", channel: "beta", at: "2026-09-09T07:00:00-05:00")
      try expect(ids([c, b, a]) == ["a", "b", "c"], "Equal instants use ascending channel then ID")
      try expect(ids([a, c, b]) == ["a", "b", "c"], "Equal-date order must remain deterministic across responses")
      let first = entry("duplicate", channel: "same", at: a.createdAt, name: "First response row")
      let second = entry("duplicate", channel: "same", at: b.createdAt, name: "Second response row")
      try expect(DraftEntry.newestFirst([first, second]).map(\.name) == [first.name, second.name], "Duplicate channel and ID preserve input order after equal dates")
      try expect(DraftEntry.newestFirst([second, first]).map(\.name) == [second.name, first.name], "Stable duplicate ordering must not introduce a name tie-breaker")
      print("PASS equal publication instants have deterministic channel/ID ties and stable duplicate rows")
    }

    do {
      for value in ["", "not-a-date", "2026-09-09", "2026-09-09T12:00:00"] {
        try expect(DraftEntry.parsePublicationDate(value) == nil, "Invalid or incomplete timestamp must remain unknown: \(value)")
        try expect(entry("invalid", at: value).publicationDate == nil, "The entry must expose an unknown publication date")
      }
      let invalidA = entry("invalid-a", channel: "alpha", at: "not-a-date")
      let invalidZ = entry("invalid-z", channel: "zeta", at: "")
      let validOld = entry("valid-old", at: "1970-01-01T00:00:00Z")
      let validNew = entry("valid-new", at: "2026-09-09T12:00:00Z")
      try expect(ids([invalidZ, validOld, invalidA, validNew]) == ["valid-new", "valid-old", "invalid-a", "invalid-z"], "Unknown custom timestamps sort after all known publication dates")
      print("PASS invalid custom publication dates remain unknown and sort last")
    }

    do {
      let withoutDate = Data("{\"id\":\"draft\",\"name\":\"Draft\",\"channel\":\"channel\",\"updates\":[]}".utf8)
      var rejectedMissingDate = false
      do { _ = try JSONDecoder().decode(DraftEntry.self, from: withoutDate) }
      catch DecodingError.keyNotFound(let key, _) { rejectedMissingDate = key.stringValue == "createdAt" }
      try expect(rejectedMissingDate, "The existing catalog schema must still require createdAt")
      let emptyDate = Data("{\"id\":\"draft\",\"name\":\"Draft\",\"channel\":\"channel\",\"createdAt\":\"\",\"updates\":[]}".utf8)
      let decoded = try JSONDecoder().decode(DraftEntry.self, from: emptyDate)
      try expect(decoded.createdAt.isEmpty && decoded.publicationDate == nil, "An empty custom date may decode without inventing an instant")
      print("PASS catalog decoding keeps createdAt required without inventing empty timestamps")
    }

    do {
      let recent = entry("z", channel: "z-channel", at: "2026-09-09T12:00:01Z", name: "Z preview", runtime: "incompatible-runtime")
      let old = entry("a", channel: "a-channel", at: "2026-09-09T12:00:00Z", name: "A preview", runtime: "current-runtime")
      try expect(ids([old, recent]) == ["z", "a"], "Name, identifier, channel, and runtime must not outrank publication date")
      try expect(DraftEntry.newestFirst([]).isEmpty, "An empty catalog must remain empty")
      try expect(ids([recent]) == ["z"], "A one-row catalog must retain the row")
      print("PASS publication order is independent of display name and native compatibility")
    }
    print("6 iOS catalog publication test groups passed")
  }
}
