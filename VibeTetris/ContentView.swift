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
            Constants.Colors.cream.ignoresSafeArea()

            HStack(alignment: .top, spacing: Constants.Layout.hStackSpacing) {
                Spacer(minLength: 0)

                TetrisBoardView(
                    grid: isAnimatingLineClear ? (viewModel.lineClearGridSnapshot ?? viewModel.grid) : viewModel.grid,
                    ghostPieceBlocks: viewModel.ghostPieceBlocks,
                    pieceBlocks: viewModel.pieceBlocks,
                    pieceColor: viewModel.pieceColor,
                    isHardDropping: isAnimatingHardDrop,
                    gridWidth: viewModel.gridWidth,
                    gridHeight: viewModel.gridHeight
                )
                .frame(maxWidth: Constants.Layout.boardMaxWidth, maxHeight: .infinity)
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
                .padding(.vertical, Constants.Layout.verticalPadding)
                .gesture(swipeGesture)
                .simultaneousGesture(rotateTap)
                .simultaneousGesture(pauseLongPress)
                .overlay {
                    Rectangle()
                        .fill(.white.opacity(hardDropFlash ? Constants.Animation.Flash.overlayOpacity : 0))
                        .animation(.easeOut(duration: Constants.Animation.Flash.duration), value: hardDropFlash)
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
                .frame(width: Constants.Layout.infoPanelWidth)
                .padding(.top, Constants.Layout.verticalPadding)

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
                try? await Task.sleep(for: .seconds(duration + Constants.Animation.completionBuffer))
                isAnimatingHardDrop = false
                hardDropFlash = true
                try? await Task.sleep(for: .milliseconds(Int(Constants.Animation.hardDropFlashDelay * 1000)))
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
                try? await Task.sleep(for: .seconds(duration + Constants.Animation.completionBuffer))
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
                let delay = dist * Constants.Animation.LineClear.waveSpeedMultiplier
                let cp = max(0, min(1, (p - delay) / max(Constants.Animation.LineClear.epsilon, 1 - delay)))

                cellBurst(cp: cp, cellSize: cellSize)
                    .position(
                        x: offsetX + cellSize * (CGFloat(col) + 0.5),
                        y: offsetY + cellSize * (CGFloat(row) + 0.5)
                    )
            }
        }
    }

    private func cellBurst(cp: CGFloat, cellSize: CGFloat) -> some View {
        typealias LC = Constants.Animation.LineClear

        // Flash — bright white burst at the very start
        let flash: CGFloat = cp < LC.flashPhaseStart
            ? LC.flashPeakOpacity
            : max(0, LC.flashPeakOpacity - (cp - LC.flashPhaseStart) / LC.flashPhaseDuration)

        // Glow — expanding radial fire ring
        let glowScale: CGFloat
        if cp < LC.glowGrowStart {
            glowScale = LC.glowInitialScale
        } else if cp < LC.glowGrowEnd {
            let growProgress = (cp - LC.glowGrowStart) / (LC.glowGrowEnd - LC.glowGrowStart)
            glowScale = LC.glowInitialScale + LC.glowGrowAmount * growProgress
        } else {
            let shrinkProgress = (cp - LC.glowGrowEnd) / (1 - LC.glowGrowEnd)
            glowScale = max(LC.glowMinScale, LC.glowShrinkFrom - LC.glowShrinkBy * shrinkProgress)
        }

        // Core — solid block that shrinks
        let coreScale: CGFloat = cp < LC.coreHoldUntil
            ? LC.coreFullScale
            : max(0, LC.coreFullScale - (cp - LC.coreHoldUntil) / LC.coreFadeDuration)

        // Core opacity — fades out before the scale shrinks
        let coreOpacity: CGFloat = cp < LC.coreOpacityHoldUntil
            ? LC.coreFullOpacity
            : max(0, LC.coreFullOpacity - (cp - LC.coreOpacityHoldUntil) / LC.coreOpacityFadeDuration)

        return ZStack {
            // Flash — bright white burst
            Rectangle()
                .fill(.white.opacity(flash))
                .frame(width: cellSize, height: cellSize)

            // Outer glow
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [
                        Constants.Colors.LineClear.glowOuter,
                        Constants.Colors.LineClear.glowMid,
                        Constants.Colors.LineClear.glowInner
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
                        Constants.Colors.LineClear.fireCoreTop,
                        Constants.Colors.LineClear.fireCoreMid,
                        Constants.Colors.LineClear.fireCoreBot
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
        let blockSize = cellSize * Constants.Layout.HardDrop.blockToCellRatio
        let inset = cellSize * Constants.Layout.blockInsetRatio
        let ox = (size.width - cellSize * gw) / 2
        let oy = (size.height - cellSize * gh) / 2

        let blocks = Array(viewModel.pieceBlocks)
        let minX = blocks.map(\.x).min() ?? 0
        let minY = blocks.map(\.y).min() ?? 0
        let yOffset = CGFloat(viewModel.hardDropDeltaY) * (1 - hardDropProgress) * cellSize

        return ZStack {
            ForEach(blocks, id: \.self) { block in
                RoundedRectangle(cornerRadius: Constants.Layout.HardDrop.blockCornerRadius)
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
        DragGesture(minimumDistance: Constants.Input.minimumSwipeDistance)
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
        LongPressGesture(minimumDuration: Constants.Input.pauseLongPressDuration)
            .onEnded { _ in viewModel.pause() }
    }

    // MARK: - Overlays

    private var pauseOverlay: some View {
        ZStack {
            Constants.Colors.cream.opacity(Constants.Layout.Overlay.backgroundOpacity).ignoresSafeArea()
            VStack(spacing: Constants.Layout.Overlay.vStackSpacing) {
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
            Constants.Colors.cream.opacity(Constants.Layout.Overlay.backgroundOpacity).ignoresSafeArea()
            VStack(spacing: Constants.Layout.Overlay.vStackSpacing) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())

                VStack(spacing: Constants.Layout.Overlay.topScoresSpacing) {
                    Text("Score: \(viewModel.score)")
                        .font(.title)
                    Text("Level: \(viewModel.level)  Lines: \(viewModel.linesCleared)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.topScores.isEmpty {
                    VStack(spacing: Constants.Layout.Overlay.topScoresSpacing) {
                        Text("TOP SCORES")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, Constants.Layout.Overlay.buttonTopPadding)
                        ForEach(viewModel.topScores.prefix(Constants.Layout.Overlay.topScoresDisplayCount), id: \.self) { entry in
                            HStack(spacing: Constants.Layout.Overlay.topScoresHStackSpacing) {
                                Text(entry.playerName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.score)")
                                    .monospacedDigit()
                            }
                            .font(.title3)
                            .frame(width: Constants.Layout.Overlay.topScoresFrameWidth)
                        }
                    }
                }

                Button("Play Again") {
                    viewModel.hardDrop()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Constants.Layout.Overlay.buttonTopPadding)
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
