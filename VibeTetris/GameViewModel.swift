import SwiftUI
import TetrisCore

struct HardDropAnimation: Equatable {
    var deltaY: Int
    var duration: TimeInterval
}

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
    var hardDropTrigger = 0
    var hardDropAnimation: HardDropAnimation?

    private let controller: GameController
    private var tickTask: Task<Void, Never>?
    private var previousPieceMinY: Int?

    init() {
        controller = GameController(isHardDropAnimated: true)
        tickTask = Task { @MainActor in
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
    func pause() { Task { await controller.enqueue(.pause) } }
    func resume() { Task { await controller.enqueue(.resume) } }
    func stop() { Task { await controller.enqueue(.stop) } }

    private func apply(_ events: Set<GameEvent>) {
        for event in events {
            switch event {
            case .grid(let v): grid = v
            case .pieceBlocks(let v, let hardDropDuration):
                if let duration = hardDropDuration,
                   let prev = previousPieceMinY,
                   let cur = v.map(\.y).min(),
                   cur - prev > 1 {
                    print("[VM] Hard drop: prevY=\(prev) curY=\(cur) delta=\(cur-prev) duration=\(duration)")
                    hardDropTrigger &+= 1
                    hardDropAnimation = HardDropAnimation(deltaY: cur - prev, duration: duration)
                } else if hardDropDuration == nil {
                    hardDropAnimation = nil
                }
                previousPieceMinY = v.map(\.y).min() ?? previousPieceMinY
                pieceBlocks = v
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

extension Color {
    static let cream = Color(red: 0.992, green: 0.973, blue: 0.918)
    static let creamDark = Color(red: 0.949, green: 0.918, blue: 0.847)
}
