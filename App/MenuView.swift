import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Codex Usage").font(.headline)
                Spacer()
                if let asOf = state.snapshot?.asOf {
                    (Text("as of ") + Text(asOf, style: .relative) + Text(" ago"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot = state.snapshot {
                ForEach(snapshot.windows) { window in
                    WindowRow(window: window)
                }
                Text("Snapshots update while Codex CLI is in use")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let synced = state.cloudSyncedAt {
                    (Text("iCloud synced ") + Text(synced, style: .relative) + Text(" ago"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No Codex sessions found — run codex once, then usage shows up here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Launch at login", isOn: $state.launchAtLogin)
                .font(.callout)

            HStack {
                Button("Refresh now") { state.refresh() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(width: 300)
    }
}

private struct WindowRow: View {
    let window: CodexWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name).font(.callout)
                Spacer()
                Text("\(Int(window.percent.rounded()))%")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            UsageBar(percent: window.percent)
                .frame(height: 6)
            if let resetsAt = window.resetsAt, let reset = compactReset(resetsAt) {
                Text("resets in \(reset)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
