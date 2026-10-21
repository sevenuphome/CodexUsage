import Foundation
import UserNotifications

protocol DailyUsageNotificationCenter: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    )
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
}

extension UNUserNotificationCenter: DailyUsageNotificationCenter {}

private final class DailyUsageNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

final class DailyUsageAlert {
    static let threshold = 20.0

    private let tracker: DailyUsageTracker
    private let center: DailyUsageNotificationCenter
    private let calendar: Calendar
    private let now: () -> Date
    private let notificationDelegate = DailyUsageNotificationDelegate()

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        center: DailyUsageNotificationCenter = UNUserNotificationCenter.current(),
        now: @escaping () -> Date = Date.init
    ) {
        tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: calendar,
            threshold: Self.threshold
        )
        self.center = center
        self.calendar = calendar
        self.now = now
        center.delegate = notificationDelegate
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("Codex daily usage notification permission failed: \(error)")
            }
        }
    }

    func evaluate(_ snapshot: CodexSnapshot) {
        let date = now()
        guard let weekly = snapshot.windows.first(where: { $0.id == "secondary" }),
              tracker.record(
                weeklyPercent: weekly.percent,
                resetsAt: weekly.resetsAt,
                at: date
              ) != nil else { return }

        let threshold = Int(Self.threshold.rounded())
        let content = UNMutableNotificationContent()
        content.title = "Codex daily usage reached \(threshold)%"
        content.body = "Your weekly usage meter increased by at least \(threshold) percentage points today."
        content.sound = .default

        let day = calendar.startOfDay(for: date).timeIntervalSince1970
        let request = UNNotificationRequest(
            identifier: "codex-daily-usage-\(Int(day))",
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                NSLog("Codex daily usage notification failed: \(error)")
            }
        }
    }
}
