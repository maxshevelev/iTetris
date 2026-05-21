import SwiftUI
import TetrisCore

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var hardDropFlash = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            HStack(alignment: .top, spacing: 16) {
                Spacer(minLength: 0)

                TetrisBoardView(
                    grid: viewModel.grid,
                    pieceBlocks: viewModel.pieceBlocks
                )
                .frame(maxWidth: 360, maxHeight: .infinity)
                .padding(.vertical, 8)
                .gesture(swipeGesture)
                .simultaneousGesture(rotateTap)
                .simultaneousGesture(pauseLongPress)
                .overlay(
                    Rectangle()
                        .fill(.white.opacity(hardDropFlash ? 0.35 : 0))
                        .allowsHitTesting(false)
                )

                InfoPanelView(
                    score: viewModel.score,
                    level: viewModel.level,
                    linesCleared: viewModel.linesCleared,
                    nextPieceBlocks: viewModel.nextPieceBlocks
                )
                .frame(width: 160)

                Spacer(minLength: 0)
            }

            if viewModel.displayState == .paused {
                pauseOverlay
            }

            if viewModel.displayState == .gameOver {
                gameOverOverlay
            }
        }
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.hardDropTrigger) {
            hardDropFlash = true
            withAnimation(.easeOut(duration: 0.25)) {
                hardDropFlash = false
            }
        }
        #if os(macOS)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(action: handleKeyPress)
        #endif
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    if dx > 0 { viewModel.moveRight() }
                    else { viewModel.moveLeft() }
                } else if dy > 0 {
                    viewModel.hardDrop()
                }
            }
    }

    private var rotateTap: some Gesture {
        TapGesture()
            .onEnded { viewModel.rotate() }
    }

    private var pauseLongPress: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in viewModel.pause() }
    }

    // MARK: - Overlays

    private var pauseOverlay: some View {
        ZStack {
            Color.cream.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.largeTitle.bold())
                Text("Tap to resume")
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture { viewModel.resume() }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.cream.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())

                VStack(spacing: 4) {
                    Text("Score: \(viewModel.score)")
                        .font(.title2)
                    Text("Level: \(viewModel.level)  Lines: \(viewModel.linesCleared)")
                        .foregroundStyle(.secondary)
                }

                if !viewModel.topScores.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP SCORES")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        case .init("j"): viewModel.moveLeft()
        case .init("l"): viewModel.moveRight()
        case .init("k"): viewModel.rotate()
        case .space:     viewModel.displayState == .paused ? viewModel.resume() : viewModel.hardDrop()
        case .escape:    viewModel.pause()
        default:         return .ignored
        }
        return .handled
    }
    #endif
}

#Preview {
    ContentView()
}
