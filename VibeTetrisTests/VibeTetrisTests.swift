//
//  VibeTetrisTests.swift
//  VibeTetrisTests
//

import Testing
import TetrisCore
@testable import VibeTetris

// MARK: - Helpers

/// A test view model with no live tick task — no game loop events fire during tests.
/// `apply()` is called directly with synthetic event sets.
@MainActor
func makeVM() -> GameViewModel {
    GameViewModel(
        controller: GameController(settings: TestGameSettings()),
        tickTask: nil
    )
}

// MARK: - Grid Size

@Suite("GameViewModel.apply")
struct ApplyTests {

    @Test("gridSize updates dimensions")
    @MainActor
    func gridSize() {
        let vm = makeVM()
        vm.apply([.gridSize(width: 12, height: 24)])
        #expect(vm.gridWidth == 12)
        #expect(vm.gridHeight == 24)
    }

    // MARK: - Grid

    @Test("grid replaces existing blocks")
    @MainActor
    func grid() {
        let vm = makeVM()
        let blocks: [PieceCoordinate: TetrominoColor] = [
            PieceCoordinate(x: 0, y: 19): .cyan,
            PieceCoordinate(x: 1, y: 19): .red,
        ]
        vm.apply([.grid(blocks)])
        #expect(vm.grid.count == 2)
        #expect(vm.grid[PieceCoordinate(x: 0, y: 19)] == .cyan)
        #expect(vm.grid[PieceCoordinate(x: 1, y: 19)] == .red)
    }

    // MARK: - Piece Blocks

    @Test("pieceBlocks updates blocks and color")
    @MainActor
    func pieceBlocks() {
        let vm = makeVM()
        let blocks: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 0), PieceCoordinate(x: 5, y: 0)]
        vm.apply([.pieceBlocks(blocks, color: .cyan, hardDropDuration: nil)])
        #expect(vm.pieceBlocks == blocks)
        #expect(vm.pieceColor == .cyan)
    }

    @Test("pieceBlocks with large Y delta triggers hard drop")
    @MainActor
    func hardDropDetection() {
        let vm = makeVM()
        // Simulate an existing piece at y=0
        let initial: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 0)]
        vm.apply([.pieceBlocks(initial, color: .cyan, hardDropDuration: nil)])

        // Next tick: piece jumped to y=10 with a duration -> hard drop
        let dropped: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 10)]
        vm.apply([.pieceBlocks(dropped, color: .cyan, hardDropDuration: 0.2)])
        #expect(vm.hardDropDeltaY == 10)
        #expect(vm.hardDropAnimDuration == 0.2)
        #expect(vm.hardDropTrigger == 1)
    }

    @Test("pieceBlocks with nil duration ends hard drop")
    @MainActor
    func hardDropEnd() {
        let vm = makeVM()
        // Put piece at y=0, then jump to y=10 (triggers hard drop)
        let initial: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 0)]
        vm.apply([.pieceBlocks(initial, color: .cyan, hardDropDuration: nil)])
        let dropped: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 10)]
        vm.apply([.pieceBlocks(dropped, color: .cyan, hardDropDuration: 0.2)])
        #expect(vm.hardDropTrigger == 1)

        // Next normal tick: no duration -> hard drop done
        let normal: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 10)]
        vm.apply([.pieceBlocks(normal, color: .cyan, hardDropDuration: nil)])
        #expect(vm.hardDropTrigger == 1) // trigger not incremented
    }

    @Test("small Y delta does not trigger hard drop")
    @MainActor
    func noFalseHardDrop() {
        let vm = makeVM()
        let initial: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 0)]
        vm.apply([.pieceBlocks(initial, color: .cyan, hardDropDuration: nil)])
        // Move down by 1 (normal gravity step)
        let oneRow: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 1)]
        vm.apply([.pieceBlocks(oneRow, color: .cyan, hardDropDuration: nil)])
        #expect(vm.hardDropTrigger == 0)
    }

    // MARK: - Next Piece

    @Test("nextPieceBlocks updates preview and color")
    @MainActor
    func nextPiece() {
        let vm = makeVM()
        let blocks: Set<PieceCoordinate> = [PieceCoordinate(x: 1, y: 0), PieceCoordinate(x: 2, y: 0)]
        vm.apply([.nextPieceBlocks(blocks, color: .yellow)])
        #expect(vm.nextPieceBlocks == blocks)
        #expect(vm.nextPieceColor == .yellow)
    }

    // MARK: - Ghost Piece

    @Test("ghostPieceBlocks updates landing preview")
    @MainActor
    func ghostPiece() {
        let vm = makeVM()
        let ghost: Set<PieceCoordinate> = [PieceCoordinate(x: 4, y: 15), PieceCoordinate(x: 5, y: 15)]
        vm.apply([.ghostPieceBlocks(ghost)])
        #expect(vm.ghostPieceBlocks == ghost)
    }

    // MARK: - Score, Level, Lines

    @Test("score updates")
    @MainActor
    func score() {
        let vm = makeVM()
        vm.apply([.score(1200)])
        #expect(vm.score == 1200)
    }

    @Test("level updates")
    @MainActor
    func level() {
        let vm = makeVM()
        vm.apply([.level(5)])
        #expect(vm.level == 5)
    }

    @Test("linesCleared with empty rows does not trigger animation")
    @MainActor
    func linesClearedNoAnimation() {
        let vm = makeVM()
        vm.apply([.linesCleared(10, clearedRows: [], animationDuration: 0)])
        #expect(vm.linesCleared == 10)
        #expect(vm.lineClearRows.isEmpty)
        #expect(vm.lineClearTrigger == 0)
    }

    @Test("linesCleared with rows triggers animation")
    @MainActor
    func linesClearedWithAnimation() {
        let vm = makeVM()
        vm.apply([.linesCleared(4, clearedRows: [19, 18], animationDuration: 0.25)])
        #expect(vm.linesCleared == 4)
        #expect(vm.lineClearRows == [19, 18])
        #expect(vm.lineClearAnimDuration == 0.25)
        #expect(vm.lineClearTrigger == 1)
    }

    // MARK: - Line Clear Snapshot Order Independence ⭐

    @Test("snapshot captures pre-clear grid regardless of Set order")
    @MainActor
    func snapshotBeforeGridReplace() {
        let vm = makeVM()

        // Pre-populate the grid with a settled block
        let initialBlock = PieceCoordinate(x: 0, y: 19)
        let initialGrid: [PieceCoordinate: TetrominoColor] = [initialBlock: .cyan]
        vm.grid = initialGrid

        // Batch contains both .grid (new state) and .linesCleared (with rows).
        // Set iteration order is undefined; the snapshot must always be the old grid.
        let newBlock = PieceCoordinate(x: 1, y: 18)
        let newGrid: [PieceCoordinate: TetrominoColor] = [newBlock: .red]
        let events: Set<GameEvent> = [
            .grid(newGrid),
            .linesCleared(4, clearedRows: [19], animationDuration: 0.25)
        ]
        vm.apply(events)

        // Snapshot should be the original pre-clear grid
        #expect(vm.lineClearGridSnapshot == initialGrid,
                "Snapshot must capture the grid before grid replacement")
        // Grid should be the new one
        #expect(vm.grid == newGrid,
                "Grid must be updated after apply")
    }

    @Test("snapshot only taken when lines are actually cleared")
    @MainActor
    func snapshotOnlyOnClear() {
        let vm = makeVM()
        let grid: [PieceCoordinate: TetrominoColor] = [PieceCoordinate(x: 0, y: 19): .cyan]
        vm.grid = grid

        // Same batch with empty clearedRows -> no snapshot
        vm.apply([.grid(grid), .linesCleared(0, clearedRows: [], animationDuration: 0)])
        #expect(vm.lineClearGridSnapshot == nil)
    }

    // MARK: - State

    @Test("state updates displayState")
    @MainActor
    func state() {
        let vm = makeVM()
        vm.apply([.state(.paused)])
        #expect(vm.displayState == .paused)

        vm.apply([.state(.gameOver)])
        #expect(vm.displayState == .gameOver)
    }

    // MARK: - Top Scores

    @Test("topScores updates leaderboard")
    @MainActor
    func topScores() {
        let vm = makeVM()
        let scores = [
            StoredScore(playerName: "Alice", score: 100),
            StoredScore(playerName: "Bob", score: 50),
        ]
        vm.apply([.topScores(scores)])
        #expect(vm.topScores.count == 2)
        #expect(vm.topScores[0].playerName == "Alice")
        #expect(vm.topScores[0].score == 100)
    }

    // MARK: - Player Name

    @Test("playerName updates identity")
    @MainActor
    func playerName() {
        let vm = makeVM()
        vm.apply([.playerName("TestPlayer")])
        #expect(vm.playerName == "TestPlayer")
    }

    // MARK: - Batch Order Independence

    @Test("same events produce identical state regardless of Set order")
    @MainActor
    func batchOrderIndependence() {
        let vm1 = makeVM()
        let vm2 = makeVM()

        // Pre-populate both with the same initial grid
        let initialGrid: [PieceCoordinate: TetrominoColor] = [
            PieceCoordinate(x: 0, y: 19): .cyan
        ]
        vm1.grid = initialGrid
        vm2.grid = initialGrid

        // Construct the same events but in different order (Set construction
        // can produce different internal ordering)
        let events1: Set<GameEvent> = [
            .gridSize(width: 10, height: 20),
            .grid([PieceCoordinate(x: 5, y: 19): .magenta]),
            .score(200),
            .level(2),
            .linesCleared(4, clearedRows: [19], animationDuration: 0.25),
            .state(.playing),
        ]
        // Reverse insertion order may produce different Set iteration
        let events2: Set<GameEvent> = [
            .state(.playing),
            .linesCleared(4, clearedRows: [19], animationDuration: 0.25),
            .level(2),
            .score(200),
            .grid([PieceCoordinate(x: 5, y: 19): .magenta]),
            .gridSize(width: 10, height: 20),
        ]

        vm1.apply(events1)
        vm2.apply(events2)

        #expect(vm2.gridWidth == vm1.gridWidth)
        #expect(vm2.gridHeight == vm1.gridHeight)
        #expect(vm2.grid == vm1.grid)
        #expect(vm2.score == vm1.score)
        #expect(vm2.level == vm1.level)
        #expect(vm2.linesCleared == vm1.linesCleared)
        #expect(vm2.lineClearRows == vm1.lineClearRows)
        #expect(vm2.lineClearGridSnapshot == vm1.lineClearGridSnapshot)
        #expect(vm2.displayState == vm1.displayState)
    }
}
