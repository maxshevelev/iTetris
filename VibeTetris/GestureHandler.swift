import Foundation
import SwiftUI

#if os(iOS)

/// Manages the three-zone gesture system with DAS/ARR auto-repeat.
@MainActor
final class GestureHandler {
    /// Direction for auto-repeat.
    enum Direction { case left, right }

    private var activeDirection: Direction?
    private var arrTask: Task<Void, Never>?
   /// Whether a hold was active (to suppress tap after hold).
    var holdActive = false
    /// Last known touch x position (set by DragGesture onChanged).
    var lastTouchX: CGFloat = 0

    // MARK: - Tap

    /// Process a tap at the given x position.
    func tap(at x: CGFloat, width: CGFloat, viewModel: GameViewModel) {
        let zone = zone(for: x, width: width)
        switch zone {
        case .left:
            viewModel.moveLeft()
            haptic(.move)
        case .center:
            viewModel.rotate()
            haptic(.rotate)
        case .right:
            viewModel.moveRight()
            haptic(.move)
        }
    }

    // MARK: - Hold

  /// Start auto-repeat for the given zone.
    /// Called by LongPressGesture after DAS delay has elapsed.
    func holdStart(width: CGFloat, viewModel: GameViewModel) {
        guard activeDirection == nil else { return }
        let zone = zone(for: lastTouchX, width: width)
        let dir: Direction?
        switch zone {
        case .left:   dir = .left
        case .center: dir = nil
        case .right:  dir = .right
        }
        guard let dir else { return }
        activeDirection = dir
        holdActive = true
        haptic(.move)
        // ARR loop — DAS delay already handled by LongPressGesture
        arrLoop(for: dir, viewModel: viewModel)
    }

    /// Stop auto-repeat.
    func holdStop() {
        arrTask?.cancel()
        arrTask = nil
        activeDirection = nil
        holdActive = false
    }

    // MARK: - Hard drop

    /// Check if the vertical movement qualifies as hard drop.
    func isHardDrop(_ dy: CGFloat) -> Bool {
        dy > Constants.Input.hardDropThreshold
    }

    // MARK: - Private

    private enum Zone { case left, center, right }

    private func zone(for x: CGFloat, width: CGFloat) -> Zone {
        let third = width / 3
        if x < third { return .left }
        if x < 2 * third { return .center }
        return .right
    }

    private func arrLoop(for direction: Direction, viewModel: GameViewModel) {
        Task { @MainActor in
            while activeDirection == direction {
                try? await Task.sleep(nanoseconds: UInt64(Constants.Input.arrInterval * 1_000_000_000))
                guard activeDirection == direction else { return }
                switch direction {
                case .left:  viewModel.moveLeft()
                case .right: viewModel.moveRight()
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
