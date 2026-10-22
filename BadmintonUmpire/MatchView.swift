import SwiftUI
import ScoringCore

struct MatchView: View {
    @EnvironmentObject private var store: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared

    @State private var engine: MatchEngine
    @State private var flipped = false
    @State private var breakRemaining = 0
    @State private var nextServerChoice: TeamSide = .a
    @State private var recordSaved = false
    @State private var confirmExit = false
    @State private var showServerPicker = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(setup: MatchSetup) {
        _engine = State(initialValue: MatchEngine(setup: setup))
    }

    /// Used by the `--smoke` preview harness (see SmokeSupport.swift / AGENTS.md).
    init(engine: MatchEngine) {
        _engine = State(initialValue: engine)
    }

    private var leftTeam: TeamSide { flipped ? .b : .a }
    private var rightTeam: TeamSide { flipped ? .a : .b }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                HStack(spacing: 0) {
                    teamPanel(leftTeam, isLeftPanel: true)
                    Divider()
                    teamPanel(rightTeam, isLeftPanel: false)
                }
            }

            if engine.isBreak {
                breakOverlay
            }
            if engine.phase == .finished {
                finishedOverlay
            }
        }
        .navigationTitle(engine.setup.mode == .singles ? lang.t("match.singles") : lang.t("match.doubles"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                LanguageToggle()

                Button {
                    showServerPicker = true
                } label: {
                    Image(systemName: "sportscourt")
                }
                .disabled(engine.phase != .playing || engine.points(for: .a) != 0 || engine.points(for: .b) != 0)
                .accessibilityLabel(lang.t("match.setInitialServer"))

                Button {
                    engine.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!engine.canUndo)
                .accessibilityLabel(lang.t("match.undo"))

                Button {
                    flipped.toggle()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .disabled(engine.phase == .finished)
                .accessibilityLabel(lang.t("match.swap"))

                Button(role: .destructive) {
                    confirmExit = true
                } label: {
                    Image(systemName: "xmark")
                }
                .disabled(engine.phase == .finished)
                .accessibilityLabel(lang.t("match.exit"))
            }
        }
        .confirmationDialog(lang.t("match.setInitialServer"), isPresented: $showServerPicker, titleVisibility: .visible) {
            Button(teamDisplay(engine.setup, .a)) { engine.setInitialServer(.a) }
            Button(teamDisplay(engine.setup, .b)) { engine.setInitialServer(.b) }
            Button(lang.t("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(lang.t("match.exitConfirm"), isPresented: $confirmExit, titleVisibility: .visible) {
            Button(lang.t("match.exitYes"), role: .destructive) { dismiss() }
            Button(lang.t("match.exitNo"), role: .cancel) {}
        }
        .onAppear {
            breakRemaining = engine.breakDuration ?? 0
            if engine.phase == .gameBreak {
                nextServerChoice = defaultNextServer
            }
            // Match screen is landscape-only; everything else stays portrait.
            OrientationController.shared.lock(to: .landscape)
        }
        .onDisappear {
            OrientationController.shared.lock(to: .portrait)
        }
        .onChange(of: engine.phase) { _, newPhase in
            if newPhase == .midBreak {
                breakRemaining = engine.setup.midBreakSeconds
                // Deciding game: change ends at the interval break.
                if engine.gameIndex == engine.setup.bestOf - 1 {
                    flipped.toggle()
                }
            } else if newPhase == .gameBreak {
                breakRemaining = engine.setup.gameBreakSeconds
                nextServerChoice = defaultNextServer
            } else if newPhase == .finished {
                saveRecordIfNeeded()
            }
        }
        .onChange(of: engine.gameIndex) { _, _ in
            // Every new game: teams change ends (manual swap button still available).
            flipped.toggle()
        }
        .onReceive(clock) { _ in
            guard engine.isBreak else { return }
            if breakRemaining > 0 {
                breakRemaining -= 1
            } else {
                endBreak()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            HStack {
                Text(lang.t("match.gameN", engine.gameIndex + 1))
                    .font(.subheadline.bold())
                Spacer()
                Text("\(lang.t("match.gameScore")) \(engine.gameWins.a) : \(engine.gameWins.b)")
                    .font(.subheadline.bold())
            }
            Text(lang.t("match.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Team panel

    /// `isLeftPanel` decides the visual slot order so that both teams' right-court
    /// players stand diagonally across the net (top-down court view).
    private func teamPanel(_ side: TeamSide, isLeftPanel: Bool) -> some View {
        let state = engine.team(side)

        return VStack(spacing: 10) {
            Text(teamDisplay(engine.setup, side))
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text(state.names.joined(separator: " / "))
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 6) {
                ForEach(0..<engine.setup.gamesToWin, id: \.self) { i in
                    Circle()
                        .fill(i < state.gameWins ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
                Text(lang.t("match.game"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(state.points)")
                .font(.system(size: 84, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if engine.setup.mode == .doubles {
                DraggableCourtRack(
                    courts: state.courts,
                    slotOrder: isLeftPanel ? [.left, .right] : [.right, .left],
                    axis: .vertical,
                    card: { idx in playerCard(side: side, index: idx) },
                    onSwap: { engine.swapCourts(side) }
                )
                .frame(height: 130)
            } else {
                playerCard(side: side, index: 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            engine.scorePoint(side)
        }
    }

    private func playerCard(side: TeamSide, index: Int) -> AnyView {
        let state = engine.team(side)
        guard index < state.names.count else { return AnyView(EmptyView()) }

        let court = engine.displayCourt(team: side, index: index)
        let isServer = engine.server?.team == side && engine.server?.index == index
        let isReceiver = engine.receiver?.team == side && engine.receiver?.index == index

        return AnyView(
            PlayerCardView(
                name: state.names[index],
                court: court,
                isServer: isServer,
                isReceiver: isReceiver
            )
        )
    }

    // MARK: - Overlays

    private var breakOverlay: some View {
        VStack(spacing: 20) {
            Text(engine.phase == .midBreak ? lang.t("match.midBreak") : lang.t("match.gameBreak"))
                .font(.title2.bold())
            Text(countdownString(breakRemaining))
                .font(.system(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            if engine.phase == .gameBreak {
                VStack(spacing: 6) {
                    ForEach(Array(engine.completedGames.enumerated()), id: \.offset) { i, game in
                        Text("\(lang.t("match.gameN", i + 1))  \(game.teamA) : \(game.teamB)")
                            .font(.headline)
                    }
                    Picker(lang.t("match.nextServer"), selection: $nextServerChoice) {
                        Text(teamDisplay(engine.setup, .a)).tag(TeamSide.a)
                        Text(teamDisplay(engine.setup, .b)).tag(TeamSide.b)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .padding(.top, 8)
                    Text(lang.t("match.nextServer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            } else {
                Text("\(lang.t("match.currentScore")) \(engine.points(for: .a)) : \(engine.points(for: .b))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Button {
                endBreak()
            } label: {
                Text(lang.t("match.skipBreak"))
                    .font(.headline)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var finishedOverlay: some View {
        VStack(spacing: 18) {
            Text(lang.t("match.finished"))
                .font(.title.bold())
            let winner = engine.makeRecord()?.winner ?? .a
            Text("\(teamDisplay(engine.setup, winner)) \(lang.t("match.wins"))")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(spacing: 6) {
                ForEach(Array(engine.completedGames.enumerated()), id: \.offset) { i, game in
                    Text("\(lang.t("match.gameN", i + 1))  \(game.teamA) : \(game.teamB)")
                        .font(.headline)
                }
                Text("\(lang.t("match.totalScore")) \(engine.gameWins.a) : \(engine.gameWins.b)")
                    .font(.subheadline.bold())
                    .padding(.top, 4)
            }
            .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text(lang.t("match.done"))
                    .font(.headline)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    /// First server of the upcoming game (before manual override): alternate each game.
    private var defaultNextServer: TeamSide {
        let nextIndex = engine.gameIndex + 1
        return nextIndex % 2 == 0 ? engine.setup.initialServing : engine.setup.initialServing.other
    }

    private func endBreak() {
        if engine.phase == .gameBreak {
            engine.overrideNextServer(nextServerChoice)
        }
        engine.skipBreak()
    }

    private func countdownString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func saveRecordIfNeeded() {
        guard !recordSaved, let record = engine.makeRecord() else { return }
        store.save(record)
        recordSaved = true
    }
}

struct PlayerCardView: View {
    let name: String
    let court: CourtSide
    let isServer: Bool
    let isReceiver: Bool
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Text(courtDisplay(court))
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Color.secondary.opacity(0.25))
                .clipShape(Circle())

            Text(name)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isServer {
                Text(lang.t("match.serve"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: Capsule())
                    .foregroundStyle(.white)
            } else if isReceiver {
                Text(lang.t("match.receive"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isServer ? Color.orange.opacity(0.25) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isServer ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}
