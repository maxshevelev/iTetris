import Foundation
import SwiftUI

// MARK: - Keybinding Profile

enum KeybindingProfile: String, Codable, CaseIterable, Sendable {
    case vim
    case arrows
    case custom

    var label: String {
        switch self {
        case .vim:    return "Vim style"
        case .arrows: return "Arrows"
        case .custom: return "Custom"
        }
    }

    var presets: [String: String] {
        switch self {
        case .vim:
            return ["moveLeft": "j", "moveRight": "l", "rotate": "k",
                    "hardDrop": "Space", "resume": "Space", "pause": "Escape", "stop": "q"]
        case .arrows:
            return ["moveLeft": "LeftArrow", "moveRight": "RightArrow", "rotate": "UpArrow",
                    "hardDrop": "Space", "resume": "Space", "pause": "Escape", "stop": "q"]
        case .custom:
            return [:]
        }
    }
}

// MARK: - ControlsConfig

/// User-configurable key bindings for macOS controls.
/// Persisted to `controls.json` in the app's Application Support directory.
@Observable
final class ControlsConfig: Codable {
    var profile: KeybindingProfile = .custom
    var moveLeft: String = "j"
    var moveRight: String = "l"
    var rotate: String = "k"
    var hardDrop: String = "Space"
    var resume: String = "Space"
    var pause: String = "Escape"
    var stop: String = "q"

    /// All bindings as label → key pairs, in display order.
    static let allBindings: [(label: String, keyPath: ReferenceWritableKeyPath<ControlsConfig, String>)] = [
        ("Move Left",  \.moveLeft),
        ("Rotate",     \.rotate),
        ("Move Right", \.moveRight),
        ("Hard Drop",  \.hardDrop),
        ("Resume",     \.resume),
        ("Pause",      \.pause),
        ("Stop",       \.stop),
    ]

    /// Apply a preset and switch profile.
    func applyPreset(_ preset: KeybindingProfile) {
        profile = preset
        for (key, value) in preset.presets {
            switch key {
            case "moveLeft":  moveLeft  = value
            case "moveRight": moveRight = value
            case "rotate":    rotate    = value
            case "hardDrop":  hardDrop  = value
            case "resume":    resume    = value
            case "pause":     pause     = value
            case "stop":      stop      = value
            default: break
            }
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case profile, moveLeft, moveRight, rotate, hardDrop, resume, pause, stop
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile   = try container.decodeIfPresent(KeybindingProfile.self, forKey: .profile) ?? .custom
        moveLeft  = try container.decodeIfPresent(String.self, forKey: .moveLeft)  ?? moveLeft
        moveRight = try container.decodeIfPresent(String.self, forKey: .moveRight) ?? moveRight
        rotate    = try container.decodeIfPresent(String.self, forKey: .rotate)    ?? rotate
        hardDrop  = try container.decodeIfPresent(String.self, forKey: .hardDrop)  ?? hardDrop
        resume    = try container.decodeIfPresent(String.self, forKey: .resume)    ?? resume
        pause     = try container.decodeIfPresent(String.self, forKey: .pause)     ?? pause
        stop      = try container.decodeIfPresent(String.self, forKey: .stop)      ?? stop
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile,   forKey: .profile)
        try container.encode(moveLeft,  forKey: .moveLeft)
        try container.encode(moveRight, forKey: .moveRight)
        try container.encode(rotate,    forKey: .rotate)
        try container.encode(hardDrop,  forKey: .hardDrop)
        try container.encode(resume,    forKey: .resume)
        try container.encode(pause,     forKey: .pause)
        try container.encode(stop,      forKey: .stop)
    }

    // MARK: - Display Helpers

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

    // MARK: - Conflict Detection

    /// Returns pairs of action labels that share the same key binding.
    /// Only movement and drop actions are conflict-checked — resume, pause, and stop are excluded
    /// since they are context-sensitive (polar opposite of another action, or gated on game state).
    var conflicts: [(String, String)] {
        let checked = Self.allBindings.filter { $0.label != "Resume" && $0.label != "Pause" && $0.label != "Stop" }
        let entries = checked.map { ($0.label, self[keyPath: $0.keyPath]) }
        var result: [(String, String)] = []
        for i in entries.indices {
            for j in (i + 1)..<entries.count {
                if entries[i].1 == entries[j].1 {
                    result.append((entries[i].0, entries[j].0))
                }
            }
        }
        return result
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
        profile   = decoded.profile
        moveLeft  = decoded.moveLeft
        moveRight = decoded.moveRight
        rotate    = decoded.rotate
        hardDrop  = decoded.hardDrop
        resume    = decoded.resume
        pause     = decoded.pause
        stop      = decoded.stop
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
