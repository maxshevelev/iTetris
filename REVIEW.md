# REVIEW.md — VibeTetris Code Review

Synthesized from six parallel review passes: Architecture, Preview Views, Settings, GameViewModel, GestureHandler, Board + Constants, and TetrisCore API.

---

## 1. Bugs and Correctness Issues

### ~~B1 — Hard-drop overlay off-screen on macOS~~ (NOT a real bug)

**File:** `ContentView.swift:567-577`

Initially flagged: the overlay is applied after `.frame(maxWidth: 360, maxHeight: .infinity)` on macOS, so the `GeometryReader` might read a different size than the board. However, `.frame(maxWidth:, maxHeight:)` only sets upper bounds — it doesn't force the view to fill available space. The `.aspectRatio(0.5, .fit)` inside `TetrisBoardView` proposes 360×720, and the frame doesn't change that (720 ≤ infinity). Both the overlay's `GeometryReader` and the board's `Canvas` see 360×720, producing the same `cellSize = 36`. **No visual issue.**

---

### B2 — `hasSwiped` guard is ineffective (iOS gestures)

**File:** `ContentView.swift:329-336`

The `LongPressGesture.onEnded` guard `guard !gestureHandler.hasSwiped` always evaluates to `false` because `hasSwiped` is set in `DragGesture.onEnded`, which fires **after** the `LongPressGesture.onEnded`. A slow horizontal swipe will incorrectly trigger hold auto-repeat.

**Fix:** Set `hasSwiped = true` in `DragGesture.onChanged` when horizontal movement exceeds the threshold, not in `onEnded`.

---

### B3 — `hardDropRowThreshold = 1` is too low

**File:** `GameViewModel.swift:126`, `Constants.swift:199`

The threshold `cur - prev > 1` means a 1-row jump does **not** trigger the animation. A piece hard-dropping from y=0 to y=1 (a single row) would be missed. The threshold should be `>= 1` or the constant should be `0`.

---

### B4 — Center zone uses `Rectangle()` instead of `RoundedRectangle(cornerRadius: 12)`

**File:** `ContentView.swift:453`

The CLAUDE.md spec states: "center zone is a `RoundedRectangle(cornerRadius: 12)`". The code uses a plain `Rectangle()`.

---

### B5 — `Task.sleep` in `onHardDropTrigger()` violates convention

**File:** `ContentView.swift:674-677`

The CLAUDE.md convention states: "Animation completion uses `withAnimation(completionCriteria: .logicallyComplete) { } completion: { }`, not `Task.sleep` buffers." The flash fade-out uses `Task.sleep`:

```swift
Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(Int(Constants.Animation.hardDropFlashDelay * 1000)))
    hardDropFlash = false
}
```

**Fix:** Wrap the flash toggle in a `withAnimation(..., completionCriteria: .logicallyComplete)` block with a completion handler.

---

### B6 — `isHardDropping` can be cleared before animation completes

**File:** `GameViewModel.swift:131-133`

`isHardDropping` is cleared on the next `pieceBlocks` event where `hardDropDuration` is `nil`. If a new piece spawns before `ContentView`'s animation completes, the overlay disappears prematurely because the board rendering layer 3 hides the active piece when `isHardDropping` is `true` (`TetrisBoardView.swift:135`).

---

### B7 — Default parameters create disconnected state in previews

**File:** `ContentView.swift:14,21`

Both `ContentView` initializers have default parameters (`ObservableSettings()`, `ControlsConfig()`). If `ContentView()` is instantiated outside `VibeTetrisApp` (e.g., in a `#Preview`), it creates fresh settings instances disconnected from the app's single source of truth. The macOS `#Preview` at line 813 uses `ContentView()` with no arguments, so it renders with a blank player name and default settings.

---

### B8 — ARR race condition

**File:** `GestureHandler.swift:77-89`

If `arrTask` is between its guard check (line 81) and the action (lines 83-86) when `holdStop()` runs, `isHolding` becomes `false` but one extra action fires before the guard catches it.

---

### B9 — Haptics fire for rejected moves

**File:** `GestureHandler.swift:26-37`

`tap()` calls `haptic()` unconditionally even if the game rejected the move (e.g., piece at wall). The game model does not indicate whether a move was accepted.

---

### B10 — `UIImpactFeedbackGenerator` created on every call

**File:** `GestureHandler.swift:100-108`

A new `UIImpactFeedbackGenerator` is created on every haptic event. Apple recommends reusing instances and calling `.prepare()` ahead of time.

---

### B11 — Silent persistence failures

**File:** `ControlsConfig.swift:163-181`, `ObservableSettings.swift`

All file I/O uses `try?` -- disk write failures are invisible to the user. If the app support directory is unwritable, settings silently fail to persist.

---

### B12 — Floating-point nanosecond multiplication

**File:** `GestureHandler.swift:80`

`UInt64(Constants.Input.arrInterval * 1_000_000_000)` uses floating-point math for an integer quantity. Use `UInt64(Constants.Input.arrInterval * Double(NSEC_PER_SEC))` or define the constant as `UInt64` directly.

---

## 2. Simplification and Cleanup

### S1 — Magic numbers in iOS zone indicators

**File:** `ContentView.swift:429-431`

```swift
let centerAlpha: CGFloat = 0.04
let iconAlpha: CGFloat = 0.12
let flashAlpha: CGFloat = 0.12
```

These should be moved to `Constants.Layout.iOS` (e.g., `zoneIndicatorCenterAlpha`, `zoneIndicatorIconAlpha`, `zoneIndicatorFlashAlpha`).

---

### S2 — Magic number in iOS stat field

**File:** `ContentView.swift:487`

`spacing: 1` should be `Constants.Layout.iOS.statFieldSpacing` or similar.

---

### S3 — Magic number in iOS bottom bar

**File:** `ContentView.swift:342`

`HStack(spacing: 40)` -- the `40` should be `Constants.Layout.iOS.bottomBarSpacing`.

---

### S4 — Duplicated line-clear / hard-drop overlay code

**Files:** `ContentView.swift:496-547` (iOS) vs `ContentView.swift:696-747` (macOS)

`iOSLineClearBurnView` and `lineClearBurnView` are near-identical. `iOSHardDropPieceView` and `hardDropPieceView` are near-identical. Both pairs compute `cellSize`, `offsetX/Y`, and iterate the same loops. The only differences are the `#if os(iOS)` guards. This duplication risks drift.

**Fix:** Extract shared `lineClearBurnView(size:)` and `hardDropPieceView(size:)` as platform-agnostic private methods.

---

### S5 — Missing `#Preview` macros

**Files:** `InfoPanelView.swift`, `PiecePreviewView.swift`

CLAUDE.md convention: "#Preview macros are included at the bottom of each view file." Neither file has one.

---

### S6 — InfoPanelView: repeated label-value sections

**File:** `InfoPanelView.swift:20-42`

Three near-identical `VStack` blocks for Score, Level, and Lines. Extract into a `StatField(label:value:)` sub-view.

---

### S7 — Hardcoded key codes in `KeyCaptureView`

**File:** `SettingsView.swift:190-198`

```swift
case 49: keyStr = "Space"
case 53: keyStr = "Escape"
case 36: keyStr = "Return"
case 48: keyStr = "Tab"
case 126: keyStr = "UpArrow"
case 125: keyStr = "DownArrow"
case 123: keyStr = "LeftArrow"
case 124: keyStr = "RightArrow"
```

These should be named constants (e.g., `kVK_Space = 49`) or use AppKit's `NSEvent.keyCode` named constants where available.

---

### S8 — Double-sync on settings open

**Files:** `SettingsView.swift:12-20,31-37`, `IOSSettingsView.swift:14-22,57-63`

Local state is initialized in `init()` with values from `settings`, then overwritten in `.onAppear()` with the same values. The `init` values are thrown away. Use `init` only and remove the `.onAppear` sync.

---

### S9 — Conflict detection warns but doesn't prevent

**File:** `ControlsConfig.swift:139-151`

The user can save conflicting bindings. A visual warning is shown but there is no enforcement. Consider preventing the save or auto-resolving.

---

### S10 — `IOSSettingsView` default binding

**File:** `IOSSettingsView.swift:14`

`showZoneIndicators: Binding<Bool> = .constant(true)` -- if the caller forgets to pass the binding, the value defaults to `true` silently. This is a non-persistent toggle with no persistence layer.

---

### S11 — `pieceBlocks.map(\.y).min()` allocates on every tick

**File:** `GameViewModel.swift:121`

`p.blocks.map(\.y).min()` creates an intermediate `[Int]` array on every piece event. Use `p.blocks.min(by: { $0.y < $1.y })?.y` to avoid allocation.

---

### S12 — CLAUDE.md documentation mismatches

**File:** `CLAUDE.md`

- Icon alpha documented as `0.06` but code uses `0.12` (ContentView:430)
- Center zone shape documented as `RoundedRectangle(cornerRadius: 12)` but code uses `Rectangle()` (ContentView:453)
- File paths in the Key Files table are missing the `VibeTetris/` subdirectory prefix

---

## 3. TetrisCore API Gaps

These are features that would simplify the UI by offloading logic from the view model into the game model.

### GAP 1 — Hard-drop event (High priority)

**Where:** `GameViewModel.swift:119-133`

The UI detects hard drops by comparing `previousPieceMinY` against current min-Y with a threshold heuristic. TetrisCore already knows a hard drop is happening via `pendingHardDropDuration` but does not surface it as a boolean.

**Risk:** A 1-row hard drop (y=0 to y=1) is missed. The UI reverse-engineers game state from coordinates.

**Fix:** Add `isHardDrop: Bool` to the `pieceBlocks` event, or emit a separate `hardDrop` event.

---

### GAP 2 — New piece event (Medium priority)

**Where:** `GameViewModel.swift:135-140`

The UI detects new pieces by checking if min-Y jumps to 0. This is a positional heuristic that breaks if spawn position ever changes.

**Fix:** Emit a `newPiece` event from `spawnNewPiece()`, or include a monotonically increasing piece index in `pieceBlocks`.

---

### GAP 3 — Pre-clear grid in `linesCleared` event (High priority)

**Where:** `GameViewModel.swift:110-113`

The UI captures `lineClearGridSnapshot = grid` before applying the new grid event within the same batch. This is a delicate dance: the snapshot must happen before the grid is replaced, but both events arrive in the same `Set<GameEvent>`.

**Risk:** If TetrisCore changes which events are batched together, the animation breaks.

**Fix:** Include `preClearGrid` in the `linesCleared` event:

```swift
case linesCleared(Int, clearedRows: Set<Int>, animationDuration: TimeInterval, preClearGrid: [PieceCoordinate: TetrominoColor])
```

---

### GAP 4 — No piece queue

TetrisCore generates a single `nextPiece` and exposes only one "next" piece. Modern Tetris uses a 7-bag randomizer with a visible queue of 3-5 upcoming pieces.

---

### GAP 5 — No hold piece

No `holdPiece` event or `.hold` `ControlEvent`. This is a standard Tetris feature.

---

### GAP 6 — No soft drop

No `.softDrop` `ControlEvent`. The game only has gravity (auto-drop) and hard drop.

---

### GAP 7 — No piece identity / shape event

The UI receives piece coordinates as `Set<PieceCoordinate>` but has no way to know the piece's shape, rotation, or identity. The iOS gesture system must compute piece span from the coordinate set (`ContentView.swift:401-424`).

**Fix:** Add shape, rotation, and piece index to `pieceBlocks`.

---

### GAP 8 — DAS/ARR should be a game-level concern

**Where:** `GestureHandler.swift:45-89`

The gesture handler implements DAS/ARR as a `Task.sleep` loop that directly calls `viewModel.moveLeft()`. This should be a game-model feature with a `press(action)` / `release(action)` interface. DAS/ARR are already `PersistentGameSettings` in TetrisCore but the gesture handler hardcodes values from `Constants.Input`.

**Benefits:** Consistency across input methods (macOS keyboard has no DAS/ARR), testability, and configurability.

---

### Summary Priority Table

| Priority | Gap | Effort |
|----------|-----|--------|
| High | GAP 1: Hard-drop event | Low -- add flag to pieceBlocks |
| High | GAP 3: Pre-clear grid in event | Low -- add field to linesCleared |
| Medium | GAP 2: New piece event | Low -- emit from spawnNewPiece |
| Medium | GAP 7: Piece identity event | Medium -- add shape/rotation to pieceBlocks |
| Medium | GAP 8: DAS/ARR as game-level | Medium -- press/release API |
| Low | GAP 4: Piece queue | High -- new 7-bag system |
| Low | GAP 5: Hold piece | Medium -- new feature |
| Low | GAP 6: Soft drop | Medium -- new feature |

---

## 4. Active Tasks from CLAUDE.md

### Hard-drop overlay off-screen -- **NOT a real bug**

**Status:** ✅ Dismissed — no visual issue.

**Reason:** `.frame(maxWidth: 360, maxHeight: .infinity)` only sets upper bounds. The `.aspectRatio(0.5, .fit)` inside `TetrisBoardView` proposes 360×720, and the frame doesn't change that. Both the overlay's `GeometryReader` and the board's `Canvas` see the same size, producing identical `cellSize` calculations.
