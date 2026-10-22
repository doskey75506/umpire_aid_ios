import SwiftUI
import ScoringCore

struct MatchDetailView: View {
    let record: MatchRecord
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showRallies = false
    @State private var sharePayload: SharePayload?

    private var winnerNames: String {
        record.setup.names(for: record.winner).joined(separator: " / ")
    }

    private var ruleLine: String {
        let base = lang.t(
            "detail.ruleFormat",
            record.setup.winScore,
            record.setup.bestOf,
            record.setup.gamesToWin
        )
        // "win by 2" is the default — only spell out when it is OFF.
        let winBy2Note = record.setup.winBy2 ? "" : lang.t("detail.ruleWinBy2")
        return base + winBy2Note
    }

    var body: some View {
        List {
            summarySection
            gamesSection
            rallySection
        }
        .navigationTitle(lang.t("detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                LanguageToggle()
                Button {
                    exportPDF()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(lang.t("detail.export"))
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section(lang.t("detail.summary")) {
            detailRow(lang.t("detail.time"), HistoryRowDateFormatter.string(from: record.startedAt))
            detailRow(lang.t("detail.duration"), HistoryRowDuration.string(from: record.duration))
            detailRow(lang.t("detail.mode"), record.setup.mode == .singles ? lang.t("setup.singles") : lang.t("setup.doubles"))
            detailRow(teamDisplay(record.setup, .a), record.setup.names(for: .a).joined(separator: " / "))
            detailRow(teamDisplay(record.setup, .b), record.setup.names(for: .b).joined(separator: " / "))
            detailRow(lang.t("detail.winner"), "\(teamDisplay(record.setup, record.winner))（\(winnerNames)）")
            detailRow(lang.t("detail.rule"), ruleLine)
        }
    }

    private var gamesSection: some View {
        Section(lang.t("detail.games")) {
            ForEach(Array(record.games.enumerated()), id: \.offset) { i, game in
                HStack {
                    Text(lang.t("match.gameN", i + 1))
                    Spacer()
                    Text("\(game.teamA) : \(game.teamB)")
                        .font(.body.monospacedDigit())
                        .fontWeight(.semibold)
                    Text(teamDisplay(record.setup, game.winner) + lang.t("detail.wins"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var rallySection: some View {
        Section(lang.t("detail.rallies")) {
            Button {
                showRallies.toggle()
            } label: {
                HStack {
                    Text(showRallies ? lang.t("detail.collapse") : lang.t("detail.expand"))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: showRallies ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showRallies {
                if record.rallies.isEmpty {
                    Text(lang.t("detail.noRallies"))
                        .foregroundStyle(.secondary)
                } else {
                    rallyHeader
                    ForEach(record.rallies, id: \.seq) { rally in
                        rallyRow(rally)
                    }
                }
            }
        }
    }

    private var rallyHeader: some View {
        HStack {
            Text("#").frame(width: 36, alignment: .leading)
            Text(lang.t("detail.timeCol")).frame(width: 52, alignment: .leading)
            Text(lang.t("detail.gameCol")).frame(width: 34, alignment: .leading)
            Spacer()
            Text(lang.t("detail.scorerCol")).frame(width: 44, alignment: .trailing)
            Text(lang.t("detail.scoreCol")).frame(width: 56, alignment: .trailing)
        }
        .font(.caption2.bold())
        .foregroundStyle(.secondary)
    }

    private func rallyRow(_ rally: RallyRecord) -> some View {
        HStack {
            Text("\(rally.seq)")
                .frame(width: 36, alignment: .leading)
            Text(Self.elapsed(rally.timestamp, since: record.startedAt))
                .frame(width: 52, alignment: .leading)
            Text("\(rally.gameIndex + 1)")
                .frame(width: 34, alignment: .leading)
            Spacer()
            Text(teamDisplay(record.setup, rally.scorer))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 56, alignment: .trailing)
            Text("\(rally.pointsA):\(rally.pointsB)")
                .font(.body.monospacedDigit())
                .frame(width: 56, alignment: .trailing)
        }
        .font(.caption)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - PDF export

    /// Include point-by-point log only when the user has expanded 「详情」.
    private func exportPDF() {
        let report = MatchReportView(record: record, includeRallies: showRallies)
            .environment(\.locale, Locale(identifier: lang.language.rawValue))
        guard let url = MatchReportPDF.make(from: report, fileName: "match_report") else { return }
        sharePayload = SharePayload(url: url)
    }

    private static func elapsed(_ date: Date, since start: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(start)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - PDF report layout

private struct MatchReportView: View {
    let record: MatchRecord
    let includeRallies: Bool
    @ObservedObject private var lang = LanguageManager.shared

    private var winnerNames: String {
        record.setup.names(for: record.winner).joined(separator: " / ")
    }

    private var ruleLine: String {
        let base = lang.t(
            "detail.ruleFormat",
            record.setup.winScore,
            record.setup.bestOf,
            record.setup.gamesToWin
        )
        let winBy2Note = record.setup.winBy2 ? "" : lang.t("detail.ruleWinBy2")
        return base + winBy2Note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(lang.t("detail.reportTitle"))
                .font(.title.bold())
            Text("\(lang.t("detail.time")): \(HistoryRowDateFormatter.string(from: record.startedAt))")
                .font(.subheadline)
            Text("\(lang.t("detail.duration")): \(HistoryRowDuration.string(from: record.duration))")
                .font(.subheadline)
            Text("\(lang.t("detail.mode")): \(record.setup.mode == .singles ? lang.t("setup.singles") : lang.t("setup.doubles"))")
                .font(.subheadline)

            Divider()

            reportRow(teamDisplay(record.setup, .a), record.setup.names(for: .a).joined(separator: " / "))
            reportRow(teamDisplay(record.setup, .b), record.setup.names(for: .b).joined(separator: " / "))
            reportRow(lang.t("detail.winner"), "\(teamDisplay(record.setup, record.winner))（\(winnerNames)）")
            reportRow(lang.t("detail.rule"), ruleLine)

            Divider()

            Text(lang.t("detail.games"))
                .font(.headline)
            ForEach(Array(record.games.enumerated()), id: \.offset) { i, game in
                HStack {
                    Text(lang.t("match.gameN", i + 1))
                    Spacer()
                    Text("\(game.teamA) : \(game.teamB)")
                        .fontWeight(.semibold)
                    Text(teamDisplay(record.setup, game.winner) + lang.t("detail.wins"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .font(.subheadline)
            }

            if includeRallies && !record.rallies.isEmpty {
                Divider()
                Text("\(lang.t("detail.rallies"))（\(lang.t("detail.withRallies"))）")
                    .font(.headline)
                ForEach(record.rallies, id: \.seq) { rally in
                    HStack {
                        Text("\(rally.seq)")
                            .frame(width: 30, alignment: .leading)
                        Text(Self.elapsed(rally.timestamp, since: record.startedAt))
                            .frame(width: 48, alignment: .leading)
                        Text("\(rally.gameIndex + 1)")
                            .frame(width: 24, alignment: .leading)
                        Spacer()
                        Text(teamDisplay(record.setup, rally.scorer))
                            .frame(width: 60, alignment: .trailing)
                        Text("\(rally.pointsA):\(rally.pointsB)")
                            .frame(width: 48, alignment: .trailing)
                    }
                    .font(.caption)
                }
            } else if !includeRallies {
                Text(lang.t("detail.withoutRallies"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(width: 548, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private static func elapsed(_ date: Date, since start: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(start)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Share sheet payload

private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Formatters

private enum HistoryRowDateFormatter {
    static func string(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

@MainActor
private enum HistoryRowDuration {
    static func string(from interval: TimeInterval) -> String {
        let total = Int(interval)
        if total >= 3600 {
            return String(format: LanguageManager.shared.t("history.durationHM"), total / 3600, (total % 3600) / 60)
        }
        return String(format: LanguageManager.shared.t("history.durationMS"), total / 60, total % 60)
    }
}
