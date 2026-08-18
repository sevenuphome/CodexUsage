import SwiftUI

func compactReset(_ date: Date) -> String? {
    let seconds = date.timeIntervalSinceNow
    guard seconds > 0 else { return nil }
    let minutes = Int(seconds / 60)
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h\(String(format: "%02d", minutes % 60))m" }
    return "\(hours / 24)d\(hours % 24)h"
}

func usageColor(_ percent: Double) -> Color {
    switch percent {
    case ..<60: return .green
    case ..<85: return .orange
    default: return .red
    }
}

struct UsageBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(usageColor(percent))
                    .frame(width: max(4, geo.size.width * min(percent, 100) / 100))
            }
        }
    }
}
