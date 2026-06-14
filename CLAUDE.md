# CLAUDE.md — VibeTetris

## Architecture & Stack

- **UI:** SwiftUI (iOS 17+ / macOS 14+) with `@Observable` macro, `Canvas` rendering
- **TetrisCore branch:** `main` (SRS rotation wall kicks, `.start` restart event, ghost piece event)
- **Cross-platform:** Single codebase; macOS gets `Settings` scene, keyboard input, AppDelegate; iOS gets gesture controls
- **State flow:** `GameController` (actor) → `AsyncStream<Set<GameEvent>>` → `GameViewModel.apply()` → `@Observable` properties → SwiftUI views
- **Settings:** `PersistentGameSettings` from TetrisCore, proxied through `ObservableSettings` for SwiftUI bindings
- **Animations:** Hard-drop overlay + flash, line-clear "burn" overlay with phase-driven radial gradients

## Key Files & Responsibilities

| File | Role |
|---|---|
| `VibeTetrisApp.swift` | `@main` entry point, macOS app delegate, Settings scene |
| `ContentView.swift` | Root view with platform-conditional bodies: `macOSBody` (board + info panel) and `iOSBody` (top bar with Settings + next piece + Pause, centered board, bottom stats bar). Animation overlays, gestures, keyboard handling |
| `GameViewModel.swift` | Bridges TetrisCore event stream to `@Observable` UI state. Two-pass `apply()`: collect → strict-order apply. Hard-drop detection. |
| `TetrisBoardView.swift` | Three-layer `Canvas` board rendering: background grid (cached), locked blocks (cached), ghost + active piece (dynamic) |
| `InfoPanelView.swift` | Score, level, lines, next-piece preview, Stop button (macOS only) |
| `PiecePreviewView.swift` | `Canvas` rendering of the next-piece miniature (4×4 grid) |
| `ObservableSettings.swift` | Thin wrapper around `any GameSettings`, exposing writable properties for SwiftUI |
| `ControlsConfig.swift` | `@Observable` class for configurable keybindings, persisted to `controls.json`. Three profiles (Vim style, Arrows, Custom). Conflict detection excludes resume/pause/stop (context-sensitive actions) |
| `SettingsView.swift` | macOS Settings window: General tab (player name, gameplay, animations) + Controls tab (key capture, profile picker) |
| `IOSSettingsView.swift` | iOS Settings sheet: Player, Gameplay, Animations, Display (zone indicators toggle) sections (no key bindings) |
| `GestureHandler.swift` | Dynamic-zone iOS gesture system: intent locked on touch begin based on finger X vs piece center X, DAS/ARR auto-repeat, hard drop on swipe down, haptic feedback, `resetForNewPiece()` lifecycle |
| `Constants.swift` | Centralized namespace: `Grid`, `Colors` (app + line-clear fire), `Layout` (board/info-panel/hard-drop/overlay/settings/iOS dimensions), `Animation` (phase thresholds, flash timing), `Input`, `Gameplay` |

## Build

- **iPhone build destination:** `platform=iOS Simulator,name=iPhone 17 Pro` — always use this for iOS builds.

## Conventions & Constraints

- **Configurable keybindings (macOS).** `ControlsConfig` reads/writes `controls.json` with three profiles (Vim style, Arrows, Custom). Conflict detection warns when two movement/drop actions share the same key; resume, pause, and stop are excluded (context-sensitive). Auto-switches to Custom profile when an individual key is changed.
- **No magic numbers.** All sizes, opacities, durations, and colors live in `Constants.swift` organized by sub-enum.
- **Three-layer board rendering.** `GridBackgroundView` + `LockedBlocksView` use `.drawingGroup()` caching; only the ghost/active-piece `Canvas` redraws every tick. Never iterate the full grid on movement ticks.
- **Event processing is order-independent.** `GameViewModel.apply()` uses a two-pass collector-then-apply pattern. Pass 1 gathers values without side effects; Pass 2 applies in a strict logical order (dimensions → grid snapshot → grid → piece → …). Never rely on `Set` iteration order.
- **Animation completion uses `withAnimation(completionCriteria: .logicallyComplete) { } completion: { }`**, not `Task.sleep` buffers.
- **Ghost piece** is provided by TetrisCore via `.ghostPieceBlocks` event (no local computation).
- **Colors** are defined in `Constants.Colors`; never inline `Color(red:green:blue:)` in views.
- **TetrominoColor → SwiftUI Color** mapping lives in `GameViewModel.swift` as a single `swiftUIColor` extension.
- **`#Preview`** macros are included at the bottom of each view file.
- **iOS layout.** `iOSBody` uses a three-section vertical stack: top bar (Settings gear button left, next-piece preview center, Pause/Resume button right), centered board with breathing room, bottom stats bar (Level, Score, Lines). All dimensions in `Constants.Layout.iOS`.
- **iOS Settings.** `IOSSettingsView` presents as a `.sheet()` from the Settings button. Tapping Settings auto-pauses the game. Uses local `@State` synced via `onChange` for `ObservableSettings`. Guarded with `#if os(iOS)`.
- **iOS gestures.** Dynamic-zone system via `GestureHandler`: zones computed relative to active piece horizontal position. On touch begin, intent (left/right/rotate) is locked based on finger X vs piece center X; intent persists for entire touch duration regardless of finger/piece movement. DAS = 170ms, ARR = 50ms (NES Tetris standards). Hold auto-repeat uses locked intent. Swipe down = hard drop (priority, fires once per gesture). Left/right intent fires on tap-and-drag (no distance check); rotate requires `minimumSwipeDistance` check. Zone indicators update reactively as piece moves, flash during gesture, and are toggleable via Settings → Display → "Zone indicators" (non-persistent). Haptic feedback: light for move, medium for rotate, heavy for hard drop. `DragGesture(minimumDistance: 0)` for touch tracking. `LongPressGesture` fires after DAS delay to start ARR loop. `resetForNewPiece()` called on `pieceBlocks` change to reset `hasHardDropped`, guarded by `isGestureActive`.

## Active Tasks & Status

| Task | Status |
|---|---|
| Extract magic numbers to Constants namespace | ✅ Done |
| Address review item 3 (Set iteration order) | ✅ Done — two-pass apply |
| Address review item 6 (Task.sleep buffer) | ✅ Done — withAnimation completion |
| Ghost piece rendering | ✅ Done |
| Review item 1 (Play Again button bug) | ✅ Done — `.start` control event |
| Review item 4 (Hard-drop overlay off-screen) | ⚠️ Open |
| Board rendering optimization | ✅ Done — three-layer with drawingGroup() caching |
| Test coverage | ✅ Done — 13 unit tests for GameViewModel.apply() |
| Configurable keybindings with profiles | ✅ Done |
| iOS dedicated layout | ✅ Done |
| iOS Settings sheet | ✅ Done |
| iOS three-zone gesture system with DAS/ARR | ✅ Done |
| iOS dynamic zones with intent locking | ✅ Done |

---

> **Rule:** Update this file on every commit that introduces a notable architectural change, adds/removes a file, or completes an active task.
