import UserNotifications
import XCTest

final class DailyUsageAlertTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private var center: TestNotificationCenter!
    private var now: Date!
    private var alert: DailyUsageAlert!

    override func setUp() {
        super.setUp()
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        center = TestNotificationCenter()
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))!
        alert = DailyUsageAlert(
            defaults: defaults,
            calendar: calendar,
            center: center,
            now: { self.now }
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        alert = nil
        now = nil
        center = nil
        calendar = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testThresholdCrossingEnqueuesOneImmediateNotification() {
        alert.evaluate(snapshot(weeklyPercent: 10))
        alert.evaluate(snapshot(weeklyPercent: 30))
        alert.evaluate(snapshot(weeklyPercent: 50))

        XCTAssertNotNil(center.delegate)
        XCTAssertEqual(center.requests.count, 1)

        let request = center.requests[0]
        let day = calendar.startOfDay(for: now).timeIntervalSince1970
        XCTAssertEqual(request.identifier, "codex-daily-usage-\(Int(day))")
        XCTAssertEqual(request.content.title, "Codex daily usage reached 20%")
        XCTAssertEqual(
            request.content.body,
            "Your weekly usage meter increased by at least 20 percentage points today."
        )
        XCTAssertNotNil(request.content.sound)
        XCTAssertNil(request.trigger)
    }

    func testMissingSecondaryWindowEnqueuesNothing() {
        let snapshot = CodexSnapshot(
            windows: [CodexWindow(id: "primary", name: "5-hour", percent: 50, resetsAt: nil)],
            asOf: now
        )

        alert.evaluate(snapshot)

        XCTAssertTrue(center.requests.isEmpty)
    }

    func testBelowThresholdEnqueuesNothing() {
        alert.evaluate(snapshot(weeklyPercent: 10))
        alert.evaluate(snapshot(weeklyPercent: 29))

        XCTAssertTrue(center.requests.isEmpty)
    }

    private func snapshot(weeklyPercent: Double) -> CodexSnapshot {
        CodexSnapshot(
            windows: [CodexWindow(id: "secondary", name: "Weekly", percent: weeklyPercent, resetsAt: nil)],
            asOf: now
        )
    }
}

private final class TestNotificationCenter: DailyUsageNotificationCenter {
    var delegate: UNUserNotificationCenterDelegate?
    private(set) var requests: [UNNotificationRequest] = []

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        completionHandler(true, nil)
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        requests.append(request)
        completionHandler?(nil)
    }
}
