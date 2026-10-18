//
//  FoodLoggerView.swift
//  HabitPet
//

import SwiftUI
import Combine

struct FoodLoggerView: View {
    let prefill: FoodItem?
    let onSave: (LoggedFood) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [FoodItem] = []
    @State private var selectedFood: FoodItem?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showingPopularFoods = false
    @State private var searchCancellable: AnyCancellable?

    private let usdaService = USDAFoodService.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                searchBar
                popularFoodsButton
                searchResultsSection
                selectedFoodSection
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let p = prefill {
                // Preselect the camera-detected item
                selectedFood = p
                searchQuery = p.name
            }
        }
        // Ensure we react if prefill arrives slightly after the sheet appears
        .onChange(of: prefill) { _, newPrefill in
            if let p = newPrefill {
                selectedFood = p
                searchQuery = p.name
            }
        }
        .onDisappear { searchCancellable?.cancel() }
    }

    // MARK: Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)

            if #available(iOS 17.0, *) {
                TextField("Search for food items...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .onChange(of: searchQuery) { _, _ in
                        performSearch()
                    }
            } else {
                TextField("Search for food items...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .onChange(of: searchQuery) { _ in
                        performSearch()
                    }
            }

            if isSearching { ProgressView().scaleEffect(0.8) }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: Popular Foods
    private var popularFoodsButton: some View {
        Group {
            if searchQuery.isEmpty && searchResults.isEmpty {
                Button(action: loadPopularFoods) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Browse Popular Foods")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: Search Results
    private var searchResultsSection: some View {
        Group {
            if (!searchQuery.isEmpty || showingPopularFoods) && selectedFood == nil {
                if isSearching {
                    ProgressView("Searching USDA database...").padding(.top, 20)
                } else if let error = searchError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                        Text("Search Error").font(.headline)
                        Text(error).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                } else if searchResults.isEmpty {
                    Text("No foods found matching \(searchQuery)")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(searchResults.prefix(20)) { food in
                                Button { selectedFood = food } label: {
                                    FoodItemRow(food: food)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: Selected Food
    private var selectedFoodSection: some View {
        Group {
            if let food = selectedFood {
                FoodDetailView(food: food) { logged in
                    onSave(logged)
                    onClose()
                    dismiss()
                } onCancel: {
                    selectedFood = nil
                }
            }
        }
    }

    // MARK: Helpers
    private func performSearch() {
        searchCancellable?.cancel()
        isSearching = false
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchError = nil
            return
        }
        isSearching = true
        searchError = nil

        searchCancellable?.cancel()
        searchCancellable = Just(searchQuery)
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .setFailureType(to: Error.self)
            .flatMap { query in usdaService.searchFoodsWithFallback(query: query) }
            .sink(
                receiveCompletion: { completion in
                    isSearching = false
                    if case .failure(let error) = completion {
                        searchError = error.localizedDescription
                    }
                },
                receiveValue: { foods in
                    searchResults = foods
                }
            )
    }

    private func loadPopularFoods() {
        showingPopularFoods = true
        searchResults = usdaService.getMockFoods()
    }
}

// MARK: - List Row
struct FoodItemRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body)
                    .lineLimit(2)

                // Only show category text if it’s not "Detected" (avoid dup with pill)
                if food.category != "Detected" {
                    Text(food.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(food.calories) cal")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    if food.usdaFood != nil {
                        Text("USDA")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    if food.category == "Detected" {
                        DetectedPill()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

fileprivate struct DetectedPill: View {
    var body: some View {
        Text("Detected")
            .font(.caption2).bold()
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .cornerRadius(6)
    }
}

// MARK: - Detail Panel
struct FoodDetailView: View {
    let food: FoodItem
    let onSave: (LoggedFood) -> Void
    let onCancel: () -> Void

    @State private var portion: Double = 1.0

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(food.name)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if food.category == "Detected" {
                            Text("Detected")
                                .font(.caption).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(999)
                        }
                    }
                    if food.category != "Detected" {
                        Text(food.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Cancel") { onCancel() }
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.horizontal)

            // Portion Size
            VStack(spacing: 8) {
                HStack {
                    Text(food.category == "Detected" || food.usdaFood == nil ? "Portion Size" : "Portion of 100 g").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text("\(Int(portion * 100))%").foregroundColor(.blue)
                }
                .padding(.horizontal)
                Slider(value: $portion, in: 0.1...3.0, step: 0.1)
                    .padding(.horizontal)
            }

            // Nutrition (per portion)
            VStack(spacing: 12) {
                Text("Nutrition (per portion)")
                    .font(.subheadline).fontWeight(.medium)
                HStack(spacing: 20) {
                    nutrientColumn(title: "Calories", value: "\(Int(Double(food.calories) * portion))")
                    nutrientColumn(title: "Protein",  value: "\(String(format: "%.1f", food.protein * portion))g")
                    nutrientColumn(title: "Carbs",    value: "\(String(format: "%.1f", food.carbs   * portion))g")
                    nutrientColumn(title: "Fats",     value: "\(String(format: "%.1f", food.fats    * portion))g")
                }
            }
            .padding(.horizontal)

            // Save
            Button {
                let logged = LoggedFood(
                    food: FoodItem(
                        id: food.id,
                        name: food.name,
                        calories: Int(Double(food.calories) * portion),
                        protein: food.protein * portion,
                        carbs:   food.carbs   * portion,
                        fats:    food.fats    * portion,
                        category: food.category,
                        usdaFood: food.usdaFood
                    ),
                    portion: portion,
                    timestamp: Date()
                )
                onSave(logged)
            } label: {
                Text("Log Food")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        // Add generous inner padding so content isn't flush to the gray card edges
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func nutrientColumn(title: String, value: String) -> some View {
        VStack {
            Text(value).font(.title2).bold()
            Text(title).font(.caption).foregroundColor(.secondary)
        }
    }
}

#Preview("FoodLoggerView") {
    FoodLoggerView(
        prefill: FoodItem(
            id: 9999,
            name: "Detected Bowl",
            calories: 540,
            protein: 32,
            carbs: 50,
            fats: 18,
            category: "Detected",
            usdaFood: nil
        ),
        onSave: { _ in },
        onClose: {}
    )
}

