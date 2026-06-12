import SwiftUI
import TetrisCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var viewModel: GameViewModel
    #if os(macOS)
    let controls: ControlsConfig
    #endif

    #if os(macOS)
    init(settings: ObservableSettings = ObservableSettings(), controls: ControlsConfig = ControlsConfig()) {
        self._viewModel = State(initialValue: GameViewModel(settings: settings))
        self.controls = controls
    }
    #else
    let settings: ObservableSettings

    init(settings: ObservableSettings = ObservableSettings()) {
        self.settings = settings
        self._viewModel = State(initialValue: GameViewModel(settings: settings))
    }
    #endif

    @Environment(\.colorScheme) var colorScheme
    @State private var hardDropFlash = false
    @State private var hardDropProgress: CGFloat = 0
    @State private var isAnimatingHardDrop = false
    @State private var lineClearProgress: CGFloat = 0
    @State private var isAnimatingLineClear = false
    #if os(macOS)
    @FocusState private var isFocused: Bool
    #endif
    #if os(iOS)
    @State private var showSettings = false
    #endif

    // MARK: - Computed Colors

    private var appBackground: Color {
        Constants.Colors.color(Constants.Colors.appBackgroundLight, Constants.Colors.appBackgroundDark, scheme: colorScheme)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            #if os(iOS)
            iOSBody
            #endif

            #if os(macOS)
            macOSBody
            #endif

            if viewModel.displayState == .paused {
                pauseOverlay
            }

            if viewModel.displayState == .gameOver {
                gameOverOverlay
            }
        }
        #if os(macOS)
        .focused($isFocused)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(action: handleKeyPress)
        #endif
    }

    // MARK: - Overlays (shared)

    private var pauseOverlay: some View {
        ZStack {
            appBackground.opacity(Constants.Layout.Overlay.backgroundOpacity).ignoresSafeArea()
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
            appBackground.opacity(Constants.Layout.Overlay.backgroundOpacity).ignoresSafeArea()
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
                    viewModel.restartGame()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Constants.Layout.Overlay.buttonTopPadding)
            }
        }
    }

    // MARK: - iOS Body

    #if os(iOS)
    private var iOSBody: some View {
        VStack(spacing: 0) {
            // Nav bar: Settings (left) + Pause (right)
            HStack {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(viewModel.displayState == .paused ? "Resume" : "Pause", action: {
                    if viewModel.displayState == .paused {
                        viewModel.resume()
                    } else {
                        viewModel.pause()
                    }
                })
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Constants.Layout.iOS.topBarPadding)
            .padding(.vertical, Constants.Layout.iOS.topBarPaddingVertical)

            // Next piece preview — centered
            PiecePreviewView(blocks: viewModel.nextPieceBlocks, color: viewModel.nextPieceColor)
                .frame(width: Constants.Layout.iOS.topBarPreviewSize, height: Constants.Layout.iOS.topBarPreviewSize)
                .padding(.vertical, Constants.Layout.iOS.topBarPaddingVertical)

            // Board — constrained, centered with breathing room
            ZStack {
                TetrisBoardView(
                    grid: isAnimatingLineClear ? (viewModel.lineClearGridSnapshot ?? viewModel.grid) : viewModel.grid,
                    ghostPieceBlocks: viewModel.ghostPieceBlocks,
                    pieceBlocks: viewModel.pieceBlocks,
                    pieceColor: viewModel.pieceColor,
                    isHardDropping: isAnimatingHardDrop,
                    gridWidth: viewModel.gridWidth,
                    gridHeight: viewModel.gridHeight
                )
                .aspectRatio(CGFloat(viewModel.gridWidth) / CGFloat(viewModel.gridHeight), contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        if isAnimatingLineClear {
                            iOSLineClearBurnView(size: geo.size)
                        }
                        if isAnimatingHardDrop {
                            iOSHardDropPieceView(size: geo.size)
                        }
                    }
                }
                .overlay {
                    Rectangle()
                        .fill(.white.opacity(hardDropFlash ? Constants.Animation.Flash.overlayOpacity : 0))
                        .animation(.easeOut(duration: Constants.Animation.Flash.duration), value: hardDropFlash)
                        .allowsHitTesting(false)
                }
            }

            // Bottom bar: level · score · lines
            HStack(spacing: 40) {
                iOSStatField(label: "LEVEL", value: "\(viewModel.level)")
                iOSStatField(label: "SCORE", value: "\(viewModel.score)")
                iOSStatField(label: "LINES", value: "\(viewModel.linesCleared)")
            }
            .padding(.horizontal, Constants.Layout.iOS.bottomBarPadding)
            .padding(.vertical, Constants.Layout.iOS.bottomBarPaddingVertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(swipeGesture)
        .simultaneousGesture(rotateTap)
        .simultaneousGesture(pauseLongPress)
        .sheet(isPresented: $showSettings) {
            IOSSettingsView(settings: settings)
        }
        .onAppear {
            viewModel.start()
        }
        .onChange(of: viewModel.hardDropTrigger) { onHardDropTrigger() }
        .onChange(of: viewModel.lineClearTrigger) { onLineClearTrigger() }
    }

    private func iOSStatField(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.medium))
        }
    }

    private func iOSLineClearBurnView(size: CGSize) -> some View {
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

    private func iOSHardDropPieceView(size: CGSize) -> some View {
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

    // MARK: - iOS Gestures

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
    #endif

    // MARK: - macOS Body

    #if os(macOS)
    private var macOSBody: some View {
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
            .overlay {
                Rectangle()
                    .fill(.white.opacity(hardDropFlash ? Constants.Animation.Flash.overlayOpacity : 0))
                    .animation(.easeOut(duration: Constants.Animation.Flash.duration), value: hardDropFlash)
                    .allowsHitTesting(false)
            }
            .padding(.vertical, Constants.Layout.verticalPadding)
            .gesture(swipeGesture)
            .simultaneousGesture(rotateTap)
            .simultaneousGesture(pauseLongPress)

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
        .onAppear {
            viewModel.start()
            NSApp.activate(ignoringOtherApps: true)
            isFocused = true
        }
        .onChange(of: viewModel.hardDropTrigger) { onHardDropTrigger() }
        .onChange(of: viewModel.lineClearTrigger) { onLineClearTrigger() }
    }

    // MARK: - macOS Gestures

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

    // MARK: - macOS Keyboard

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let keyStr = ControlsConfig.keyString(from: press.key)

        if keyStr == controls.moveLeft  { viewModel.moveLeft(); return .handled }
        if keyStr == controls.moveRight { viewModel.moveRight(); return .handled }
        if keyStr == controls.rotate    { viewModel.rotate(); return .handled }
        if keyStr == controls.resume, viewModel.displayState == .paused {
            viewModel.resume()
            return .handled
        }
        if keyStr == controls.hardDrop {
            viewModel.hardDrop()
            return .handled
        }
        if keyStr == controls.pause { viewModel.pause(); return .handled }
        if keyStr == controls.stop  { viewModel.stop(); return .handled }

        return .ignored
    }
    #endif

    // MARK: - Animation Handlers (shared)

    private func onHardDropTrigger() {
        isAnimatingHardDrop = true
        hardDropProgress = 0
        let duration = viewModel.hardDropAnimDuration
        withAnimation(.easeIn(duration: duration), completionCriteria: .logicallyComplete) {
            hardDropProgress = 1.0
        } completion: {
            isAnimatingHardDrop = false
            hardDropFlash = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(Constants.Animation.hardDropFlashDelay * 1000)))
                hardDropFlash = false
            }
        }
    }

    private func onLineClearTrigger() {
        isAnimatingLineClear = true
        lineClearProgress = 0
        let duration = viewModel.lineClearAnimDuration
        withAnimation(.easeIn(duration: duration), completionCriteria: .logicallyComplete) {
            lineClearProgress = 1.0
        } completion: {
            isAnimatingLineClear = false
            viewModel.lineClearGridSnapshot = nil
        }
    }

    // MARK: - Line Clear Burn Overlay (macOS)

    #if os(macOS)
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
    #endif

    // MARK: - Shared Cell Burst

    private func cellBurst(cp: CGFloat, cellSize: CGFloat) -> some View {
        typealias LC = Constants.Animation.LineClear

        let flash: CGFloat = cp < LC.flashPhaseStart
            ? LC.flashPeakOpacity
            : max(0, LC.flashPeakOpacity - (cp - LC.flashPhaseStart) / LC.flashPhaseDuration)

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

        let coreScale: CGFloat = cp < LC.coreHoldUntil
            ? LC.coreFullScale
            : max(0, LC.coreFullScale - (cp - LC.coreHoldUntil) / LC.coreFadeDuration)

        let coreOpacity: CGFloat = cp < LC.coreOpacityHoldUntil
            ? LC.coreFullOpacity
            : max(0, LC.coreFullOpacity - (cp - LC.coreOpacityHoldUntil) / LC.coreOpacityFadeDuration)

        return ZStack {
            Rectangle()
                .fill(.white.opacity(flash))
                .frame(width: cellSize, height: cellSize)

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
}

#if os(macOS)
#Preview {
    ContentView()
}
#endif
