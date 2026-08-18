import SwiftUI

@main
struct CodexUsageApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(state: state)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text(state.title)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
