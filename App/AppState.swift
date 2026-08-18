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

    @Published var cloudSyncedAt: Date?

    private var timer: Timer?
    private var lastSignature = ""

    private var cloudSyncNeeded: Bool {
        guard let synced = cloudSyncedAt else { return true }
        return Date().timeIntervalSince(synced) > 30 * 60
    }

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
            publishToCloud()
        } else if cloudSyncNeeded {
            // Retry until the first publish lands, then heartbeat every
            // 30 min so the iPhone's staleness display stays honest.
            publishToCloud()
        }
    }

    private func publishToCloud() {
        guard let snapshot else { return }
        Task { [weak self] in
            do {
                try await CodexCloud.publish(snapshot)
                await MainActor.run { self?.cloudSyncedAt = Date() }
            } catch {
                NSLog("CodexCloud publish FAILED: \(error)")
            }
        }
    }
}
