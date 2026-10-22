import Foundation
import ScoringCore

final class HistoryStore: ObservableObject {
    @Published private(set) var records: [MatchRecord] = []

    /// Preview/smoke mode: seeded records, never writes to disk.
    private let isPreview: Bool

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("match_history.json")
    }()

    init(previewRecords: [MatchRecord]? = nil) {
        if let seeded = previewRecords {
            isPreview = true
            records = seeded.sorted { $0.startedAt > $1.startedAt }
        } else {
            isPreview = false
            load()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([MatchRecord].self, from: data)
        else { return }
        records = list.sorted { $0.startedAt > $1.startedAt }
    }

    private func persist() {
        guard !isPreview else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func save(_ record: MatchRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        persist()
    }

    /// Filtered view helper: matches any player name (case-insensitive).
    func filtered(searchText: String) -> [MatchRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return records }
        return records.filter { record in
            record.setup.teamANames.contains { $0.localizedCaseInsensitiveContains(query) }
                || record.setup.teamBNames.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
