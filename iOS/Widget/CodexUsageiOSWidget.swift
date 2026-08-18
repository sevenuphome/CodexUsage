import WidgetKit
import SwiftUI

@main
struct CodexUsageiOSWidgets: WidgetBundle {
    var body: some Widget {
        CodexiOSWidget()
    }
}

struct CodexiOSWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CodexUsageiOS", provider: CodexiOSProvider()) { entry in
            CodexiOSWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Codex Usage")
        .description("Codex CLI rate-limit usage, synced from your Mac.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

struct CodexiOSEntry: TimelineEntry {
    let date: Date
    let windows: [CodexWindow]
    let asOf: Date?
}

struct CodexiOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexiOSEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CodexiOSEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
        } else {
            Task { completion(await current()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexiOSEntry>) -> Void) {
        Task {
            completion(Timeline(entries: [await current()], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    private func current() async -> CodexiOSEntry {
        if let fetched = try? await CodexCloud.fetch() {
            return CodexiOSEntry(date: Date(), windows: fetched.snapshot.windows, asOf: fetched.snapshot.asOf)
        }
        return CodexiOSEntry(date: Date(), windows: [], asOf: nil)
    }
}

extension CodexiOSEntry {
    static var sample: CodexiOSEntry {
        CodexiOSEntry(date: Date(), windows: [
            CodexWindow(id: "primary", name: "5-hour", percent: 18, resetsAt: Date().addingTimeInterval(2 * 3600)),
            CodexWindow(id: "secondary", name: "Weekly", percent: 42, resetsAt: Date().addingTimeInterval(3 * 86400)),
        ], asOf: Date())
    }
}

// MARK: - Views

struct CodexiOSWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexiOSEntry

    private var primary: CodexWindow? { entry.windows.first }

    var body: some View {
        switch family {
        case _ where entry.windows.isEmpty:
            emptyView
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            barsView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
            Text("Open Mac app").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var circularView: some View {
        Gauge(value: min(primary?.percent ?? 0, 100), in: 0...100) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 9, weight: .bold))
        } currentValueLabel: {
            Text("\(Int((primary?.percent ?? 0).rounded()))")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var inlineView: some View {
        if let primary, let resetsAt = primary.resetsAt, let reset = compactReset(resetsAt) {
            return Text("Codex \(Int(primary.percent.rounded()))% · \(reset)")
        }
        return Text("Codex \(Int((primary?.percent ?? 0).rounded()))%")
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.windows.prefix(3)) { window in
                HStack(spacing: 4) {
                    Text(shortName(window))
                        .font(.caption2)
                    Spacer(minLength: 2)
                    Text("\(Int(window.percent.rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                    if let resetsAt = window.resetsAt, let reset = compactReset(resetsAt) {
                        Text(reset)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var barsView: some View {
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

    private func shortName(_ window: CodexWindow) -> String {
        window.name
            .replacingOccurrences(of: "5-hour", with: "5h")
            .replacingOccurrences(of: "Weekly", with: "7d")
    }
}
