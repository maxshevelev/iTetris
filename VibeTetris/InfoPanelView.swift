import SwiftUI
import TetrisCore

/// Stats card — Score, Level, Lines, and Stop button.
struct InfoPanelView: View {
    let score: Int
    let level: Int
    let linesCleared: Int
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

            if let onStop {
                Button("Stop", role: .destructive, action: onStop)
                    .buttonStyle(.bordered)
            }
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
