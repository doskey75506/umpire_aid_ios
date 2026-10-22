import SwiftUI
import ScoringCore

/// Launch-argument driven screen renderer for smoke-testing UI without taps.
/// Usage: pass `--smoke <screen>` to the app launch arguments.
/// Valid screens: setup, slots, match, midbreak, gamebreak, finished, history, detail.
/// See AGENTS.md.
enum SmokeScreen: String {
    case setup
    case setupdoubles
    case slots
    case match
    case midbreak
    case gamebreak
    case finished
    case history
    case detail

    static var current: SmokeScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "--smoke"), idx + 1 < args.count else { return nil }
        return SmokeScreen(rawValue: args[idx + 1])
    }

    static var doublesSetup: MatchSetup {
        MatchSetup(
            mode: .doubles,
            teamANames: ["甲一", "甲二"],
            teamBNames: ["乙一", "乙二"],
            initialServing: .a,
            teamACourts: [.right, .left],
            teamBCourts: [.right, .left]
        )
    }

    /// Engine advanced to the state needed for break / finished screens.
    static func engine(for screen: SmokeScreen) -> MatchEngine {
        var setup = doublesSetup
        if screen == .gamebreak || screen == .finished {
            setup.winScore = 2
            setup.winBy2 = false
        }
        var engine = MatchEngine(setup: setup, startedAt: Date().addingTimeInterval(-180))
        func rally(_ side: TeamSide) {
            engine.scorePoint(side)
            if engine.phase == .midBreak { engine.skipBreak() }
        }
        switch screen {
        case .match:
            rally(.a); rally(.a); rally(.b); rally(.a); rally(.b)
        case .midbreak:
            // Leave the interval break active (no skip).
            for _ in 0..<11 { engine.scorePoint(.a) }
        case .gamebreak:
            engine.scorePoint(.a); engine.skipBreak() // 1-0, interval passed
            engine.scorePoint(.a)                     // 2-0 -> game over
        case .finished:
            engine.scorePoint(.a); engine.skipBreak()
            engine.scorePoint(.a)                 // game 1: 2-0 for A
            engine.skipBreak()
            engine.scorePoint(.a); engine.skipBreak()
            engine.scorePoint(.a)                 // game 2: 2-0 for A -> match over
        default:
            break
        }
        return engine
    }

    static var sampleRecord: MatchRecord {
        let setup = doublesSetup
        let start = Date().addingTimeInterval(-3700)
        var seed = 0
        let rallies: [RallyRecord] = (0..<24).map { i in
            let scorer: TeamSide = (i % 3 == 0) ? .b : .a
            let aScore = min(21, seed + ((i % 3 == 0) ? 0 : 1))
            let bScore = min(20, seed)
            if i % 2 == 1 { seed += 1 }
            return RallyRecord(
                seq: i + 1,
                timestamp: start.addingTimeInterval(Double(i) * 12),
                gameIndex: (i < 12) ? 0 : 1,
                scorer: scorer,
                pointsA: aScore,
                pointsB: bScore,
                serving: scorer
            )
        }
        return MatchRecord(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(3600),
            setup: setup,
            games: [
                CompletedGame(teamA: 21, teamB: 18, winner: .a),
                CompletedGame(teamA: 19, teamB: 21, winner: .b),
                CompletedGame(teamA: 21, teamB: 17, winner: .a),
            ],
            winner: .a,
            rallies: rallies
        )
    }
}

struct SmokeView: View {
    let screen: SmokeScreen
    @StateObject private var store: HistoryStore
    @State private var courtsA: [CourtSide] = [.right, .left]
    @State private var courtsB: [CourtSide] = [.left, .right]
    @ObservedObject private var lang = LanguageManager.shared

    init(screen: SmokeScreen) {
        self.screen = screen
        _store = StateObject(wrappedValue: HistoryStore(previewRecords: screen == .history ? [SmokeScreen.sampleRecord] : nil))
    }

    var body: some View {
        NavigationStack {
            content
        }
        .environmentObject(store)
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .setup:
            SetupView()
        case .setupdoubles:
            SetupView(initialMode: .doubles)
        case .slots:
            Form {
                Section(lang.t("team.home")) {
                    CourtSlotsView(names: ["主一", "主二"], courts: $courtsA)
                }
                Section(lang.t("team.away")) {
                    CourtSlotsView(names: ["客一", "客二"], courts: $courtsB)
                }
            }
            .navigationTitle(lang.t("setup.courtSection"))
        case .match, .midbreak, .gamebreak, .finished:
            MatchView(engine: SmokeScreen.engine(for: screen))
        case .history:
            HistoryView()
        case .detail:
            MatchDetailView(record: SmokeScreen.sampleRecord)
        }
    }
}
