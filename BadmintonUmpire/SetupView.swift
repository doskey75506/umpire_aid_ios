import SwiftUI
import ScoringCore

struct SetupView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    init(initialMode: GameMode = .singles) {
        _mode = State(initialValue: initialMode)
        // Prefill with localized defaults; user can edit. Track edits so
        // unmodified defaults stay language-flexible (empty → localized fallback).
        _teamALabel = State(initialValue: LanguageManager.shared.t("team.home"))
        _teamBLabel = State(initialValue: LanguageManager.shared.t("team.away"))
    }

    @State private var mode: GameMode
    @State private var teamALabel: String
    @State private var teamBLabel: String
    @State private var teamACustom = false
    @State private var teamBCustom = false
    @State private var nameA1 = ""
    @State private var nameA2 = ""
    @State private var nameB1 = ""
    @State private var nameB2 = ""
    @State private var initialServing: TeamSide = .a
    @State private var courtsA: [CourtSide] = [.right, .left]
    @State private var courtsB: [CourtSide] = [.right, .left]
    @State private var winScore = 15
    @State private var bestOf = 3
    @State private var winBy2 = true
    @State private var midBreakSeconds = 60
    @State private var gameBreakSeconds = 120

    private var setup: MatchSetup {
        MatchSetup(
            mode: mode,
            teamANames: mode == .singles ? [nameA1] : [nameA1, nameA2],
            teamBNames: mode == .singles ? [nameB1] : [nameB1, nameB2],
            teamALabel: teamACustom ? teamALabel : "",
            teamBLabel: teamBCustom ? teamBLabel : "",
            initialServing: initialServing,
            teamACourts: courtsA,
            teamBCourts: courtsB,
            winScore: winScore,
            bestOf: bestOf,
            winBy2: winBy2,
            midBreakSeconds: midBreakSeconds,
            gameBreakSeconds: gameBreakSeconds
        )
    }

    private func displayName(_ raw: String, fallback: TeamSide) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return lang.t(fallback == .a ? "team.home" : "team.away")
        }
        return trimmed
    }

    var body: some View {
        Form {
            Section(lang.t("setup.mode")) {
                Picker(lang.t("setup.mode.label"), selection: $mode) {
                    Text(lang.t("setup.singles")).tag(GameMode.singles)
                    Text(lang.t("setup.doubles")).tag(GameMode.doubles)
                }
                .pickerStyle(.segmented)
            }

            Section {
                teamEntry(
                    title: lang.t("team.home"),
                    label: $teamALabel,
                    isCustom: $teamACustom,
                    firstPlayer: $nameA1,
                    secondPlayer: $nameA2
                )
                teamEntry(
                    title: lang.t("team.away"),
                    label: $teamBLabel,
                    isCustom: $teamBCustom,
                    firstPlayer: $nameB1,
                    secondPlayer: $nameB2
                )
            } header: {
                Text(lang.t("setup.namesSection"))
            } footer: {
                Text(lang.t("setup.namesFooter"))
            }

            Section {
                Picker(lang.t("setup.initialServer"), selection: $initialServing) {
                    Text(displayName(teamALabel, fallback: .a)).tag(TeamSide.a)
                    Text(displayName(teamBLabel, fallback: .b)).tag(TeamSide.b)
                }
            } header: {
                Text(lang.t("setup.servingSection"))
            } footer: {
                Text(lang.t("setup.servingFooter"))
            }

            if mode == .doubles {
                Section {
                    CourtSlotsView(names: [nameA1, nameA2], courts: $courtsA)
                    CourtSlotsView(names: [nameB1, nameB2], courts: $courtsB)
                } header: {
                    Text(lang.t("setup.courtSection"))
                } footer: {
                    Text(lang.t("setup.courtFooter"))
                }
            }

            Section(lang.t("setup.rules")) {
                HStack {
                    TextField(lang.t("setup.winScore"), value: $winScore, format: .number)
                        .keyboardType(.numberPad)
                    Text(lang.t("setup.pointsUnit"))
                }
                Picker(lang.t("setup.bestOf"), selection: $bestOf) {
                    Text(lang.t("setup.game1")).tag(1)
                    Text(lang.t("setup.game3")).tag(3)
                    Text(lang.t("setup.game5")).tag(5)
                }
                Toggle(lang.t("setup.winBy2"), isOn: $winBy2)
                HStack {
                    Text(lang.t("setup.midThreshold"))
                    Spacer()
                    Text(lang.t("\(setup.midScore) \(lang.t("setup.pointsUnit"))"))
                        .foregroundStyle(.secondary)
                }
            }

            Section(lang.t("setup.breaks")) {
                HStack {
                    TextField(lang.t("setup.midBreak"), value: $midBreakSeconds, format: .number)
                        .keyboardType(.numberPad)
                    Text(lang.t("setup.secondsUnit"))
                }
                HStack {
                    TextField(lang.t("setup.gameBreak"), value: $gameBreakSeconds, format: .number)
                        .keyboardType(.numberPad)
                    Text(lang.t("setup.secondsUnit"))
                }
            }

            Section {
                NavigationLink {
                    MatchView(setup: setup)
                } label: {
                    Text(lang.t("setup.start"))
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .disabled(!setup.isValid)
            } footer: {
                if !setup.isValid {
                    Text(lang.t("setup.invalid"))
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(lang.t("setup.title"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(lang.t("common.cancel"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                LanguageToggle()
            }
        }
    }

    private func teamEntry(
        title: String,
        label: Binding<String>,
        isCustom: Binding<Bool>,
        firstPlayer: Binding<String>,
        secondPlayer: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(title, text: label)
                .font(.headline)
                .onChange(of: label.wrappedValue) { _, _ in isCustom.wrappedValue = true }

            VStack(alignment: .leading, spacing: 8) {
                TextField(mode == .doubles ? lang.t("setup.player1") : lang.t("setup.player"), text: firstPlayer)
                if mode == .doubles {
                    TextField(lang.t("setup.player2"), text: secondPlayer)
                }
            }
            .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
}

/// Two draggable slots (left / right service court) for one doubles team.
struct CourtSlotsView: View {
    let names: [String]
    @Binding var courts: [CourtSide]
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        DraggableCourtRack(
            courts: courts,
            slotOrder: [.left, .right],
            axis: .horizontal,
            card: { idx in
                let court = courts[idx]
                let raw = idx < names.count ? names[idx] : ""
                let fallback = lang.t(idx == 0 ? "setup.player1" : "setup.player2")
                let name = raw.isEmpty ? fallback : raw
                return AnyView(
                    VStack(spacing: 4) {
                        Text(courtDisplay(court))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                )
            },
            onSwap: { courts.swapAt(0, 1) }
        )
        .frame(height: 66)
        .padding(.vertical, 4)
    }
}
