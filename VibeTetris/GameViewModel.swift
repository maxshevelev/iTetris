import SwiftUI
import TetrisCore

@Observable
final class GameViewModel {
    // MARK: - UI State

    var grid: [PieceCoordinate: TetrominoColor] = [:]
    var gridWidth = Constants.Grid.defaultWidth
    var gridHeight = Constants.Grid.defaultHeight
    var pieceBlocks: Set<PieceCoordinate> = []
    var pieceColor: TetrominoColor = Constants.Gameplay.defaultPieceColor
    var nextPieceBlocks: Set<PieceCoordinate> = []
    var nextPieceColor: TetrominoColor = Constants.Gameplay.defaultPieceColor
    var score = 0
    var level = Constants.Gameplay.defaultLevel
    var linesCleared = 0
    var displayState: GameDisplayState = .playing
    var topScores: [StoredScore] = []
    var playerName: String = ""
    var hardDropTrigger = 0
    var hardDropDeltaY: Int = 0
    var hardDropAnimDuration: TimeInterval = 0
    var isHardDropping = false
    var lineClearRows: Set<Int> = []
    var lineClearAnimDuration: TimeInterval = 0
    var lineClearTrigger = 0
    var newPieceTrigger = 0
    var lineClearGridSnapshot: [PieceCoordinate: TetrominoColor]?
    var ghostPieceBlocks: Set<PieceCoordinate> = []

    // MARK: - Dependencies

    private let controller: GameController
    private var tickTask: Task<Void, Never>?
    private var previousPieceMinY: Int?

    init(settings: ObservableSettings = ObservableSettings()) {
        let controller = GameController(settings: settings.raw)
        self.controller = controller
        self.tickTask = Task { @MainActor in
            for await events in controller.tick {
                apply(events)
            }
        }
    }

    /// Injected initializer — for tests.
    /// Pass `tickTask: nil` to suppress the live event loop.
    init(controller: GameController, tickTask: Task<Void, Never>?) {
        self.controller = controller
        self.tickTask = tickTask
    }

    deinit {
        tickTask?.cancel()
    }

    // MARK: - Actions

    func start() {
        Task { await controller.start() }
    }
    func restartGame() { Task { await controller.enqueue(ControlEvent.start) } }

    func moveLeft() { Task { await controller.enqueue(ControlEvent.moveLeft) } }
    func moveRight() { Task { await controller.enqueue(ControlEvent.moveRight) } }
    func rotate() { Task { await controller.enqueue(ControlEvent.rotate) } }
    func hardDrop() { Task { await controller.enqueue(ControlEvent.hardDrop) } }
    func pause() { Task { await controller.enqueue(ControlEvent.pause) } }
    func resume() { Task { await controller.enqueue(ControlEvent.resume) } }
    func stop() { Task { await controller.enqueue(ControlEvent.stop) } }

    func apply(_ events: Set<GameEvent>) {
        // Pass 1 — collect all event values without applying them.
        // This decouples the application order from Set's undefined iteration order.
        var gridSizeEvent: (w: Int, h: Int)?
        var gridEvent: [PieceCoordinate: TetrominoColor]?
        var pieceEvent: (blocks: Set<PieceCoordinate>, color: TetrominoColor, hardDropDuration: TimeInterval?)?
        var nextPieceEvent: (blocks: Set<PieceCoordinate>, color: TetrominoColor)?
        var scoreEvent: Int?
        var levelEvent: Int?
        var linesEvent: (total: Int, rows: Set<Int>, duration: TimeInterval)?
        var stateEvent: GameDisplayState?
        var topScoresEvent: [StoredScore]?
        var playerNameEvent: String?
        var ghostEvent: Set<PieceCoordinate>?

        for event in events {
            switch event {
            case .gridSize(let w, let h):          gridSizeEvent = (w, h)
            case .grid(let v):                     gridEvent = v
            case .pieceBlocks(let v, let c, let d): pieceEvent = (v, c, d)
            case .nextPieceBlocks(let v, let c):    nextPieceEvent = (v, c)
            case .ghostPieceBlocks(let v):          ghostEvent = v
            case .score(let v):                    scoreEvent = v
            case .level(let v):                    levelEvent = v
            case .linesCleared(let v, let r, let d): linesEvent = (v, r, d)
            case .state(let v):                    stateEvent = v
            case .topScores(let v):                topScoresEvent = v
            case .playerName(let v):               playerNameEvent = v
            }
        }

        // Pass 2 — apply in strict logical order.

        // 1. Board dimensions
        if let s = gridSizeEvent { gridWidth = s.w; gridHeight = s.h }

        // 2. Snapshot the grid BEFORE it is replaced (line-clear animation needs pre-clear state)
        if let line = linesEvent, !line.rows.isEmpty {
            lineClearGridSnapshot = grid
        }

        // 3. Grid
        if let v = gridEvent { grid = v }

        // 4. Current piece (includes hard-drop and new-piece detection)
        if let p = pieceEvent {
            pieceColor = p.color
            let cur = p.blocks.map(\.y).min()

            if let duration = p.hardDropDuration,
               let prev = previousPieceMinY,
               let cur = cur {
                // hardDropDuration != nil is the sole hard-drop signal — no threshold needed.
                hardDropTrigger &+= 1
                hardDropDeltaY = cur - prev
                hardDropAnimDuration = duration
                isHardDropping = true
            } else if p.hardDropDuration == nil {
                isHardDropping = false
            }

            // New piece detection: min-Y jumps to spawn row (0) from a higher value
            if let cur = cur,
               (previousPieceMinY == nil || previousPieceMinY! > 0),
               cur == 0 {
                newPieceTrigger &+= 1
            }

            previousPieceMinY = cur ?? previousPieceMinY
            pieceBlocks = p.blocks
        }

        // 5. Ghost piece (landing preview, provided by TetrisCore)
        if let v = ghostEvent { ghostPieceBlocks = v }

        // 6. Next piece
        if let n = nextPieceEvent { nextPieceColor = n.color; nextPieceBlocks = n.blocks }

        // 7. Score
        if let v = scoreEvent { score = v }

        // 8. Level
        if let v = levelEvent { level = v }

        // 9. Lines cleared (triggers burn animation)
        if let l = linesEvent {
            linesCleared = l.total
            if !l.rows.isEmpty {
                lineClearRows = l.rows
                lineClearAnimDuration = l.duration
                lineClearTrigger &+= 1
            }
        }

        // 10. Game state
        if let v = stateEvent { displayState = v }

        // 11. Leaderboard
        if let v = topScoresEvent { topScores = v }

        // 12. Player identity
        if let v = playerNameEvent { playerName = v }
    }
}

extension TetrominoColor {
    var swiftUIColor: Color {
        switch self {
        case .cyan:    .cyan
        case .yellow:  .yellow
        case .magenta: .purple
        case .green:   .green
        case .red:     .red
        case .blue:    .blue
        case .orange:  .orange
        }
    }
}
