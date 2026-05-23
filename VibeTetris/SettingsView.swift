import SwiftUI

struct SettingsView: View {
    let settings: ObservableSettings
    @State private var nameDraft: String
    @State private var lockImmediately: Bool
    @State private var hardDropAnimated: Bool
    @State private var lineClearAnimated: Bool

    init(settings: ObservableSettings) {
        self.settings = settings
        self._nameDraft = State(initialValue: settings.playerName)
        self._lockImmediately = State(initialValue: settings.lockImmediatelyAfterHardDrop)
        self._hardDropAnimated = State(initialValue: settings.isHardDropAnimated)
        self._lineClearAnimated = State(initialValue: settings.isLineClearAnimated)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 240, height: 260)
        .onAppear {
            nameDraft = settings.playerName
            lockImmediately = settings.lockImmediatelyAfterHardDrop
            hardDropAnimated = settings.isHardDropAnimated
            lineClearAnimated = settings.isLineClearAnimated
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
    }

    private var generalTab: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $nameDraft)
            }
            Section("Gameplay") {
                Toggle("Lock after hard drop", isOn: $lockImmediately)
            }
            Section("Animations") {
                Toggle("Animate hard drop", isOn: $hardDropAnimated)
                Toggle("Animate line clears", isOn: $lineClearAnimated)
            }
        }
        .formStyle(.grouped)
    }
}
