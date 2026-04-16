//
//  HabitPetFlow.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI
import Combine

// MARK: - UserDataStore
//
// Persistent storage for the user's profile and onboarding progress.
//
// Why this exists:
// Before this change, the entire profile (name, email, biometrics, goals,
// food preferences, selected character) lived in an in-memory `@State` on
// `HabitPetFlow`. Nothing was written to disk. The only things persisted were
// two Boolean flags (`hp_isSignedIn`, `hp_hasOnboarded`) flipped at the END of
// onboarding in `NotificationsScreen`. That caused two symptoms users were
// reporting as "login is broken":
//
//   1. Quit onboarding mid-flow and the flags never flip, so the next launch
//      throws you back at the intro video.
//   2. Finish onboarding, quit, relaunch — the flags ARE set so the app skips
//      straight to Home, but the profile is empty because nothing was saved.
//      The greeting shows "Good morning, " and everything looks broken.
//
// UserDataStore fixes both by:
//   • Encoding `UserData` as JSON into `UserDefaults` whenever it mutates
//     (debounced so we don't thrash disk on every keystroke).
//   • Tracking the last completed onboarding step so users can resume.
//   • Honouring the old `hp_isSignedIn` / `hp_hasOnboarded` flags for
//     backwards-compat with the install base shipping today.
//
// This intentionally uses `UserDefaults` instead of Keychain / Core Data /
// SwiftData. The profile is not sensitive (no password, no token), it's small
// (< 1 KB), and we want a zero-dependency change that ships safely to a live
// App Store build. When we move to real cloud sync, this store becomes the
// offline cache layer and the JSON format doesn't need to change.
//
final class UserDataStore: ObservableObject {

    // MARK: Storage keys
    //
    // Versioned so a future schema change can bump `_v2` without stomping
    // the current key.
    private enum Keys {
        static let userData          = "hp_userData_v1"
        static let lastCompletedStep = "hp_lastCompletedStep_v1"

        // Legacy keys from v1.x of the shipped app. We keep reading AND
        // writing them so existing users' "signed in" state survives the
        // update, and so any old code path that still checks these keeps
        // working.
        static let legacyIsSignedIn   = "hp_isSignedIn"
        static let legacyHasOnboarded = "hp_hasOnboarded"
    }

    // MARK: Published state
    @Published var userData: UserData

    /// Index of the last onboarding screen the user finished. `-1` = nothing
    /// done yet, `0` = IntroScreen done, ..., `5` = NotificationsScreen done.
    @Published var lastCompletedStep: Int

    // MARK: Internals
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // --- Load persisted userData, falling back to a fresh struct ---
        if let blob = defaults.data(forKey: Keys.userData),
           let decoded = try? JSONDecoder().decode(UserData.self, from: blob) {
            self.userData = decoded
        } else {
            self.userData = UserData()
        }

        // --- Load last completed step, defaulting to -1 ---
        //
        // `integer(forKey:)` returns 0 for a missing key, which is
        // indistinguishable from "user finished screen 0 (Intro)". We want
        // that distinction so we use `object(forKey:)` to probe existence.
        if defaults.object(forKey: Keys.lastCompletedStep) != nil {
            self.lastCompletedStep = defaults.integer(forKey: Keys.lastCompletedStep)
        } else {
            self.lastCompletedStep = -1
        }

        // --- Autosave userData on change (debounced) ---
        //
        // `dropFirst()` skips the initial value so we don't rewrite what we
        // just loaded. Debounce keeps us off the disk while the user is
        // actively typing.
        $userData
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] latest in
                self?.persist(latest)
            }
            .store(in: &cancellables)

        // --- Autosave step progress on change (immediate) ---
        $lastCompletedStep
            .dropFirst()
            .sink { [weak self] step in
                self?.defaults.set(step, forKey: Keys.lastCompletedStep)
            }
            .store(in: &cancellables)
    }

    // MARK: - Resume logic

    /// The screen index the flow should open on at cold launch.
    ///
    /// Rules, in priority order:
    ///  1. LEGACY RECOVERY — if the user has the old `hp_isSignedIn` or
    ///     `hp_hasOnboarded` flag from a previous version of the app but no
    ///     persisted profile, we inherited them from the broken build. Drop
    ///     them into SignUp so they can enter their details. This is the
    ///     backwards-compatibility hatch; without it, these users would open
    ///     the app after the update and still see an empty Home.
    ///  2. COMPLETE PROFILE — a profile with name + email AND progress >= 5
    ///     (finished the whole flow) goes straight to Home.
    ///  3. PARTIAL PROGRESS — resume at the next screen after wherever they
    ///     left off, capped at the last onboarding screen.
    ///  4. NEW USER — start at the Intro.
    var startingScreen: Int {
        let hasLegacyFlag   = defaults.bool(forKey: Keys.legacyIsSignedIn) ||
                              defaults.bool(forKey: Keys.legacyHasOnboarded)
        let profileComplete = !userData.name.isEmpty && !userData.email.isEmpty

        if hasLegacyFlag && !profileComplete {
            return 1 // SignUpScreen — let them rebuild their profile
        }
        if profileComplete && lastCompletedStep >= 5 {
            return 6 // HomeScreen
        }
        if lastCompletedStep >= 0 {
            return min(lastCompletedStep + 1, 5)
        }
        return 0 // IntroScreen
    }

    // MARK: - Progress tracking

    /// Called when the user finishes a screen. No-op if the step is earlier
    /// than what we already recorded (so going back and forward doesn't
    /// clobber progress).
    func markStepCompleted(_ step: Int) {
        if step > lastCompletedStep {
            lastCompletedStep = step
        }
        // Once the user finishes the full onboarding flow, flip the legacy
        // flags too. NotificationsScreen also writes these directly today;
        // duplicating the write is harmless and keeps us correct if that
        // code path ever changes.
        if step >= 5 {
            defaults.set(true, forKey: Keys.legacyIsSignedIn)
            defaults.set(true, forKey: Keys.legacyHasOnboarded)
        }
    }

    // MARK: - Reset
    //
    // Reserved for a future "Reset profile" button on HomeScreen. Wipes the
    // profile AND the legacy flags so the user is genuinely back at screen 0
    // on next launch.
    func reset() {
        userData = UserData()
        lastCompletedStep = -1
        defaults.removeObject(forKey: Keys.userData)
        defaults.removeObject(forKey: Keys.lastCompletedStep)
        defaults.set(false, forKey: Keys.legacyIsSignedIn)
        defaults.set(false, forKey: Keys.legacyHasOnboarded)
    }

    // MARK: - Persistence

    private func persist(_ snapshot: UserData) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            // Encoding failure on a Codable struct with primitive fields
            // should be unreachable; log and move on rather than crashing.
            assertionFailure("UserDataStore: failed to encode UserData")
            return
        }
        defaults.set(data, forKey: Keys.userData)
    }
}

// MARK: - Goal Calculation
//
// Derive a calorie goal from the user's saved profile. The user enters their
// goal as a text string (e.g., "lose", "maintain", "gain") during onboarding.
// We map that to a ballpark daily calorie target. A proper implementation would
// use the Mifflin-St Jeor equation with the user's height/weight/age/gender,
// but those fields are stored as strings and may be empty, so we keep it simple
// with sensible defaults for now.
private func goalFromUserData(_ ud: UserData) -> Int {
    let goalText = ud.goal.lowercased()
    if goalText.contains("lose") || goalText.contains("slim") || goalText.contains("cut") {
        return 1800
    } else if goalText.contains("gain") || goalText.contains("bulk") || goalText.contains("muscle") {
        return 2600
    } else if goalText.contains("maintain") {
        return 2200
    }
    // Fallback: 2000 is the FDA reference daily intake
    return 2000
}

// MARK: - HabitPetFlow

struct HabitPetFlow: View {
    @StateObject private var store = UserDataStore()
    @StateObject private var nutrition = NutritionState()
    @State private var currentScreen: Int = 0
    @State private var didBootstrap = false

    var body: some View {
        ZStack {
            switch currentScreen {
            case 0:
                IntroScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 1:
                SignUpScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 2:
                BiometricsScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 3:
                GoalSettingScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 4:
                FoodPreferencesScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 5:
                NotificationsScreen(currentScreen: $currentScreen, userData: $store.userData)
            case 6:
                HomeScreen(userData: store.userData, nutrition: nutrition)
            case 7:
                RecipesView(
                    currentScreen: $currentScreen,
                    loggedFoods: $nutrition.loggedMeals,
                    onFoodLogged: { _ in },
                    userData: store.userData,
                    nutrition: nutrition
                )
            default:
                HomeScreen(userData: store.userData, nutrition: nutrition)
            }
        }
        .animation(.easeInOut, value: currentScreen)
        .transition(.slide)
        // Track progress: when the user advances from screen N to N+1, we
        // consider screen N "completed" and persist it. This means a user
        // who quits mid-flow will resume at the next screen on cold launch,
        // instead of getting dumped back at the Intro.
        .onChange(of: currentScreen) { oldValue, newValue in
            if newValue > oldValue {
                let completed = newValue - 1
                if completed >= 0 && completed <= 5 {
                    store.markStepCompleted(completed)
                }
            }
        }
        .onAppear {
            // Guard against re-entry: `onAppear` can fire multiple times as
            // the view hierarchy rebuilds, and we only want to honour the
            // persisted starting screen on the very first appearance.
            guard !didBootstrap else { return }
            didBootstrap = true
            currentScreen = store.startingScreen

            // Set the calorie goal from the user's profile instead of
            // hardcoding 2296. Falls back to 2000 if the goal field is empty.
            let goal = goalFromUserData(store.userData)
            nutrition.setGoal(goal)
        }
    }
}

#Preview {
    HabitPetFlow()
}
