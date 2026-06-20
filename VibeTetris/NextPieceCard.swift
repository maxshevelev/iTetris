import SwiftUI
import TetrisCore

struct NextPieceCard: View {
    let blocks: Set<PieceCoordinate>
    let color: TetrominoColor

    @Environment(\.colorScheme) var colorScheme

    private var panelBg: Color {
        Constants.Colors.color(Constants.Colors.panelBackgroundLight, Constants.Colors.panelBackgroundDark, scheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT")
                .font(.caption)
                .foregroundStyle(.secondary)
            PiecePreviewView(blocks: blocks, color: color)
                .aspectRatio(1, contentMode: .fit)
        }
        .padding(Constants.Layout.Panel.padding)
        .frame(maxWidth: .infinity)
        .background(panelBg)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.Panel.cornerRadius))
        .shadow(
            color: .black.opacity(Constants.Layout.Panel.shadowOpacity),
            radius: Constants.Layout.Panel.shadowRadius,
            y: Constants.Layout.Panel.shadowY
        )
    }
}

#Preview {
    NextPieceCard(
        blocks: [
            PieceCoordinate(x: 0, y: 1),
            PieceCoordinate(x: 1, y: 1),
            PieceCoordinate(x: 2, y: 1),
            PieceCoordinate(x: 3, y: 1),
        ],
        color: .cyan
    )
}
