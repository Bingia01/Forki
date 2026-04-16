//
//  Models.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import Foundation
import CoreGraphics

// `Codable` so the profile can be serialized to UserDefaults between launches.
// All existing fields are already Codable-compatible (String, Int, Bool,
// [String], CGFloat, and CharacterType which is a String-backed enum), so
// Swift synthesizes the conformance for us with no custom logic required.
struct UserData: Codable {
    var name: String = ""
    var email: String = ""
    var age: String = ""
    var gender: String = ""          // added
    var height: String = ""
    var weight: String = ""
    var goal: String = ""
    var goalDuration: Int = 0
    var foodPreferences: [String] = []
    var notifications: Bool = false
    var selectedCharacter: CharacterType = .avatar

    // live-updating scales
    var heightScale: CGFloat = 1.0
    var weightScale: CGFloat = 1.0
}

// `Codable` so food items can be persisted as part of LoggedFood.
// All fields are already Codable: Int, String, Double, and USDAFood?
// (USDAFood conforms to Codable in USDAFoodModels.swift).
struct FoodItem: Identifiable, Equatable, Codable {
    let id: Int
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fats: Double
    let category: String
    let usdaFood: USDAFood?

    init(
        id: Int,
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fats: Double,
        category: String,
        usdaFood: USDAFood? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.category = category
        self.usdaFood = usdaFood
    }

    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// `Codable` so logged meals can be persisted to UserDefaults.
// Note: the original `let id = UUID()` generated a new UUID every time
// Swift decoded the struct from JSON (because the auto-init fires during
// decode). Changing to `let id: UUID` with a default in the explicit init
// preserves the existing call sites (they don't pass `id`) while letting
// the Codable decoder populate `id` from the saved JSON.
struct LoggedFood: Identifiable, Codable {
    let id: UUID
    let food: FoodItem
    let portion: Double
    let timestamp: Date

    init(food: FoodItem, portion: Double, timestamp: Date, id: UUID = UUID()) {
        self.id = id
        self.food = food
        self.portion = portion
        self.timestamp = timestamp
    }
}

enum AvatarState: String {
    case happy, neutral, sad, strong, overweight
}

// MARK: - Recipe Models
struct Recipe: Identifiable, Equatable {
    let id: String
    let title: String
    let imageName: String
    let prepTime: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let category: RecipeCategory
    let tags: [String]
    let description: String
    let ingredients: [String]
    let instructions: [String]
}

enum RecipeCategory: String, CaseIterable {
    case mealPrep = "Meal Prep"
    case grocery = "Grocery"
    case restaurant = "Restaurant/Dining"
    case quickMeals = "Quick Meals"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Recipe Extension for Food Logging
extension Recipe {
    func toFoodItem() -> FoodItem {
        return FoodItem(
            id: Int(id) ?? 0,
            name: title,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fat,
            category: "Recipe"
        )
    }
}

// MARK: - Character Types
enum CharacterType: String, CaseIterable, Identifiable, Codable {
    case avoFriend = "Avo Friend"
    case bobaBuddy = "Boba Buddy"
    case berrySweet = "Berry Sweet"
    case squirtle = "Squirtle"
    case avatar = "HabitPet"
    case mochiMouse = "Mochi Mouse"
    
    var id: String { self.rawValue }
    
    var modelName: String {
        return self.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .avoFriend:
            return "A nutritious companion who loves healthy fats and green goodness"
        case .bobaBuddy:
            return "A sweet and bubbly friend who brings joy to your wellness journey"
        case .berrySweet:
            return "A delightful companion packed with antioxidants and natural sweetness"
        case .squirtle:
            return "A water-type Pokémon known for its friendly nature"
        case .avatar:
            return "A balanced companion for your health journey"
        case .mochiMouse:
            return "A soft and sweet companion who makes healthy eating fun"
        }
    }
    
    var emoji: String {
        switch self {
        case .avoFriend: return "🥑"
        case .bobaBuddy: return "🧋"
        case .berrySweet: return "🍓"
        case .squirtle: return "🐢"
        case .avatar: return "👤"
        case .mochiMouse: return "🐭"
        }
    }
    
    var imageName: String {
        switch self {
        case .avoFriend: return "avocado"
        case .bobaBuddy: return "boba"
        case .berrySweet: return "strawberry"
        case .squirtle: return "squirtle"
        case .avatar: return "habitpet"
        case .mochiMouse: return "MochiMouse"
        }
    }
}

