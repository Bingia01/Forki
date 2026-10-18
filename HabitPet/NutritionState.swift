import Foundation
import SwiftUI

final class NutritionState: ObservableObject {
    // FoodItem already contains the selected portion's totals, including in
    // existing v1 logs. Portion is metadata and must not be applied twice.
    @Published var loggedMeals: [LoggedFood] = [] {
        didSet { refresh(); persistMeals() }
    }
    @Published private(set) var caloriesCurrent = 0
    @Published private(set) var caloriesGoal: Int
    @Published private(set) var proteinCurrent = 0.0
    @Published private(set) var carbsCurrent = 0.0
    @Published private(set) var fatsCurrent = 0.0
    @Published private(set) var avatarState: AvatarState = .neutral
    @Published private(set) var level = 1
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private let mealsKey = "hp_loggedMeals_v1"
    private let goalKey = "hp_calorieGoal_v1"

    init(goal: Int = 2000, defaults: UserDefaults = .standard,
         calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        let saved = defaults.integer(forKey: goalKey)
        caloriesGoal = (1000...4000).contains(saved) ? saved : min(4000, max(1000, goal))
        if let data = defaults.data(forKey: mealsKey),
           let meals = try? JSONDecoder().decode([LoggedFood].self, from: data) {
            loggedMeals = meals
        }
        refresh()
    }
    var hasSavedGoal: Bool { defaults.object(forKey: goalKey) != nil }
    var todaysMeals: [LoggedFood] { meals(on: now()) }
    func meals(on date: Date) -> [LoggedFood] {
        loggedMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    var mealsLoggedToday: Int { todaysMeals.count }
    var progressPercent: Int {
        Int((min(1, Double(caloriesCurrent) / Double(caloriesGoal)) * 100).rounded())
    }
    func add(_ food: LoggedFood) { loggedMeals.append(food) }
    func replaceAll(with foods: [LoggedFood]) { loggedMeals = foods }
    func reset() {
        loggedMeals = []
        caloriesGoal = 2000
        defaults.removeObject(forKey: goalKey)
        defaults.removeObject(forKey: mealsKey)
        refresh()
    }
    func remove(id: UUID) { loggedMeals.removeAll { $0.id == id } }
    func setGoal(_ goal: Int) {
        guard (1000...4000).contains(goal) else { return }
        caloriesGoal = goal
        defaults.set(goal, forKey: goalKey)
        refresh()
    }
    func refresh() {
        let today = todaysMeals
        caloriesCurrent = today.reduce(0) { $0 + max(0, $1.food.calories) }
        func total(_ value: (FoodItem) -> Double) -> Double {
            today.reduce(0) { result, meal in
                let amount = value(meal.food)
                return result + (amount.isFinite ? max(0, amount) : 0)
            }
        }
        proteinCurrent = total { $0.protein }
        carbsCurrent = total { $0.carbs }
        fatsCurrent = total { $0.fats }
        level = 1 + loggedMeals.count / 10
        let progress = Double(caloriesCurrent) / Double(caloriesGoal)
        if progress < 0.3 { avatarState = .sad }
        else if progress < 0.7 { avatarState = .neutral }
        else if progress < 0.9 { avatarState = .happy }
        else if progress <= 1.1 { avatarState = .strong }
        else { avatarState = .overweight }
    }
    private func persistMeals() {
        guard let data = try? JSONEncoder().encode(loggedMeals) else { return }
        defaults.set(data, forKey: mealsKey)
    }
}
