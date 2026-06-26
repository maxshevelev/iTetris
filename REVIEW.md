# REVIEW.md — VibeTetris Deep Review

> Fresh review as of 2026-06-22. Previously fixed issues are struck through. New findings added.

---

## 1. Bugs

### B1 — No auto-resume after dismissing iOS Settings

**File:** `ContentView.swift:149-152` (Settings button), `ContentView.swift:360` (sheet)

Tapping the Settings gear button pauses the game and shows the sheet. Dismissing the sheet (✕ button) leaves the game paused — the user must manually tap the Pause button to resume.

**Expected:** Closing Settings should auto-resume.

**Fix:**

```swift
.onChange(of: showSettings) { oldValue, newValue in
    if oldValue && !newValue {
        viewModel.resume()
    }
}
```

---

### ~~B2 — `hasSwiped` guard ineffective~~ (FIXED)

**File:** `ContentView.swift:251-258`

`hasSwiped` was set in `DragGesture.onEnded` (after `LongPressGesture.onEnded`). Now set in `onChanged` so the guard works.

---

### ~~B3 — `hardDropRowThreshold = 1` too low~~ (FIXED)

Hard-drop detection now uses `hardDropDuration != nil` — no threshold needed.

---

### B6 — `isHardDropping` can be cleared before animation completes

**File:** `GameViewModel.swift:131-135`

`isHardDropping` is cleared on the next `pieceBlocks` event where `hardDropDuration` is `nil`. If a new piece spawns before the ContentView animation completes, the board's layer 3 would render the new piece (since `isHardDropping` is `false`), but the overlay animation is still running with stale piece data.

In practice this is unlikely (the hard-drop animation is very short — `dropInterval * 0.5` ≤ 250ms), but it's a latent race.

**Severity:** Low (theoretical — animation is fast enough that the next tick rarely arrives mid-animation).

---

### B7 — Preview uses disconnected settings

**File:** `ContentView.swift:836-841`

The macOS `#Preview` creates fresh `ObservableSettings()` and `ControlsConfig()` instances, so it renders with default values (blank player name, default keybindings). Not a runtime bug, but misleading for preview purposes.

**Severity:** Trivial (preview-only).

---

### B8 — ARR fires one extra action after `holdStop()`

**File:** `GestureHandler.swift:77-89`

If `holdStop()` clears `isHolding` between the guard check (line 81) and the action dispatch (lines 83-86), one extra ARR action fires before the next guard iteration catches it.

**Severity:** Low (50ms window, rarely observable).

---

### B9 — Haptics fire for rejected moves

**File:** `GestureHandler.swift:26-37`

`tap()` always fires a haptic, even if the game rejected the move (e.g., piece already at wall). The game model doesn't report whether a move was accepted.

**Severity:** Low (cosmetic — extra haptic on wall collision).

---

### B10 — `UIImpactFeedbackGenerator` created on every call

**File:** `GestureHandler.swift:100-108`

A new generator is created for every haptic event. Apple recommends reusing instances and calling `.prepare()`.

**Severity:** Low (minor performance).

---

### B11 — Silent persistence failures

**File:** `ControlsConfig.swift:163-181`

All file I/O uses `try?` — disk write failures are invisible to the user.

**Severity:** Low (edge case — unwritable app support directory).

---

### B12 — Floating-point nanosecond multiplication

**File:** `GestureHandler.swift:80`

`UInt64(Constants.Input.arrInterval * 1_000_000_000)` uses floating-point for an integer quantity.

**Severity:** Trivial.

---

## 2. Code Quality

### ~~S1–S3 — Magic numbers in iOS zone indicators, stat field, bottom bar~~ (FIXED)

All moved to `Constants.Layout.iOS`.

---

### ~~S4 — Duplicated animation overlay views (iOS ↔ macOS)~~ (FIXED)

`iOSLineClearBurnView` / `iOSHardDropPieceView` were near-identical to `lineClearBurnView` / `hardDropPieceView`.

**Fix applied:** Removed the iOS-specific copies. Both platforms now call the shared `lineClearBurnView(size:)` and `hardDropPieceView(size:)` under `// MARK: - Animation Overlays (shared)`. File reduced from 843 → 787 lines (56 lines eliminated).

---

### S5 — Missing `#Preview` macros

**Files:** `InfoPanelView.swift`, `PiecePreviewView.swift`

CLAUDE.md convention requires `#Preview` macros on every view file. Neither has one.

**Fix:** Add `#Preview` blocks at the bottom of each file.

---

### S6 — InfoPanelView: repeated label-value sections

**File:** `InfoPanelView.swift:19-42`

Three near-identical `VStack` blocks for Score, Level, Lines. Extract into a `StatField(label:value:)` sub-view.

---

### S7 — Hardcoded key codes in `KeyCaptureView`

**File:** `SettingsView.swift:190-198`

```swift
case 49: keyStr = "Space"
case 53: keyStr = "Escape"
```

Use named constants (`kVK_Space = 49`) or AppKit's `NX_KEYTYPE_` constants.

---

### S8 — Double-sync on settings open

**Files:** `SettingsView.swift:12-20,31-37`, `IOSSettingsView.swift:14-22,57-63`

Local state initialized in `init()` from `settings`, then overwritten in `.onAppear()` with the same values. The `init` values are thrown away.

**Fix:** Remove the `.onAppear` sync — `init` values are sufficient since the view is created fresh each time the settings sheet opens.

---

### S9 — Conflict detection warns but doesn't prevent

**File:** `ControlsConfig.swift:139-151`

User can save conflicting bindings. Consider preventing the save or auto-resolving.

**Severity:** Low (warning is visible).

---

### S10 — Dead code: `Constants.Gameplay.hardDropRowThreshold`

**File:** `Constants.swift:225`

```swift
static let hardDropRowThreshold = 1
```

Hard-drop detection uses `hardDropDuration != nil` — this constant is never read.

**Fix:** Remove it.

---

### S11 — `pieceBlocks.map(\.y).min()` allocates on every tick

**File:** `GameViewModel.swift:123`

`p.blocks.map(\.y).min()` creates an intermediate `[Int]` array. Use `p.blocks.min(by: { $0.y < $1.y })?.y` to avoid allocation.

---

### S12 — `pieceBlocks.map(\.x)` called 4× in `calculateZoneLayout`

**File:** `ContentView.swift:421-425`

```swift
let minX = CGFloat(pieceBlocks.map(\.x).min()!)
let maxX = CGFloat(pieceBlocks.map(\.x).max()!)
span = pieceBlocks.map(\.x).max()! - pieceBlocks.map(\.x).min()! + 1
```

**Fix:** Extract once:

```swift
let xValues = pieceBlocks.map(\.x)
let minX = CGFloat(xValues.min()!)
let maxX = CGFloat(xValues.max()!)
let span = xValues.max()! - xValues.min()! + 1
```

---

### S13 — `boardSize` recomputed multiple times per render pass

**File:** `ContentView.swift:208-237`

In the iOS `GeometryReader`, `boardSize(from:gridWidth:gridHeight:)` is called at least twice per render (once for zone layout, once inside `onChanged`). During gestures, up to 3×.

**Fix:** Cache as a `@State` or compute once in the `GeometryReader` and pass it down.

---

### S14 — CLAUDE.md documentation mismatches

**File:** `CLAUDE.md`

- File paths in the Key Files table are missing the `VibeTetris/` subdirectory prefix.

---

## 3. TetrisCore API Opportunities

These are features that would simplify the UI by offloading logic from the view model into the game model — keeping the model UI-agnostic.

### ~~GAP 1 — Hard-drop detection~~ (FIXED)

`hardDropDuration != nil` is the sole signal. No TetrisCore change needed.

---

### ~~GAP 2 — New piece event~~ (FIXED)

TetrisCore emits `.newPiece`. UI uses it directly.

---

### ~~GAP 3 — Pre-clear grid snapshot~~ (NOT a real gap)

Two-pass apply with strict ordering (`.linesCleared` before `.grid`) captures the snapshot correctly.

---

### GAP 4 — `hardDropDeltaY` in the event

**File:** `GameViewModel.swift:36,125-132`

The UI tracks `previousPieceMinY` across ticks to compute the hard-drop vertical distance. This is **game logic in the UI layer**.

**Proposal:**

```swift
case pieceBlocks(Set<PieceCoordinate>, color: TetrominoColor,
                 hardDropDuration: TimeInterval?, hardDropDeltaY: Int?)
```

TetrisCore knows `startY` and `currentY` in `hardDropPiece()` — it can compute the delta.

**Benefit:** Removes `previousPieceMinY` state from `GameViewModel`. Makes the ViewModel truly stateless per-tick.

---

### GAP 5 — Piece shape and position in the event stream

**File:** `ContentView.swift:410-433` (`calculateZoneLayout`)

The UI receives piece blocks as `Set<PieceCoordinate>` — a flat set of grid cells. No shape, rotation, or spawn position. The iOS gesture system must derive piece center and span from coordinates.

**Proposal:**

```swift
case pieceBlocks(Set<PieceCoordinate>, shape: TetrominoShape, rotation: Int,
                 x: Int, y: Int, color: TetrominoColor,
                 hardDropDuration: TimeInterval?, hardDropDeltaY: Int?)
```

Or a separate event:

```swift
case currentPiece(TetrominoShape, rotation: Int, x: Int, y: Int)
```

**Benefits:**
- **Hold mechanic:** Needs shape identity, not block positions.
- **iOS zones:** Core could compute bounding box and send it directly.
- **Debugging:** "T at rotation 2" > set of 4 coordinates.
- **Future features:** T-Spin detection, scoring breakdowns.

---

### GAP 6 — Next piece shape identity

**File:** `GameViewModel.swift:14-15`

Same as above — `nextPieceBlocks` sends coordinates and color but not shape.

**Proposal:**

```swift
case nextPieceBlocks(Set<PieceCoordinate>, shape: TetrominoShape, color: TetrominoColor)
```

**Benefit:** Enables hold mechanic, 7-bag display, and "next piece" labels without reverse-engineering the shape from coordinates.

---

### GAP 7 — `pieceLocked` event

There is no event for when a piece locks. The UI infers it from hard-drop + new-piece sequences.

**Proposal:**

```swift
case pieceLocked
```

**Benefits:**
- Lock animation / haptic feedback (currently only hard drops get visual feedback).
- Score popup at the exact moment of lock.
- Cleaner state machine — eliminates `isHardDropping` ambiguity.

---

### GAP 8 — `gameStarted` event

**File:** `ContentView.swift:373-379` (`newPieceTrigger` handler)

No explicit signal that the game has reset. The UI infers from `.gridSize` + `.grid` (empty) + `.score(0)` + `.state(.playing)`.

**Proposal:**

```swift
case gameStarted
```

**Benefits:**
- Clear reset of animation state, gesture state, overlays in one place.
- Cleaner than using `.newPiece` for gesture resets.

---

### GAP 9 — `scoreDelta` event

**File:** `GameViewModel.swift:152`

`.score(Int)` sends the absolute score. The UI cannot distinguish "+40" from a score of "1040".

**Proposal:**

```swift
case score(Int, delta: Int)
```

**Benefit:** Enables "score popup" animations ("+40" floating up) without the UI tracking previous score and computing deltas. UI shouldn't do arithmetic on game state.

---

### GAP 10 — Line clear context (Tetris bonus, T-Spin)

**File:** `GameViewModel.swift:159-165`

`.linesCleared` tells the UI how many lines and which rows, but not *how* they were cleared.

**Proposal:**

```swift
case linesCleared(Int, clearedRows: Set<Int>, animationDuration: TimeInterval,
                  isTetris: Bool, isTSpin: Bool)
```

**Benefits:**
- T-Spin clears could get a different animation.
- Score breakdown: "T-Spin Triple +800".

---

### GAP 11 — DAS/ARR as game-level concern

**File:** `GestureHandler.swift:45-89`

iOS implements DAS/ARR as a `Task.sleep` loop calling `viewModel.moveLeft()`. macOS keyboard has no DAS/ARR — same key press fires one action. DAS/ARR are already in `PersistentGameSettings` in TetrisCore but the gesture handler hardcodes values from `Constants.Input`.

**Proposal:** `press(action)` / `release(action)` interface on `GameController` that handles DAS/ARR internally.

**Benefits:**
- Consistency across input methods.
- Configurability (user-tunable DAS/ARR).
- Testability.

---

### GAP 12 — Piece queue (7-bag)

TetrisCore generates a single `nextPiece`. Modern Tetris shows 3-5 upcoming pieces.

**Proposal:** Emit a piece queue event:

```swift
case pieceQueue([TetrominoShape])
```

---

### GAP 13 — Hold piece

No `holdPiece` event or `.hold` `ControlEvent`.

**Proposal:**

```swift
case holdPiece(TetrominoShape?)  // nil = no hold available
case ControlEvent.hold
```

---

### GAP 14 — Soft drop

No `.softDrop` `ControlEvent`.

**Proposal:**

```swift
case ControlEvent.softDrop
```

---

## 4. Summary

| Category | Count | Priority |
|---|---|---|
| Bugs (active) | 8 (B1, B6-B12) | B1 = Medium, rest = Low–Trivial |
| Bugs (fixed) | 3 (B2-B4) | — |
| Code Quality (active) | 11 (S4-S14) | S4, S5, S10 = Medium; rest = Low |
| Code Quality (fixed) | 3 (S1-S3) | — |
| API Opportunities | 11 (GAP 4-14) | GAP 4-5 = High value, GAP 11 = Medium, rest = Nice-to-have |

### Highest-impact quick wins

| # | Item | Effort | Impact |
|---|---|---|---|
| 1 | **B1** — Auto-resume after iOS Settings dismiss | 5 min | Medium (UX) |
| 2 | **S10** — Remove dead `hardDropRowThreshold` | 1 min | Low (cleanup) |
| 3 | **S12** — Deduplicate `pieceBlocks.map(\.x)` | 1 min | Low (cleanliness) |
| 4 | **S8** — Remove double-sync in settings views | 5 min | Low (cleanliness) |
| 5 | **S5** — Add missing `#Preview` macros | 5 min | Low (convention) |
| 6 | **GAP 4** — `hardDropDeltaY` in TetrisCore event | Medium | High (removes ViewModel state) |
| 7 | **GAP 5** — Piece shape/position in event | Medium | High (enables hold, simplifies iOS zones) |
