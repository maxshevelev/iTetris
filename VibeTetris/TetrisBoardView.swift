import SwiftUI
import TetrisCore

struct TetrisBoardView: View {
    let grid: [PieceCoordinate: TetrominoColor]
    let ghostPieceBlocks: Set<PieceCoordinate>
    let pieceBlocks: Set<PieceCoordinate>
    let pieceColor: TetrominoColor
    let isHardDropping: Bool
    let gridWidth: Int
    let gridHeight: Int

    var body: some View {
        Canvas { context, size in
            let cellW = size.width / CGFloat(gridWidth)
            let cellH = size.height / CGFloat(gridHeight)
            let cellSize = min(cellW, cellH)
            let offsetX = (size.width - cellSize * CGFloat(gridWidth)) / 2
            let offsetY = (size.height - cellSize * CGFloat(gridHeight)) / 2

            for y in 0..<gridHeight {
                for x in 0..<gridWidth {
                    let rect = CGRect(
                        x: offsetX + CGFloat(x) * cellSize,
                        y: offsetY + CGFloat(y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(.white))
                    context.stroke(
                        Path(rect),
                        with: .color(.gray.opacity(Constants.Layout.Board.gridLineOpacity)),
                        lineWidth: Constants.Layout.Board.gridLineWidth
                    )

                    if let color = grid[PieceCoordinate(x: x, y: y)] {
                        let inset = cellSize * Constants.Layout.blockInsetRatio
                        context.fill(
                            Path(rect.insetBy(dx: inset, dy: inset)),
                            with: .color(color.swiftUIColor)
                        )
                    }
                }
            }

            if !isHardDropping {
                // Ghost piece — landing preview
                for block in ghostPieceBlocks {
                    guard block.y >= 0, block.x >= 0,
                          block.x < gridWidth, block.y < gridHeight else { continue }
                    let rect = CGRect(
                        x: offsetX + CGFloat(block.x) * cellSize,
                        y: offsetY + CGFloat(block.y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    let inset = cellSize * Constants.Layout.blockInsetRatio
                    context.fill(
                        Path(rect.insetBy(dx: inset, dy: inset)),
                        with: .color(Constants.Colors.ghostPiece)
                    )
                }

                for block in pieceBlocks {
                    guard block.y >= 0, block.x >= 0,
                          block.x < gridWidth, block.y < gridHeight else { continue }
                    let rect = CGRect(
                        x: offsetX + CGFloat(block.x) * cellSize,
                        y: offsetY + CGFloat(block.y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    let inset = cellSize * Constants.Layout.blockInsetRatio
                    context.fill(
                        Path(rect.insetBy(dx: inset, dy: inset)),
                        with: .color(pieceColor.swiftUIColor)
                    )
                }
            }
        }
        .aspectRatio(CGFloat(gridWidth) / CGFloat(gridHeight), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.Board.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.Board.cornerRadius)
                .stroke(.gray.opacity(Constants.Layout.Board.borderOpacity), lineWidth: Constants.Layout.Board.borderWidth)
        )
    }
}
