import Foundation
import SwiftUI

/// User-configurable key bindings for macOS controls.
/// Persisted to `controls.json` in the app's Application Support directory.
@Observable
final class ControlsConfig: Codable {
    var moveLeft: String = "j"
    var moveRight: String = "l"
    var rotate: String = "k"
    var hardDrop: String = "Space"
    var pause: String = "Escape"
    var stop: String = "q"

    enum CodingKeys: String, CodingKey {
        case moveLeft, moveRight, rotate, hardDrop, pause, stop
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        moveLeft  = try container.decodeIfPresent(String.self, forKey: .moveLeft)  ?? moveLeft
        moveRight = try container.decodeIfPresent(String.self, forKey: .moveRight) ?? moveRight
        rotate    = try container.decodeIfPresent(String.self, forKey: .rotate)    ?? rotate
        hardDrop  = try container.decodeIfPresent(String.self, forKey: .hardDrop)  ?? hardDrop
        pause     = try container.decodeIfPresent(String.self, forKey: .pause)     ?? pause
        stop      = try container.decodeIfPresent(String.self, forKey: .stop)      ?? stop
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(moveLeft,  forKey: .moveLeft)
        try container.encode(moveRight, forKey: .moveRight)
        try container.encode(rotate,    forKey: .rotate)
        try container.encode(hardDrop,  forKey: .hardDrop)
        try container.encode(pause,     forKey: .pause)
        try container.encode(stop,      forKey: .stop)
    }

    /// Human-readable label for a stored key string.
    static func displayName(for key: String) -> String {
        switch key {
        case "Space":   return "Space"
        case "Escape":  return "Esc"
        case "Return":  return "Return"
        case "Tab":     return "Tab"
        case "UpArrow":   return "↑"
        case "DownArrow": return "↓"
        case "LeftArrow": return "←"
        case "RightArrow":return "→"
        default:        return key.uppercased()
        }
    }

    /// Convert a SwiftUI `KeyEquivalent` to a config string suitable for storage and matching.
    static func keyString(from key: KeyEquivalent) -> String {
        if key == .space     { return "Space" }
        if key == .escape    { return "Escape" }
        if key == .return    { return "Return" }
        if key == .tab       { return "Tab" }
        if key == .upArrow   { return "UpArrow" }
        if key == .downArrow { return "DownArrow" }
        if key == .leftArrow { return "LeftArrow" }
        if key == .rightArrow{ return "RightArrow" }
        return String(key.character).lowercased()
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "home.maxik.VibeTetris"
        let dir = appSupport.appendingPathComponent(bundleID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("controls.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return }
        moveLeft  = decoded.moveLeft
        moveRight = decoded.moveRight
        rotate    = decoded.rotate
        hardDrop  = decoded.hardDrop
        pause     = decoded.pause
        stop      = decoded.stop
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
