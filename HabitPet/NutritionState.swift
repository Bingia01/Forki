import Foundation
import SwiftUI

final class NutritionState: ObservableObject {
    // Source of truth
    @Published var loggedMeals: [LoggedFood] = []
    @Published var caloriesCurrent: Int = 0
    @Published var caloriesGoal: Int
    @Published var proteinCurrent: Double = 0
    @Published var carbsCurrent: Double   = 0
    @Published var fatsCurrent: Double    = 0
    @Published var avatarState: AvatarState = .neutral  // default on sign up

    // Defaults: Level 1; you can wire up a real level system later
    @Published var level: Int = 1

    // MARK: - Persistence
    //
    // Meals are stored as a JSON array in UserDefaults under a versioned key.
    // On init, we load any previously saved meals so the user's food log
    // survives app restarts. On every add/replaceAll, we re-save.
    private let mealsKey = "hp_loggedMeals_v1"
    private let defaults: UserDefaults

    init(goal: Int = 2000, defaults: UserDefaults = .standard) {
        self.caloriesGoal = goal
        self.defaults = defaults

        // Load persisted meals (if any)
        if let data = defaults.data(forKey: mealsKey),
           let saved = try? JSONDecoder().decode([LoggedFood].self, from: data) {
            self.loggedMeals = saved
        }

        recomputeFromMeals()
    }

    // Derived
    var mealsLoggedToday: Int { loggedMeals.count } // swap for a date-filtered count if needed
    var progressPercent: Int {
        let pct = Double(caloriesCurrent) / Double(max(1, caloriesGoal)) * 100
        return Int(min(pct, 100).rounded())
    }

    // Public ops
    func add(_ lf: LoggedFood) {
        loggedMeals.append(lf)
        recomputeFromMeals()
        persistMeals()
    }

    func replaceAll(with foods: [LoggedFood]) {
        loggedMeals = foods
        recomputeFromMeals()
        persistMeals()
    }

    func setGoal(_ newGoal: Int) {
        caloriesGoal = newGoal
        updateAvatarState()
        objectWillChange.send()
    }

    // MARK: - Internals

    private func recomputeFromMeals() {
        caloriesCurrent = 0
        proteinCurrent = 0
        carbsCurrent   = 0
        fatsCurrent    = 0

        for f in loggedMeals {
            caloriesCurrent += Int(Double(f.food.calories) * f.portion)
            proteinCurrent  += f.food.protein * f.portion
            carbsCurrent    += f.food.carbs   * f.portion
            fatsCurrent     += f.food.fats    * f.portion
        }
        updateAvatarState()
    }

    private func updateAvatarState() {
        let progress = Double(caloriesCurrent) / Double(max(1, caloriesGoal))
        if progress < 0.3 { avatarState = .sad }
        else if progress < 0.7 { avatarState = .neutral }
        else if progress < 0.9 { avatarState = .happy }
        else if progress < 1.1 { avatarState = .strong }
        else { avatarState = .overweight }
    }

    private func persistMeals() {
        guard let data = try? JSONEncoder().encode(loggedMeals) else {
            assertionFailure("NutritionState: failed to encode loggedMeals")
            return
        }
        defaults.set(data, forKey: mealsKey)
    }
}
