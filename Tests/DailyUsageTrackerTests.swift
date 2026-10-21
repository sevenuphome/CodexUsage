import XCTest

final class DailyUsageTrackerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tracker: DailyUsageTracker!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: calendar,
            threshold: DailyUsageAlert.threshold
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        tracker = nil
        calendar = nil
        super.tearDown()
    }

    func testAlertsWhenUsageIncreaseReachesTwentyPercent() {
        let date = makeDate(day: 20)

        XCTAssertNil(tracker.record(weeklyPercent: 10, resetsAt: nil, at: date))
        XCTAssertNil(tracker.record(weeklyPercent: 25, resetsAt: nil, at: date))
        XCTAssertEqual(tracker.record(weeklyPercent: 30, resetsAt: nil, at: date), 20)
    }

    func testAlertsOnlyOncePerDay() {
        let date = makeDate(day: 20)

        XCTAssertNil(tracker.record(weeklyPercent: 10, resetsAt: nil, at: date))
        XCTAssertEqual(tracker.record(weeklyPercent: 30, resetsAt: nil, at: date), 20)
        XCTAssertNil(tracker.record(weeklyPercent: 60, resetsAt: nil, at: date))
    }

    func testStartsAnewOnTheNextDay() {
        XCTAssertNil(tracker.record(weeklyPercent: 10, resetsAt: nil, at: makeDate(day: 20)))
        XCTAssertEqual(tracker.record(weeklyPercent: 30, resetsAt: nil, at: makeDate(day: 20)), 20)
        XCTAssertNil(tracker.record(weeklyPercent: 35, resetsAt: nil, at: makeDate(day: 21)))
        XCTAssertEqual(tracker.record(weeklyPercent: 55, resetsAt: nil, at: makeDate(day: 21)), 20)
    }

    func testCountsUsageAfterTheWeeklyWindowResets() {
        let date = makeDate(day: 20)
        let firstReset = makeDate(day: 21)
        let nextReset = makeDate(day: 28)

        XCTAssertNil(tracker.record(weeklyPercent: 80, resetsAt: firstReset, at: date))
        XCTAssertNil(tracker.record(weeklyPercent: 5, resetsAt: nextReset, at: date))
        XCTAssertEqual(tracker.record(weeklyPercent: 20, resetsAt: nextReset, at: date), 20)
    }

    func testIgnoresADecreaseWithoutAWindowReset() {
        let date = makeDate(day: 20)

        XCTAssertNil(tracker.record(weeklyPercent: 10, resetsAt: nil, at: date))
        XCTAssertNil(tracker.record(weeklyPercent: 25, resetsAt: nil, at: date))
        XCTAssertNil(tracker.record(weeklyPercent: 20, resetsAt: nil, at: date))
        XCTAssertNil(tracker.record(weeklyPercent: 25, resetsAt: nil, at: date))
        XCTAssertEqual(tracker.record(weeklyPercent: 30, resetsAt: nil, at: date), 20)
    }

    private func makeDate(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12))!
    }
}
