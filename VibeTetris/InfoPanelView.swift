import SwiftUI
import TetrisCore

struct InfoPanelView: View {
    let score: Int
    let level: Int
    let linesCleared: Int
    let nextPieceBlocks: Set<PieceCoordinate>
    let nextPieceColor: TetrominoColor
    var onStop: (() -> Void)?

    @Environment(\.colorScheme) var colorScheme

    private var panelBg: Color {
        Constants.Colors.color(Constants.Colors.panelBackgroundLight, Constants.Colors.panelBackgroundDark, scheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Layout.InfoPanel.sectionSpacing) {
            VStack(alignment: .leading, spacing: Constants.Layout.InfoPanel.fieldLabelSpacing) {
                Text("SCORE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(score)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: Constants.Layout.InfoPanel.fieldLabelSpacing) {
                Text("LEVEL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: Constants.Layout.InfoPanel.fieldLabelSpacing) {
                Text("LINES")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(linesCleared)")
                    .font(.largeTitle.monospacedDigit().weight(.medium))
            }

            VStack(alignment: .leading, spacing: Constants.Layout.InfoPanel.nextPieceSpacing) {
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
        .padding(Constants.Layout.InfoPanel.padding)
        .background(panelBg)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.InfoPanel.cornerRadius))
        .shadow(color: .black.opacity(Constants.Layout.InfoPanel.shadowOpacity), radius: Constants.Layout.InfoPanel.shadowRadius, y: Constants.Layout.InfoPanel.shadowY)
    }
}
