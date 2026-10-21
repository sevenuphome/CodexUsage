import Foundation

struct DailyUsageTracker {
    private enum Keys {
        static let day = "dailyUsageAlert.day"
        static let lastPercent = "dailyUsageAlert.lastPercent"
        static let accumulatedPercent = "dailyUsageAlert.accumulatedPercent"
        static let resetTimestamp = "dailyUsageAlert.resetTimestamp"
        static let alerted = "dailyUsageAlert.alerted"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let threshold: Double

    init(defaults: UserDefaults, calendar: Calendar = .current, threshold: Double) {
        self.defaults = defaults
        self.calendar = calendar
        self.threshold = threshold
    }

    func record(weeklyPercent: Double, resetsAt: Date?, at date: Date = Date()) -> Double? {
        let percent = min(max(weeklyPercent, 0), 100)
        let day = dayKey(for: date)

        guard defaults.string(forKey: Keys.day) == day else {
            startDay(day, percent: percent, resetsAt: resetsAt)
            return nil
        }

        let lastPercent = defaults.double(forKey: Keys.lastPercent)
        let previousReset = defaults.object(forKey: Keys.resetTimestamp) as? Double
        let currentReset = resetsAt?.timeIntervalSince1970
        let resetChanged = previousReset.map { previous in
            currentReset.map { $0 > previous + 1 } ?? false
        } ?? false

        let increase: Double
        let nextLastPercent: Double
        if resetChanged {
            increase = percent
            nextLastPercent = percent
        } else if percent > lastPercent {
            increase = percent - lastPercent
            nextLastPercent = percent
        } else {
            increase = 0
            nextLastPercent = lastPercent
        }

        let accumulated = defaults.double(forKey: Keys.accumulatedPercent) + increase
        defaults.set(nextLastPercent, forKey: Keys.lastPercent)
        defaults.set(accumulated, forKey: Keys.accumulatedPercent)
        storeReset(resetsAt)

        guard accumulated >= threshold, !defaults.bool(forKey: Keys.alerted) else { return nil }
        defaults.set(true, forKey: Keys.alerted)
        return accumulated
    }

    private func startDay(_ day: String, percent: Double, resetsAt: Date?) {
        defaults.set(day, forKey: Keys.day)
        defaults.set(percent, forKey: Keys.lastPercent)
        defaults.set(0, forKey: Keys.accumulatedPercent)
        defaults.set(false, forKey: Keys.alerted)
        storeReset(resetsAt)
    }

    private func storeReset(_ resetsAt: Date?) {
        if let resetsAt {
            defaults.set(resetsAt.timeIntervalSince1970, forKey: Keys.resetTimestamp)
        } else {
            defaults.removeObject(forKey: Keys.resetTimestamp)
        }
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(parts.era ?? 0)-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
