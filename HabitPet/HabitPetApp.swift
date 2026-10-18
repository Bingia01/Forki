//
//  HabitPetApp.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

@main
struct HabitPetApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-reset") {
            for key in ["hp_userData_v1", "hp_lastCompletedStep_v1", "hp_isSignedIn", "hp_hasOnboarded", "hp_loggedMeals_v1", "hp_calorieGoal_v1"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            HabitPetFlow()
        }
    }
}
