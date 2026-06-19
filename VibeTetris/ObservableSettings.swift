import Foundation
import TetrisCore

@Observable
final class ObservableSettings {
    let raw: any GameSettings

    var playerName: String {
        get { raw.playerName }
        set { raw.playerName = newValue }
    }
    var lockImmediatelyAfterHardDrop: Bool {
        get { raw.lockImmediatelyAfterHardDrop }
        set { raw.lockImmediatelyAfterHardDrop = newValue }
    }
    var isHardDropAnimated: Bool {
        get { raw.isHardDropAnimated }
        set { raw.isHardDropAnimated = newValue }
    }
    var isLineClearAnimated: Bool {
        get { raw.isLineClearAnimated }
        set { raw.isLineClearAnimated = newValue }
    }
    var initialLevel: Int {
        get { raw.initialLevel }
        set { raw.initialLevel = newValue }
    }

    /// Production initializer — wraps `PersistentGameSettings` and sets animation defaults.
    init() {
        let settings = PersistentGameSettings()
        settings.isHardDropAnimated = true
        settings.isLineClearAnimated = true
        self.raw = settings
    }

    /// Injected initializer — for tests or other scenarios that provide their own `GameSettings`.
    init(raw: any GameSettings) {
        self.raw = raw
    }
}
