import SwiftUI

/// Card showing current keybindings as action → key badge rows.
struct ControlsHelpView: View {
    let controls: ControlsConfig

    @Environment(\.colorScheme) var colorScheme

    /// Keybinding rows to display — excludes Resume (context-sensitive).
    private let rows: [(label: String, key: String)]

    init(controls: ControlsConfig) {
        self.controls = controls
        self.rows = [
            ("Move Left",   ControlsConfig.displayName(for: controls.moveLeft)),
            ("Rotate",      ControlsConfig.displayName(for: controls.rotate)),
            ("Move Right",  ControlsConfig.displayName(for: controls.moveRight)),
            ("Hard Drop",   ControlsConfig.displayName(for: controls.hardDrop)),
            ("Pause",       ControlsConfig.displayName(for: controls.pause)),
            ("Stop",        ControlsConfig.displayName(for: controls.stop)),
        ]
    }

    private var panelBg: Color {
        Constants.Colors.color(Constants.Colors.panelBackgroundLight, Constants.Colors.panelBackgroundDark, scheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTROLS")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(rows, id: \.label) { row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    keyBadge(row.key)
                }
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

    @ViewBuilder
    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(.caption)
            .padding(.horizontal, Constants.Layout.Panel.keyBadgeHorizontalPadding)
            .padding(.vertical, Constants.Layout.Panel.keyBadgeVerticalPadding)
            .background(panelBg.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.Panel.keyBadgeCornerRadius))
    }
}

#Preview {
    ControlsHelpView(controls: ControlsConfig())
}
