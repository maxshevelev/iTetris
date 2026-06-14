import SwiftUI

#if os(iOS)

struct IOSSettingsView: View {
    let settings: ObservableSettings
    @Binding var showZoneIndicators: Bool
    @State private var nameDraft: String
    @State private var lockImmediately: Bool
    @State private var hardDropAnimated: Bool
    @State private var lineClearAnimated: Bool
    @State private var initialLevel: Int

    init(settings: ObservableSettings, showZoneIndicators: Binding<Bool> = .constant(true)) {
        self.settings = settings
        self._showZoneIndicators = showZoneIndicators
        self._nameDraft = State(initialValue: settings.playerName)
        self._lockImmediately = State(initialValue: settings.lockImmediatelyAfterHardDrop)
        self._hardDropAnimated = State(initialValue: settings.isHardDropAnimated)
        self._lineClearAnimated = State(initialValue: settings.isLineClearAnimated)
        self._initialLevel = State(initialValue: settings.initialLevel)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Player") {
                    TextField("Name", text: $nameDraft)
                }
                Section("Gameplay") {
                    Toggle("Immediate lock after hard drop", isOn: $lockImmediately)
                    Picker("Initial level", selection: $initialLevel) {
                        ForEach(Constants.Layout.Settings.levelRange, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                }
                Section("Animations") {
                    Toggle("Animate hard drop", isOn: $hardDropAnimated)
                    Toggle("Animate line clears", isOn: $lineClearAnimated)
                }
                Section("Display") {
                    Toggle("Zone indicators", isOn: $showZoneIndicators)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                nameDraft = settings.playerName
                lockImmediately = settings.lockImmediatelyAfterHardDrop
                hardDropAnimated = settings.isHardDropAnimated
                lineClearAnimated = settings.isLineClearAnimated
                initialLevel = settings.initialLevel
            }
            .onChange(of: nameDraft) { _, newValue in
                settings.playerName = newValue
            }
            .onChange(of: lockImmediately) { _, newValue in
                settings.lockImmediatelyAfterHardDrop = newValue
            }
            .onChange(of: hardDropAnimated) { _, newValue in
                settings.isHardDropAnimated = newValue
            }
            .onChange(of: lineClearAnimated) { _, newValue in
                settings.isLineClearAnimated = newValue
            }
            .onChange(of: initialLevel) { _, newValue in
                settings.initialLevel = newValue
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    IOSSettingsView(settings: ObservableSettings(), showZoneIndicators: .constant(true))
}

#endif
