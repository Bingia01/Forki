import SwiftUI
import Charts

struct StatsScreen: View {
    let userData: UserData
    @ObservedObject var nutrition: NutritionState
    var onNavigate: ((Int) -> Void)? = nil
    @State private var date = Date()
    @State private var period = Period.week
    @State private var goal = 2000
    private let calendar = Calendar.current
    enum Period: String, CaseIterable { case day = "Day", week = "Week", month = "Month" }
    struct Day: Identifiable { let date: Date; let calories: Int; var id: Date { date } }
    private var dates: [Date] {
        let end = calendar.startOfDay(for: date)
        let start: Date
        switch period {
        case .day: start = end
        case .week: start = calendar.date(byAdding: .day, value: -6, to: end)!
        case .month: start = calendar.dateInterval(of: .month, for: end)!.start
        }
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0...max(0, count)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private var meals: [LoggedFood] {
        guard let start = dates.first, let end = calendar.date(byAdding: .day, value: 1, to: dates.last ?? date) else { return [] }
        return nutrition.loggedMeals.filter { $0.timestamp >= start && $0.timestamp < end }.sorted { $0.timestamp > $1.timestamp }
    }
    private var days: [Day] {
        dates.map { date in Day(date: date, calories: nutrition.meals(on: date).reduce(0) { $0 + $1.food.calories }) }
    }
    private var totalCalories: Int { meals.reduce(0) { $0 + $1.food.calories } }
    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                List {
                    Section {
                        DatePicker("Ending on", selection: $date, in: ...Date(), displayedComponents: .date)
                        Picker("Period", selection: $period) {
                            ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    Section("Logged nutrition") {
                        LabeledContent("Total calories", value: "\(totalCalories) kcal")
                        LabeledContent("Average per day", value: "\(totalCalories / max(1, dates.count)) kcal")
                        Text("Days without logged meals count as zero. These totals describe your logs, not your actual food intake.")
                            .font(.caption).foregroundStyle(.secondary)
                        Chart(days) { day in
                            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Calories", day.calories))
                            RuleMark(y: .value("Current daily goal", nutrition.caloriesGoal)).foregroundStyle(.orange)
                        }.frame(height: 180)
                        LabeledContent("Protein", value: String(format: "%.1f g", meals.reduce(0) { $0 + $1.food.protein }))
                        LabeledContent("Carbs", value: String(format: "%.1f g", meals.reduce(0) { $0 + $1.food.carbs }))
                        LabeledContent("Fats", value: String(format: "%.1f g", meals.reduce(0) { $0 + $1.food.fats }))
                    }
                    Section("Daily goal") {
                        Stepper("\(goal) kcal", value: $goal, in: 1000...4000, step: 50)
                        Button("Save Goal") { nutrition.setGoal(goal) }
                            .disabled(goal == nutrition.caloriesGoal)
                    }
                    Section("Food history") {
                        if meals.isEmpty { Text("No meals logged in this period.").foregroundStyle(.secondary) }
                        ForEach(meals) { meal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.food.name)
                                Text("\(meal.food.calories) kcal · \(meal.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .swipeActions { Button("Delete", role: .destructive) { nutrition.remove(id: meal.id) } }
                        }
                    }
                }
                .navigationTitle("Your Progress")
                .onAppear { goal = nutrition.caloriesGoal }
            }
            UniversalNavigationBar(onHome: { onNavigate?(6) }, onRecipes: { onNavigate?(7) },
                onCamera: { onNavigate?(10) }, onStats: {}, onProfile: { onNavigate?(9) }, currentScreen: .stats)
        }
    }
}
