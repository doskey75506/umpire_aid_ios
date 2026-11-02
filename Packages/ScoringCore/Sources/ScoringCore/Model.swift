import Foundation

public enum GameMode: String, Codable, CaseIterable, Sendable {
    case singles
    case doubles
}

public enum TeamSide: String, Codable, CaseIterable, Sendable {
    case a
    case b

    public var other: TeamSide { self == .a ? .b : .a }
    /// Default team name; actual display name comes from `MatchSetup.teamName(_:)`.
    public var label: String { self == .a ? "主队" : "客队" }
}

public enum CourtSide: String, Codable, CaseIterable, Sendable {
    case left
    case right

    public var label: String { self == .left ? "左" : "右" }
    public var toggled: CourtSide { self == .left ? .right : .left }
}

public enum MatchPhase: Equatable, Sendable {
    case playing
    case midBreak
    case gameBreak
    case finished
}

public struct MatchSetup: Codable, Equatable, Sendable {
    public var mode: GameMode
    public var teamANames: [String]
    public var teamBNames: [String]
    /// Team display names; default "主队"/"客队", editable before the match.
    public var teamALabel: String
    public var teamBLabel: String
    public var initialServing: TeamSide
    /// Doubles initial court slots, parallel to names. Ignored for singles.
    public var teamACourts: [CourtSide]
    public var teamBCourts: [CourtSide]
    public var winScore: Int
    public var bestOf: Int
    public var winBy2: Bool
    public var midBreakSeconds: Int
    public var gameBreakSeconds: Int

    public init(
        mode: GameMode = .singles,
        teamANames: [String] = [""],
        teamBNames: [String] = [""],
        teamALabel: String = TeamSide.a.label,
        teamBLabel: String = TeamSide.b.label,
        initialServing: TeamSide = .a,
        teamACourts: [CourtSide] = [.right, .left],
        teamBCourts: [CourtSide] = [.right, .left],
        winScore: Int = 15,
        bestOf: Int = 3,
        winBy2: Bool = true,
        midBreakSeconds: Int = 60,
        gameBreakSeconds: Int = 120
    ) {
        self.mode = mode
        self.teamANames = teamANames
        self.teamBNames = teamBNames
        self.teamALabel = teamALabel
        self.teamBLabel = teamBLabel
        self.initialServing = initialServing
        self.teamACourts = teamACourts
        self.teamBCourts = teamBCourts
        self.winScore = winScore
        self.bestOf = bestOf
        self.winBy2 = winBy2
        self.midBreakSeconds = midBreakSeconds
        self.gameBreakSeconds = gameBreakSeconds
    }

    /// Display name for a team; falls back to the default label when blank.
    public func teamName(_ side: TeamSide) -> String {
        let raw = (side == .a ? teamALabel : teamBLabel)
            .trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? side.label : raw
    }

    /// Games needed to win the match.
    public var gamesToWin: Int { bestOf / 2 + 1 }

    /// Interval-break threshold: first team to reach this score (21 -> 11, 15 -> 8).
    public var midScore: Int { (winScore + 1) / 2 }

    /// Maximum score at which a win-by-two game ends regardless of the margin.
    /// The 15-point format uses a 21-point cap; other formats retain the 30-point cap.
    public var capScore: Int { winScore == 15 ? 21 : 30 }

    public func names(for team: TeamSide) -> [String] {
        team == .a ? teamANames : teamBNames
    }

    public func courts(for team: TeamSide) -> [CourtSide] {
        team == .a ? teamACourts : teamBCourts
    }

    public var isValid: Bool {
        let expected = mode == .singles ? 1 : 2
        guard teamANames.count == expected, teamBNames.count == expected else { return false }
        guard teamANames.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              teamBNames.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return false }
        guard winScore >= 1, bestOf == 1 || bestOf == 3 || bestOf == 5 else { return false }
        guard midBreakSeconds >= 0, gameBreakSeconds >= 0 else { return false }
        if mode == .doubles {
            for courts in [teamACourts, teamBCourts] {
                guard courts.count == 2, Set(courts) == [.left, .right] else { return false }
            }
        }
        return true
    }

    /// Tolerant decoding: records written before team labels existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decode(GameMode.self, forKey: .mode)
        teamANames = try c.decode([String].self, forKey: .teamANames)
        teamBNames = try c.decode([String].self, forKey: .teamBNames)
        teamALabel = try c.decodeIfPresent(String.self, forKey: .teamALabel) ?? TeamSide.a.label
        teamBLabel = try c.decodeIfPresent(String.self, forKey: .teamBLabel) ?? TeamSide.b.label
        initialServing = try c.decode(TeamSide.self, forKey: .initialServing)
        teamACourts = try c.decode([CourtSide].self, forKey: .teamACourts)
        teamBCourts = try c.decode([CourtSide].self, forKey: .teamBCourts)
        winScore = try c.decode(Int.self, forKey: .winScore)
        bestOf = try c.decode(Int.self, forKey: .bestOf)
        winBy2 = try c.decode(Bool.self, forKey: .winBy2)
        midBreakSeconds = try c.decode(Int.self, forKey: .midBreakSeconds)
        gameBreakSeconds = try c.decode(Int.self, forKey: .gameBreakSeconds)
    }
}

public struct CompletedGame: Codable, Equatable, Sendable {
    public var teamA: Int
    public var teamB: Int
    public var winner: TeamSide

    public init(teamA: Int, teamB: Int, winner: TeamSide) {
        self.teamA = teamA
        self.teamB = teamB
        self.winner = winner
    }
}

public struct RallyRecord: Codable, Equatable, Sendable {
    public var seq: Int
    public var timestamp: Date
    public var gameIndex: Int
    public var scorer: TeamSide
    public var pointsA: Int
    public var pointsB: Int
    public var serving: TeamSide

    public init(seq: Int, timestamp: Date, gameIndex: Int, scorer: TeamSide, pointsA: Int, pointsB: Int, serving: TeamSide) {
        self.seq = seq
        self.timestamp = timestamp
        self.gameIndex = gameIndex
        self.scorer = scorer
        self.pointsA = pointsA
        self.pointsB = pointsB
        self.serving = serving
    }
}

public struct MatchRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var setup: MatchSetup
    public var games: [CompletedGame]
    public var winner: TeamSide
    public var rallies: [RallyRecord]

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date, setup: MatchSetup, games: [CompletedGame], winner: TeamSide, rallies: [RallyRecord]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.setup = setup
        self.games = games
        self.winner = winner
        self.rallies = rallies
    }

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    public var scoreLine: String {
        games.map { "\($0.teamA):\($0.teamB)" }.joined(separator: "  ")
    }

    public var participants: String {
        let a = setup.names(for: .a).joined(separator: " / ")
        let b = setup.names(for: .b).joined(separator: " / ")
        return "\(a) vs \(b)"
    }
}
