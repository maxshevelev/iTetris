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

    init() {
        let settings = PersistentGameSettings()
        settings.isHardDropAnimated = true
        settings.isLineClearAnimated = true
        self.raw = settings
    }
}
