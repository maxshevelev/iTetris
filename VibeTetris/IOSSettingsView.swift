import SwiftUI

struct IOSSettingsView: View {
    @Bindable var settings: ObservableSettings

    var body: some View {
        NavigationView {
            Form {
                Section("Player") {
                    TextField("Name", text: $settings.playerName)
                }
                Section("Gameplay") {
                    Toggle("Immediate lock after hard drop", isOn: $settings.lockImmediatelyAfterHardDrop)
                    Picker("Initial level", selection: $settings.initialLevel) {
                        ForEach(Constants.Layout.Settings.levelRange, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                }
                Section("Animations") {
                    Toggle("Animate hard drop", isOn: $settings.isHardDropAnimated)
                    Toggle("Animate line clears", isOn: $settings.isLineClearAnimated)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    IOSSettingsView(settings: ObservableSettings())
}
