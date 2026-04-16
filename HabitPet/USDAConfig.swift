//
//  USDAConfig.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//

import Foundation

/// Configuration for USDA FoodData Central API
struct USDAConfig {
    
    // MARK: - API Configuration
    
    /// Your USDA FoodData Central API key from data.gov
    /// To get an API key:
    /// 1. Visit https://api.data.gov/signup/
    /// 2. Sign up for a free account
    /// 3. Use your API key here
    static let apiKey = "n3AiWycITdyVaTdXZhQZOKC1IPa25vaWmhWvqBFY"
    
    /// Base URL for USDA FoodData Central API
    static let baseURL = "https://api.nal.usda.gov/fdc/v1"
    
    // MARK: - Search Configuration
    
    /// Default page size for search results (max: 200)
    static let defaultPageSize = 25
    
    /// Maximum page size allowed by API
    static let maxPageSize = 200
    
    /// Search debounce delay in milliseconds
    static let searchDebounceDelay: Int = 500
    
    /// Cache expiration time in seconds
    static let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    // MARK: - Data Type Preferences
    
    /// Preferred data types in order of preference
    static let preferredDataTypes = [
        "Foundation",    // Lab-quality nutrient data
        "SR Legacy",     // USDA's legacy nutrient database
        "Branded"        // Branded food products
    ]
    
    // MARK: - Nutrient IDs
    
    /// Common nutrient IDs in USDA FoodData Central
    struct NutrientIDs {
        static let energy = 1008          // Energy (kcal)
        static let protein = 1003         // Protein
        static let carbohydrates = 1005   // Carbohydrate, by difference
        static let totalLipid = 1004      // Total lipid (fat)
        static let fiber = 1079           // Fiber, total dietary
        static let sugars = 2000          // Sugars, total including NLEA
        static let sodium = 1093          // Sodium, Na
        static let calcium = 1087         // Calcium, Ca
        static let iron = 1089            // Iron, Fe
        static let vitaminC = 1162        // Vitamin C, total ascorbic acid
        static let vitaminA = 1106        // Vitamin A, RAE
        static let saturatedFat = 1258    // Fatty acids, total saturated
        static let monounsaturatedFat = 1292  // Fatty acids, total monounsaturated
        static let polyunsaturatedFat = 1293  // Fatty acids, total polyunsaturated
        static let cholesterol = 1253     // Cholesterol
    }
    
    // MARK: - Error Messages
    
    struct ErrorMessages {
        static let apiKeyRequired = "USDA API key is required. Please obtain one from data.gov"
        static let networkError = "Network error occurred. Please check your internet connection."
        static let noResults = "No foods found matching your search."
        static let rateLimitExceeded = "Rate limit exceeded. Please try again later."
        static let invalidResponse = "Invalid response from USDA API."
        static let decodingError = "Failed to decode USDA API response."
    }
    
    // MARK: - Cache Keys
    
    struct CacheKeys {
        static let searchResults = "usda_search_results"
        static let foodDetails = "usda_food_details"
        static let popularFoods = "usda_popular_foods"
    }
    
    // MARK: - Validation
    
    /// Check if API key is configured (not demo key)
    static var isApiKeyConfigured: Bool {
        return apiKey != "DEMO_KEY" && !apiKey.isEmpty
    }
    
    /// Get API key with fallback message
    static var apiKeyOrFallback: String {
        return isApiKeyConfigured ? apiKey : "DEMO_KEY"
    }
}

// MARK: - USDA API Endpoints

extension USDAConfig {
    
    /// Search foods endpoint
    static var searchFoodsURL: String {
        return "\(baseURL)/foods/search"
    }
    
    /// Get food details endpoint
    static func foodDetailsURL(fdcId: Int) -> String {
        return "\(baseURL)/food/\(fdcId)"
    }
    
    /// Get multiple food details endpoint
    static var multipleFoodDetailsURL: String {
        return "\(baseURL)/foods"
    }
    
    /// Get food list endpoint (for pagination)
    static var foodListURL: String {
        return "\(baseURL)/foods/list"
    }
}

// MARK: - Helper Methods

extension USDAConfig {
    
    /// Build query parameters for search request
    static func buildSearchQueryParameters(
        query: String,
        pageSize: Int = defaultPageSize,
        pageNumber: Int = 1,
        dataType: String? = nil,
        sortBy: String = "lowercaseDescription.keyword",
        sortOrder: String = "asc"
    ) -> [String: String] {
        
        var parameters: [String: String] = [
            "api_key": apiKeyOrFallback,
            "query": query,
            "pageSize": String(min(pageSize, maxPageSize)),
            "pageNumber": String(pageNumber),
            "sortBy": sortBy,
            "sortOrder": sortOrder
        ]
        
        if let dataType = dataType {
            parameters["dataType"] = dataType
        }
        
        return parameters
    }
    
    /// Get nutrient name by ID
    static func nutrientName(for id: Int) -> String {
        switch id {
        case NutrientIDs.energy: return "Energy"
        case NutrientIDs.protein: return "Protein"
        case NutrientIDs.carbohydrates: return "Carbohydrates"
        case NutrientIDs.totalLipid: return "Total Fat"
        case NutrientIDs.fiber: return "Fiber"
        case NutrientIDs.sugars: return "Sugars"
        case NutrientIDs.sodium: return "Sodium"
        case NutrientIDs.calcium: return "Calcium"
        case NutrientIDs.iron: return "Iron"
        case NutrientIDs.vitaminC: return "Vitamin C"
        case NutrientIDs.vitaminA: return "Vitamin A"
        case NutrientIDs.saturatedFat: return "Saturated Fat"
        case NutrientIDs.monounsaturatedFat: return "Monounsaturated Fat"
        case NutrientIDs.polyunsaturatedFat: return "Polyunsaturated Fat"
        case NutrientIDs.cholesterol: return "Cholesterol"
        default: return "Unknown"
        }
    }
    
    /// Get nutrient unit by ID
    static func nutrientUnit(for id: Int) -> String {
        switch id {
        case NutrientIDs.energy: return "kcal"
        case NutrientIDs.protein, NutrientIDs.carbohydrates, NutrientIDs.totalLipid,
             NutrientIDs.fiber, NutrientIDs.sugars: return "g"
        case NutrientIDs.sodium, NutrientIDs.calcium, NutrientIDs.iron: return "mg"
        case NutrientIDs.vitaminC, NutrientIDs.vitaminA: return "mg"
        case NutrientIDs.saturatedFat, NutrientIDs.monounsaturatedFat,
             NutrientIDs.polyunsaturatedFat, NutrientIDs.cholesterol: return "g"
        default: return ""
        }
    }
}

