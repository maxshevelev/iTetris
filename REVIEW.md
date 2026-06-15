# iOS Gesture System — Deep Review

## Overview

The iOS gesture system uses a dynamic 3-zone layout (left / rotate / right) computed around the active piece's horizontal center. Intent is locked on touch begin, DAS/ARR auto-repeat fires via `LongPressGesture` + `Task.sleep`, and horizontal/vertical swipes are detected on release. Zone indicators provide visual feedback.

**Key files:**
- `GestureHandler.swift` — transient gesture state, intent, hold/ARR loop, haptics
- `ContentView.swift` (iOSBody) — `DragGesture` + `LongPressGesture` wiring, zone calculation, zone indicator rendering
- `Constants.swift` — DAS (170ms), ARR (50ms), thresholds

---

## Findings

### 🔴 Bugs

#### 1. `hasSwiped` stale state on rapid taps

**Location:** `GestureHandler.swift:20` + `ContentView.swift:286`

`hasSwiped` is set to `true` in `onEnded` when a swipe is detected but is **never cleared in `onEnded`**. It only gets reset by `resetSwipe()` (called in `onChanged` when `!isGestureActive`) or `resetForNewPiece()`.

**Scenario:** Fast swipe → `hasSwiped = true`. Immediate second tap (before new piece). If `onChanged` doesn't fire on the second tap — the very edge case the `gestureStartZoneLayout` fallback exists for — `hasSwiped` is still `true`. The `LongPressGesture` guard at line 353 (`guard !gestureHandler.hasSwiped`) would **wrongly suppress hold auto-repeat** on the second gesture.

**Fix:** Clear `hasSwiped` at the top of `onEnded` before processing, or reset it when `isGestureActive` transitions to `false`.

```swift
// In onEnded, before any processing:
gestureHandler.hasSwiped = false
```

#### 2. `resetForNewPiece()` fires on every `pieceBlocks` change — not just new spawns

**Location:** `ContentView.swift:378-384`

```swift
.onChange(of: viewModel.pieceBlocks) {
    guard !gestureHandler.isGestureActive else { return }
    gestureHandler.resetForNewPiece()
}
```

`pieceBlocks` changes on **every game tick** — gravity drop, rotation, hard drop, and new piece spawn. `resetForNewPiece()` clears both `hasHardDropped` and `hasSwiped`. The `!isGestureActive` guard means it only fires when no gesture is active, which limits the blast radius, but the intent is wrong: this should only fire when a new piece spawns, not on every tick.

This also partially masks Bug #1 (clearing `hasSwiped` on every tick), making the codebase fragile — if the guard condition ever changes, Bug #1 becomes much more severe.

**Fix:** Respond to a "new piece" signal rather than `pieceBlocks` changes. Options:
- Add a `newPieceTrigger` counter in `GameViewModel` (like `hardDropTrigger`), or
- Detect new-piece by checking if `pieceBlocks` min-Y jumped to the spawn row (0).

#### 3. Race: `holdStart` can fire after `onEnded` for gestures ≈ DAS duration

**Location:** `ContentView.swift:348-356`

`LongPressGesture(minimumDuration: DAS)` fires its `onEnded` exactly at the DAS mark. If the user lifts their finger at ~170ms, the `DragGesture.onEnded` and `LongPressGesture.onEnded` are essentially simultaneous. Swift concurrency doesn't guarantee ordering here.

If `LongPressGesture.onEnded` runs **after** `DragGesture.onEnded`:
- `isGestureActive` is already `false`, `lockedIntent` is still set
- `holdStart()` sees `!isHolding` and a valid `lockedIntent`
- ARR loop starts **after** the user released — one unwanted extra movement

**Fix:** In `holdStart()`, add a guard for `isGestureActive`:

```swift
func holdStart(viewModel: GameViewModel) {
    guard let intent = lockedIntent, !isHolding, isGestureActive else { return }
    guard intent != .rotate else { return }
    // ...
}
```

This ensures hold only starts while the drag is still active.

---

### 🟡 Design Concerns

#### 4. Wide pieces get oversized rotate zones

**Location:** `ContentView.swift:427`

```swift
let rotateWidth = max(cellSize * 3, cellSize * CGFloat(span))
```

For any piece with `span >= 4` (e.g., I-piece horizontally oriented, or future wide pieces), the rotate zone grows to 4+ cells. On a 10-wide board, that leaves only 6 cells total for left + right zones. The rotate zone dominates the screen.

**Consider:** Capping `rotateWidth` at `cellSize * 4` or `cellSize * 5` to guarantee minimum side-zone width, especially for 4-wide pieces like the I-tetromino.

#### 5. Dual `isGestureActive` — one in `GestureHandler`, one in `ContentView`

**Location:** `GestureHandler.swift:15` and `ContentView.swift:39`

Both track the same concept. `ContentView.isGestureActive` gates intent-locking (line 227) and `resetForNewPiece()` (line 382). `GestureHandler.isGestureActive` is used in the hold race fix and `resetForNewPiece()`.

They're kept in sync but barely — both are set to `true`/`false` in parallel at nearly every gesture boundary. A single missed update would desynchronize them.

**Consider:** Using only `GestureHandler.isGestureActive` and reading it from `ContentView`. The `ContentView` state variable becomes redundant.

#### 6. Haptic feedback on every ARR tick (50ms)

**Location:** `GestureHandler.swift:88`

At 50ms intervals, that's 20 haptic pulses per second. On devices with precise Taptic Engines this can feel muddy or fatiguing over long holds. iOS's `UIImpactFeedbackGenerator` is not designed for high-frequency use — Apple's own docs recommend throttling.

**Consider:** Only firing haptics on the first ARR tick (DAS transition) and every Nth subsequent tick (e.g., every 3rd = ~150ms).

#### 7. Swipe direction overrides zone intent unconditionally

**Location:** `ContentView.swift:283-294`

A fast horizontal swipe always moves left/right regardless of which zone the finger started in. This means:
- Starting in the **rotate zone** and swiping left → moves left, doesn't rotate
- Starting in the **left zone** and swiping right → moves right (opposite of zone intent)

This can be surprising. The zone intent was locked for a reason.

**Consider:** Either respect the locked intent on swipes (a swipe in the rotate zone → rotate, not move), or document this as intentional "swipe = fast move regardless of zone" behavior.

#### 8. `calculateZoneLayout` called on every `GeometryReader` render

**Location:** `ContentView.swift:209-214`

The zone layout is recalculated on every render pass of the `GeometryReader`, which includes every frame of hard-drop and line-clear animations. The calculation itself is cheap (min/max of a small set), but it's unnecessary work during animations that don't affect piece position.

**Consider:** Caching the zone layout and only recalculating when `pieceBlocks` or `geo.size` changes.

#### 9. `swipeMaxDuration` (300ms) is uncoupled from `dasDelay` (170ms)

**Location:** `Constants.swift:182-186`

If DAS is ever changed (e.g., a "sensitivity" setting), the swipe timing threshold should scale with it. A 300ms swipe max with a 100ms DAS means almost any deliberate movement is a swipe. A 300ms swipe max with a 300ms DAS means swipes are nearly impossible.

**Consider:** Expressing `swipeMaxDuration` as a multiple of `dasDelay`:

```swift
static let swipeMaxDuration = dasDelay * 1.5  // 255ms with current DAS
```

---

### 🟢 Code Quality

#### 10. Magic numbers in zone indicator rendering

**Location:** `ContentView.swift:447-448, 488`

```swift
let iconSize: CGFloat = 30
// ...
.padding(.top, 20)
```

These violate the CLAUDE.md convention ("No magic numbers"). Should be in `Constants.Layout.iOS`.

#### 11. Zone intent resolution repeats the same pattern 3 times

**Location:** `ContentView.swift:302-332`

The intent-fallback logic (locked → start layout → fresh layout) repeats the identical zone-boundary check three times:

```swift
if value.startLocation.x < leftEdge { intent = .left }
else if value.startLocation.x > rightEdge { intent = .right }
else { intent = .rotate }
```

**Consider:** Extract to a helper:

```swift
private func intent(for x: CGFloat, layout: ZoneLayout) -> GestureHandler.Intent {
    if x < layout.leftWidth { return .left }
    if x > layout.leftWidth + layout.rotateWidth { return .right }
    return .rotate
}
```

#### 12. `boardSize(from:gridWidth:gridHeight:)` computed in 3 places

**Location:** `ContentView.swift:208, 231, 316`

If the sizing logic ever changes, all three sites need updating.

**Consider:** Storing as a derived value from `GeometryReader` and passing `bSize` through the gesture closures.

#### 13. `@MainActor` on `GestureHandler` is redundant

**Location:** `GestureHandler.swift:7`

`ContentView` (which owns the handler via `@State`) is already a SwiftUI view that runs entirely on the main actor. The annotation is harmless but unnecessary.

---

### 🔵 UX Observations

#### 14. No guard against gestures while paused

Gestures still enqueue actions on `GameController` while paused. The controller may reject them, but the **haptic feedback fires regardless**. A tap in the left zone while paused produces a haptic pulse and a no-op — the user might think something went wrong.

**Consider:** Guarding gesture handlers with `viewModel.displayState == .playing`.

#### 15. Hard-drop threshold (40pt) is absolute, not relative

**Location:** `Constants.swift:178`

40pt works on iPhone but may feel different on iPad (where the board is smaller relative to the screen, making 40pt a longer swipe). On a future iPad build, this would need adjustment.

**Consider:** Expressing as a fraction of the board height: `hardDropThreshold = boardSize.height * 0.02`.

---

## Summary

| Severity | Count | Key items |
|---|---|---|
| 🔴 Bug | 3 | `hasSwiped` stale state, `resetForNewPiece` overfires, hold/race condition |
| 🟡 Design | 7 | Wide-piece zones, dual state, haptic fatigue, swipe overrides intent, render waste, uncoupled timing |
| 🟢 Quality | 5 | Magic numbers, repeated code, redundant calls, redundant annotation |
| 🔵 UX | 2 | Paused gestures, absolute threshold |

The gesture system is well-architected overall — intent locking, DAS/ARR, and dynamic zones are thoughtfully implemented. The bugs are subtle edge cases (rapid input, timing boundaries) rather than fundamental flaws. The design concerns are mostly about robustness for future changes (settings, platforms, piece types) rather than current correctness.

---
*Review by project analysis. 2026-06-15.*
