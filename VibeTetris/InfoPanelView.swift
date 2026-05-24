import SwiftUI
import TetrisCore

struct InfoPanelView: View {
    let score: Int
    let level: Int
    let linesCleared: Int
    let nextPieceBlocks: Set<PieceCoordinate>
    let nextPieceColor: TetrominoColor
    var onStop: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(score)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LINES")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(linesCleared)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PiecePreviewView(blocks: nextPieceBlocks, color: nextPieceColor)
                    .aspectRatio(1, contentMode: .fit)
            }

            if let onStop {
                Button("Stop", role: .destructive, action: onStop)
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
