import SwiftUI

struct MainTabs: View {
    @ObservedObject var store: UserDataStore
    @ObservedObject var nutrition: NutritionState
    @State private var tab = 6
    @State private var showCamera = false
    @State private var showProfile = false
    @State private var queuedFood: FoodItem?
    @State private var foodToLog: FoodItem?
    @State private var cameraError: String?

    var body: some View {
        content
            .sheet(isPresented: $showProfile) { ProfileView(nutrition: nutrition) }
            .sheet(isPresented: $showCamera, onDismiss: {
                foodToLog = queuedFood; queuedFood = nil
            }) {
                CalorieCameraBridge { result in
                    switch result {
                    case .success(let item, _):
                        queuedFood = FoodItem(id: Int.random(in: 1000...999999), name: item.label,
                            calories: Int(item.cFused.rounded()), protein: item.protein ?? 0,
                            carbs: item.carbs ?? 0, fats: item.fats ?? 0, category: "Detected")
                    case .failed(let error): cameraError = error.localizedDescription
                    case .cancelled: break
                    }
                    showCamera = false
                }
            }
            .sheet(item: $foodToLog) { food in
                FoodLoggerView(prefill: food, onSave: { nutrition.add($0) }, onClose: { foodToLog = nil })
            }
            .alert("Food Camera", isPresented: Binding(get: { cameraError != nil }, set: { if !$0 { cameraError = nil } })) {
                Button("OK") { cameraError = nil }
            } message: { Text(cameraError ?? "") }
    }
    @ViewBuilder private var content: some View {
        switch tab {
        case 7:
            RecipesView(currentScreen: $tab, loggedFoods: $nutrition.loggedMeals, userData: store.userData,
                        nutrition: nutrition, onNavigate: navigate)
        case 8:
            StatsScreen(userData: store.userData, nutrition: nutrition, onNavigate: navigate)
        default:
            HomeScreen(userData: store.userData, nutrition: nutrition, onNavigate: navigate)
        }
    }
    private func navigate(_ destination: Int) {
        if destination == 9 { showProfile = true }
        else if destination == 10 { showCamera = true }
        else { tab = destination }
    }
}
