import SwiftUI

@main
struct VibeTetrisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 640)
        .windowResizability(.contentSize)
        #endif
    }
}
