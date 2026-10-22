import SwiftUI
import ScoringCore

struct HistoryView: View {
    @EnvironmentObject private var store: HistoryStore
    @ObservedObject private var lang = LanguageManager.shared
    @State private var searchText = ""

    private var filtered: [MatchRecord] {
        store.filtered(searchText: searchText)
    }

    var body: some View {
        Group {
            if store.records.isEmpty {
                ContentUnavailableView(
                    lang.t("history.empty"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(lang.t("history.emptyHint"))
                )
            } else {
                List {
                    ForEach(filtered) { record in
                        NavigationLink {
                            MatchDetailView(record: record)
                        } label: {
                            HistoryRow(record: record)
                        }
                    }
                    .onDelete { indexSet in
                        let ids = Set(indexSet.map { filtered[$0].id })
                        store.delete(ids: ids)
                    }

                    if filtered.isEmpty {
                        Text(lang.t("history.noMatch", searchText))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(lang.t("history.title"))
        .searchable(text: $searchText, prompt: lang.t("history.search"))
        .toolbar {
            LanguageToggle()
            if !store.records.isEmpty {
                EditButton()
            }
        }
    }
}

private struct HistoryRow: View {
    let record: MatchRecord
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.participants)
                .font(.subheadline.bold())
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(record.setup.mode == .singles ? lang.t("history.singles") : lang.t("history.doubles"))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2), in: Capsule())

                Text(record.scoreLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(teamDisplay(record.setup, record.winner) + lang.t("history.wins"))
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            HStack {
                Text(Self.dateFormatter.string(from: record.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.durationFormatter(record.duration, lang: lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func durationFormatter(_ interval: TimeInterval, lang: LanguageManager) -> String {
        let total = Int(interval)
        if total >= 3600 {
            return String(format: lang.t("history.durationHM"), total / 3600, (total % 3600) / 60)
        }
        return String(format: lang.t("history.durationMS"), total / 60, total % 60)
    }
}
