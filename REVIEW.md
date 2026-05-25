# VibeTetris — Code Review

## Overview

**VibeTetris** is a SwiftUI-based Tetris game targeting both iOS and macOS. Game logic lives in the external `TetrisCore` package (authored by the same developer); this project is the full-stack UI layer — board rendering, animations, input handling, settings, and presentation state.

The codebase is clean, concise (~600 lines of Swift across 8 files), and makes good use of modern Swift/SwiftUI features (`@Observable`, `AsyncSequence`, `Canvas`, `Task` with `@MainActor`). The animation system is visually rich (hard drop ghosting, line-clear fire bursts).

---

## What Works Well

- **Clean separation of concerns.** `TetrisCore` owns all game logic. `GameViewModel` bridges the core event stream to declarative UI state. Each view file has a single responsibility.
- **Modern Swift patterns.** Uses `@Observable` (iOS 17/macOS 14), `AsyncSequence` for event streaming, `Canvas` for performant rendering, and structured concurrency throughout.
- **Cross-platform done right.** macOS gets keyboard input, a `Settings` scene with a `SettingsView`, and an `AppDelegate` for "quit on window close". iOS gets gesture-based controls. Both platforms share the same `ContentView` body.
- **Rich animation architecture.** Hard drops render an overlay of the piece sliding down; line clears explode cells outward with radial fire gradients. Triggers are timestamp-coordinated with `Task.sleep` to avoid race conditions between Core Animation and the game event stream.
- **Settings are observable and persisted.** `ObservableSettings` wraps the core's `PersistentGameSettings` and projects writable properties for SwiftUI bindings.
- **Good git history hygiene.** 19 commits with atomic, well-scoped changes. Each commit message explains *why*, not just *what*.

---

## Issues & Suggestions

### 1. 🐛 "Play Again" fires `hardDrop()` instead of restarting the game

**File:** `ContentView.swift`, game over overlay

```swift
Button("Play Again") {
    viewModel.hardDrop()
}
```

This sends a `.hardDrop` action while the game state is `.gameOver`. If `TetrisCore` happens to interpret this as a restart, that's an implicit contract that will break if the core ever changes. A dedicated `start()` call (or a new `restart()` entry point) would be clearer and safer.

**Recommendation:** Call `viewModel.start()` or add a `restart()` action to `GameController` / `GameViewModel`.

---

### 2. 🤔 Hard drop detection heuristic is fragile

**File:** `GameViewModel.swift`, inside `apply()`

```swift
if let prev = previousPieceMinY,
   let cur = v.map(\.y).min(),
   cur - prev > 1 {
    hardDropTrigger &+= 1
    ...
}
```

A hard drop is inferred by detecting a vertical jump greater than 1 row. While this matches normal game physics (gravity moves 1 row/tick), it couples the animation trigger to an assumption about game speed. If a future game mode allows falling 2 rows per tick, the hard drop animation will fire on every gravity step.

**Recommendation:** Have `TetrisCore` emit an explicit `GameEvent.hardDropStarted(duration:)` instead of nesting the duration inside `.pieceBlocks`. Likewise `isHardDropping = false` is set when `hardDropDuration == nil` — an explicit `.hardDropCompleted` event would be more intention-revealing.

---

### 3. ⚠️ Line-clear snapshot may capture already-cleared rows

**File:** `GameViewModel.swift`, inside `apply()`

```swift
if hasLineClear { lineClearGridSnapshot = grid }

for event in events {
    case .grid(let v): grid = v
    case .linesCleared(...): ...
}
```

Events in the batch are processed in an unspecified order. If `.grid` updates are applied *before* `.linesCleared` in the same batch, the snapshot will already be the post-clear grid. The code currently works because `TetrisCore` probably emits `.linesCleared` before `.grid` in the same set, but the iteration order over `Set<GameEvent>` is undefined — this is a latent bug.

**Recommendation:** Take the snapshot at the point where the old grid is still present. Either (a) save the snapshot before applying *any* event in the batch, or (b) ask `TetrisCore` to include the pre-clear rows in the `.linesCleared` payload directly.

---

### 4. 📐 Hard drop overlay can render blocks off-screen

**File:** `ContentView.swift`, `hardDropPieceView()`

The `TetrisBoardView` guards against out-of-bounds rendering with `guard block.y >= 0, block.x >= 0, ...`. The hard drop overlay in `ContentView` does not — it renders all `pieceBlocks` unconditionally using `minX`/`minY` offsets. If the piece's bounding box extends below the board during animation, cells will render below the canvas.

**Recommendation:** Add the same bounds check, or rely on `.clipShape` by wrapping the overlay in a clipped container that matches the board dimensions.

---

### 5. 🔢 Magic numbers in line-clear animation

**File:** `ContentView.swift`, `cellBurst(cp:cellSize:)`

```swift
let flash: CGFloat = cp < 0.06 ? 1.0 : max(0, 1.0 - (cp - 0.06) / 0.15)
let glowScale: CGFloat = cp < 0.08 ? 0.6 : (cp < 0.35 ? 0.6 + 1.2 * (cp - 0.08) / 0.27 : max(0.1, 1.8 - 1.7 * (cp - 0.35) / 0.65))
let coreScale: CGFloat = cp < 0.5 ? 1.0 : max(0, 1.0 - (cp - 0.5) / 0.5)
let coreOpacity: CGFloat = cp < 0.4 ? 1.0 : max(0, 1.0 - (cp - 0.4) / 0.4)
```

These phase thresholds (0.06, 0.08, 0.15, 0.27, 0.35, 0.4, 0.5, 0.65) are tuned entirely by feel and aren't self-documenting. A future maintainer won't know which value controls the flash burst vs. the fire fade.

**Recommendation:** Extract named constants or a small struct `LineClearPhase(flash, glowScale, coreScale, coreOpacity: (CGFloat) -> CGFloat)` that documents each visual stage.

---

### 6. ⏱️ `Task.sleep(duration + 0.05)` buffer is fragile

**File:** `ContentView.swift`, hard drop and line clear animation callbacks

```swift
try? await Task.sleep(for: .seconds(duration + 0.05))
isAnimatingHardDrop = false
```

A 50ms safety margin avoids the SwiftUI animation ending just before the sleep fires. This works but isn't robust against device performance variation or a future SwiftUI rendering engine change.

**Recommendation:** Use `withAnimation(..., completionCriteria: .logicallyComplete) { ... } completion: { ... }` (available from iOS 17/macOS 14) to get a guaranteed callback. If the animation duration comes from `TetrisCore`, use it to create an explicit animation, then notify completion through the built-in callback.

---

### 7. 🧪 Zero test coverage

**File:** `VibeTetrisTests/VibeTetrisTests.swift`

```swift
@Test func example() async throws {
    // Write your test here...
}
```

The test target has a single placeholder. `GameViewModel.apply()` has complex event processing (grid merges, hard drop detection, line clear snapshotting, scoring updates) and no tests. The UI test target is equally empty.

**Recommendation:**
- Unit-test `apply()` by constructing `Set<GameEvent>` inputs and asserting the resulting `@Observable` properties.
- Snapshot-test the `TetrisBoardView` and `PiecePreviewView` Canvas output with known grid/piece inputs.
- UI-test the gesture flow (drag → piece moves) at a high level.

---

### 8. ♿ No accessibility support

No `.accessibilityLabel()`, `.accessibilityValue()`, or VoiceOver-friendly annotations exist for the board, pieces, score display, or control buttons. A blind or low-vision player cannot use the game.

**Recommendation at minimum:**
- Give the board a label and value describing the current piece position and score.
- Make the "Stop", "Resume", "Play Again" buttons accessible.
- Consider a "voice command" mode if TetrisCore exposes grid state for spoken feedback.

---

### 9. 📏 `TetrisBoardView` draws every grid cell every frame

**File:** `TetrisBoardView.swift`

```swift
for y in 0..<gridHeight {
    for x in 0..<gridWidth {
        context.fill(Path(rect), with: .color(.white))
        context.stroke(Path(rect), ...)
    }
}
```

A 10×20 grid draws 200 white rectangles + 200 strokes every frame (~400 Path operations). In practice this is fine for a 10×20 board on modern hardware, but it's worth noting the `Canvas` redraws entirely whenever the observable grid/piece state changes.

**Recommendation:** Pre-compute the background stripe pattern into a static image or `GraphicsContext.ResolvedImage` once, then draw it as a single blit, overlaying only occupied cells. Not urgent unless profiling shows a problem.

---

### 10. 📁 `ObservableSettings` existentials

**File:** `ObservableSettings.swift`

```swift
let raw: any GameSettings
```

Using `any GameSettings` (an existential protocol) means every property access goes through the existential witness table. For a settings object accessed only on user interaction this is harmless. However, if `TetrisCore` were to read settings on every tick (e.g., `isHardDropAnimated` in the controller loop), the existential dispatch would add a small overhead.

**Recommendation:** If `TetrisCore` reads these values internally via its own concrete type reference (which it likely does — `ObservableSettings` only wraps), there's no issue. Just something to keep in mind if performance profiling ever flags it.

---

### 11. 🎮 macOS keyboard mapping is Vim-style (subjective)

**File:** `ContentView.swift`, `handleKeyPress()`

```swift
case .init("j"): viewModel.moveLeft()
case .init("l"): viewModel.moveRight()
case .init("k"): viewModel.rotate()
```

Arrow keys are the conventional choice for Tetris. The `hjkl` mapping is clever for Vim users but discoverability is zero — there's no on-screen hint or settings toggle.

**Recommendation:** Add arrow key bindings as a fallback, or show the key map in the Info panel on macOS.

---

## Summary

| Category        | Rating   |
|-----------------|----------|
| Architecture    | ⭐⭐⭐⭐ |
| Code quality    | ⭐⭐⭐⭐ |
| Visual design   | ⭐⭐⭐⭐⭐ |
| Test coverage   | ⭐ (empty)    |
| Accessibility   | ⭐ (none)     |
| Robustness      | ⭐⭐⭐   |

The project is well-structured, visually impressive, and clearly built with care. The main risks are the "Play Again" bug, the implicit hard drop detection heuristic, and the undefined event iteration order for line-clear snapshots. Addressing those three items and adding basic unit tests for `GameViewModel.apply()` would elevate the codebase from "great prototype" to "production-ready."

---
*Review by project analysis. 2026-05-25.*
