# VibeTetris 🎮

A cross-platform Tetris game built with SwiftUI, powered by the [TetrisCore](https://github.com/maxshevelev/TetrisCore) engine.

## Features

- **SRS rotation** with full wall-kick tables (Super Rotation System)
- **Ghost piece** — translucent landing preview as you move
- **Hard-drop animation** — piece slides down with a landing flash
- **Line-clear burn effect** — row-removal animation with radial fire gradients
- **Pause / resume**, game-over screen with local leaderboard
- **macOS:** keyboard controls (j/l — move, k — rotate, space — hard drop, escape — pause)
- **iOS:** swipe to move, tap to rotate, long press to pause
- **Settings window** (macOS) — player name, animation toggles, initial level

## Architecture

```
TetrisCore (SPM package)
    ↓ AsyncStream<Set<GameEvent>>
GameViewModel (two-pass apply)
    ↓ @Observable properties
SwiftUI Views (Canvas-based rendering)
```

- **Three-layer board caching:** grid background → locked blocks → ghost/active piece
- **Animation completion** via `withAnimation(completionCriteria:)` — no fragile timers
- **Constants.swift** — all magic numbers, colors, and layout values centralized
- **No game logic in the UI layer** — everything goes through TetrisCore

## Building

Open `VibeTetris.xcodeproj` in Xcode 16+ and run on macOS (15.7+) or iOS (18+).

## Testing

13 unit tests covering all event types in `GameViewModel.apply()`, including order-independence verification.
