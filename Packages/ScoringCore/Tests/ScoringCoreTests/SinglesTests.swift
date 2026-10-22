import XCTest
@testable import ScoringCore

final class SinglesTests: XCTestCase {
    private func makeEngine(winScore: Int = 21, winBy2: Bool = true, bestOf: Int = 3) -> MatchEngine {
        MatchEngine(
            setup: MatchSetup(
                mode: .singles,
                teamANames: ["Alice"],
                teamBNames: ["Bob"],
                initialServing: .a,
                winScore: winScore,
                bestOf: bestOf,
                winBy2: winBy2
            ),
            startedAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Score a point and dismiss any interval break it triggers
    /// (break timing itself is covered by dedicated tests).
    private func rally(_ engine: inout MatchEngine, _ side: TeamSide) {
        engine.scorePoint(side)
        if engine.phase == .midBreak { engine.skipBreak() }
    }

    func testInitialStateServerIsRightCourtOnEvenScore() {
        let engine = makeEngine()
        XCTAssertEqual(engine.server?.team, .a)
        XCTAssertEqual(engine.server?.court, .right)
        XCTAssertEqual(engine.receiver?.team, .b)
    }

    func testServingWinSwitchesCourtAndKeepsServer() {
        var engine = makeEngine()
        engine.scorePoint(.a)
        XCTAssertEqual(engine.points(for: .a), 1)
        XCTAssertEqual(engine.server?.team, .a)
        XCTAssertEqual(engine.server?.court, .left, "odd score -> left court")
        engine.scorePoint(.a)
        XCTAssertEqual(engine.server?.court, .right, "even score -> right court again")
    }

    func testReceivingWinMakesReceiverServerAtParityCourt() {
        var engine = makeEngine()
        engine.scorePoint(.b)
        XCTAssertEqual(engine.points(for: .b), 1)
        XCTAssertEqual(engine.serving, .b)
        XCTAssertEqual(engine.server?.team, .b)
        XCTAssertEqual(engine.server?.court, .left, "new server at court matching own odd score")
        XCTAssertEqual(engine.receiver?.team, .a)
    }

    func testMidBreakTriggersAt11AndOnlyOnce() {
        var engine = makeEngine(winScore: 21)
        XCTAssertEqual(engine.setup.midScore, 11)
        for _ in 0..<10 { engine.scorePoint(.a) }
        XCTAssertEqual(engine.phase, .playing)
        engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .midBreak)
        engine.skipBreak()
        XCTAssertEqual(engine.phase, .playing)
        // Bob scores 4 to prove no re-trigger from the other side.
        for _ in 0..<4 { engine.scorePoint(.b) }
        XCTAssertEqual(engine.phase, .playing, "interval break happens once per game")
    }

    func testMidScoreFormula() {
        XCTAssertEqual(MatchSetup(winScore: 21).midScore, 11)
        XCTAssertEqual(MatchSetup(winScore: 15).midScore, 8)
        XCTAssertEqual(MatchSetup(winScore: 11).midScore, 6)
        XCTAssertEqual(MatchSetup(winScore: 30).midScore, 15)
    }

    func testGameEndsAtWinScoreWithTwoPointLead() {
        var engine = makeEngine(winScore: 21, winBy2: true)
        for _ in 0..<20 { rally(&engine, .a); rally(&engine, .b) }
        XCTAssertEqual(engine.phase, .playing, "20-20 deuce, not over")
        rally(&engine, .a)
        XCTAssertEqual(engine.phase, .playing, "21-20 needs a 2-point lead")
        rally(&engine, .a)
        XCTAssertEqual(engine.phase, .gameBreak, "22-20 ends the game")
        XCTAssertEqual(engine.completedGames.last?.teamA, 22)
        XCTAssertEqual(engine.completedGames.last?.teamB, 20)
    }

    func testWinBy2DisabledEndsAtTarget() {
        var engine = makeEngine(winScore: 21, winBy2: false)
        for _ in 0..<20 { rally(&engine, .a); rally(&engine, .b) }
        rally(&engine, .a)
        XCTAssertEqual(engine.phase, .gameBreak, "21-20 ends when 2-point lead not required")
    }

    func testNoMidBreakWhenGameEndsOnTheSameThreshold() {
        // winScore 1 -> midScore 1; game-over check must win over the break.
        var engine = makeEngine(winScore: 1, winBy2: false, bestOf: 1)
        engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .finished, "game over takes priority over interval break")
        XCTAssertNil(engine.breakDuration)
    }

    func testUndoRestoresStateIncludingBreak() {
        var engine = makeEngine()
        for _ in 0..<11 { engine.scorePoint(.a) }
        XCTAssertEqual(engine.phase, .midBreak)
        XCTAssertTrue(engine.canUndo)
        engine.undo()
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertEqual(engine.points(for: .a), 10)
        XCTAssertEqual(engine.rallies.count, 10)
        engine.undo()
        XCTAssertEqual(engine.points(for: .a), 9)
        XCTAssertEqual(engine.rallies.count, 9)
    }

    func testUndoDisabledAtMatchEnd() {
        var engine = makeEngine(winScore: 2, winBy2: false, bestOf: 1)
        rally(&engine, .a)
        engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertFalse(engine.canUndo)
        engine.undo()
        XCTAssertEqual(engine.points(for: .a), 2, "undo is a no-op after match end")
    }

    func testScoringIsIgnoredDuringBreak() {
        var engine = makeEngine()
        for _ in 0..<11 { engine.scorePoint(.a) }
        XCTAssertEqual(engine.phase, .midBreak)
        engine.scorePoint(.b)
        XCTAssertEqual(engine.points(for: .b), 0, "no scoring while on break")
    }
}
