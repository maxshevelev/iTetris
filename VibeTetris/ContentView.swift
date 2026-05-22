import SwiftUI
import TetrisCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var hardDropFlash = false
    @State private var hardDropProgress: CGFloat = 0
    @State private var isAnimatingHardDrop = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            HStack(alignment: .top, spacing: 16) {
                Spacer(minLength: 0)

                TetrisBoardView(
                    grid: viewModel.grid,
                    pieceBlocks: viewModel.pieceBlocks,
                    isHardDropping: isAnimatingHardDrop || viewModel.isHardDropping
                )
                .frame(maxWidth: 360, maxHeight: .infinity)
                .overlay {
                    if isAnimatingHardDrop {
                        GeometryReader { geo in
                            hardDropPieceView(size: geo.size)
                        }
                    }
                }
                .padding(.vertical, 8)
                .gesture(swipeGesture)
                .simultaneousGesture(rotateTap)
                .simultaneousGesture(pauseLongPress)
                .overlay(
                    Rectangle()
                        .fill(.white.opacity(hardDropFlash ? 0.35 : 0))
                        .animation(.easeOut(duration: 0.25), value: hardDropFlash)
                        .allowsHitTesting(false)
                )

                InfoPanelView(
                    score: viewModel.score,
                    level: viewModel.level,
                    linesCleared: viewModel.linesCleared,
                    nextPieceBlocks: viewModel.nextPieceBlocks
                )
                .frame(width: 160)
                .padding(.top, 8)

                Spacer(minLength: 0)
            }

            if viewModel.displayState == .paused {
                pauseOverlay
            }

            if viewModel.displayState == .gameOver {
                gameOverOverlay
            }
        }
        .focused($isFocused)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(action: handleKeyPress)
        .onAppear {
            viewModel.start()
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            #endif
            isFocused = true
        }
        .onChange(of: viewModel.hardDropTrigger) {
            isAnimatingHardDrop = true
            hardDropProgress = 0
            withAnimation(.easeIn(duration: viewModel.hardDropAnimDuration)) {
                hardDropProgress = 1.0
            }
            let duration = viewModel.hardDropAnimDuration
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                isAnimatingHardDrop = false
                hardDropFlash = true
                try? await Task.sleep(for: .milliseconds(80))
                hardDropFlash = false
            }
        }
    }

    // MARK: - Hard Drop Overlay

    private func hardDropPieceView(size: CGSize) -> some View {
        let cellSize = min(size.width / 10, size.height / 20)
        let blockSize = cellSize * 0.84
        let inset = cellSize * 0.08
        let ox = (size.width - cellSize * 10) / 2
        let oy = (size.height - cellSize * 20) / 2

        let blocks = viewModel.pieceBlocks
        let minX = blocks.map(\.x).min() ?? 0
        let minY = blocks.map(\.y).min() ?? 0
        let yOffset = CGFloat(viewModel.hardDropDeltaY) * (1 - hardDropProgress) * cellSize

        return ZStack {
            ForEach(blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 2)
                    .fill(block.color.swiftUIColor)
                    .frame(width: blockSize, height: blockSize)
                    .offset(x: CGFloat(block.x - minX) * cellSize,
                            y: CGFloat(block.y - minY) * cellSize)
            }
        }
        .position(
            x: ox + CGFloat(minX) * cellSize + inset + blockSize / 2,
            y: oy + CGFloat(minY) * cellSize + inset + blockSize / 2 - yOffset
        )
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

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .init("j"): viewModel.moveLeft()
        case .init("l"): viewModel.moveRight()
        case .init("k"): viewModel.rotate()
        case .space:
            if viewModel.displayState == .paused { viewModel.resume() }
            else { viewModel.hardDrop() }
        case .escape: viewModel.pause()
        default: return .ignored
        }
        return .handled
    }
}

#Preview {
    ContentView()
}
