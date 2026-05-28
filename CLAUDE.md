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
| `ContentView.swift` | Root view: board, info panel, animation overlays, gestures, keyboard handling |
| `GameViewModel.swift` | Bridges TetrisCore event stream to `@Observable` UI state. Two-pass `apply()`: collect → strict-order apply. Ghost piece computation. Hard-drop detection. |
| `TetrisBoardView.swift` | Three-layer `Canvas` board rendering: background grid (cached), locked blocks (cached), ghost + active piece (dynamic) |
| `InfoPanelView.swift` | Score, level, lines, next-piece preview, Stop button |
| `PiecePreviewView.swift` | `Canvas` rendering of the next-piece miniature (4×4 grid) |
| `ObservableSettings.swift` | Thin wrapper around `any GameSettings`, exposing writable properties for SwiftUI |
| `ControlsConfig.swift` | `@Observable` class for configurable keybindings, persisted to `controls.json` |
| `SettingsView.swift` | macOS Settings window: General tab (player name, gameplay, animations) + Controls tab (key capture) |
| `Constants.swift` | Centralized namespace: `Grid`, `Colors` (app + line-clear fire), `Layout` (board/info-panel/hard-drop/overlay/settings dimensions), `Animation` (phase thresholds, flash timing), `Input`, `Gameplay` |

## Conventions & Constraints

- **Configurable keybindings (macOS).** `ControlsConfig` reads/writes `controls.json` with three profiles (Vim style, Arrows, Custom). Conflict detection warns when two actions share the same key.
- **No magic numbers.** All sizes, opacities, durations, and colors live in `Constants.swift` organized by sub-enum.
- **Three-layer board rendering.** `GridBackgroundView` + `LockedBlocksView` use `.drawingGroup()` caching; only the ghost/active-piece `Canvas` redraws every tick. Never iterate the full grid on movement ticks.
- **Event processing is order-independent.** `GameViewModel.apply()` uses a two-pass collector-then-apply pattern. Pass 1 gathers values without side effects; Pass 2 applies in a strict logical order (dimensions → grid snapshot → grid → piece → …). Never rely on `Set` iteration order.
- **Animation completion uses `withAnimation(completionCriteria: .logicallyComplete) { } completion: { }`**, not `Task.sleep` buffers.
- **Ghost piece** is now provided by TetrisCore via `.ghostPieceBlocks` event (no local computation).
- **Colors** are defined in `Constants.Colors`; never inline `Color(red:green:blue:)` in views.
- **TetrominoColor → SwiftUI Color** mapping lives in `GameViewModel.swift` as a single `swiftUIColor` extension.
- **`#Preview`** macros are included at the bottom of each view file.

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

---

> **Rule:** Update this file on every commit that introduces a notable architectural change, adds/removes a file, or completes an active task.
