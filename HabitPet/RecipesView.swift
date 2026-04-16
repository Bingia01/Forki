//
//  RecipesView.swift
//  HabitPet
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI

struct RecipesView: View {
    @Binding var currentScreen: Int
    @Binding var loggedFoods: [LoggedFood]
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery: String = ""
    @State private var selectedFilter: RecipeCategory? = nil
    @State private var selectedRecipe: Recipe? = nil
    
    // Navigation state
    @State private var showHome = false
    @State private var showStats = false
    @State private var showAICamera = false
    @State private var showProfile = false
    
    // Callback for triggering feeding animations in parent view
    var onFoodLogged: ((LoggedFood) -> Void)? = nil

    // User data for navigation
    let userData: UserData?

    // Shared nutrition state — passed from the parent so all screens share one instance.
    // Previously this was `@State private var nutrition = NutritionState()` which created
    // a separate, empty, disconnected copy. StatsScreen opened from RecipesView would
    // show 0 calories even if the user had logged food on HomeScreen.
    @ObservedObject var nutrition: NutritionState

    init(currentScreen: Binding<Int>, loggedFoods: Binding<[LoggedFood]>, onFoodLogged: ((LoggedFood) -> Void)? = nil, userData: UserData? = nil, nutrition: NutritionState = NutritionState()) {
        self._currentScreen = currentScreen
        self._loggedFoods = loggedFoods
        self.onFoodLogged = onFoodLogged
        self.userData = userData
        self.nutrition = nutrition
    }
    
    private let recipes: [Recipe] = [
        Recipe(
            id: "1",
            title: "Grilled Chicken with Quinoa",
            imageName: "grilled-chicken-quinoa",
            prepTime: "30 min",
            calories: 425,
            protein: 42.0,
            fat: 12.0,
            carbs: 38.0,
            category: .mealPrep,
            tags: ["High-Protein", "Balanced", "Gluten-Free"],
            description: "A perfectly balanced meal with lean protein and whole grains.",
            ingredients: ["Chicken breast", "Quinoa", "Olive oil", "Lemon", "Herbs"],
            instructions: ["Season chicken", "Grill for 6-7 min per side", "Cook quinoa", "Serve together"]
        ),
        Recipe(
            id: "2",
            title: "Baked Salmon with Broccoli & Brown Rice",
            imageName: "salmon-broccoli-rice",
            prepTime: "35 min",
            calories: 520,
            protein: 45.0,
            fat: 18.0,
            carbs: 42.0,
            category: .mealPrep,
            tags: ["High-Protein", "Omega-3", "Pescatarian"],
            description: "Rich in omega-3 fatty acids and complete protein.",
            ingredients: ["Salmon fillet", "Broccoli", "Brown rice", "Garlic", "Olive oil"],
            instructions: ["Preheat oven to 400°F", "Season salmon", "Roast broccoli", "Cook rice", "Bake salmon 12-15 min"]
        ),
        Recipe(
            id: "3",
            title: "Vegetable Stir-Fry with Tofu",
            imageName: "veggie-stir-fry",
            prepTime: "20 min",
            calories: 320,
            protein: 18.0,
            fat: 14.0,
            carbs: 35.0,
            category: .mealPrep,
            tags: ["Vegetarian", "Quick Meals", "Plant-Based"],
            description: "Quick and nutritious plant-based protein meal.",
            ingredients: ["Tofu", "Mixed vegetables", "Soy sauce", "Ginger", "Garlic"],
            instructions: ["Press tofu", "Cut vegetables", "Stir-fry tofu", "Add vegetables", "Season"]
        ),
        Recipe(
            id: "4",
            title: "Greek Yogurt Parfait",
            imageName: "greek-yogurt-parfait",
            prepTime: "5 min",
            calories: 280,
            protein: 20.0,
            fat: 8.0,
            carbs: 32.0,
            category: .grocery,
            tags: ["Quick Meals", "High-Protein", "Breakfast"],
            description: "Perfect breakfast with probiotics and antioxidants.",
            ingredients: ["Greek yogurt", "Berries", "Granola", "Honey", "Nuts"],
            instructions: ["Layer yogurt", "Add berries", "Top with granola", "Drizzle honey"]
        ),
        Recipe(
            id: "5",
            title: "Avocado Toast with Egg",
            imageName: "avocado-toast",
            prepTime: "10 min",
            calories: 350,
            protein: 15.0,
            fat: 18.0,
            carbs: 28.0,
            category: .quickMeals,
            tags: ["Vegetarian", "Breakfast", "Healthy Fats"],
            description: "Nutrient-dense breakfast with healthy fats.",
            ingredients: ["Whole grain bread", "Avocado", "Egg", "Lemon", "Salt"],
            instructions: ["Toast bread", "Mash avocado", "Fry egg", "Assemble", "Season"]
        ),
        Recipe(
            id: "6",
            title: "Chicken Caesar Salad",
            imageName: "chicken-caesar-salad",
            prepTime: "15 min",
            calories: 380,
            protein: 32.0,
            fat: 16.0,
            carbs: 24.0,
            category: .restaurant,
            tags: ["High-Protein", "Low-Carb", "Classic"],
            description: "Classic salad with lean protein and crisp greens.",
            ingredients: ["Chicken breast", "Romaine lettuce", "Parmesan", "Caesar dressing", "Croutons"],
            instructions: ["Grill chicken", "Wash lettuce", "Make dressing", "Toss salad", "Top with chicken"]
        ),
        Recipe(
            id: "7",
            title: "Turkey & Hummus Wrap",
            imageName: "turkey-hummus-wrap",
            prepTime: "8 min",
            calories: 340,
            protein: 28.0,
            fat: 12.0,
            carbs: 32.0,
            category: .grocery,
            tags: ["Quick Meals", "High-Protein", "Portable"],
            description: "Perfect on-the-go meal with lean protein.",
            ingredients: ["Whole wheat tortilla", "Turkey slices", "Hummus", "Vegetables", "Spinach"],
            instructions: ["Spread hummus", "Add turkey", "Layer vegetables", "Roll tightly", "Cut in half"]
        ),
        Recipe(
            id: "8",
            title: "Buddha Bowl",
            imageName: "buddha-bowl",
            prepTime: "25 min",
            calories: 410,
            protein: 16.0,
            fat: 15.0,
            carbs: 48.0,
            category: .mealPrep,
            tags: ["Vegetarian", "Balanced", "Colorful"],
            description: "Nutrient-packed bowl with diverse plant foods.",
            ingredients: ["Quinoa", "Chickpeas", "Sweet potato", "Kale", "Tahini"],
            instructions: ["Cook quinoa", "Roast vegetables", "Prepare tahini sauce", "Assemble bowl", "Drizzle sauce"]
        ),
        Recipe(
            id: "9",
            title: "Scrambled Eggs with Spinach",
            imageName: "scrambled-eggs-spinach",
            prepTime: "10 min",
            calories: 260,
            protein: 18.0,
            fat: 14.0,
            carbs: 16.0,
            category: .quickMeals,
            tags: ["High-Protein", "Breakfast", "Vegetarian"],
            description: "Protein-rich breakfast with iron-packed greens.",
            ingredients: ["Eggs", "Spinach", "Butter", "Salt", "Pepper"],
            instructions: ["Heat pan", "Sauté spinach", "Beat eggs", "Scramble gently", "Season"]
        ),
        Recipe(
            id: "10",
            title: "Mediterranean Tuna Salad",
            imageName: "tuna-mediterranean-salad",
            prepTime: "12 min",
            calories: 310,
            protein: 28.0,
            fat: 16.0,
            carbs: 18.0,
            category: .grocery,
            tags: ["High-Protein", "Pescatarian", "Mediterranean"],
            description: "Fresh Mediterranean flavors with lean protein.",
            ingredients: ["Tuna", "Tomatoes", "Cucumber", "Olives", "Feta cheese"],
            instructions: ["Drain tuna", "Chop vegetables", "Mix ingredients", "Add dressing", "Serve"]
        ),
        Recipe(
            id: "11",
            title: "Baked Chicken with Sweet Potato",
            imageName: "baked-chicken-sweet-potato",
            prepTime: "40 min",
            calories: 445,
            protein: 38.0,
            fat: 11.0,
            carbs: 42.0,
            category: .mealPrep,
            tags: ["High-Protein", "Balanced", "Comfort Food"],
            description: "Comforting meal with lean protein and complex carbs.",
            ingredients: ["Chicken thighs", "Sweet potato", "Olive oil", "Rosemary", "Garlic"],
            instructions: ["Preheat oven", "Season chicken", "Cut sweet potato", "Roast together", "Serve"]
        ),
        Recipe(
            id: "12",
            title: "Spinach & Berry Salad",
            imageName: "spinach-berry-salad",
            prepTime: "15 min",
            calories: 295,
            protein: 24.0,
            fat: 12.0,
            carbs: 26.0,
            category: .restaurant,
            tags: ["High-Protein", "Low-Calorie", "Antioxidants"],
            description: "Antioxidant-rich salad with lean protein.",
            ingredients: ["Spinach", "Mixed berries", "Grilled chicken", "Walnuts", "Balsamic"],
            instructions: ["Wash spinach", "Grill chicken", "Prepare berries", "Make dressing", "Toss salad"]
        ),
        Recipe(
            id: "13",
            title: "Turkey Pasta with Marinara",
            imageName: "turkey-pasta-marinara",
            prepTime: "25 min",
            calories: 480,
            protein: 32.0,
            fat: 14.0,
            carbs: 52.0,
            category: .mealPrep,
            tags: ["High-Protein", "Balanced", "Family-Friendly"],
            description: "Family-friendly meal with lean ground turkey.",
            ingredients: ["Ground turkey", "Whole wheat pasta", "Marinara sauce", "Onion", "Garlic"],
            instructions: ["Cook pasta", "Brown turkey", "Add sauce", "Simmer", "Serve over pasta"]
        ),
        Recipe(
            id: "14",
            title: "Protein Smoothie Bowl",
            imageName: "protein-smoothie-bowl",
            prepTime: "8 min",
            calories: 320,
            protein: 22.0,
            fat: 10.0,
            carbs: 38.0,
            category: .quickMeals,
            tags: ["High-Protein", "Breakfast", "Refreshing"],
            description: "Refreshing breakfast bowl packed with protein.",
            ingredients: ["Protein powder", "Banana", "Berries", "Almond milk", "Granola"],
            instructions: ["Blend smoothie", "Pour in bowl", "Add toppings", "Serve immediately"]
        ),
        Recipe(
            id: "15",
            title: "Grilled Shrimp Skewers",
            imageName: "grilled-shrimp-skewers",
            prepTime: "20 min",
            calories: 285,
            protein: 32.0,
            fat: 8.0,
            carbs: 22.0,
            category: .restaurant,
            tags: ["High-Protein", "Low-Calorie", "Pescatarian"],
            description: "Light and flavorful seafood with minimal calories.",
            ingredients: ["Shrimp", "Bell peppers", "Onion", "Olive oil", "Lemon"],
            instructions: ["Skewer shrimp", "Marinate", "Grill 3-4 min", "Flip", "Serve"]
        ),
        Recipe(
            id: "16",
            title: "Veggie Burger",
            imageName: "veggie-burger",
            prepTime: "15 min",
            calories: 380,
            protein: 18.0,
            fat: 16.0,
            carbs: 42.0,
            category: .restaurant,
            tags: ["Vegetarian", "Balanced", "Plant-Based"],
            description: "Satisfying plant-based burger with all the fixings.",
            ingredients: ["Veggie patty", "Whole grain bun", "Avocado", "Lettuce", "Tomato"],
            instructions: ["Cook patty", "Toast bun", "Slice vegetables", "Assemble burger", "Serve"]
        ),
        Recipe(
            id: "17",
            title: "Overnight Oats",
            imageName: "overnight-oats",
            prepTime: "5 min prep + overnight",
            calories: 310,
            protein: 14.0,
            fat: 10.0,
            carbs: 42.0,
            category: .mealPrep,
            tags: ["Breakfast", "Quick Meals", "Make-Ahead"],
            description: "Convenient make-ahead breakfast with fiber.",
            ingredients: ["Rolled oats", "Greek yogurt", "Milk", "Chia seeds", "Berries"],
            instructions: ["Mix ingredients", "Refrigerate overnight", "Top with berries", "Serve cold"]
        ),
        Recipe(
            id: "18",
            title: "Tuna Poke Bowl",
            imageName: "tuna-poke-bowl",
            prepTime: "15 min",
            calories: 395,
            protein: 36.0,
            fat: 14.0,
            carbs: 32.0,
            category: .restaurant,
            tags: ["High-Protein", "Pescatarian", "Fresh"],
            description: "Fresh Hawaiian-inspired bowl with raw fish.",
            ingredients: ["Fresh tuna", "Rice", "Cucumber", "Avocado", "Soy sauce"],
            instructions: ["Cut tuna", "Cook rice", "Slice vegetables", "Arrange bowl", "Drizzle sauce"]
        ),
        Recipe(
            id: "19",
            title: "Black Bean Tacos",
            imageName: "black-bean-tacos",
            prepTime: "18 min",
            calories: 340,
            protein: 16.0,
            fat: 12.0,
            carbs: 42.0,
            category: .quickMeals,
            tags: ["Vegetarian", "Balanced", "Mexican"],
            description: "Protein-rich vegetarian tacos with bold flavors.",
            ingredients: ["Black beans", "Corn tortillas", "Avocado", "Salsa", "Cilantro"],
            instructions: ["Heat beans", "Warm tortillas", "Mash avocado", "Assemble tacos", "Garnish"]
        ),
        Recipe(
            id: "20",
            title: "Grilled Tilapia with Asparagus",
            imageName: "grilled-tilapia-asparagus",
            prepTime: "22 min",
            calories: 295,
            protein: 34.0,
            fat: 9.0,
            carbs: 20.0,
            category: .mealPrep,
            tags: ["High-Protein", "Low-Calorie", "Pescatarian"],
            description: "Light and flaky fish with crisp asparagus.",
            ingredients: ["Tilapia fillet", "Asparagus", "Lemon", "Olive oil", "Herbs"],
            instructions: ["Season fish", "Trim asparagus", "Grill fish", "Grill asparagus", "Serve"]
        )
    ]
    
    var filteredRecipes: [Recipe] {
        let searchFiltered = searchQuery.isEmpty ? recipes : recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(searchQuery) ||
            recipe.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
        
        if let selectedFilter = selectedFilter {
            return searchFiltered.filter { $0.category == selectedFilter }
        }
        
        return searchFiltered
    }
    
    // MARK: - Navigation Bar
    private var universalNavigationBar: some View {
        UniversalNavigationBar(
            onHome: { showHome = true },
            onRecipes: { /* Already on recipes screen */ },
            onCamera: { showAICamera = true },
            onStats: { showStats = true },
            onProfile: { showProfile = true },
            currentScreen: .recipes
        )
    }
    
    // MARK: - Logging Functions
    private func logMeal(_ recipe: Recipe) {
        let foodItem = recipe.toFoodItem()
        let loggedFood = LoggedFood(food: foodItem, portion: 1.0, timestamp: Date())
        // Use nutrition.add() so the calorie/macro totals get recomputed
        // AND the meal gets persisted to UserDefaults. Direct append to
        // loggedFoods would bypass both.
        nutrition.add(loggedFood)
        
        // Trigger feeding animation callback if available
        onFoodLogged?(loggedFood)
        
        // If we're in a full screen (called from HomeScreen), dismiss the full screen
        // If we're in onboarding flow, navigate to Home Screen
        if currentScreen >= 6 {
            dismiss() // Dismiss the full screen
        } else {
            withAnimation(.easeInOut) {
                currentScreen = 6 // Home Screen
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            NavigationView {
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#34d399"),
                            Color(hex: "#14b8a6"),
                            Color(hex: "#06b6d4")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 16) {
                                HStack {
                                    Button {
                                        if currentScreen >= 6 {
                                            dismiss() // Dismiss full screen when called from HomeScreen
                                        } else {
                                            withAnimation { currentScreen -= 1 }
                                        }
                                    } label: {
                                        Image(systemName: "arrow.left")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Today's Picks for You")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Placeholder for symmetry
                                    Color.clear
                                        .frame(width: 24, height: 24)
                                }
                                
                                // Search Bar
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    
                                    TextField("Search recipes...", text: $searchQuery)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(25)
                            }
                            .padding(.horizontal)
                            
                            // Filter Buttons
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    FilterButton(
                                        title: "All",
                                        isSelected: selectedFilter == nil,
                                        action: { selectedFilter = nil }
                                    )
                                    
                                    ForEach(RecipeCategory.allCases, id: \.self) { category in
                                        FilterButton(
                                            title: category.displayName,
                                            isSelected: selectedFilter == category,
                                            action: { selectedFilter = category }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Recipe Cards
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRecipes) { recipe in
                                    RecipeCard(recipe: recipe, onLogMeal: { logMeal(recipe) }) {
                                        selectedRecipe = recipe
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer().frame(height: 100) // room for bottom bar
                        }
                    }
                }
            }
            
            // Bottom Navigation Bar
            universalNavigationBar
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe, currentScreen: $currentScreen, loggedFoods: $loggedFoods, onLogMeal: { logMeal(recipe) })
        }
        // Navigation sheets
        .fullScreenCover(isPresented: $showHome) {
            // Navigate back to Home Screen with the shared nutrition state
            if let userData = userData {
                HomeScreen(userData: userData, nutrition: nutrition)
            } else {
                Text("Home navigation requires user data")
                    .foregroundColor(.gray)
            }
        }
        .fullScreenCover(isPresented: $showStats) {
            // Navigate to Stats Screen with the shared nutrition state
            if let userData = userData {
                StatsScreen(userData: userData, nutrition: nutrition)
            } else {
                Text("Stats functionality requires user data")
            }
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
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2)
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Recipe Card
struct RecipeCard: View {
    let recipe: Recipe
    let onLogMeal: () -> Void
    let onTap: () -> Void
    
    private var imageOverlay: some View {
        Group {
            if UIImage(named: recipe.imageName) == nil {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                            Text(recipe.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    )
            }
        }
    }
    
    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recipe.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Prep time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(recipe.prepTime)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                
                // Calories badge
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 10))
                    Text("\(recipe.calories) cal")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Recipe Image
                Image(recipe.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .overlay(imageOverlay)
                
                // Recipe Content
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    // Tags
                    tagsView
                    
                    // Nutrition Info
                    Text("Nutrition: \(Int(recipe.protein))g protein, \(Int(recipe.fat))g fat, \(Int(recipe.carbs))g carbs")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Log Button - Same style as FoodLoggerView
                    Button {
                        onLogMeal()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log This Meal")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.cyan)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Recipe Detail View
struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Binding var currentScreen: Int
    @Binding var loggedFoods: [LoggedFood]
    let onLogMeal: () -> Void
    
    private var imageOverlay: some View {
        Group {
            if UIImage(named: recipe.imageName) == nil {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text(recipe.title)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    )
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe Image
                    Image(recipe.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                        .overlay(imageOverlay)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(recipe.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(recipe.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Nutrition Facts
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nutrition Facts")
                                .font(.headline)
                            
                            HStack {
                                NutritionFact(label: "Calories", value: "\(recipe.calories)")
                                Spacer()
                                NutritionFact(label: "Protein", value: "\(Int(recipe.protein))g")
                            }
                            
                            HStack {
                                NutritionFact(label: "Fat", value: "\(Int(recipe.fat))g")
                                Spacer()
                                NutritionFact(label: "Carbs", value: "\(Int(recipe.carbs))g")
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients")
                                .font(.headline)
                            
                            ForEach(recipe.ingredients, id: \.self) { ingredient in
                                HStack {
                                    Text("•")
                                    Text(ingredient)
                                    Spacer()
                                }
                            }
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                            
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                    Text(instruction)
                                    Spacer()
                                }
                            }
                        }
                        
                        // Log Meal Button - Same style as FoodLoggerView
                        Button {
                            onLogMeal()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Log This Meal")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.cyan)
                            .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Nutrition Fact
struct NutritionFact: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    RecipesView(
        currentScreen: .constant(7), 
        loggedFoods: .constant([]),
        onFoodLogged: { _ in },
        userData: UserData(name: "Preview User", email: "preview@example.com")
    )
}
