import SwiftUI
import TetrisCore

/// Cached grid background — white cells with subtle grid lines.
private struct GridBackgroundView: View {
    let gridWidth: Int
    let gridHeight: Int

    var body: some View {
        Canvas { context, size in
            let cellW = size.width / CGFloat(gridWidth)
            let cellH = size.height / CGFloat(gridHeight)
            let cellSize = min(cellW, cellH)
            let ox = (size.width - cellSize * CGFloat(gridWidth)) / 2
            let oy = (size.height - cellSize * CGFloat(gridHeight)) / 2

            for y in 0..<gridHeight {
                for x in 0..<gridWidth {
                    let rect = CGRect(
                        x: ox + CGFloat(x) * cellSize,
                        y: oy + CGFloat(y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(Path(rect), with: .color(.white))
                    context.stroke(
                        Path(rect),
                        with: .color(.gray.opacity(Constants.Layout.Board.gridLineOpacity)),
                        lineWidth: Constants.Layout.Board.gridLineWidth
                    )
                }
            }
        }
    }
}

/// Cached locked blocks — only redraws when the grid dictionary changes.
private struct LockedBlocksView: View {
    let grid: [PieceCoordinate: TetrominoColor]
    let gridWidth: Int
    let gridHeight: Int

    var body: some View {
        Canvas { context, size in
            let cellW = size.width / CGFloat(gridWidth)
            let cellH = size.height / CGFloat(gridHeight)
            let cellSize = min(cellW, cellH)
            let offsetX = (size.width - cellSize * CGFloat(gridWidth)) / 2
            let offsetY = (size.height - cellSize * CGFloat(gridHeight)) / 2
            let inset = cellSize * Constants.Layout.blockInsetRatio

            for (coord, color) in grid {
                guard coord.x >= 0, coord.x < gridWidth,
                      coord.y >= 0, coord.y < gridHeight else { continue }
                let rect = CGRect(
                    x: offsetX + CGFloat(coord.x) * cellSize,
                    y: offsetY + CGFloat(coord.y) * cellSize,
                    width: cellSize,
                    height: cellSize
                ).insetBy(dx: inset, dy: inset)
                context.fill(Path(rect), with: .color(color.swiftUIColor))
            }
        }
    }
}

// MARK: - TetrisBoardView

struct TetrisBoardView: View {
    let grid: [PieceCoordinate: TetrominoColor]
    let ghostPieceBlocks: Set<PieceCoordinate>
    let pieceBlocks: Set<PieceCoordinate>
    let pieceColor: TetrominoColor
    let isHardDropping: Bool
    let gridWidth: Int
    let gridHeight: Int

    var body: some View {
        ZStack {
            // Layer 1: grid background (cached via drawingGroup)
            GridBackgroundView(gridWidth: gridWidth, gridHeight: gridHeight)
                .drawingGroup()

            // Layer 2: locked blocks (cached via drawingGroup)
            LockedBlocksView(grid: grid, gridWidth: gridWidth, gridHeight: gridHeight)
                .drawingGroup()

            // Layer 3: ghost + active piece (redraws every tick)
            Canvas { context, size in
                let cellW = size.width / CGFloat(gridWidth)
                let cellH = size.height / CGFloat(gridHeight)
                let cellSize = min(cellW, cellH)
                let offsetX = (size.width - cellSize * CGFloat(gridWidth)) / 2
                let offsetY = (size.height - cellSize * CGFloat(gridHeight)) / 2
                let inset = cellSize * Constants.Layout.blockInsetRatio

                func cellRect(_ block: PieceCoordinate) -> CGRect {
                    CGRect(
                        x: offsetX + CGFloat(block.x) * cellSize,
                        y: offsetY + CGFloat(block.y) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                }

                func fillBlock(_ block: PieceCoordinate, _ color: Color) {
                    let rect = cellRect(block).insetBy(dx: inset, dy: inset)
                    context.fill(Path(rect), with: .color(color))
                }

                // Ghost piece
                for block in ghostPieceBlocks {
                    guard block.x >= 0, block.x < gridWidth,
                          block.y >= 0, block.y < gridHeight else { continue }
                    fillBlock(block, Constants.Colors.ghostPiece)
                }

                // Active piece
                if !isHardDropping {
                    for block in pieceBlocks {
                        guard block.x >= 0, block.x < gridWidth,
                              block.y >= 0, block.y < gridHeight else { continue }
                        fillBlock(block, pieceColor.swiftUIColor)
                    }
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
