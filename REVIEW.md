# VibeTetris — Code Review

*Branch: `ios-settings-restructure` · 2026-06-19*

---

## Git Diff Issues

The current branch adds `README.md`, `REVIEW.md`, and `CLAUDE.md` as app bundle resources in
`project.pbxproj`. These documentation files should **not** be bundled with the app. Remove them
from the Resources build phase.

---

## Critical

### C1. GameViewModel never cancels tickTask on deallocation

**File:** `GameViewModel.swift:36`

The `tickTask` is created in `init` and stored as a property, but there is no `deinit` to cancel
it. If `ContentView` is ever dismissed (e.g., future multi-scene setup), the task continues running
and calling `apply()` on a deallocated `@Observable` object. With the `@Observable` macro, the
object is retained by the task closure — a **retain cycle**: the ViewModel will never be
deallocated as long as the GameController is running.

**Fix:** Add a `deinit` that cancels the task:

```swift
deinit {
    tickTask?.cancel()
}
```

### C2. Tests create a real GameViewModel with a live GameController event stream

**File:** `VibeTetrisTests/VibeTetrisTests.swift:15`

`makeVM()` constructs a real `GameViewModel(settings:)`, which spins up a `GameController` with an
active `AsyncStream`. Events from the real game engine can fire during tests, causing flaky
assertions. The test harness should use a mock/stubbed controller or a test-only initializer that
takes a `GameEvent` publisher.

**Fix:** Add a test-only `init(events: some AsyncSequence<GameEvent>)` or inject a `GameController`
protocol.

---

## High

### H1. Duplicate rendering code between iOS and macOS

**File:** `ContentView.swift:496-547 (iOS)` and `ContentView.swift:691-742 (macOS)`

`iOSLineClearBurnView`/`iOSHardDropPieceView` and `lineClearBurnView`/`hardDropPieceView` are
near-identical. The only difference is the `#if os(iOS)`/`#if os(macOS)` guard and the function
name prefix. Same code, same logic, same parameters.

**Fix:** Make them platform-agnostic. The functions already take `size: CGSize` as a parameter, so
they work on both platforms. Remove the `#if os` split.

### H2. `calculateZoneLayout` recomputes on every render pass

**File:** `ContentView.swift:208-214`

Called unconditionally in the iOS body view, this runs on every state change — including every
game tick (piece movement, score update, etc.). It performs `pieceBlocks.map(\.x).min()!` and
`pieceBlocks.map(\.x).max()!` on every render.

**Fix:** Cache the result in a `@State` and only recompute when `pieceBlocks` or `gridWidth`
actually change, using `.onChange`.

### H3. `GestureHandler` does not cancel `arrTask` on deallocation

**File:** `GestureHandler.swift:15`

If the `GestureHandler` is deallocated while an ARR loop is active, the `Task` continues
executing. Although `ContentView` holds it as `@State` so this is unlikely in practice, it is a
correctness gap.

**Fix:** Add a `deinit { holdStop() }`.

### H4. `Task.sleep` used for flash delay — violates project convention

**File:** `ContentView.swift:670`

CLAUDE.md states: *"Animation completion uses `withAnimation(completionCriteria: .logicallyComplete)`
— not `Task.sleep` buffers."* Yet the hard-drop flash delay at line 670 uses
`Task.sleep(for: .milliseconds(...))`.

**Fix:** Chain the flash toggle inside the `withAnimation` completion block with a short
`withAnimation` for the fade-out, or use a second `withAnimation` with a delay.

### H5. `ObservableSettings` overrides user-persisted animation preferences on init

**File:** `ObservableSettings.swift:31-32`

```swift
settings.isHardDropAnimated = true
settings.isLineClearAnimated = true
```

These lines unconditionally force animations on every time `ObservableSettings()` is created,
overriding whatever `PersistentGameSettings` stored. If the user disabled animations, they are
re-enabled on next launch.

**Fix:** Remove the forced overrides. Let the persisted values stand.

---

## Medium

### M1. `ContentView` is 812 lines — single-responsibility violation

**File:** `ContentView.swift`

Contains: iOS body layout, macOS body layout, zone indicator rendering, zone layout computation,
gesture handling state, animation triggers, line-clear burn rendering, hard-drop piece rendering,
and keyboard handling. The iOS gesture system alone (lines 207-370) is a substantial subsystem.

**Fix:** Extract at minimum: (a) `IOSZoneLayoutCalculator` (or a `@Observable` class),
(b) `IOSGestureOverlayView` (the entire gesture `Color.clear` overlay as its own view),
(c) `LineClearBurnOverlayView` and `HardDropOverlayView` as standalone views.

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

The iOS body has `GeometryReader` at line 175, and a second `GeometryReader` inside the board
overlay at line 190. `GeometryReader` forces lazy layout and is known to cause performance issues.
The inner one is only used to get the board size for the animation overlays.

**Fix:** Pass the board size from the outer `GeometryReader` into the overlay views as a parameter
instead of nesting another `GeometryReader`.

### M4. Zone indicator alpha values are magic numbers

**File:** `ContentView.swift:429-431`

```swift
let centerAlpha: CGFloat = 0.04
let iconAlpha: CGFloat = 0.12
let flashAlpha: CGFloat = 0.12
```

CLAUDE.md says *"All sizes, opacities, durations, and colors live in `Constants.swift`."* These
three alphas are not in Constants.

**Fix:** Move to `Constants.Layout.iOS` as `zoneIndicatorCenterAlpha`,
`zoneIndicatorIconAlpha`, `zoneIndicatorFlashAlpha`.

### M5. `UIImpactFeedbackGenerator` created on every haptic call

**File:** `GestureHandler.swift:107`

A new `UIImpactFeedbackGenerator` is instantiated for every tap, hold, or hard-drop. Apple's docs
recommend preparing generators ahead of time. For a fast ARR loop at 50ms intervals, this means
creating 20 generators per second.

**Fix:** Cache three `UIImpactFeedbackGenerator` instances (one per feedback style) as `static let`
properties in `GestureHandler`, and call `.prepare()` once at launch.

### M6. `KeyCaptureView.Coordinator` can leak event monitors

**File:** `SettingsView.swift:170-176`

`updateNSView` calls `startMonitor` when `isRecording` is true, but `startMonitor` does not check
if a monitor already exists. If `isRecording` toggles true quickly, a new monitor is added without
removing the old one.

**Fix:** In `startMonitor`, call `stopMonitor()` first, or guard `if monitor == nil`.

### M7. `SettingsView` and `IOSSettingsView` duplicate state-syncing pattern

**File:** `SettingsView.swift` and `IOSSettingsView.swift`

Both views use the same pattern: local `@State` vars initialized from `settings`, synced via
`.onChange` back to `settings`. With `@Observable` + `@Bindable`, direct bindings like
`TextField("Name", text: $settings.playerName)` work in SwiftUI forms and eliminate the need for
local state + onChange.

**Fix:** Use `@Bindable var settings: ObservableSettings` and bind directly:
`$settings.playerName`, `$settings.lockImmediatelyAfterHardDrop`, etc.

### M8. macOS keyboard handler processes keys while game is paused

**File:** `ContentView.swift:637-655`

`handleKeyPress` does not check `viewModel.displayState` before dispatching move/rotate/hard-drop.
Keys are enqueued on the GameController even when paused. (The GameController may drop them, but
the commands are still sent.)

**Fix:** Guard with
`guard viewModel.displayState == .playing else { return .ignored }`
at the top of `handleKeyPress`.

---

## Low

### L1. `#Preview` only for macOS

**File:** `ContentView.swift:807`

Only a macOS preview exists. No iOS preview.

**Fix:** Add `#Preview(traits: .iPhone)` for iOS.

### L2. `applyPreset` uses string-key switch instead of key paths

**File:** `ControlsConfig.swift:60-74`

The preset application uses `switch key` on string keys. A type-safe approach using the existing
`allBindings` key paths would eliminate the string mapping.

**Fix:** Define presets as `[ReferenceWritableKeyPath<ControlsConfig, String>: String]` and apply
with `self[keyPath: kp] = value`.

### L3. `GridBackgroundView` draws 200 fill + 200 stroke operations

**File:** `TetrisBoardView.swift:27-42`

For a 10×20 grid, every cell is filled and stroked individually. The `.drawingGroup()` cache helps,
but the initial render is expensive.

**Fix:** Draw the background as a single filled rectangle, then draw only the grid lines
(horizontal + vertical) as a single path.

### L4. `hardDropRowThreshold = 1` is too low

**File:** `Constants.swift:199`

A row delta of just 1 triggers a hard-drop animation. A normal gravity step also moves the piece
by 1 row. The condition `cur - prev > 1` means a 2-row jump triggers it, which can happen on a
normal tick if the piece was at the top and dropped two rows (e.g., initial spawn with a
simultaneous tick). A threshold of 3-5 would be more robust.

**Fix:** Increase `hardDropRowThreshold` to at least 3.

### L5. Force unwrap on `pieceBlocks.map(\.x).min()!` in `calculateZoneLayout`

**File:** `ContentView.swift:412`

Guarded by an `isEmpty` check on line 407, but a future refactor could break this. Safer to use
`minX ?? 0` pattern.

---

## Summary

| Severity | Count | Key items |
|---|---|---|
| **Critical** | 2 | ViewModel retain cycle, flaky tests |
| **High** | 5 | Duplicated rendering code, un-cached zone layout, no deinit on GestureHandler, Task.sleep violation, settings override |
| **Medium** | 8 | God-view, redundant map calls, GeometryReader nesting, magic numbers, haptic generator churn, monitor leak, duplicate settings pattern, key handling while paused |
| **Low** | 5 | Missing iOS preview, string-key presets, grid rendering, threshold value, force unwrap |
