import SwiftUI
import TetrisCore

struct TetrisBoardView: View {
    let grid: [[BlockState]]
    let pieceBlocks: [PieceBlock]
    let isHardDropping: Bool
    let gridWidth = 10
    let gridHeight = 20

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
                        with: .color(.gray.opacity(0.18)),
                        lineWidth: 0.5
                    )

                    if y < grid.count, x < grid[y].count,
                       case .filled(let color) = grid[y][x] {
                        let inset = cellSize * 0.08
                        context.fill(
                            Path(rect.insetBy(dx: inset, dy: inset)),
                            with: .color(color.swiftUIColor)
                        )
                    }
                }
            }

            if !isHardDropping {
                for block in pieceBlocks {
                    guard block.y >= 0, block.x >= 0,
                          block.x < gridWidth, block.y < gridHeight else { continue }
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
        }
        .aspectRatio(CGFloat(gridWidth) / CGFloat(gridHeight), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.gray.opacity(0.4), lineWidth: 1)
        )
    }
}
