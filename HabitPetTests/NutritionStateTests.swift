import XCTest
#if SWIFT_PACKAGE
@testable import ForkiCore
#else
@testable import HabitPet
#endif

final class NutritionStateTests: XCTestCase {
    var defaults: UserDefaults!
    var suite: String!
    override func setUp() { suite = "forki-tests-" + UUID().uuidString; defaults = UserDefaults(suiteName: suite) }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    func meal(calories: Int = 200, portion: Double = 2, date: Date) -> LoggedFood {
        LoggedFood(food: FoodItem(id: 1, name: "Food", calories: calories, protein: 20, carbs: 10, fats: 5, category: "Test"), portion: portion, timestamp: date)
    }
    func testSelectedPortionAndExistingLogsCountExactlyOnce() {
        let date = Date()
        let state = NutritionState(defaults: defaults, now: { date })
        state.add(meal(date: date))
        XCTAssertEqual(state.caloriesCurrent, 200)
        XCTAssertEqual(state.proteinCurrent, 20)
        let reloaded = NutritionState(defaults: defaults, now: { date })
        XCTAssertEqual(reloaded.caloriesCurrent, 200)
        XCTAssertEqual(reloaded.loggedMeals.first?.id, state.loggedMeals.first?.id)
    }
    func testHalfPortionIsNotHalvedAgain() {
        let state = NutritionState(defaults: defaults)
        state.add(meal(calories: 50, portion: 0.5, date: Date()))
        XCTAssertEqual(state.caloriesCurrent, 50)
    }
    func testDayBoundaryUsesLocalCalendarAndPreservesHistory() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        var now = ISO8601DateFormatter().date(from: "2026-10-18T16:59:00Z")!
        let state = NutritionState(defaults: defaults, calendar: calendar, now: { now })
        state.add(meal(date: now))
        XCTAssertEqual(state.mealsLoggedToday, 1)
        now = now.addingTimeInterval(120); state.refresh()
        XCTAssertEqual(state.caloriesCurrent, 0)
        XCTAssertEqual(state.mealsLoggedToday, 0)
        XCTAssertEqual(state.loggedMeals.count, 1)
        state.add(meal(calories: 100, portion: 1, date: now))
        XCTAssertEqual(state.caloriesCurrent, 100)
        state.remove(id: state.loggedMeals.last!.id)
        XCTAssertEqual(state.caloriesCurrent, 0)
    }
    func testCustomGoalPersistsAndInvalidGoalsAreRejected() {
        let state = NutritionState(defaults: defaults)
        state.setGoal(2750)
        state.setGoal(0)
        XCTAssertEqual(NutritionState(defaults: defaults).caloriesGoal, 2750)
    }
    func testResetClearsMealsAndSavedGoal() {
        let state = NutritionState(defaults: defaults)
        state.setGoal(2750)
        state.add(meal(date: Date()))
        state.reset()
        XCTAssertFalse(state.hasSavedGoal)
        XCTAssertEqual(state.caloriesCurrent, 0)
        let reloaded = NutritionState(defaults: defaults)
        XCTAssertTrue(reloaded.loggedMeals.isEmpty)
        XCTAssertEqual(reloaded.caloriesGoal, 2000)
    }
    func testOnboardingGoalIdentifiers() {
        for (id, expected) in [("slim",1800),("content",2200),("strong",2600)] {
            var user = UserData(); user.goal = id
            XCTAssertEqual(goalFromUserData(user), expected)
        }
    }
}
