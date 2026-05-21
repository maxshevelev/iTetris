import SwiftUI
import TetrisCore

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(alignment: .top, spacing: 16) {
                    Spacer(minLength: 0)

                    TetrisBoardView(
                        grid: viewModel.grid,
                        pieceBlocks: viewModel.pieceBlocks
                    )
                    .frame(maxWidth: 360, maxHeight: .infinity)
                    .padding(.vertical, 8)

                    InfoPanelView(
                        score: viewModel.score,
                        level: viewModel.level,
                        linesCleared: viewModel.linesCleared,
                        nextPieceBlocks: viewModel.nextPieceBlocks
                    )

                    Spacer(minLength: 0)
                }

                GameControlsView(
                    onMoveLeft: { viewModel.moveLeft() },
                    onMoveRight: { viewModel.moveRight() },
                    onRotate: { viewModel.rotate() },
                    onHardDrop: { viewModel.hardDrop() },
                    onPause: { viewModel.togglePause() }
                )
                .padding(.bottom, 24)

                Spacer(minLength: 0)
            }

            // Overlays
            if viewModel.displayState == .paused {
                pauseOverlay
            }

            if viewModel.displayState == .gameOver {
                gameOverOverlay
            }
        }
        .onAppear { viewModel.start() }
        #if os(macOS)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(action: handleKeyPress)
        #endif
    }

    // MARK: - Overlays

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Press ESC or tap Pause to continue")
                    .foregroundStyle(.gray)
            }
        }
        .onTapGesture { viewModel.togglePause() }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text("Score: \(viewModel.score)")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Level: \(viewModel.level)  Lines: \(viewModel.linesCleared)")
                        .foregroundStyle(.gray)
                }

                if !viewModel.topScores.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP SCORES")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.top, 8)
                        ForEach(viewModel.topScores.prefix(5), id: \.self) { entry in
                            HStack {
                                Text(entry.playerName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.score)")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 200)
                        }
                    }
                }

                Button("Play Again") {
                    viewModel.hardDrop()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Keyboard (macOS)

    #if os(macOS)
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:  viewModel.moveLeft()
        case .rightArrow: viewModel.moveRight()
        case .upArrow:    viewModel.rotate()
        case .downArrow:  viewModel.hardDrop()
        case .space:      viewModel.hardDrop()
        case .escape:     viewModel.togglePause()
        case .init("q"):  viewModel.quit()
        default:          return .ignored
        }
        return .handled
    }
    #endif
}

#Preview {
    ContentView()
}
