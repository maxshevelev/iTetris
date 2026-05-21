import SwiftUI
import TetrisCore

struct PiecePreviewView: View {
    let blocks: [PieceBlock]
    private let previewSize = 4

    var body: some View {
        Canvas { context, size in
            guard !blocks.isEmpty else { return }
            let cellSize = min(size.width, size.height) / CGFloat(previewSize)
            let offsetX = (size.width - cellSize * CGFloat(previewSize)) / 2
            let offsetY = (size.height - cellSize * CGFloat(previewSize)) / 2

            for block in blocks {
                let rect = CGRect(
                    x: offsetX + CGFloat(block.x) * cellSize,
                    y: offsetY + CGFloat(block.y) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                let inset = cellSize * 0.08
                context.fill(
                    Path(rect.insetBy(dx: inset, dy: inset)),
                    with: .color(block.color.swiftUIColor)
                )
            }
        }
        .frame(width: 80, height: 80)
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.gray.opacity(0.5), lineWidth: 1)
        )
    }
}
