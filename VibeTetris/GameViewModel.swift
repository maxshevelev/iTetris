import SwiftUI
import TetrisCore

@Observable
final class GameViewModel {
    var grid: [[BlockState]] = []
    var pieceBlocks: [PieceBlock] = []
    var nextPieceBlocks: [PieceBlock] = []
    var score = 0
    var level = 1
    var linesCleared = 0
    var displayState: GameDisplayState = .playing
    var topScores: [StoredScore] = []
    var playerName: String = ""

    private let controller: GameController
    private var tickTask: Task<Void, Never>?

    init() {
        controller = GameController(onGameFinished: {})
        tickTask = Task {
            for await events in controller.tick {
                apply(events)
            }
        }
    }

    func start() {
        Task { await controller.start() }
    }

    func moveLeft() { Task { await controller.enqueue(.moveLeft) } }
    func moveRight() { Task { await controller.enqueue(.moveRight) } }
    func rotate() { Task { await controller.enqueue(.rotate) } }
    func hardDrop() { Task { await controller.enqueue(.hardDrop) } }
    func togglePause() { Task { await controller.enqueue(.esc) } }
    func quit() { Task { await controller.enqueue(.quit) } }

    private func apply(_ events: Set<GameEvent>) {
        for event in events {
            switch event {
            case .grid(let v): grid = v
            case .pieceBlocks(let v): pieceBlocks = v
            case .nextPieceBlocks(let v): nextPieceBlocks = v
            case .score(let v): score = v
            case .level(let v): level = v
            case .linesCleared(let v): linesCleared = v
            case .state(let v): displayState = v
            case .topScores(let v): topScores = v
            case .playerName(let v): playerName = v
            }
        }
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
