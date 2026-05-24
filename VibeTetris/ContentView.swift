import SwiftUI
import TetrisCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var viewModel: GameViewModel

    init(settings: ObservableSettings = ObservableSettings()) {
        self._viewModel = State(initialValue: GameViewModel(settings: settings))
    }
    @State private var hardDropFlash = false
    @State private var hardDropProgress: CGFloat = 0
    @State private var isAnimatingHardDrop = false
    @State private var lineClearProgress: CGFloat = 0
    @State private var isAnimatingLineClear = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            HStack(alignment: .top, spacing: 16) {
                Spacer(minLength: 0)

                TetrisBoardView(
                    grid: isAnimatingLineClear ? (viewModel.lineClearGridSnapshot ?? viewModel.grid) : viewModel.grid,
                    pieceBlocks: viewModel.pieceBlocks,
                    pieceColor: viewModel.pieceColor,
                    isHardDropping: isAnimatingHardDrop,
                    gridWidth: viewModel.gridWidth,
                    gridHeight: viewModel.gridHeight
                )
                .frame(maxWidth: 360, maxHeight: .infinity)
                .overlay {
                    GeometryReader { geo in
                        if isAnimatingLineClear {
                            lineClearBurnView(size: geo.size)
                        }
                        if isAnimatingHardDrop {
                            hardDropPieceView(size: geo.size)
                        }
                    }
                }
                .padding(.vertical, 8)
                .gesture(swipeGesture)
                .simultaneousGesture(rotateTap)
                .simultaneousGesture(pauseLongPress)
                .overlay {
                    Rectangle()
                        .fill(.white.opacity(hardDropFlash ? 0.35 : 0))
                        .animation(.easeOut(duration: 0.25), value: hardDropFlash)
                        .allowsHitTesting(false)
                }

                InfoPanelView(
                    score: viewModel.score,
                    level: viewModel.level,
                    linesCleared: viewModel.linesCleared,
                    nextPieceBlocks: viewModel.nextPieceBlocks,
                    nextPieceColor: viewModel.nextPieceColor,
                    onStop: { viewModel.stop() }
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
            let duration = viewModel.hardDropAnimDuration
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: duration)) {
                    hardDropProgress = 1.0
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration + 0.05))
                isAnimatingHardDrop = false
                hardDropFlash = true
                try? await Task.sleep(for: .milliseconds(80))
                hardDropFlash = false
            }
        }
        .onChange(of: viewModel.lineClearTrigger) {
            isAnimatingLineClear = true
            lineClearProgress = 0
            let duration = viewModel.lineClearAnimDuration
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: duration)) {
                    lineClearProgress = 1.0
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration + 0.05))
                isAnimatingLineClear = false
                viewModel.lineClearGridSnapshot = nil
            }
        }
    }

    // MARK: - Line Clear Burn Overlay

    private func lineClearBurnView(size: CGSize) -> some View {
        let gw = CGFloat(viewModel.gridWidth)
        let gh = CGFloat(viewModel.gridHeight)
        let cellSize = min(size.width / gw, size.height / gh)
        let offsetX = (size.width - cellSize * gw) / 2
        let offsetY = (size.height - cellSize * gh) / 2
        let p = lineClearProgress
        let cols = viewModel.gridWidth

        return ForEach(Array(viewModel.lineClearRows), id: \.self) { row in
            ForEach(0..<cols, id: \.self) { col in
                let dist = abs(CGFloat(col) - CGFloat(cols - 1) / 2) / (CGFloat(cols - 1) / 2)
                let delay = dist * 0.2
                let cp = max(0, min(1, (p - delay) / max(0.001, 1 - delay)))

                cellBurst(cp: cp, cellSize: cellSize)
                    .position(
                        x: offsetX + cellSize * (CGFloat(col) + 0.5),
                        y: offsetY + cellSize * (CGFloat(row) + 0.5)
                    )
            }
        }
    }

    private func cellBurst(cp: CGFloat, cellSize: CGFloat) -> some View {
        let flash: CGFloat = cp < 0.06 ? 1.0 : max(0, 1.0 - (cp - 0.06) / 0.15)
        let glowScale: CGFloat = cp < 0.08 ? 0.6 : (cp < 0.35 ? 0.6 + 1.2 * (cp - 0.08) / 0.27 : max(0.1, 1.8 - 1.7 * (cp - 0.35) / 0.65))
        let coreScale: CGFloat = cp < 0.5 ? 1.0 : max(0, 1.0 - (cp - 0.5) / 0.5)
        let coreOpacity: CGFloat = cp < 0.4 ? 1.0 : max(0, 1.0 - (cp - 0.4) / 0.4)

        return ZStack {
            // Flash — bright white burst
            Rectangle()
                .fill(.white.opacity(flash))
                .frame(width: cellSize, height: cellSize)

            // Outer glow
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [
                        .orange,
                        .red.opacity(0.5),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: cellSize * glowScale
                ))
                .frame(width: cellSize * 2 * glowScale, height: cellSize * 2 * glowScale)

            // Fire core
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1, green: 0.95, blue: 0.6),
                        Color(red: 1, green: 0.5, blue: 0),
                        Color(red: 0.8, green: 0, blue: 0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .opacity(coreOpacity)
                .frame(width: cellSize * coreScale, height: cellSize * coreScale)
        }
    }

    // MARK: - Hard Drop Overlay

    private func hardDropPieceView(size: CGSize) -> some View {
        let gw = CGFloat(viewModel.gridWidth)
        let gh = CGFloat(viewModel.gridHeight)
        let cellSize = min(size.width / gw, size.height / gh)
        let blockSize = cellSize * 0.84
        let inset = cellSize * 0.08
        let ox = (size.width - cellSize * gw) / 2
        let oy = (size.height - cellSize * gh) / 2

        let blocks = Array(viewModel.pieceBlocks)
        let minX = blocks.map(\.x).min() ?? 0
        let minY = blocks.map(\.y).min() ?? 0
        let yOffset = CGFloat(viewModel.hardDropDeltaY) * (1 - hardDropProgress) * cellSize

        return ZStack {
            ForEach(blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: 2)
                    .fill(viewModel.pieceColor.swiftUIColor)
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
                Button("Resume") { viewModel.resume() }
                    .buttonStyle(.borderedProminent)
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
                        .font(.title)
                    Text("Level: \(viewModel.level)  Lines: \(viewModel.linesCleared)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.topScores.isEmpty {
                    VStack(spacing: 4) {
                        Text("TOP SCORES")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        ForEach(viewModel.topScores.prefix(5), id: \.self) { entry in
                            HStack(spacing: 8) {
                                Text(entry.playerName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.score)")
                                    .monospacedDigit()
                            }
                            .font(.title3)
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
        case .init("q"): viewModel.stop()
        default: return .ignored
        }
        return .handled
    }
}

#Preview {
    ContentView()
}
