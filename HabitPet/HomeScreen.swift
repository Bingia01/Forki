//
//  HomeScreen.swift
//  HabitPet
//

import SwiftUI
import Combine


struct HomeScreen: View {
    // Shared nutrition/progress state — owned by HabitPetFlow, passed in.
    // Previously this was `@StateObject private var nutrition = NutritionState(goal: 2296)`
    // which created an isolated copy with a hardcoded goal. Now the parent
    // owns the single instance and all screens share it.
    @ObservedObject var nutrition: NutritionState

    // Other UI state
    @State private var streak: Int = 5
    @State private var showFoodLogger = false
    @State private var showFeedingEffect = false
    @State private var showRecipes = false
    @State private var currentScreen: Int = 6
    @State private var showSearch = false
    @State private var showStats = false
    @State private var showProfile = false
    @State private var showAICamera = false
    @State private var aiPrefill: FoodItem? = nil
    @State private var useDetectedLogger = false // legacy flag (kept harmless)
    @State private var aiSigmaKcal: Int = 0
    @State private var usdaCancellable: AnyCancellable?

    // Half-sized Food Log View (for library uploads)
    @State private var showHalfSizedLog = false
    @State private var libraryFoodItem: FoodItem? = nil

    let userData: UserData
    var onNavigate: ((Int) -> Void)?

    init(userData: UserData, nutrition: NutritionState, onNavigate: ((Int) -> Void)? = nil) {
        self.userData = userData
        self.nutrition = nutrition
        self.onNavigate = onNavigate
    }

    // Derived
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
    private var goalProgressPercentage: Double {
        Double(nutrition.progressPercent)
    }
    private var avatarStateDescription: String {
        switch nutrition.avatarState {
        case .sad:        return "😢 Hungry"
        case .neutral:    return "😐 Neutral"
        case .happy:      return "😊 Satisfied"
        case .strong:     return "💪 Strong"
        case .overweight: return "😅 Overfed"
        }
    }
    private var avatarStateColor: Color {
        switch nutrition.avatarState {
        case .sad: return .red
        case .neutral: return .gray
        case .happy: return .green
        case .strong: return .blue
        case .overweight: return .orange
        }
    }

    // Pull the heavy gradient out so the type-checker doesn’t inline it
    private static let bgGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "#0f172a"), location: 0.0),
            .init(color: Color(hex: "#1e293b"), location: 0.15),
            .init(color: Color(hex: "#0f4c75"), location: 0.30),
            .init(color: Color(hex: "#3730a3"), location: 0.45),
            .init(color: Color(hex: "#1e40af"), location: 0.60),
            .init(color: Color(hex: "#0891b2"), location: 0.75),
            .init(color: Color(hex: "#0d9488"), location: 0.90),
            .init(color: Color(hex: "#059669"), location: 1.0),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                Self.bgGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerView
                        avatarCard
                        streakCard
                        dailyCaloriesCard
                        macrosCard

                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding()
                }
            }

            // Bottom bar
            bottomBar
        }
        // AI Camera
        .sheet(isPresented: $showAICamera) {
            CalorieCameraBridge { output in
                switch output {
                case .success(let res, _):
                    showAICamera = false
                    aiPrefill = FoodItem(id: Int.random(in: 1000...999999), name: res.label,
                        calories: Int(res.cFused.rounded()), protein: res.protein ?? 0,
                        carbs: res.carbs ?? 0, fats: res.fats ?? 0, category: "Detected")

                case .failed(let error):
                    print("🔍 Failed: \(error)")

                case .cancelled:
                    print("🔍 Cancelled")
                    // no prefill retained on cancel
                    aiPrefill = nil
                }
            }
        }
        // Detected logger (AI Camera) - opens only when aiPrefill is set
        .sheet(item: $aiPrefill) { item in
            FoodLoggerView(
                prefill: item,
                onSave: { loggedFood in
                    nutrition.add(loggedFood)
                    showFeedingEffect = true
                    aiPrefill = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showFeedingEffect = false }
                },
                onClose: { aiPrefill = nil }
            )
            .presentationDetents([.medium, .large])
        }
        // Manual logger (Log Food button) - always empty
        .sheet(isPresented: $showFoodLogger) {
            FoodLoggerView(
                prefill: nil,
                onSave: { loggedFood in
                    nutrition.add(loggedFood)
                    showFeedingEffect = true
                    showFoodLogger = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showFeedingEffect = false }
                },
                onClose: { showFoodLogger = false }
            )
            .presentationDetents([.medium, .large])
        }
        // Recipes
        .fullScreenCover(isPresented: $showRecipes) {
            RecipesView(
                currentScreen: $currentScreen,
                loggedFoods: $nutrition.loggedMeals,   // ✅ bind to the shared list
                onFoodLogged: { _ in
                    showFeedingEffect = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showFeedingEffect = false
                    }
                },
                userData: userData,
                nutrition: nutrition                   // ✅ pass the shared instance
            )
        }
        // Stats
        .fullScreenCover(isPresented: $showStats) {
            StatsScreen(userData: userData, nutrition: nutrition)
        }
        // Keep avatar/video in sync with numbers even if updated elsewhere
        .onChange(of: nutrition.caloriesCurrent) { _, _ in /* avatar auto-updates inside model */ }

        .onAppear {
            // NutritionState is now owned by HabitPetFlow and shared across
            // all screens. No seeding needed — the state is already live.
        }
    }

    // MARK: - Sections
    
    private var headerView: some View {
        VStack(spacing: 6) {
            Text("\(greeting), \(userData.name)!")
                .font(.title2).bold()
                .foregroundColor(.white)
            Text("Your pet is waiting for some nourishment!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }

    private var avatarCard: some View {
        VStack(spacing: 12) {
            AvatarView(state: nutrition.avatarState, showFeedingEffect: $showFeedingEffect, character: userData.selectedCharacter)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 10)

            Text(userData.selectedCharacter.displayName)
                .font(.headline)
                .foregroundColor(.white)
            Text("Level \(nutrition.level) • \(nutrition.mealsLoggedToday) meals logged today")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Text(avatarStateDescription)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(avatarStateColor.opacity(0.2))
                .cornerRadius(8)

            HStack(spacing: 12) {
                Button {
                    aiPrefill = nil   // always open regular logger from Home button
                    showFoodLogger = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Log Food")
                    }
                    .font(.subheadline).bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#06b6d4"), Color(hex: "#3b82f6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                Button(action: { if let onNavigate { onNavigate(7) } else { showRecipes = true } }) {
                    HStack {
                        Image(systemName: "book")
                        Text("Recipes")
                    }
                    .font(.subheadline).bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3)))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2)))
    }

    private var streakCard: some View {
        Text("\(Int(goalProgressPercentage))% on track towards my goal!")
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
    }

    private var dailyCaloriesCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Daily Calories")
                    .font(.headline)
                Spacer()
                Text("\(nutrition.caloriesCurrent) / \(nutrition.caloriesGoal)")
                    .accessibilityIdentifier("daily-calories")
                    .font(.headline).bold()
                    .foregroundColor(.red)
            }

            ProgressView(value: Double(nutrition.caloriesCurrent), total: Double(nutrition.caloriesGoal))
                .progressViewStyle(LinearProgressViewStyle(tint: .red))

            HStack {
                Text("\(nutrition.progressPercent)% of goal")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(max(0, nutrition.caloriesGoal - nutrition.caloriesCurrent)) remaining")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrients")
                .font(.headline)

            MacroRow(label: "Protein", current: nutrition.proteinCurrent, goal: 120, color: .orange)
            MacroRow(label: "Carbs", current: nutrition.carbsCurrent, goal: 258, color: .blue)
            MacroRow(label: "Fats", current: nutrition.fatsCurrent, goal: 77, color: .purple)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }

    private var bottomBar: some View {
        UniversalNavigationBar(
            onHome: { /* Already on home screen */ },
            onRecipes: { if let onNavigate { onNavigate(7) } else { showRecipes = true } },
            onCamera: { if let onNavigate { onNavigate(10) } else { showAICamera = true } },
            onStats: { if let onNavigate { onNavigate(8) } else { showStats = true } },
            onProfile: { onNavigate?(9) },
            currentScreen: .home
        )
    }
}

// MARK: - MacroRow
struct MacroRow: View {
    let label: String
    let current: Double
    let goal: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(current))g / \(Int(goal))g")
                    .foregroundColor(color)
                    .bold()
            }
            ProgressView(value: current, total: max(1, goal))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
            Text("\(goal <= 0 ? 0 : Int((current / goal) * 100))% of goal")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}


// MARK: - Utilities

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


// MARK: - Preview
// (HomeScreenWithNutrition was deleted — it was a ~300 line duplicate of
// HomeScreen that existed because HomeScreen previously created its own
// NutritionState via @StateObject. Now that HomeScreen accepts nutrition
// as an init param, StatsScreen can use HomeScreen directly. See commit
// history for the full struct if needed.)
// MARK: - Preview
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen(
            userData: UserData(name: "Janice", email: "test@example.com"),
            nutrition: NutritionState(goal: 2000)
        )
    }
}

