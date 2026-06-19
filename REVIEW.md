# REVIEW.md — VibeTetris Deep Review

*Generated: 2026-06-19*

---

## Bugs

### B1. ObservableSettings overwrites user animation preferences on every launch

**File:** `ObservableSettings.swift:30-34`

```swift
init() {
    let settings = PersistentGameSettings()
    settings.isHardDropAnimated = true   // overwrites stored false
    settings.isLineClearAnimated = true  // overwrites stored false
    self.raw = settings
}
```

This unconditionally sets animation defaults to `true` on every app launch. If the user disabled animations, they will be silently re-enabled on the next launch.

**Fix:** Remove the forced overrides. Let `PersistentGameSettings` own its defaults.

### B2. Duplicate event monitor leak in KeyCaptureView

**File:** `SettingsView.swift:183-207`

If `isRecording` is `true` and `updateNSView` is called again (can happen during any SwiftUI view update while recording), `startMonitor` creates a second `NSEvent` monitor without removing the first. The old reference is overwritten in `self.monitor`, so `stopMonitor` can never remove it — leaking event monitors and causing duplicate key captures.

**Fix:** Add a guard at the top of `startMonitor`:

```swift
func startMonitor(isRecording: Binding<Bool>, capturedKey: Binding<String>) {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ... }
```

### B3. macOS keyboard handler processes keys while game is paused

**File:** `ContentView.swift:637-655`

`handleKeyPress` does not check `viewModel.displayState` before dispatching move/rotate/hard-drop actions. Keys are enqueued on the GameController even when paused. (The GameController may drop them, but the commands are still sent.)

**Fix:** Guard at the top of `handleKeyPress`:

```swift
guard viewModel.displayState == .playing else { return .ignored }
```

### B4. GestureHandler does not cancel arrTask on deallocation

**File:** `GestureHandler.swift:15`

If the `GestureHandler` is deallocated while an ARR auto-repeat loop is active, the `Task` continues executing. Although `ContentView` holds it as `@State` so this is unlikely in practice, it is a correctness gap.

**Fix:** Add `deinit { holdStop() }`.

---

## High

### H1. Duplicate rendering code between iOS and macOS

**File:** `ContentView.swift:496-547` (iOS) and `ContentView.swift:691-742` (macOS)

`iOSLineClearBurnView`/`iOSHardDropPieceView` and `lineClearBurnView`/`hardDropPieceView` are near-identical. The only difference is the `#if os(iOS)`/`#if os(macOS)` guard and the function name prefix. Same code, same logic, same parameters.

**Fix:** Make them platform-agnostic. The functions already take `size: CGSize` as a parameter, so they work on both platforms. Remove the `#if os` split.

### H2. `calculateZoneLayout` recomputes on every render pass

**File:** `ContentView.swift:209-214`

Called unconditionally in the iOS body view, this runs on every state change — including every game tick (piece movement, score update, etc.). It performs `pieceBlocks.map(\.x).min()!` and `pieceBlocks.map(\.x).max()!` on every render.

**Fix:** Cache the result in a `@State` and only recompute when `pieceBlocks` or `gridWidth` actually change, using `.onChange`.

### H3. `Task.sleep` used for flash delay — violates project convention

**File:** `ContentView.swift:669-672`

CLAUDE.md states: *"Animation completion uses `withAnimation(completionCriteria: .logicallyComplete)` — not `Task.sleep` buffers."* Yet the hard-drop flash delay uses `Task.sleep(for: .milliseconds(...))`.

**Fix:** Chain the flash toggle inside the `withAnimation` completion block with a short `withAnimation` for the fade-out.

---

## Medium

### M1. `ContentView` is 811 lines — single-responsibility violation

**File:** `ContentView.swift`

Contains: iOS body layout, macOS body layout, zone indicator rendering, zone layout computation, gesture handling state, animation triggers, line-clear burn rendering, hard-drop piece rendering, and keyboard handling. The iOS gesture system alone (lines 207-370) is a substantial subsystem.

**Fix:** Extract at minimum: (a) `IOSZoneLayoutCalculator` (or a `@Observable` class), (b) `IOSGestureOverlayView` (the entire gesture `Color.clear` overlay as its own view), (c) `LineClearBurnOverlayView` and `HardDropOverlayView` as standalone views.

### M2. `pieceBlocks.map(\.x)` called multiple times in `calculateZoneLayout`

**File:** `ContentView.swift:412-416`

```swift
let minX = CGFloat(pieceBlocks.map(\.x).min()!)
let maxX = CGFloat(pieceBlocks.map(\.x).max()!)
// ...
span = pieceBlocks.map(\.x).max()! - pieceBlocks.map(\.x).min()! + 1
```

The `map(\.x).min()` and `map(\.x).max()` are each computed twice.

**Fix:** Store `minX` and `maxX` and derive `span = Int(maxX - minX) + 1`.

### M3. Deep `GeometryReader` nesting in iOS body

**File:** `ContentView.swift:175` and `ContentView.swift:190`

The iOS body has `GeometryReader` at line 175, and a second `GeometryReader` inside the board overlay at line 190. `GeometryReader` forces lazy layout and is known to cause performance issues. The inner one is only used to get the board size for the animation overlays.

**Fix:** Pass the board size from the outer `GeometryReader` into the overlay views as a parameter instead of nesting another `GeometryReader`.

### M4. Zone indicator alpha values are magic numbers

**File:** `ContentView.swift:429-431`

```swift
let centerAlpha: CGFloat = 0.04
let iconAlpha: CGFloat = 0.12
let flashAlpha: CGFloat = 0.12
```

CLAUDE.md says *"All sizes, opacities, durations, and colors live in `Constants.swift`."* These three alphas are not in Constants.

**Fix:** Move to `Constants.Layout.iOS` as `zoneIndicatorCenterAlpha`, `zoneIndicatorIconAlpha`, `zoneIndicatorFlashAlpha`.

### M5. `UIImpactFeedbackGenerator` created on every haptic call

**File:** `GestureHandler.swift:100-108`

A new `UIImpactFeedbackGenerator` is instantiated for every tap, hold, or hard-drop. Apple's docs recommend preparing generators ahead of time. For a fast ARR loop at 50ms intervals, this means creating 20 generators per second.

**Fix:** Cache three `UIImpactFeedbackGenerator` instances (one per feedback style) as `static let` properties in `GestureHandler`, and call `.prepare()` once at launch.

### M6. `SettingsView` and `IOSSettingsView` duplicate state-syncing pattern

**File:** `SettingsView.swift` and `IOSSettingsView.swift`

Both views use the same pattern: local `@State` vars initialized from `settings`, synced via `.onChange` back to `settings`. With `@Observable` + `@Bindable`, direct bindings like `TextField("Name", text: $settings.playerName)` work in SwiftUI forms and eliminate the need for local state + onChange.

**Fix:** Use `@Bindable var settings: ObservableSettings` and bind directly: `$settings.playerName`, `$settings.lockImmediatelyAfterHardDrop`, etc.

### M7. `@State` with class type — `GestureHandler`

**File:** `ContentView.swift:39`

```swift
@State private var gestureHandler = GestureHandler()
```

`GestureHandler` is a `final class`, but `@State` is designed for value types. The semantics of `@State` with a class are undefined by SwiftUI — it may or may not preserve the same instance across view re-creations. If SwiftUI creates a new instance, gesture state (including `isGestureActive`) would be silently reset mid-gesture.

**Fix:** Either make `GestureHandler` a `struct`, or hold it as a plain `private lazy var`.

---

## Low

### L1. Bare NSKeyCodes in KeyCaptureView

**File:** `SettingsView.swift:190-197`

Hardcoded key codes (`49` = Space, `53` = Escape, `36` = Return, `48` = Tab, `126` = Up, etc.) are bare magic numbers.

**Fix:** Define named constants:

```swift
private enum ReservedKeyCode {
    static let space = 49
    static let escape = 53
    static let returnKey = 36
    static let tab = 48
    static let upArrow = 126
    // ...
}
```

### L2. Hardcoded layout values in KeyField

**File:** `SettingsView.swift:141-146`

`minWidth: 60`, `padding(.horizontal, 6)`, `padding(.vertical, 3)`, `cornerRadius: 4`, `lineWidth: 1.5`, `lineWidth: 1` — these belong in `Constants.Layout.KeyField`.

### L3. `hardDropRowThreshold = 1` is too low

**File:** `Constants.swift:199`

A row delta of just 1 triggers a hard-drop animation. A normal gravity step also moves the piece by 1 row. The condition `cur - prev > 1` means a 2-row jump triggers it, which can happen on a normal tick if the piece was at the top and dropped two rows (e.g., initial spawn with a simultaneous tick). A threshold of 3-5 would be more robust.

**Fix:** Increase `hardDropRowThreshold` to at least 3.

### L4. Force unwrap on `pieceBlocks.map(\.x).min()!` in `calculateZoneLayout`

**File:** `ContentView.swift:412-413`

Guarded by an `isEmpty` check on line 407, but a future refactor could break this. Safer to use `minX ?? 0` pattern.

### L5. `applyPreset` uses string-key switch instead of key paths

**File:** `ControlsConfig.swift:60-74`

The preset application uses `switch key` on string keys. A type-safe approach using the existing `allBindings` key paths would eliminate the string mapping.

**Fix:** Define presets as `[ReferenceWritableKeyPath<ControlsConfig, String>: String]` and apply with `self[keyPath: kp] = value`.

### L6. `GridBackgroundView` draws 200 fill + 200 stroke operations

**File:** `TetrisBoardView.swift:27-42`

For a 10×20 grid, every cell is filled and stroked individually. The `.drawingGroup()` cache helps, but the initial render is expensive.

**Fix:** Draw the background as a single filled rectangle, then draw only the grid lines (horizontal + vertical) as a single path.

### L7. No iOS preview for ContentView

**File:** `ContentView.swift:807-811`

Only a macOS `#Preview` exists. No iOS preview.

### L8. Division by zero edge case in line-clear burn

**File:** `ContentView.swift:507, 702`

```swift
let dist = abs(CGFloat(col) - CGFloat(cols - 1) / 2) / (CGFloat(cols - 1) / 2)
```

If `cols` is 1, the denominator is 0 → `NaN` or `inf`. Unlikely with a 10-column grid, but if grid size becomes configurable this will break.

**Fix:** `guard cols > 1 else { dist = 0 }`

---

## TetrisCore API — Opportunities for Cleaner UI Code

The UI layer currently has to infer game state from event combinations. These API additions to TetrisCore would eliminate heuristics and simplify `GameViewModel.apply()`:

### High Impact

#### A. Dedicated `newPiece` event

**Problem:** The VM detects new pieces via a fragile heuristic — checking if piece min-Y jumps to 0 from a non-zero value (`GameViewModel.swift:136-140`). If a piece spawns at Y=0 and the previous piece was also at Y=0, it would miss the event.

**Proposal:**

```swift
case newPiece  // emitted when a new piece spawns
```

Replaces the `newPieceTrigger` counter and eliminates the heuristic entirely.

#### B. Dedicated `hardDropLanded` event

**Problem:** The VM infers hard drops by comparing piece Y positions across events and checking a threshold (`GameViewModel.swift:119-133`). It tracks `previousPieceMinY` and uses `hardDropRowThreshold` — a fragile heuristic.

**Proposal:**

```swift
case hardDropLanded(animationDuration: TimeInterval)
```

Removes the need for `previousPieceMinY` tracking and the `hardDropRowThreshold` heuristic.

#### C. Pre-clear grid snapshot in line-clear event

**Problem:** The grid event fires with lines already removed. The VM must snapshot the grid *before* applying, requiring the two-pass apply pattern and careful ordering. The VM stores `lineClearGridSnapshot` for the burn animation.

**Proposal:**

```swift
case linesCleared(total: Int, clearedRows: Set<Int>,
                  animationDuration: TimeInterval,
                  preClearGrid: [PieceCoordinate: TetrominoColor])
```

Eliminates the grid snapshot requirement and the ordering dependency between `grid` and `linesCleared` events.

### Medium Impact

#### D. Piece position in `pieceBlocks` event

**Problem:** The UI iterates `pieceBlocks` to compute min-X, min-Y, and span for iOS zone calculations (`ContentView.swift:401-424`).

**Proposal:**

```swift
case pieceBlocks(blocks: Set<PieceCoordinate>, color: TetrominoColor,
                 position: PiecePosition, hardDropDuration: TimeInterval?)

public struct PiecePosition: Hashable, Sendable {
    let minX: Int
    let minY: Int
    let span: Int  // maxX - minX + 1
}
```

#### E. `GameController.displayState` — synchronous state query

**Problem:** The UI derives `displayState` from events. If events are delayed or lost, the UI could be out of sync with the controller's actual state.

**Proposal:**

```swift
nonisolated public var displayState: GameDisplayState { ... }
```

Or a snapshot method:

```swift
public func snapshot() async -> GameSnapshot
```

#### F. Ghost blocks included in piece event

**Problem:** `pieceBlocks` and `ghostPieceBlocks` are separate events. The VM applies them independently, and the ghost is always computed from the same piece position.

**Proposal:**

```swift
case pieceBlocks(blocks: Set<PieceCoordinate>, color: TetrominoColor,
                 ghostBlocks: Set<PieceCoordinate>?,
                 hardDropDuration: TimeInterval?)
```

Reduces event count and eliminates a diff check in the render path.

### Low Impact (Nice-to-Have)

#### G. `TetrominoColor` conforms to `CaseIterable`

Useful for color pickers or any UI that iterates colors.

#### H. `TetrominoShape.boundingBox` computed property

```swift
public var boundingBox: (width: Int, height: Int) { ... }
```

Avoids creating a `Tetromino` and iterating blocks just to find dimensions.

#### I. Grid dimensions on `GameSettings`

```swift
var gridWidth: Int { get }   // default 10
var gridHeight: Int { get }  // default 20
```

Makes settings the source of truth if grid size ever becomes configurable.

---

## Summary

| Severity | Count | Key items |
|---|---|---|
| **Bug** | 4 | Settings override, monitor leak, keys while paused, no GestureHandler deinit |
| **High** | 3 | Duplicated rendering, un-cached zone layout, Task.sleep violation |
| **Medium** | 7 | God-view, redundant map calls, GeometryReader nesting, magic alphas, haptic churn, duplicate settings pattern, @State with class |
| **Low** | 8 | Magic key codes, KeyField layout, threshold value, force unwrap, string-key presets, grid rendering, missing iOS preview, division-by-zero edge case |
| **API** | 9 | 3 high-impact (newPiece, hardDropLanded, preClearGrid), 3 medium (position, displayState, ghost merge), 3 nice-to-have |
