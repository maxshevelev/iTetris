import SwiftUI

struct SettingsView: View {
    let settings: ObservableSettings
    @State private var nameDraft: String
    @State private var lockImmediately: Bool
    @State private var hardDropAnimated: Bool
    @State private var lineClearAnimated: Bool
    @State private var initialLevel: Int

    init(settings: ObservableSettings) {
        self.settings = settings
        self._nameDraft = State(initialValue: settings.playerName)
        self._lockImmediately = State(initialValue: settings.lockImmediatelyAfterHardDrop)
        self._hardDropAnimated = State(initialValue: settings.isHardDropAnimated)
        self._lineClearAnimated = State(initialValue: settings.isLineClearAnimated)
        self._initialLevel = State(initialValue: settings.initialLevel)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 320)
        .frame(minHeight: 300)
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

    private var generalTab: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $nameDraft)
            }
            Section("Gameplay") {
                Toggle("Immediate lock after hard drop", isOn: $lockImmediately)
                Picker("Initial level", selection: $initialLevel) {
                    ForEach(1...10, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
            }
            Section("Animations") {
                Toggle("Animate hard drop", isOn: $hardDropAnimated)
                Toggle("Animate line clears", isOn: $lineClearAnimated)
            }
        }
        .formStyle(.grouped)
    }
}
