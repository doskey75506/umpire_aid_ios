import XCTest
@testable import ScoringCore

final class DoublesTests: XCTestCase {
    /// Team A: Alice(right)/Amy(left); Team B: Bob(right)/Bea(left).
    private func makeEngine() -> MatchEngine {
        MatchEngine(
            setup: MatchSetup(
                mode: .doubles,
                teamANames: ["Alice", "Amy"],
                teamBNames: ["Bob", "Bea"],
                initialServing: .a,
                teamACourts: [.right, .left],
                teamBCourts: [.right, .left]
            ),
            startedAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Score a point and dismiss any interval break it triggers.
    private func rally(_ engine: inout MatchEngine, _ side: TeamSide) {
        engine.scorePoint(side)
        if engine.phase == .midBreak { engine.skipBreak() }
    }

    func testInitialServerIsRightCourtPlayerOfServingTeam() {
        let engine = makeEngine()
        XCTAssertEqual(engine.server?.team, .a)
        XCTAssertEqual(engine.server?.index, 0, "Alice occupies the right court at 0-0")
        XCTAssertEqual(engine.server?.court, .right)
        XCTAssertEqual(engine.receiver?.team, .b)
        XCTAssertEqual(engine.receiver?.index, 0, "Bob (right court) receives")
    }

    func testServingWinSwapsPartnersAndSameServerContinues() {
        var engine = makeEngine()
        engine.scorePoint(.a)
        // Parity flipped to odd -> left court; Alice must now occupy it.
        XCTAssertEqual(engine.team(.a).courts, [.left, .right], "partners swapped courts")
        XCTAssertEqual(engine.server?.index, 0, "same server (Alice) continues after scoring")
        XCTAssertEqual(engine.server?.court, .left)

        engine.scorePoint(.a)
        XCTAssertEqual(engine.team(.a).courts, [.right, .left])
        XCTAssertEqual(engine.server?.index, 0, "Alice still serving at 2-0")
        XCTAssertEqual(engine.server?.court, .right)
    }

    func testReceivingWinKeepsCourtsAndServerFollowsParityOccupant() {
        var engine = makeEngine()
        // Bob (index 0, right) wins the rally: A stays put, B stays put.
        engine.scorePoint(.b)
        XCTAssertEqual(engine.team(.a).courts, [.right, .left], "receiver-side team did not move")
        XCTAssertEqual(engine.team(.b).courts, [.right, .left])
        XCTAssertEqual(engine.serving, .b)
        XCTAssertEqual(engine.points(for: .b), 1)
        // B odd -> left court occupant serves: Bea (index 1).
        XCTAssertEqual(engine.server?.index, 1, "odd score -> left-court player (Bea) serves")

        // B serves and wins: partners swap, Bea keeps serving from the right court.
        engine.scorePoint(.b)
        XCTAssertEqual(engine.team(.b).courts, [.left, .right])
        XCTAssertEqual(engine.server?.index, 1, "Bea continues serving after her own side wins")
        XCTAssertEqual(engine.server?.court, .right)

        // A wins a rally while B was serving: A does not move; A's parity decides.
        engine.scorePoint(.a)
        XCTAssertEqual(engine.team(.a).courts, [.right, .left], "receiving win -> no court swap")
        // A now at 1 point -> odd -> left court occupant Amy (index 1) serves.
        XCTAssertEqual(engine.server?.team, .a)
        XCTAssertEqual(engine.server?.index, 1)
    }

    func testManualCourtSwapChangesServerByParity() {
        var engine = makeEngine()
        // A at 0-0 (even): Alice (right) serves. Manually swap -> Amy on right.
        engine.swapCourts(.a)
        XCTAssertEqual(engine.team(.a).courts, [.left, .right])
        XCTAssertEqual(engine.server?.index, 1, "Amy now occupies the parity (right) court")
    }

    func testPositionsResetToInitialSetupFromGameTwo() {
        let setup = MatchSetup(
            mode: .doubles,
            teamANames: ["Alice", "Amy"],
            teamBNames: ["Bob", "Bea"],
            initialServing: .a,
            teamACourts: [.right, .left],
            teamBCourts: [.right, .left],
            winScore: 2,
            bestOf: 3,
            winBy2: false
        )
        var engine = MatchEngine(setup: setup, startedAt: Date(timeIntervalSince1970: 0))

        engine.scorePoint(.a) // 1-0 -> midBreak (midScore = 1)
        XCTAssertEqual(engine.phase, .midBreak)
        engine.skipBreak()
        engine.scorePoint(.b) // 1-1, B receives -> no swap for B
        engine.scorePoint(.b) // 1-2 -> B wins game 1; B's serving win swaps partners
        XCTAssertEqual(engine.phase, .gameBreak)
        XCTAssertEqual(engine.team(.a).courts, [.left, .right], "A moved during game 1")
        XCTAssertEqual(engine.team(.b).courts, [.left, .right], "B moved during game 1")

        engine.swapCourts(.a) // manual adjustment before the break ends
        XCTAssertEqual(engine.team(.a).courts, [.right, .left])

        engine.skipBreak() // advance to game 2
        XCTAssertEqual(engine.gameIndex, 1)
        XCTAssertEqual(engine.points(for: .a), 0)
        XCTAssertEqual(engine.points(for: .b), 0)
        XCTAssertEqual(engine.team(.a).courts, [.right, .left], "game 2 resets to initial positions")
        XCTAssertEqual(engine.team(.b).courts, [.right, .left], "reset also discards manual adjustments")
        XCTAssertEqual(engine.serving, .b, "serving alternates each game")
    }

    func testMatchEndsWhenOneSideWinsGamesToWin() {
        var engine = makeEngine()
        var setup = engine.setup
        setup.winScore = 2
        setup.bestOf = 3
        setup.winBy2 = false
        engine = MatchEngine(setup: setup)

        // Game 1
        rally(&engine, .a); engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .gameBreak)
        engine.skipBreak()
        // Game 2
        rally(&engine, .a); engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertNotNil(engine.finishedAt)
        XCTAssertEqual(engine.completedGames.count, 2)

        let record = engine.makeRecord()
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.winner, .a)
        XCTAssertEqual(record?.games.count, 2)
        XCTAssertEqual(record?.rallies.count, 4)
        XCTAssertEqual(record?.scoreLine, "2:0  2:0")
    }
}
