import Foundation

public struct TeamState: Equatable, Sendable {
    public var names: [String]
    /// Parallel to `names`. Doubles: stored court slots (manually adjustable).
    /// Singles: kept in sync with the score-parity court of the player.
    public var courts: [CourtSide]
    public var points: Int
    public var gameWins: Int

    public init(names: [String], courts: [CourtSide], points: Int = 0, gameWins: Int = 0) {
        self.names = names
        self.courts = courts
        self.points = points
        self.gameWins = gameWins
    }
}

/// Pure scoring engine for a badminton match.
///
/// Rules implemented (confirmed with the product owner):
/// - Rally point scoring; game won at `winScore` (with 2-point margin when `winBy2`,
///   capped at 30: reaching 30 wins outright, e.g. 30:29).
/// - Server is ALWAYS the player occupying the court matching the serving team's
///   score parity (even -> right, odd -> left).
/// - Doubles: when the serving team wins a rally, the two partners swap courts
///   (the same server keeps serving from the other court). When the receiving team
///   wins, courts do not change; the player now occupying the parity court becomes
///   the new server.
/// - Singles: the player's court always follows their own score parity; the
///   receiver always stands on the same-labeled court as the server.
/// - Interval break at `midScore` (ceil(winScore/2)) once per game; between-game
///   break after every game except the last.
/// - From game 2 onward, court positions reset to the initial setup; serving team
///   alternates each game.
public struct MatchEngine: Equatable, Sendable {
    public let setup: MatchSetup
    public let startedAt: Date

    public private(set) var teamA: TeamState
    public private(set) var teamB: TeamState
    public private(set) var gameIndex: Int
    public private(set) var serving: TeamSide
    public private(set) var phase: MatchPhase
    public private(set) var midBreakTriggered: Bool
    public private(set) var completedGames: [CompletedGame]
    public private(set) var rallies: [RallyRecord]
    public private(set) var finishedAt: Date?
    /// Manual choice for who serves first in the next game (consumed by advanceGame).
    public private(set) var pendingNextServer: TeamSide?

    private var undoStack: [Snapshot]

    private struct Snapshot: Equatable, Sendable {
        var teamA: TeamState
        var teamB: TeamState
        var gameIndex: Int
        var serving: TeamSide
        var phase: MatchPhase
        var midBreakTriggered: Bool
        var completedGames: [CompletedGame]
        var rallies: [RallyRecord]
        var finishedAt: Date?
        var pendingNextServer: TeamSide?
    }

    public init(setup: MatchSetup, startedAt: Date = Date()) {
        self.setup = setup
        self.startedAt = startedAt
        self.gameIndex = 0
        self.serving = setup.initialServing
        self.phase = .playing
        self.midBreakTriggered = false
        self.completedGames = []
        self.rallies = []
        self.finishedAt = nil
        self.pendingNextServer = nil
        self.undoStack = []

        let aCourts: [CourtSide]
        let bCourts: [CourtSide]
        if setup.mode == .doubles, setup.teamACourts.count == 2, setup.teamBCourts.count == 2,
           Set(setup.teamACourts) == [.left, .right], Set(setup.teamBCourts) == [.left, .right] {
            aCourts = setup.teamACourts
            bCourts = setup.teamBCourts
        } else {
            // Singles (or invalid doubles setup): both players start on the right
            // court (score 0 is even), mirrored for the receiver.
            aCourts = Array(repeating: .right, count: max(setup.teamANames.count, 1))
            bCourts = Array(repeating: .right, count: max(setup.teamBNames.count, 1))
        }
        self.teamA = TeamState(names: setup.teamANames, courts: aCourts)
        self.teamB = TeamState(names: setup.teamBNames, courts: bCourts)
    }

    // MARK: - Derived state

    public func team(_ side: TeamSide) -> TeamState {
        side == .a ? teamA : teamB
    }

    private mutating func setTeam(_ side: TeamSide, _ state: TeamState) {
        if side == .a { teamA = state } else { teamB = state }
    }

    public func points(for side: TeamSide) -> Int { team(side).points }

    public var gameWins: (a: Int, b: Int) { (teamA.gameWins, teamB.gameWins) }

    /// The current server, if one can be derived.
    public var server: (team: TeamSide, index: Int, court: CourtSide)? {
        let state = team(serving)
        let court: CourtSide = state.points % 2 == 0 ? .right : .left
        if setup.mode == .singles {
            return (serving, 0, court)
        }
        guard state.courts.count == 2 else { return nil }
        if let idx = state.courts.firstIndex(of: court) {
            return (serving, idx, court)
        }
        return nil
    }

    /// The receiver (same-labeled court as the server), if derivable.
    public var receiver: (team: TeamSide, index: Int)? {
        guard let srv = server else { return nil }
        let other = srv.team.other
        let state = team(other)
        if setup.mode == .singles {
            return (other, 0)
        }
        guard state.courts.count == 2, let idx = state.courts.firstIndex(of: srv.court) else { return nil }
        return (other, idx)
    }

    /// Court label to display for a player card. Doubles uses stored positions;
    /// singles always mirrors the server's court (one player per side).
    public func displayCourt(team side: TeamSide, index: Int) -> CourtSide {
        let state = team(side)
        guard index < state.courts.count else { return .right }
        if setup.mode == .doubles { return state.courts[index] }
        if let srv = server, srv.team == side { return srv.court }
        return server?.court ?? (state.points % 2 == 0 ? .right : .left)
    }

    public var canUndo: Bool { !undoStack.isEmpty && phase != .finished }

    public var isBreak: Bool { phase == .midBreak || phase == .gameBreak }

    /// Seconds of rest for the current break phase, if any.
    public var breakDuration: Int? {
        switch phase {
        case .midBreak: return setup.midBreakSeconds
        case .gameBreak: return setup.gameBreakSeconds
        default: return nil
        }
    }

    // MARK: - Actions

    /// Record a point for `side`. No-op unless currently playing.
    public mutating func scorePoint(_ side: TeamSide, now: Date = Date()) {
        guard phase == .playing else { return }
        pushUndo()

        var state = team(side)
        state.points += 1
        if setup.mode == .doubles {
            if serving == side, state.courts.count == 2 {
                // Serving side wins: partners swap courts, same server continues
                // (the parity court now points to the same player).
                state.courts.swapAt(0, 1)
            }
        } else if state.courts.count == 1 {
            state.courts[0] = state.points % 2 == 0 ? .right : .left
        }
        setTeam(side, state)
        serving = side

        rallies.append(
            RallyRecord(
                seq: rallies.count + 1,
                timestamp: now,
                gameIndex: gameIndex,
                scorer: side,
                pointsA: teamA.points,
                pointsB: teamB.points,
                serving: side
            )
        )

        evaluateAfterPoint()
    }

    /// End the current break and resume / advance to the next game.
    public mutating func skipBreak() {
        switch phase {
        case .midBreak:
            phase = .playing
        case .gameBreak:
            advanceGame()
            phase = .playing
        default:
            break
        }
    }

    /// Manually pick who serves first in the next game (only during the
    /// between-games break; consumed by the game advance).
    public mutating func overrideNextServer(_ team: TeamSide) {
        guard phase == .gameBreak else { return }
        pendingNextServer = team
    }

    /// Reassign who serves first in the *current* game. Only allowed before
    /// any point has been scored (0:0), so rally-derived serving is never
    /// overwritten mid-game.
    public mutating func setInitialServer(_ team: TeamSide) {
        guard phase == .playing, teamA.points == 0, teamB.points == 0 else { return }
        pushUndo()
        serving = team
    }

    /// Doubles only: swap the team's two players between courts (manual adjustment).
    public mutating func swapCourts(_ side: TeamSide) {
        guard setup.mode == .doubles, phase != .finished else { return }
        var state = team(side)
        guard state.courts.count == 2 else { return }
        pushUndo()
        state.courts.swapAt(0, 1)
        setTeam(side, state)
    }

    /// Revert the last scoring / court-adjustment action.
    public mutating func undo() {
        guard canUndo, let snap = undoStack.popLast() else { return }
        teamA = snap.teamA
        teamB = snap.teamB
        gameIndex = snap.gameIndex
        serving = snap.serving
        phase = snap.phase
        midBreakTriggered = snap.midBreakTriggered
        completedGames = snap.completedGames
        rallies = snap.rallies
        finishedAt = snap.finishedAt
        pendingNextServer = snap.pendingNextServer
    }

    /// Build the persistent record for a finished match.
    public func makeRecord() -> MatchRecord? {
        guard phase == .finished, let end = finishedAt else { return nil }
        let winner: TeamSide = teamA.gameWins >= setup.gamesToWin ? .a : .b
        return MatchRecord(
            startedAt: startedAt,
            endedAt: end,
            setup: setup,
            games: completedGames,
            winner: winner,
            rallies: rallies
        )
    }

    // MARK: - Internals

    private mutating func pushUndo() {
        undoStack.append(
            Snapshot(
                teamA: teamA,
                teamB: teamB,
                gameIndex: gameIndex,
                serving: serving,
                phase: phase,
                midBreakTriggered: midBreakTriggered,
                completedGames: completedGames,
                rallies: rallies,
                finishedAt: finishedAt,
                pendingNextServer: pendingNextServer
            )
        )
    }

    private mutating func evaluateAfterPoint() {
        let winnerState = team(serving)
        let loserState = team(serving.other)
        let target = setup.winScore
        let gameOver: Bool
        if setup.winBy2 {
            // 2-point lead required, but capped: reaching 30 wins outright (e.g. 30:29).
            let lead = winnerState.points - loserState.points
            gameOver = winnerState.points >= target && (lead >= 2 || winnerState.points >= 30)
        } else {
            gameOver = winnerState.points >= target
        }

        if gameOver {
            completeGame()
        } else if !midBreakTriggered && winnerState.points >= setup.midScore {
            midBreakTriggered = true
            phase = .midBreak
        }
    }

    private mutating func completeGame() {
        var winner = team(serving)
        completedGames.append(
            CompletedGame(teamA: teamA.points, teamB: teamB.points, winner: serving)
        )
        winner.gameWins += 1
        setTeam(serving, winner)

        if winner.gameWins >= setup.gamesToWin {
            phase = .finished
            finishedAt = Date()
        } else {
            phase = .gameBreak
        }
    }

    private mutating func advanceGame() {
        gameIndex += 1
        midBreakTriggered = false
        teamA.points = 0
        teamB.points = 0
        // From game 2 on: reset court positions to the initial setup.
        if setup.mode == .doubles, setup.teamACourts.count == 2, setup.teamBCourts.count == 2,
           Set(setup.teamACourts) == [.left, .right], Set(setup.teamBCourts) == [.left, .right] {
            teamA.courts = setup.teamACourts
            teamB.courts = setup.teamBCourts
        } else {
            teamA.courts = Array(repeating: .right, count: teamA.courts.count)
            teamB.courts = Array(repeating: .right, count: teamB.courts.count)
        }
        // Serving: manual override for this game, else alternate each game.
        if let override = pendingNextServer {
            serving = override
        } else {
            serving = gameIndex % 2 == 0 ? setup.initialServing : setup.initialServing.other
        }
        pendingNextServer = nil
    }
}
