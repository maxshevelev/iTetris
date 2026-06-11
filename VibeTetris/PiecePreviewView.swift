import SwiftUI
import TetrisCore

struct PiecePreviewView: View {
    let blocks: Set<PieceCoordinate>
    let color: TetrominoColor

    var body: some View {
        Canvas { context, size in
            guard !blocks.isEmpty else { return }

            // Compute bounding box of the piece
            let minX = blocks.map(\.x).min()!
            let maxX = blocks.map(\.x).max()!
            let minY = blocks.map(\.y).min()!
            let maxY = blocks.map(\.y).max()!
            let pieceWidth = maxX - minX + 1
            let pieceHeight = maxY - minY + 1

            let cellSize = min(size.width, size.height) / CGFloat(Constants.Layout.Preview.gridSize)
            let totalWidth = CGFloat(pieceWidth) * cellSize
            let totalHeight = CGFloat(pieceHeight) * cellSize

            // Offset to center the bounding box in the canvas
            let offsetX = (size.width - totalWidth) / 2
            let offsetY = (size.height - totalHeight) / 2

            for block in blocks {
                let rect = CGRect(
                    x: offsetX + CGFloat(block.x - minX) * cellSize,
                    y: offsetY + CGFloat(block.y - minY) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                let inset = cellSize * Constants.Layout.blockInsetRatio
                context.fill(
                    Path(rect.insetBy(dx: inset, dy: inset)),
                    with: .color(color.swiftUIColor)
                )
            }
        }
    }
}
