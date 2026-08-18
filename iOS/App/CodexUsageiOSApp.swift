import SwiftUI
import WidgetKit

@main
struct CodexUsageiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var fetched: CodexCloud.Fetched?
    @State private var errorText: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Group {
                if let fetched {
                    List {
                        Section {
                            ForEach(fetched.snapshot.windows) { window in
                                WindowRowView(window: window)
                            }
                        } footer: {
                            VStack(alignment: .leading, spacing: 2) {
                                (Text("Snapshot from Codex CLI ") + Text(fetched.snapshot.asOf, style: .relative) + Text(" ago"))
                                (Text("Synced from Mac ") + Text(fetched.published, style: .relative) + Text(" ago"))
                            }
                        }
                    }
                } else if loading {
                    ProgressView()
                } else {
                    ContentUnavailableView {
                        Label("No data yet", systemImage: "icloud")
                    } description: {
                        Text(errorText ?? "Open the Codex Usage app on your Mac — it publishes usage to iCloud, then it shows up here and in the widget.")
                    } actions: {
                        Button("Retry") { Task { await load() } }
                    }
                }
            }
            .navigationTitle("Codex Usage")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        loading = fetched == nil
        defer { loading = false }
        do {
            fetched = try await CodexCloud.fetch()
            errorText = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct WindowRowView: View {
    let window: CodexWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name)
                Spacer()
                Text("\(Int(window.percent.rounded()))%")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            UsageBar(percent: window.percent)
                .frame(height: 6)
            if let resetsAt = window.resetsAt, let reset = compactReset(resetsAt) {
                Text("resets in \(reset)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
