import SwiftUI

struct GameControlsView: View {
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onRotate: () -> Void
    let onHardDrop: () -> Void
    let onPause: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ControlButton(systemName: "arrow.left", action: onMoveLeft)
            ControlButton(systemName: "arrow.right", action: onMoveRight)
            ControlButton(systemName: "arrow.triangle.2.circlepath", action: onRotate)
            ControlButton(systemName: "arrow.down.to.line", action: onHardDrop)
            ControlButton(systemName: "pause", action: onPause)
        }
    }
}

private struct ControlButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
