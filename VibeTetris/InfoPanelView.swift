import SwiftUI
import TetrisCore

struct InfoPanelView: View {
    let score: Int
    let level: Int
    let linesCleared: Int
    let nextPieceBlocks: [PieceBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(score)")
                    .font(.title.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.title.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LINES")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(linesCleared)")
                    .font(.title.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PiecePreviewView(blocks: nextPieceBlocks)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
