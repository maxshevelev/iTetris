import Foundation
import TetrisCore

/// In-memory GameSettings — does not touch disk.
/// Safe for use in tests; each instance is independent.
final class TestGameSettings: GameSettings, @unchecked Sendable {
    private let lock = NSLock()

    private var _playerName: String
    private var _lockImmediately: Bool
    private var _hardDropAnimated: Bool
    private var _lineClearAnimated: Bool
    private var _initialLevel: Int
    private var _ghostPieceEnabled: Bool

    var playerName: String {
        get { lock.withLock { _playerName } }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            lock.withLock { _playerName = trimmed }
        }
    }

    var lockImmediatelyAfterHardDrop: Bool {
        get { lock.withLock { _lockImmediately } }
        set { lock.withLock { _lockImmediately = newValue } }
    }

    var isHardDropAnimated: Bool {
        get { lock.withLock { _hardDropAnimated } }
        set { lock.withLock { _hardDropAnimated = newValue } }
    }

    var isLineClearAnimated: Bool {
        get { lock.withLock { _lineClearAnimated } }
        set { lock.withLock { _lineClearAnimated = newValue } }
    }

    var initialLevel: Int {
        get { lock.withLock { _initialLevel } }
        set { lock.withLock { _initialLevel = min(10, max(1, newValue)) } }
    }

    var isGhostPieceEnabled: Bool {
        get { lock.withLock { _ghostPieceEnabled } }
        set { lock.withLock { _ghostPieceEnabled = newValue } }
    }

    func addListener(_ listener: SettingsUpdateListener) {}
    func removeListener(_ listener: SettingsUpdateListener) {}

    init(
        playerName: String = "TestPlayer",
        lockImmediatelyAfterHardDrop: Bool = false,
        isHardDropAnimated: Bool = true,
        isLineClearAnimated: Bool = true,
        initialLevel: Int = 1,
        isGhostPieceEnabled: Bool = true
    ) {
        self._playerName = playerName
        self._lockImmediately = lockImmediatelyAfterHardDrop
        self._hardDropAnimated = isHardDropAnimated
        self._lineClearAnimated = isLineClearAnimated
        self._initialLevel = initialLevel
        self._ghostPieceEnabled = isGhostPieceEnabled
    }
}
