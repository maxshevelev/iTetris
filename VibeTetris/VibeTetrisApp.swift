import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct VibeTetrisApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var settings = ObservableSettings()
    @State private var controls = ControlsConfig()

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView(settings: settings, controls: controls)
            #else
            ContentView(settings: settings)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: Constants.Layout.AppWindow.defaultWidth, height: Constants.Layout.AppWindow.defaultHeight)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(settings: settings, controls: controls)
        }
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
