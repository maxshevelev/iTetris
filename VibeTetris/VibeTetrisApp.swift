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

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        #if os(macOS)
        .defaultSize(width: Constants.Layout.AppWindow.defaultWidth, height: Constants.Layout.AppWindow.defaultHeight)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(settings: settings)
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
