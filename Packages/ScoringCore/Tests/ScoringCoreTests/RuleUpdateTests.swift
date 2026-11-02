import XCTest
@testable import ScoringCore

final class RuleUpdateTests: XCTestCase {
    private func makeEngine(
        winScore: Int = 21,
        bestOf: Int = 3,
        winBy2: Bool = true,
        initialServing: TeamSide = .a
    ) -> MatchEngine {
        MatchEngine(
            setup: MatchSetup(
                mode: .singles,
                teamANames: ["Alice"],
                teamBNames: ["Bob"],
                initialServing: initialServing,
                winScore: winScore,
                bestOf: bestOf,
                winBy2: winBy2
            ),
            startedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func rally(_ engine: inout MatchEngine, _ side: TeamSide) {
        engine.scorePoint(side)
        if engine.phase == .midBreak { engine.skipBreak() }
    }

    // MARK: - Defaults (requirement: 15-point games, 60s interval break)

    func testUpdatedDefaults() {
        let setup = MatchSetup()
        XCTAssertEqual(setup.winScore, 15, "default win score is 15")
        XCTAssertEqual(setup.midBreakSeconds, 60, "default interval break is 60s")
        XCTAssertEqual(setup.midScore, 8, "15-point game: interval at 8")
    }

    // MARK: - Score caps

    func testCapAt30WinsOutright() {
        var engine = makeEngine(winScore: 21, winBy2: true)
        for _ in 0..<29 { rally(&engine, .a); rally(&engine, .b) }
        XCTAssertEqual(engine.points(for: .a), 29)
        XCTAssertEqual(engine.points(for: .b), 29)
        XCTAssertEqual(engine.phase, .playing, "29:29 still needs a 2-point lead below the cap")

        engine.scorePoint(.a)
        XCTAssertEqual(engine.phase, .gameBreak, "30:29 ends the game at the cap")
        XCTAssertEqual(engine.completedGames.last?.teamA, 30)
        XCTAssertEqual(engine.completedGames.last?.teamB, 29)
    }

    func testFifteenPointGameCapsAt21() {
        // 15-point games can reach deuce, but 21:20 decides at their lower cap.
        var engine = makeEngine(winScore: 15, winBy2: true)
        XCTAssertEqual(engine.setup.capScore, 21)
        for _ in 0..<19 { rally(&engine, .a); rally(&engine, .b) }
        engine.scorePoint(.a) // 20:19, lead only 1
        XCTAssertEqual(engine.phase, .playing, "20:19 below the cap still needs a 2-point lead")
        engine.scorePoint(.b) // 20:20
        XCTAssertEqual(engine.phase, .playing, "20:20 still deuce")
        XCTAssertTrue(engine.isGamePoint(.a), "at 20:20 either side wins the next point at the 21-point cap")
        XCTAssertTrue(engine.isGamePoint(.b), "at 20:20 either side wins the next point at the 21-point cap")
        engine.scorePoint(.a) // 21:20
        XCTAssertEqual(engine.phase, .gameBreak, "21 ends a 15-point game at the cap")
        XCTAssertEqual(engine.completedGames.last?.teamA, 21)
        XCTAssertEqual(engine.completedGames.last?.teamB, 20)
    }

    // MARK: - Match ends at majority (requirement: remaining games not played)

    func testMatchStopsOnceMajorityReached() {
        var engine = makeEngine(winScore: 2, bestOf: 3, winBy2: false)
        rally(&engine, .a)
        engine.scorePoint(.a) // game 1 -> A
        XCTAssertEqual(engine.phase, .gameBreak)
        engine.skipBreak()
        rally(&engine, .a)
        engine.scorePoint(.a) // game 2 -> A: majority of 2
        XCTAssertEqual(engine.phase, .finished, "match ends at 2 wins; game 3 never played")
        XCTAssertEqual(engine.completedGames.count, 2)
    }

    // MARK: - Manual first server for the next game (requirement 6)

    func testOverrideNextServerAppliesToNextGameOnly() {
        var engine = makeEngine(winScore: 2, bestOf: 3, winBy2: false, initialServing: .a)
        rally(&engine, .a)
        engine.scorePoint(.a) // game 1 done
        XCTAssertEqual(engine.phase, .gameBreak)

        engine.overrideNextServer(.a) // manual pick: keep A serving despite alternation
        engine.skipBreak()
        XCTAssertEqual(engine.serving, .a, "manual override wins over the alternating default")
        XCTAssertEqual(engine.gameIndex, 1)

        // Finish game 2 for B; override must NOT persist into game 3.
        rally(&engine, .b)
        engine.scorePoint(.b)
        XCTAssertEqual(engine.phase, .gameBreak)
        engine.skipBreak()
        XCTAssertEqual(engine.serving, .a, "game 3 falls back to the alternating default")
    }

    func testOverrideIgnoredOutsideGameBreak() {
        var engine = makeEngine()
        engine.overrideNextServer(.b)
        XCTAssertNil(engine.pendingNextServer, "override only accepted during the between-games break")
    }

    func testUndoRestoresPendingOverride() {
        var engine = makeEngine(winScore: 2, bestOf: 3, winBy2: false)
        rally(&engine, .a)
        engine.scorePoint(.a)
        engine.overrideNextServer(.b)
        XCTAssertNotNil(engine.pendingNextServer)
        engine.undo() // reverts to the last point of game 1 (pre-override snapshot chain)
        // After undoing the game-winning point the engine is back in game 1 playing.
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertNil(engine.pendingNextServer, "stale override must not leak into a later game advance")
    }

    // MARK: - Set initial server of the current game (0:0 only)

    func testSetInitialServerOnlyAtZeroZero() {
        var engine = makeEngine(initialServing: .a)
        engine.setInitialServer(.b)
        XCTAssertEqual(engine.serving, .b, "0:0 allows reassigning the first server")

        engine.scorePoint(.b) // 0:1 — rally underway
        engine.setInitialServer(.a)
        XCTAssertEqual(engine.serving, .b, "must not overwrite rally-derived serving mid-game")
    }

    func testSetInitialServerUndoable() {
        var engine = makeEngine(initialServing: .a)
        engine.setInitialServer(.b)
        XCTAssertEqual(engine.serving, .b)
        engine.undo()
        XCTAssertEqual(engine.serving, .a, "undo restores the original first server")
    }

    // MARK: - Game point / match point

    func testGamePointOneAwayWithWinBy2() {
        var engine = makeEngine(winScore: 21, winBy2: true)
        for _ in 0..<19 { rally(&engine, .a); rally(&engine, .b) }
        XCTAssertEqual(engine.points(for: .a), 19)
        XCTAssertFalse(engine.isGamePoint(.a), "20 would only tie at deuce, not win")

        engine.scorePoint(.a) // 20:19
        if engine.phase == .midBreak { engine.skipBreak() }
        XCTAssertTrue(engine.isGamePoint(.a), "21:19 wins with a 2-point lead")
        XCTAssertFalse(engine.isGamePoint(.b), "20:21 does not win for B")

        engine.scorePoint(.b) // 20:20
        XCTAssertFalse(engine.isGamePoint(.a), "deuce: need 2-point lead")
        XCTAssertFalse(engine.isGamePoint(.b))
    }

    func testGamePointNearCap() {
        var engine = makeEngine(winScore: 21, winBy2: true)
        for _ in 0..<28 { rally(&engine, .a); rally(&engine, .b) }
        engine.scorePoint(.a) // 29:28
        if engine.phase == .midBreak { engine.skipBreak() }
        XCTAssertTrue(engine.isGamePoint(.a), "30:28 wins by 2 (and hits the cap)")
        XCTAssertFalse(engine.isGamePoint(.b), "29:29 would not win for B")
        engine.scorePoint(.b) // 29:29
        XCTAssertTrue(engine.isGamePoint(.a), "30:29 hits the cap and wins outright")
        XCTAssertTrue(engine.isGamePoint(.b), "cap applies to either side")
    }

    func testGamePointWithoutWinBy2() {
        var engine = makeEngine(winScore: 15, winBy2: false)
        for _ in 0..<14 { rally(&engine, .a) } // 14:0 (mid-break skipped by rally)
        XCTAssertTrue(engine.isGamePoint(.a), "next point reaches 15 and wins outright")
        XCTAssertFalse(engine.isGamePoint(.b))
        engine.scorePoint(.a)
        XCTAssertFalse(engine.isGamePoint(.a), "game already decided")
        XCTAssertEqual(engine.phase, .gameBreak)
    }

    func testMatchPointOnlyWhenGameWinsMatch() {
        var engine = makeEngine(winScore: 2, bestOf: 3, winBy2: false)
        rally(&engine, .a) // 1:0 in game 1
        XCTAssertTrue(engine.isGamePoint(.a))
        XCTAssertFalse(engine.isMatchPoint(.a), "game 1 of best-of-3 does not win the match")
        engine.scorePoint(.a) // game 1 to A (1-0 games)
        engine.skipBreak()
        rally(&engine, .a) // 1:0 in game 2, gameWins 1-0
        XCTAssertTrue(engine.isGamePoint(.a))
        XCTAssertTrue(engine.isMatchPoint(.a), "game point in game 2 with a 1-0 lead wins the match")
    }

    func testNoGamePointAfterGameOver() {
        var engine = makeEngine(winScore: 2, winBy2: false)
        rally(&engine, .a)
        rally(&engine, .a)
        XCTAssertEqual(engine.phase, .gameBreak)
        XCTAssertFalse(engine.isGamePoint(.a), "game already over — no highlight")
    }
}
