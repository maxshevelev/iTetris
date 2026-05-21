import SwiftUI
import TetrisCore

struct InfoPanelView: View {
    let score: Int
    let level: Int
    let linesCleared: Int
    let nextPieceBlocks: [PieceBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORE")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("\(score)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("LEVEL")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("\(level)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("LINES")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("\(linesCleared)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.caption)
                    .foregroundStyle(.gray)
                PiecePreviewView(blocks: nextPieceBlocks)
            }
        }
        .padding(12)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
