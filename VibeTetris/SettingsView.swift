import SwiftUI

struct SettingsView: View {
    let settings: ObservableSettings
    @Bindable var controls: ControlsConfig
    @State private var nameDraft: String
    @State private var lockImmediately: Bool
    @State private var hardDropAnimated: Bool
    @State private var lineClearAnimated: Bool
    @State private var initialLevel: Int

    init(settings: ObservableSettings, controls: ControlsConfig) {
        self.settings = settings
        self.controls = controls
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
            controlsTab
                .tabItem { Label("Controls", systemImage: "keyboard") }
        }
        .frame(width: Constants.Layout.Settings.windowWidth)
        .frame(minHeight: Constants.Layout.Settings.windowMinHeight)
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
                    ForEach(Constants.Layout.Settings.levelRange, id: \.self) { level in
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

    private var controlsTab: some View {
        Form {
            Section {
                Picker("Profile", selection: $controls.profile) {
                    ForEach(KeybindingProfile.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .onChange(of: controls.profile) { _, newValue in
                    controls.applyPreset(newValue)
                    controls.save()
                }
            }

            if !controls.conflicts.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Conflicting keys", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.subheadline.bold())
                        ForEach(controls.conflicts, id: \.0) { a, b in
                            Text("\(a) and \(b) are bound to the same key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Key Bindings") {
                ForEach(ControlsConfig.allBindings, id: \.label) { binding in
                    KeyField(label: binding.label, key: Binding(
                        get: { controls[keyPath: binding.keyPath] },
                        set: { newValue in
                            controls[keyPath: binding.keyPath] = newValue
                            controls.profile = .custom
                            controls.save()
                        }
                    ))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Key Capture Field

private struct KeyField: View {
    let label: String
    @Binding var key: String
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Group {
                if isRecording {
                    Text("Press key...")
                        .foregroundStyle(.secondary)
                } else {
                    Text(ControlsConfig.displayName(for: key))
                }
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: isRecording ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isRecording = true
            }
        }
        #if os(macOS)
        .background(KeyCaptureView(isRecording: $isRecording, capturedKey: $key))
        #endif
    }
}

// MARK: - NSEvent Monitor (macOS)

#if os(macOS)
import AppKit

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var capturedKey: String

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            context.coordinator.startMonitor(isRecording: $isRecording, capturedKey: $capturedKey)
        } else {
            context.coordinator.stopMonitor()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?

        func startMonitor(isRecording: Binding<Bool>, capturedKey: Binding<String>) {
            guard monitor == nil else { return } // already listening — prevent leaked monitors
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard isRecording.wrappedValue else { return event }

                var keyStr: String
                let kc = event.keyCode
                switch kc {
                case 49: keyStr = "Space"
                case 53: keyStr = "Escape"
                case 36: keyStr = "Return"
                case 48: keyStr = "Tab"
                case 126: keyStr = "UpArrow"
                case 125: keyStr = "DownArrow"
                case 123: keyStr = "LeftArrow"
                case 124: keyStr = "RightArrow"
                default:
                    guard let chars = event.charactersIgnoringModifiers?.lowercased(),
                          let first = chars.first else { return event }
                    keyStr = String(first)
                }

                capturedKey.wrappedValue = keyStr
                isRecording.wrappedValue = false
                return nil
            }
        }

        func stopMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { stopMonitor() }
    }
}
#endif
