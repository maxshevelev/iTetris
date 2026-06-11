import SwiftUI
import TetrisCore

/// Centralized app-wide constants — colors, layout values, animation parameters, and gameplay tuning.
enum Constants {

    // MARK: - Grid

    enum Grid {
        static let defaultWidth = 10
        static let defaultHeight = 20
    }

    // MARK: - Colors

    enum Colors {
        // App background
        static let cream = Color(red: 0.992, green: 0.973, blue: 0.918)
        static let creamDark = Color(red: 0.949, green: 0.918, blue: 0.847)

        // Ghost piece — light shadow showing landing position
        static let ghostPiece = Color.gray.opacity(0.22)

        // Line-clear fire effect
        enum LineClear {
            static let glowOuter = Color.orange
            static let glowMid = Color.red.opacity(0.5)
            static let glowInner = Color.clear

            static let fireCoreTop = Color(red: 1, green: 0.95, blue: 0.6)
            static let fireCoreMid = Color(red: 1, green: 0.5, blue: 0)
            static let fireCoreBot = Color(red: 0.8, green: 0, blue: 0)
        }
    }

    // MARK: - Layout

    enum Layout {
        static let boardMaxWidth: CGFloat = 360
        static let infoPanelWidth: CGFloat = 160
        static let verticalPadding: CGFloat = 8
        static let hStackSpacing: CGFloat = 16

        /// Shared inset applied to blocks inside grid cells.
        static let blockInsetRatio: CGFloat = 0.08

        enum Board {
            static let cornerRadius: CGFloat = 4
            static let borderOpacity: CGFloat = 0.4
            static let borderWidth: CGFloat = 1
            static let gridLineOpacity: CGFloat = 0.18
            static let gridLineWidth: CGFloat = 0.5
        }

        enum InfoPanel {
            static let sectionSpacing: CGFloat = 24
            static let fieldLabelSpacing: CGFloat = 2
            static let nextPieceSpacing: CGFloat = 4
            static let padding: CGFloat = 20
            static let cornerRadius: CGFloat = 12
            static let shadowOpacity: CGFloat = 0.06
            static let shadowRadius: CGFloat = 4
            static let shadowY: CGFloat = 2
        }

        enum Preview {
            static let gridSize = 4
        }

        enum HardDrop {
            static let blockToCellRatio: CGFloat = 0.84
            static let blockCornerRadius: CGFloat = 2
        }

        enum Overlay {
            static let backgroundOpacity: CGFloat = 0.92
            static let vStackSpacing: CGFloat = 16
            static let topScoresSpacing: CGFloat = 4
            static let topScoresHStackSpacing: CGFloat = 8
            static let topScoresFrameWidth: CGFloat = 200
            static let topScoresDisplayCount = 5
            static let buttonTopPadding: CGFloat = 8
        }

        enum Settings {
            static let windowWidth: CGFloat = 320
            static let windowMinHeight: CGFloat = 480
            static let levelRange = 1...10
        }

        enum AppWindow {
            static let defaultWidth: CGFloat = 480
            static let defaultHeight: CGFloat = 640
        }

        // MARK: - iOS Layout

        enum iOS {
            // Top bar
            static let topBarPadding: CGFloat = 16
            static let topBarPaddingVertical: CGFloat = 12
            static let topBarPreviewSize: CGFloat = 40

            // Board — constrained width for breathing room on sides
            static let boardMaxWidth: CGFloat = 240

            // Bottom bar
            static let bottomBarPadding: CGFloat = 20
            static let bottomBarPaddingVertical: CGFloat = 12
        }
    }

    // MARK: - Animation

    enum Animation {
        /// Delay after hard-drop landing before the white flash overlay appears (seconds).
        static let hardDropFlashDelay: TimeInterval = 0.080

        enum Flash {
            static let overlayOpacity: CGFloat = 0.35
            static let duration: TimeInterval = 0.25
        }

        /// Phase-driven parameters for the line-clear "burn" effect.
        /// `cp` (cell progress) ranges 0→1 and drives all sub-effects.
        enum LineClear {
            /// How fast the burn wave travels outward from center (0→1 delay factor).
            static let waveSpeedMultiplier: CGFloat = 0.2
            /// Small epsilon to avoid division by zero when normalizing cell progress.
            static let epsilon: CGFloat = 0.001

            // Flash — bright white burst at the very start
            static let flashPeakOpacity: CGFloat = 1.0
            static let flashPhaseStart: CGFloat = 0.06
            static let flashPhaseDuration: CGFloat = 0.15

            // Glow — expanding radial fire ring
            static let glowInitialScale: CGFloat = 0.6
            static let glowGrowStart: CGFloat = 0.08
            static let glowGrowEnd: CGFloat = 0.35
            static let glowGrowAmount: CGFloat = 1.2
            static let glowShrinkFrom: CGFloat = 1.8
            static let glowShrinkBy: CGFloat = 1.7
            static let glowMinScale: CGFloat = 0.1

            // Core — solid block that shrinks and fades
            static let coreHoldUntil: CGFloat = 0.5
            static let coreFadeDuration: CGFloat = 0.5
            static let coreFullScale: CGFloat = 1.0
            static let coreOpacityHoldUntil: CGFloat = 0.4
            static let coreOpacityFadeDuration: CGFloat = 0.4
            static let coreFullOpacity: CGFloat = 1.0
        }
    }

    // MARK: - Input

    enum Input {
        static let minimumSwipeDistance: CGFloat = 20
        static let pauseLongPressDuration: TimeInterval = 0.5
    }

    // MARK: - Gameplay

    enum Gameplay {
        static let defaultPieceColor: TetrominoColor = .cyan
        static let defaultLevel = 1
        /// Minimum row delta between consecutive `.pieceBlocks` events to trigger a hard-drop animation.
        static let hardDropRowThreshold = 1
    }
}
