//
//  StatsScreen.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI
import Charts

struct StatsScreen: View {
    let userData: UserData
    @ObservedObject var nutrition: NutritionState   // 🔗 mirrors Home

    // UI state
    @State private var selectedPeriod: TimePeriod = .daily
    @State private var selectedTab: StatsTab = .overview
    @State private var hoveredDataPoint: WeeklyData? = nil
    @State private var hoveredBarData: WeekdayWeekendData? = nil
    @State private var hoveredNutritionSegment: FoodGroupData? = nil

    // Goals UI state
    @State private var tempGoal: Double = 2000
    @State private var selectedGoalType: GoalType = .maintenance
    @State private var hasUnsavedChanges: Bool = false

    // Navigation state (optional)
    @State private var showRecipes = false
    @State private var showAICamera = false
    @State private var showProfile = false

    // Mock data for charts (kept from your version)
    private let weeklyData = [
        WeeklyData(date: "Mon", calories: 1850, target: 2000),
        WeeklyData(date: "Tue", calories: 2100, target: 2000),
        WeeklyData(date: "Wed", calories: 1920, target: 2000),
        WeeklyData(date: "Thu", calories: 2250, target: 2000),
        WeeklyData(date: "Fri", calories: 1780, target: 2000),
        WeeklyData(date: "Sat", calories: 2400, target: 2000),
        WeeklyData(date: "Sun", calories: 1650, target: 2000)
    ]
    private let foodGroupData = [
        FoodGroupData(name: "Protein", calories: 600, percentage: 30, color: .red, icon: "🥩"),
        FoodGroupData(name: "Carbs", calories: 800, percentage: 40, color: .orange, icon: "🍞"),
        FoodGroupData(name: "Fats", calories: 400, percentage: 20, color: .blue, icon: "🥑"),
        FoodGroupData(name: "Fruits", calories: 150, percentage: 8, color: .purple, icon: "🍎"),
        FoodGroupData(name: "Veggies", calories: 50, percentage: 3, color: .green, icon: "🥕")
    ]
    private let weekdayWeekendData = [
        WeekdayWeekendData(week: "Week 1", weekday: 1850, weekend: 2200),
        WeekdayWeekendData(week: "Week 2", weekday: 1700, weekend: 2000),
        WeekdayWeekendData(week: "Week 3", weekday: 1920, weekend: 2300),
        WeekdayWeekendData(week: "Week 4", weekday: 1780, weekend: 2100)
    ]
    private let monthlyStats = MonthlyStats(
        monthAvg: 1925,
        bestDay: 2100,
        consistency: 78,
        total: 59675
    )
    private let mealDistributionData = [
        MealData(name: "Breakfast", calories: 450, icon: "🌅"),
        MealData(name: "Lunch", calories: 650, icon: "☀️"),
        MealData(name: "Dinner", calories: 550, icon: "🌙")
    ]
    private let achievementData = [
        AchievementData(title: "7-Day Streak", progress: 85, icon: "🔥", achieved: false),
        AchievementData(title: "Perfect Week", progress: 100, icon: "🎯", achieved: true),
        AchievementData(title: "Consistency Master", progress: 65, icon: "📈", achieved: false)
    ]

    // Pull the heavy gradient out so the type-checker doesn't inline it
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

    // Derived properties
    private var currentCalories: Int { nutrition.caloriesCurrent }
    private var currentGoal: Int { nutrition.caloriesGoal }
    private var avatarState: AvatarState { nutrition.avatarState }
    private var mealsLoggedToday: Int { nutrition.mealsLoggedToday }
    private var loggedFoods: [LoggedFood] { nutrition.loggedMeals }
    
    // Navigation state
    @State private var showHome: Bool = false
    
    private var progressPercentage: Double { Double(nutrition.progressPercent) }
    private var avatarStateColor: Color {
        switch nutrition.avatarState {
        case .sad: return .red
        case .neutral: return .gray
        case .happy: return .green
        case .strong: return .blue
        case .overweight: return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                Self.bgGradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Avatar Card (light version)
                        avatarCard
                        
                        // Today's Progress Ring (centered)
                        progressRingSection
                        
                        // Main Content Tabs
                        tabContent
                        
                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom Navigation Bar
            universalNavigationBar
        }
        .onTapGesture {
            // Dismiss tooltips when tapping outside
            hoveredDataPoint = nil
            hoveredBarData = nil
            hoveredNutritionSegment = nil
        }
        // Navigation sheets
        .fullScreenCover(isPresented: $showHome) {
            // Navigate back to Home with the shared nutrition state.
            // Previously this used HomeScreenWithNutrition (a ~300 line
            // duplicate of HomeScreen). Now that HomeScreen accepts
            // nutrition as a param, we can use the real thing directly.
            HomeScreen(userData: userData, nutrition: nutrition)
        }
        .fullScreenCover(isPresented: $showRecipes) {
            RecipesView(
                currentScreen: .constant(6),
                loggedFoods: .constant(loggedFoods),
                onFoodLogged: { _ in },
                userData: userData,
                nutrition: nutrition
            )
        }
        .sheet(isPresented: $showAICamera) {
            // TODO: Implement AI Camera
            Text("AI Camera functionality coming soon")
        }
        .sheet(isPresented: $showProfile) {
            // TODO: Implement profile functionality
            Text("Profile functionality coming soon")
        }
    }
    
    // MARK: - Navigation Bar
    private var universalNavigationBar: some View {
        UniversalNavigationBar(
            onHome: { showHome = true },
            onRecipes: { showRecipes = true },
            onCamera: { showAICamera = true },
            onStats: { /* Already on stats screen */ },
            onProfile: { showProfile = true },
            currentScreen: .stats
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("My Progress")
                .font(.title2).bold()
                .foregroundColor(.white)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Avatar Card (Light Version)
    private var avatarCard: some View {
        VStack(spacing: 12) {
            AvatarView(state: avatarState, showFeedingEffect: .constant(false))
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)

            Text(userData.selectedCharacter.displayName)
                .font(.headline)
                .foregroundColor(.white)
            Text("Level 1 • \(mealsLoggedToday) meals logged today")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Text("\(Int(progressPercentage))% on track towards my goal!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(avatarStateColor.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Progress Ring Section (Centered)
    private var progressRingSection: some View {
        VStack(spacing: 16) {
            Text("Today's Progress")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            progressRing
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Progress Ring
    private var progressRing: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progressPercentage / 100)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                // Percentage text
                VStack(spacing: 4) {
                    Text("\(Int(progressPercentage))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Complete")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            VStack(spacing: 4) {
                Text("\(currentCalories.formatted()) / \(currentGoal.formatted()) cal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(max(0, currentGoal - currentCalories)) cal remaining")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Tab Content
    private var tabContent: some View {
        VStack(spacing: 16) {
            // Tab Selector
            HStack(spacing: 0) {
                ForEach(StatsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == tab ? Color.white.opacity(0.2) : Color.clear)
                    }
                }
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
            
            // Tab Content
            Group {
                switch selectedTab {
                case .overview:
                    overviewContent
                case .trends:
                    trendsContent
                case .breakdown:
                    breakdownContent
                case .goals:
                    goalsContent
                }
            }
        }
    }
    
    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // This Week's Progress
            thisWeeksProgressSection
            
            // Today's Nutrition
            todaysNutritionSection
            
            // Daily Goal Cards
            dailyGoalSection
        }
    }
    
    // MARK: - This Week's Progress Section
    private var thisWeeksProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📈")
                    .font(.system(size: 16))
                Text("This Week's Progress")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            ZStack {
                Chart(weeklyData) { data in
                    LineMark(
                        x: .value("Day", data.date),
                        y: .value("Calories", data.calories)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Day", data.date),
                        y: .value("Calories", data.calories)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(40)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                // Interactive overlay for hover detection
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(weeklyData.indices, id: \.self) { index in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / CGFloat(weeklyData.count))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hoveredDataPoint = weeklyData[index]
                                }
                        }
                    }
                    
                    // Tooltip positioned outside the chart area
                    if let data = hoveredDataPoint {
                        VStack(spacing: 4) {
                            Text(data.date)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text("Target:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.target.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 8) {
                                Text("Intake:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.calories.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .position(
                            x: CGFloat(weeklyData.firstIndex(where: { $0.id == data.id }) ?? 0) * (geometry.size.width / CGFloat(weeklyData.count)) + (geometry.size.width / CGFloat(weeklyData.count)) / 2,
                            y: geometry.size.height - 20
                        )
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Today's Nutrition Section
    private var todaysNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🥗")
                    .font(.system(size: 16))
                Text("Today's Nutrition")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Interactive Pie Chart (smaller)
                ZStack {
                    // Pie Chart
                    ZStack {
                        ForEach(Array(foodGroupData.enumerated()), id: \.offset) { index, food in
                            let startAngle = getStartAngle(for: index)
                            let endAngle = getEndAngle(for: index)
                            
                            Circle()
                                .trim(from: startAngle, to: endAngle)
                                .stroke(food.color, style: StrokeStyle(lineWidth: 25, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                                .scaleEffect(hoveredNutritionSegment?.id == food.id ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: hoveredNutritionSegment?.id)
                                .onTapGesture {
                                    hoveredNutritionSegment = hoveredNutritionSegment?.id == food.id ? nil : food
                                }
                        }
                    }
                    
                    // Tooltip
                    if let food = hoveredNutritionSegment {
                        VStack(spacing: 2) {
                            Text("\(food.name): \(food.calories) cal")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(6)
                        .offset(y: -70)
                    }
                }
                .padding(.leading, 2)
                
                // Legend (vertical layout)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(foodGroupData, id: \.name) { food in
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text(food.icon)
                                    .font(.system(size: 14))
                                
                                Text(food.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(food.percentage)%")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(food.calories) cal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Daily Goal Section
    private var dailyGoalSection: some View {
        VStack(spacing: 12) {
            // Daily Goal Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Goal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(currentGoal.formatted())")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("target calories")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("🎯")
                    .font(.system(size: 20))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            
            // Consumed Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consumed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(currentCalories.formatted())")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("calories today")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("🍽️")
                    .font(.system(size: 20))
            }
            .padding(16)
            .background(Color.green.opacity(0.2))
            .cornerRadius(16)
            
            // Remaining Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(max(0, currentGoal - currentCalories))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("until goal")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("⏱️")
                    .font(.system(size: 20))
            }
            .padding(16)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(16)
            
            // Progress Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(Int(progressPercentage))%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("of daily goal")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("📈")
                        .font(.system(size: 20))
                    
                    Text("12%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(8)
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.2))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Weekly Progress Chart
    private var weeklyProgressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📈")
                    .font(.system(size: 16))
                Text("This Week's Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Chart(weeklyData) { data in
                LineMark(
                    x: .value("Day", data.date),
                    y: .value("Calories", data.calories)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("Day", data.date),
                    y: .value("Calories", data.calories)
                )
                .foregroundStyle(.green)
                .symbolSize(30)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisTick()
                    AxisValueLabel {
                        if let stringValue = value.as(String.self) {
                            Text(stringValue)
                                .font(.system(size: 10))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Nutrition Breakdown
    private var nutritionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🥗")
                    .font(.system(size: 16))
                Text("Today's Nutrition")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Donut Chart
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 120, height: 120)
                
                ForEach(Array(foodGroupData.enumerated()), id: \.offset) { index, food in
                    let startAngle = getStartAngle(for: index)
                    let endAngle = getEndAngle(for: index)
                    
                    Circle()
                        .trim(from: startAngle, to: endAngle)
                        .stroke(food.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            // Legend
            VStack(alignment: .leading, spacing: 8) {
                ForEach(foodGroupData, id: \.name) { food in
                    HStack {
                        Text(food.icon)
                            .font(.system(size: 14))
                        Text(food.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(food.percentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text("\(food.calories) cal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Trends Content
    private var trendsContent: some View {
        VStack(spacing: 20) {
            // Calorie Trend Analysis
            calorieTrendAnalysis
            
            // Weekday vs Weekend Calories
            weekdayWeekendSection
            
            // Monthly Overview
            monthlyOverviewSection
        }
    }
    
    // MARK: - Calorie Trend Analysis
    private var calorieTrendAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📈")
                    .font(.system(size: 16))
                Text("Calorie Trend Analysis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            ZStack {
                Chart(weeklyData) { data in
                    LineMark(
                        x: .value("Day", data.date),
                        y: .value("Target", data.target)
                    )
                    .foregroundStyle(.white.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    LineMark(
                        x: .value("Day", data.date),
                        y: .value("Calories", data.calories)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Day", data.date),
                        y: .value("Calories", data.calories)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(40)
                }
                .frame(height: 250)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartBackground { chartProxy in
                    Rectangle()
                        .fill(.clear)
                }
                
                // Interactive overlay for hover detection
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(weeklyData.indices, id: \.self) { index in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / CGFloat(weeklyData.count))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hoveredDataPoint = weeklyData[index]
                                }
                        }
                    }
                    
                    // Tooltip positioned outside the chart area
                    if let data = hoveredDataPoint {
                        VStack(spacing: 4) {
                            Text(data.date)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text("Target:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.target.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 8) {
                                Text("Intake:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.calories.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .position(
                            x: CGFloat(weeklyData.firstIndex(where: { $0.id == data.id }) ?? 0) * (geometry.size.width / CGFloat(weeklyData.count)) + (geometry.size.width / CGFloat(weeklyData.count)) / 2,
                            y: geometry.size.height - 20
                        )
                    }
                }
            }
            .frame(height: 250)
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Weekday vs Weekend Section
    private var weekdayWeekendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📊")
                    .font(.system(size: 16))
                Text("Weekday vs Weekend Calories")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("+375 cal avg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
            }
            
            // Summary Cards
            HStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text("1,888")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Weekday Avg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("👔")
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text("2,263")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Weekend Avg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("🎉")
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Bar Chart
            ZStack {
                Chart(weekdayWeekendData) { data in
                    BarMark(
                        x: .value("Week", data.week),
                        y: .value("Weekday", data.weekday)
                    )
                    .foregroundStyle(.green)
                    
                    BarMark(
                        x: .value("Week", data.week),
                        y: .value("Weekend", data.weekend)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisTick()
                            .foregroundStyle(.white.opacity(0.6))
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                // Interactive overlay for hover detection
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(weekdayWeekendData.indices, id: \.self) { index in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: geometry.size.width / CGFloat(weekdayWeekendData.count))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hoveredBarData = weekdayWeekendData[index]
                                }
                        }
                    }
                    
                    // Tooltip positioned outside the chart area
                    if let data = hoveredBarData {
                        VStack(spacing: 4) {
                            Text(data.week)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text("Weekdays:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.weekday.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            HStack(spacing: 8) {
                                Text("Weekends:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(data.weekend.formatted()) cal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .position(
                            x: CGFloat(weekdayWeekendData.firstIndex(where: { $0.id == data.id }) ?? 0) * (geometry.size.width / CGFloat(weekdayWeekendData.count)) + (geometry.size.width / CGFloat(weekdayWeekendData.count)) / 2,
                            y: geometry.size.height - 20
                        )
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Monthly Overview Section
    private var monthlyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📈")
                    .font(.system(size: 16))
                Text("Monthly Overview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Stats Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // Month Avg
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Month Avg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("📅")
                            .font(.system(size: 12))
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(monthlyStats.monthAvg.formatted())")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 2) {
                            Text("📈")
                                .font(.system(size: 10))
                            Text("3%")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    Text("calories/day")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Best Day
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Best Day")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("🏆")
                            .font(.system(size: 12))
                    }
                    
                    Text("\(monthlyStats.bestDay.formatted())")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("closest to goal")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .background(Color.green.opacity(0.2))
                .cornerRadius(12)
                
                // Consistency
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Consistency")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("🎯")
                            .font(.system(size: 12))
                    }
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(monthlyStats.consistency)%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 2) {
                            Text("📈")
                                .font(.system(size: 10))
                            Text("5%")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    Text("days on track")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Total
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("📊")
                            .font(.system(size: 12))
                    }
                    
                    Text("\(monthlyStats.total.formatted())")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("calories this month")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }

    // MARK: - Breakdown Content
    private var breakdownContent: some View {
        VStack(spacing: 20) {
            // Daily Nutrition Breakdown
            dailyNutritionBreakdown
            
            // Meal Distribution
            mealDistributionSection
        }
    }
    
    // MARK: - Daily Nutrition Breakdown
    private var dailyNutritionBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🥗")
                    .font(.system(size: 16))
                Text("Daily Nutrition Breakdown")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Interactive Pie Chart
                ZStack {
                    // Pie Chart
                    ZStack {
                        ForEach(Array(foodGroupData.enumerated()), id: \.offset) { index, food in
                            let startAngle = getStartAngle(for: index)
                            let endAngle = getEndAngle(for: index)
                            
                            Circle()
                                .trim(from: startAngle, to: endAngle)
                                .stroke(food.color, style: StrokeStyle(lineWidth: 25, lineCap: .round))
                                .frame(width: 130, height: 130)
                                .rotationEffect(.degrees(-90))
                                .scaleEffect(hoveredNutritionSegment?.id == food.id ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: hoveredNutritionSegment?.id)
                                .onTapGesture {
                                    hoveredNutritionSegment = hoveredNutritionSegment?.id == food.id ? nil : food
                                }
                        }
                    }
                    
                    // Tooltip
                    if let food = hoveredNutritionSegment {
                        VStack(spacing: 2) {
                            Text("Calories")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(food.calories) cal")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(6)
                        .offset(y: -75)
                    }
                }
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(foodGroupData, id: \.name) { food in
                        HStack {
                            Text(food.icon)
                                .font(.system(size: 14))
                            Text(food.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(food.percentage)%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text("\(food.calories) cal")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Meal Distribution Section
    private var mealDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🥗")
                    .font(.system(size: 16))
                Text("Meal Distribution")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ForEach(mealDistributionData, id: \.name) { meal in
                    HStack(spacing: 12) {
                        Text(meal.icon)
                            .font(.system(size: 16))
                        
                        Text(meal.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 80, alignment: .leading)
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 16)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * (Double(meal.calories) / 1000.0), height: 16)
                            }
                        }
                        .frame(height: 16)
                        
                        Text("\(meal.calories) cal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Goals Content
    private var goalsContent: some View {
        VStack(spacing: 20) {
            // Daily Calorie Goal
            dailyCalorieGoalSection
            
            // Achievement Tracker
            achievementTrackerSection
        }
    }
    
    // MARK: - Daily Calorie Goal Section
    private var dailyCalorieGoalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("🎯")
                    .font(.system(size: 16))
                Text("Daily Calorie Goal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Current Goal Display
            VStack(spacing: 4) {
                Text("\(Int(tempGoal).formatted())")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                Text("calories per day")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            
            // Adjust Goal Slider
            VStack(spacing: 12) {
                Text("Adjust Goal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Slider(value: $tempGoal, in: 1000...4000, step: 50)
                        .accentColor(.green)
                        .onChange(of: tempGoal) { _, _ in
                            hasUnsavedChanges = true
                            updateSelectedGoalType()
                        }
                    
                    HStack {
                        Text("1,000")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("4,000")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Preset Goal Buttons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(GoalType.allCases, id: \.self) { goalType in
                    Button(action: {
                        tempGoal = Double(goalType.calories)
                        selectedGoalType = goalType
                        hasUnsavedChanges = true
                    }) {
                        VStack(spacing: 8) {
                            Text(goalType.icon)
                                .font(.system(size: 20))
                            Text(goalType.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text("\(goalType.calories)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(selectedGoalType == goalType ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedGoalType == goalType ? Color.green : Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: resetGoal) {
                    Text("Reset")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 1)
                        )
                }
                
                Button(action: saveGoal) {
                    Text("Save Goal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(hasUnsavedChanges ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(hasUnsavedChanges ? Color.green : Color.green.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!hasUnsavedChanges)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Achievement Tracker Section
    private var achievementTrackerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🏆")
                    .font(.system(size: 16))
                Text("Achievement Tracker")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ForEach(achievementData, id: \.title) { achievement in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(achievement.icon)
                                .font(.system(size: 16))
                            Text(achievement.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if achievement.achieved {
                                Text("✓ Achieved")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * (Double(achievement.progress) / 100.0), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("\(achievement.progress)% complete")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    
    // MARK: - Helper Functions
    
    
    private func updateSelectedGoalType() {
        let closestGoal = GoalType.allCases.min { abs($0.calories - Int(tempGoal)) < abs($1.calories - Int(tempGoal)) }
        selectedGoalType = closestGoal ?? .maintenance
    }
    
    private func resetGoal() {
        tempGoal = Double(currentGoal)
        selectedGoalType = .maintenance
        hasUnsavedChanges = false
    }
    
    private func saveGoal() {
        nutrition.setGoal(Int(tempGoal))
        hasUnsavedChanges = false
    }
    
    private func getStartAngle(for index: Int) -> Double {
        let totalPercentage = 100.0
        var cumulativePercentage = 0.0
        
        for i in 0..<index {
            cumulativePercentage += Double(foodGroupData[i].percentage)
        }
        
        return cumulativePercentage / totalPercentage
    }
    
    private func getEndAngle(for index: Int) -> Double {
        let totalPercentage = 100.0
        var cumulativePercentage = 0.0
        
        for i in 0...index {
            cumulativePercentage += Double(foodGroupData[i].percentage)
        }
        
        return cumulativePercentage / totalPercentage
    }
}

// MARK: - Supporting Views and Models

struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let trend: TrendDirection?
    let trendValue: String?
    let backgroundColor: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        trend: TrendDirection? = nil,
        trendValue: String? = nil,
        backgroundColor: Color = .white
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.trend = trend
        self.trendValue = trendValue
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let icon = icon {
                    Text(icon)
                        .font(.system(size: 14))
                }
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                if let trend = trend, let trendValue = trendValue {
                    HStack(spacing: 2) {
                        Text(trend.icon)
                            .font(.system(size: 10))
                        Text(trendValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(trend.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(trend.color.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

enum TrendDirection {
    case up, down, neutral
    
    var icon: String {
        switch self {
        case .up: return "📈"
        case .down: return "📉"
        case .neutral: return "➡️"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
}

enum TimePeriod: CaseIterable {
    case daily, weekly, monthly, custom
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "📅"
        case .weekly: return "📊"
        case .monthly: return "📈"
        case .custom: return "🎯"
        }
    }
}

enum StatsTab: CaseIterable {
    case overview, trends, breakdown, goals
    
    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .trends: return "Trends"
        case .breakdown: return "Breakdown"
        case .goals: return "Goals"
        }
    }
}

struct WeeklyData: Identifiable {
    let id = UUID()
    let date: String
    let calories: Int
    let target: Int
}

struct FoodGroupData: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let percentage: Int
    let color: Color
    let icon: String
}

struct WeekdayWeekendData: Identifiable {
    let id = UUID()
    let week: String
    let weekday: Int
    let weekend: Int
}

struct MonthlyStats {
    let monthAvg: Int
    let bestDay: Int
    let consistency: Int
    let total: Int
}

struct MealData: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let icon: String
}

enum GoalType: CaseIterable {
    case weightLoss, maintenance, muscleGain, bulking
    
    var displayName: String {
        switch self {
        case .weightLoss: return "Weight Loss"
        case .maintenance: return "Maintenance"
        case .muscleGain: return "Muscle Gain"
        case .bulking: return "Bulking"
        }
    }
    
    var calories: Int {
        switch self {
        case .weightLoss: return 1500
        case .maintenance: return 2000
        case .muscleGain: return 2500
        case .bulking: return 3000
        }
    }
    
    var icon: String {
        switch self {
        case .weightLoss: return "📉"
        case .maintenance: return "⚖️"
        case .muscleGain: return "💪"
        case .bulking: return "🏋️"
        }
    }
}

struct AchievementData: Identifiable {
    let id = UUID()
    let title: String
    let progress: Int
    let icon: String
    let achieved: Bool
}

// MARK: - Preview
#Preview {
    StatsScreen(
        userData: UserData(name: "Janice", email: "test@example.com"),
        nutrition: NutritionState()
    )
}
