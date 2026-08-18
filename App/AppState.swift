import Foundation
import SwiftUI
import ServiceManagement
import WidgetKit

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: CodexSnapshot?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var timer: Timer?
    private var lastSignature = ""

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var title: String {
        guard let first = snapshot?.windows.first else { return "…" }
        return "\(Int(first.percent.rounded()))%"
    }

    func refresh() {
        // Local file scan — cheap enough to run every tick
        let latest = CodexReader.latest()
        snapshot = latest

        let signature = latest?.windows
            .map { "\($0.id):\(Int($0.percent))" }
            .joined(separator: ",") ?? ""
        if signature != lastSignature {
            lastSignature = signature
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
