//
//  USDAFoodModels.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//  Updated: resilient models for both /foods/search and /food/{fdcId}
//

import Foundation

// MARK: - Search response

struct USDASearchResponse: Codable {
    let totalHits: Int
    let currentPage: Int
    let totalPages: Int
    let foods: [USDAFood]
}

// MARK: - Category can be String (search) or object (details)

enum FoodCategoryValue: Codable {
    case string(String)
    case object(FoodCategory)

    var descriptionText: String {
        switch self {
        case .string(let s): return s
        case .object(let o): return o.description
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            self = .object(try c.decode(FoodCategory.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .object(let o):
            try o.encode(to: encoder)
        }
    }
}

// MARK: - USDAFood (works for both search & details)

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String

    // Common optional metadata
    let dataType: String?
    let gtinUpc: String?
    let publishedDate: String?
    let brandOwner: String?
    let brandName: String?
    let ingredients: String?
    let marketCountry: String?
    let foodCategory: FoodCategoryValue?   // ← resilient
    let modifiedDate: String?
    let dataSource: String?
    let packageWeight: String?
    let servingSizeUnit: String?
    let servingSize: Double?
    let householdServingFullText: String?
    let tradeChannels: [String]?
    let allHighlightFields: String?
    let score: Double?

    // Collections (present in either response type)
    let microbes: [Microbe]?
    let foodNutrients: [FoodNutrient]?     // ← resilient
    let finalFoodInputFoods: [FinalFoodInputFood]?
    let foodMeasures: [FoodMeasure]?
    let foodAttributes: [FoodAttribute]?
    let foodAttributeTypes: [FoodAttributeType]?
    let foodVersionIds: [Int]?
    let foodComponents: [FoodComponent]?
    let footnote: String?
    let foodClass: String?
    let foodCode: String?
    let foodDescription: String?
    let foodId: Int?
    let foodName: String?
    let foodStatus: String?
    let foodType: String?
    let foodUrl: String?
    let publicationDate: String?
    let scientificName: String?
    @FlexibleString var ndbNumber: String?
    let additionalDescriptions: String?
    let foodUpdateLog: [FoodUpdateLog]?
    let inputFoods: [InputFood]?
    let labels: [Label]?
    let langualFactors: [LangualFactor]?
    let nutrientConversionFactors: [NutrientConversionFactor]?
    let nutrientDataSources: [NutrientDataSource]?
    let sampleFoods: [SampleFood]?
    let subSampleFoods: [SubSampleFood]?
    let tableAliasNames: [TableAliasName]?
    let wweiaFoodCategory: WWEIAFoodCategory?

    var id: Int { fdcId }

    // Convert to your app's FoodItem (assumes your FoodItem has `usdaFood: USDAFood?`)
    func toFoodItem() -> FoodItem {
        let n = extractNutrients()
        return FoodItem(
            id: fdcId,
            name: description,
            calories: Int(n.calories.rounded()),
            protein: n.protein,
            carbs: n.carbohydrates,
            fats: n.fats,
            category: foodCategory?.descriptionText ?? "Unknown",
            usdaFood: self
        )
    }

    /// Extract (kcal, g) from either the search or details nutrient shape.
    private func extractNutrients() -> (calories: Double, protein: Double, carbohydrates: Double, fats: Double) {
        guard let nutrients = foodNutrients else { return (0,0,0,0) }

        var energy: [Int: Double] = [:]
        var protein: Double = 0
        var carbs: Double = 0
        var fats: Double = 0

        for n in nutrients {
            // Prefer nested nutrient.id; fall back to nutrientId (search)
            let nutrientId = n.nutrient?.id ?? n.nutrientId
            guard let id = nutrientId else { continue }

            // Prefer amount (details); fall back to value (search)
            let rawAmount = n.amount ?? n.value ?? 0
            let amount = rawAmount.isFinite ? max(0, rawAmount) : 0

            switch id {
            case 1008, 2047, 2048:                    energy[id] = amount
            case USDAConfig.NutrientIDs.protein:       protein  = amount
            case USDAConfig.NutrientIDs.carbohydrates: carbs    = amount
            case USDAConfig.NutrientIDs.totalLipid:    fats     = amount
            default: break
            }
        }
        return (energy[2048] ?? energy[1008] ?? energy[2047] ?? 0, protein, carbs, fats)
    }
}

// MARK: - Resilient nutrient item

struct FoodNutrient: Codable {
    // Details shape
    let id: Int?
    let amount: Double?
    let nutrient: Nutrient?
    let foodNutrientDerivation: FoodNutrientDerivation?
    let foodNutrientSource: FoodNutrientSource?
    let dataPoints: Int?
    let min: Double?
    let max: Double?
    let median: Double?
    let type: String?
    let foodNutrientSourceId: Int?
    let plStudyId: Int?
    let retentionFactor: RetentionFactor?
    let subSampleId: Int?

    // Search shape
    let nutrientId: Int?
    let nutrientName: String?
    let unitName: String?
    let value: Double?
}

// MARK: - Supporting structures (unchanged from your file)

struct FoodCategory: Codable {
    let id: Int
    let code: String
    let description: String
}

struct Microbe: Codable {
    let id: Int
    let name: String
    let rank: String
    let taxId: String
    let nameLong: String
}

struct Nutrient: Codable {
    let id: Int
    let number: String
    let name: String
    let rank: Int
    let unitName: String
    let unitSymbol: String?
    let unitConversionFactor: Double?
    let nutrientClass: NutrientClass?
    let nutrientRank: Int?
    let lastUpdated: String?
}

struct NutrientClass: Codable {
    let id: Int
    let code: String
    let description: String
}

struct FoodNutrientDerivation: Codable {
    let id: Int
    let code: String
    let description: String
    let foodNutrientSource: FoodNutrientSource?
}

struct FoodNutrientSource: Codable {
    let id: Int
    let code: String
    let description: String
    let lastUpdated: String?
}

struct RetentionFactor: Codable {
    let id: Int
    let code: String
    let description: String
}

struct FinalFoodInputFood: Codable {
    let id: Int
    let amount: Double?
    let foodDescription: String?
    let ingredientCode: String?
    let ingredientDescription: String?
    let ingredientWeight: Double?
    let portionCode: String?
    let portionDescription: String?
    let unit: String?
    let portionAmount: Double?
    let modifier: String?
    let foodId: Int?
    let ingredientCodeId: Int?
    let unitId: Int?
    let portionCodeId: Int?
    let inputFood: InputFood?
}

struct InputFood: Codable {
    let id: Int
    let foodDescription: String
    let ingredientCode: String?
    let ingredientDescription: String?
    let ingredientWeight: Double?
    let portionCode: String?
    let portionDescription: String?
    let unit: String?
    let portionAmount: Double?
    let modifier: String?
    let foodId: Int?
    let ingredientCodeId: Int?
    let unitId: Int?
    let portionCodeId: Int?
}

struct FoodMeasure: Codable {
    let disseminationText: String?
    let gramWeight: Double?
    let id: Int
    let modifier: String?
    let rank: Int?
    let measureUnitAbbreviation: String?
    let measureUnitName: String?
    let measureUnitId: Int?
}

struct FoodAttribute: Codable {
    let id: Int
    let seqNum: Int?
    let value: String?
    let foodAttributeType: FoodAttributeType?
}

struct FoodAttributeType: Codable {
    let id: Int
    let name: String
    let description: String
}

struct FoodComponent: Codable {
    let id: Int
    let name: String
    let dataPoints: Int?
    let gramWeight: Double?
    let isRefuse: Bool?
    let minYearAcquired: Int?
    let percentWeight: Double?
    let refuseYear: Int?
}

struct FoodUpdateLog: Codable {
    let fdcId: Int
    let availableDate: String
    let brandDescription: String?
    let dataSource: String?
    let dataType: String?
    let description: String?
    let foodClass: String?
    let gtinUpc: String?
    let householdServingFullText: String?
    let ingredients: String?
    let modifiedDate: String?
    let publicationDate: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let brandedFoodCategory: String?
    let changes: String?
    let foodAttributes: [FoodAttribute]?
}

struct Label: Codable {
    let id: Int
    let name: String
    let abbreviation: String?
    let description: String?
    let isRequired: Bool?
    let isVisible: Bool?
    let nutrient: Nutrient?
    let nutrientId: Int?
}

struct LangualFactor: Codable {
    let id: Int
    let description: String
    let code: String
}

struct NutrientConversionFactor: Codable {
    let id: Int
    let type: String?
    let value: Double?
    let nutrient: Nutrient?
    let foodNutrient: FoodNutrient?
}

struct NutrientDataSource: Codable {
    let id: Int
    let title: String
    let authors: String?
    let volume: String?
    let issue: String?
    let publicationDate: String?
    let informationSource: String?
    let pageNumbers: String?
    let url: String?
    let doi: String?
    let publisher: String?
    let accessionNumber: String?
    let citation: String?
}

struct SampleFood: Codable {
    let id: Int
    let description: String
    let dataSource: String?
    let dataType: String?
    let publicationDate: String?
    let foodClass: String?
    let foodCode: String?
    let foodDescription: String?
    let foodId: Int?
    let foodName: String?
    let foodStatus: String?
    let foodType: String?
    let foodUrl: String?
    let scientificName: String?
    @FlexibleString var ndbNumber: String?
    let additionalDescriptions: String?
}

struct SubSampleFood: Codable {
    let id: Int
    let description: String
    let dataSource: String?
    let dataType: String?
    let publicationDate: String?
    let foodClass: String?
    let foodCode: String?
    let foodDescription: String?
    let foodId: Int?
    let foodName: String?
    let foodStatus: String?
    let foodType: String?
    let foodUrl: String?
    let scientificName: String?
    @FlexibleString var ndbNumber: String?
    let additionalDescriptions: String?
}

struct TableAliasName: Codable {
    let id: Int
    let tableAliasName: String
}

struct WWEIAFoodCategory: Codable {
    let wweiaFoodCategoryCode: Int
    let wweiaFoodCategoryDescription: String
}

// USDA identifiers may be JSON numbers in Foundation responses and strings in
// legacy responses. Preserve one representation in saved food logs.
@propertyWrapper
struct FlexibleString: Codable {
    var wrappedValue: String?
    init(wrappedValue: String? = nil) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { wrappedValue = nil }
        else if let value = try? c.decode(String.self) { wrappedValue = value }
        else { wrappedValue = String(try c.decode(Int.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}
extension KeyedDecodingContainer {
    func decode(_ type: FlexibleString.Type, forKey key: Key) throws -> FlexibleString {
        try decodeIfPresent(type, forKey: key) ?? FlexibleString()
    }
}
