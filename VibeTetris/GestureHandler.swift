import Foundation
import SwiftUI

#if os(iOS)

/// Manages dynamic-zone gesture system with intent locking and DAS/ARR auto-repeat.
@MainActor
final class GestureHandler {
    /// Locked intent for the current touch.
    enum Intent { case left, right, rotate }

    var lockedIntent: Intent?
    var isHolding = false
    /// Whether a gesture is currently active (to prevent mid-gesture resets).
    var isGestureActive = false
    private var arrTask: Task<Void, Never>?
    /// Whether hard drop has already fired for this gesture (to fire only once).
    var hasHardDropped = false

    // MARK: - Tap

    /// Process a tap using the locked intent.
    func tap(_ intent: Intent, viewModel: GameViewModel) {
        switch intent {
        case .left:
            viewModel.moveLeft()
            haptic(.move)
        case .right:
            viewModel.moveRight()
            haptic(.move)
        case .rotate:
            viewModel.rotate()
            haptic(.rotate)
        }
    }

    // MARK: - Hold

    /// Start auto-repeat for the locked intent.
    /// Called by LongPressGesture after DAS delay has elapsed.
    /// Rotate intent does not auto-repeat — ignored.
    func holdStart(viewModel: GameViewModel) {
        guard let intent = lockedIntent, !isHolding else { return }
        guard intent != .rotate else { return }
        isHolding = true
        haptic(.move)
        // ARR loop — DAS delay already handled by LongPressGesture
        arrLoop(for: intent, viewModel: viewModel)
    }

    /// Stop auto-repeat.
    func holdStop() {
        arrTask?.cancel()
        arrTask = nil
        isHolding = false
    }

    // MARK: - Piece lifecycle

    /// Reset transient state when a new piece spawns.
    func resetForNewPiece() {
        hasHardDropped = false
    }

    // MARK: - Private

    private func arrLoop(for intent: Intent, viewModel: GameViewModel) {
        Task { @MainActor in
            while isHolding, lockedIntent == intent {
                try? await Task.sleep(nanoseconds: UInt64(Constants.Input.arrInterval * 1_000_000_000))
                guard isHolding, lockedIntent == intent else { return }
                switch intent {
                case .left:  viewModel.moveLeft()
                case .right: viewModel.moveRight()
                case .rotate: break // no auto-rotate
                }
                haptic(.move)
            }
        }
    }

    // MARK: - Haptics

    enum HapticType { case move, rotate, hardDrop }

    private func haptic(_ type: HapticType) {
        Self.haptic(type)
    }

    static func haptic(_ type: HapticType) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch type {
        case .move:       style = .light
        case .rotate:     style = .medium
        case .hardDrop:   style = .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

#endif
