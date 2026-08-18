import WidgetKit
import SwiftUI

@main
struct CodexUsageWidgets: WidgetBundle {
    var body: some Widget {
        CodexWidget()
    }
}

struct CodexWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexUsage", provider: CodexProvider()) { entry in
            CodexWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Codex Usage")
        .description("Codex CLI rate-limit usage from your local session logs.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CodexEntry: TimelineEntry {
    let date: Date
    let windows: [CodexWindow]
    let asOf: Date?
}

struct CodexProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CodexEntry) -> Void) {
        completion(context.isPreview ? .sample : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func current() -> CodexEntry {
        if let snapshot = CodexReader.latest() {
            return CodexEntry(date: Date(), windows: snapshot.windows, asOf: snapshot.asOf)
        }
        return CodexEntry(date: Date(), windows: [], asOf: nil)
    }
}

extension CodexEntry {
    static var sample: CodexEntry {
        CodexEntry(date: Date(), windows: [
            CodexWindow(id: "primary", name: "5-hour", percent: 18, resetsAt: Date().addingTimeInterval(2 * 3600)),
            CodexWindow(id: "secondary", name: "Weekly", percent: 42, resetsAt: Date().addingTimeInterval(3 * 86400)),
        ], asOf: Date())
    }
}

struct CodexWidgetView: View {
    let entry: CodexEntry

    var body: some View {
        if entry.windows.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text("Run codex once").font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.weight(.bold))
                    Text("Codex").font(.caption.weight(.semibold))
                    Spacer()
                    if let asOf = entry.asOf {
                        Text(asOf, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                ForEach(entry.windows) { window in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(window.name).font(.caption2)
                            Spacer()
                            Text("\(Int(window.percent.rounded()))%")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                            if let resetsAt = window.resetsAt, let reset = compactReset(resetsAt) {
                                Text(reset)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        UsageBar(percent: window.percent)
                            .frame(height: 5)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(2)
        }
    }
}
