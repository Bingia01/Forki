import Foundation

enum FoodAnalysisError: LocalizedError {
    case configuration, invalidResult, unavailable
    var errorDescription: String? {
        switch self {
        case .configuration: return "Food analysis is not configured. Please use manual food logging."
        case .invalidResult: return "Food could not be identified reliably. Try a clearer photo or log it manually."
        case .unavailable: return "Food analysis is unavailable. Try again later or log your food manually."
        }
    }
}

struct FoodAnalysisService {
    var session: URLSession = .shared
    func analyze(_ image: Data) async throws -> AICameraNutritionResult {
        let config = try BackendConfiguration()
        var request = URLRequest(url: config.functionsURL.appendingPathComponent("analyze_food"))
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.publicKey, forHTTPHeaderField: "apikey")
        let token = try await AccountService.shared.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["imageBase64": image.base64EncodedString(), "mimeType": "image/jpeg"])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FoodAnalysisError.unavailable
        }
        return try Self.decode(data)
    }
    static func decode(_ data: Data) throws -> AICameraNutritionResult {
        struct Macros: Decodable { let proteinG: Double; let carbsG: Double; let fatG: Double }
        struct Item: Decodable {
            let label: String; let confidence: Double; let calories: Double
            let sigmaCalories: Double?; let totalMacros: Macros?
        }
        struct Payload: Decodable { let items: [Item] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data), !payload.items.isEmpty,
              payload.items.allSatisfy({ !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (0.3...1).contains($0.confidence) && (0...10000).contains($0.calories) }) else {
            throw FoodAnalysisError.invalidResult
        }
        let items = payload.items
        let macrosKnown = items.allSatisfy { $0.totalMacros != nil }
        guard macrosKnown else { throw FoodAnalysisError.invalidResult }
        func sum(_ f: (Macros) -> Double) throws -> Double? {
            guard macrosKnown else { return nil }
            let values = items.compactMap(\.totalMacros).map(f)
            guard values.allSatisfy({ $0.isFinite && (0...2000).contains($0) }) else { throw FoodAnalysisError.invalidResult }
            return values.reduce(0, +)
        }
        let calories = items.reduce(0) { $0 + $1.calories }
        guard calories <= 10000 else { throw FoodAnalysisError.invalidResult }
        return try AICameraNutritionResult(label: items.map(\.label).joined(separator: ", "), confidence: items.map(\.confidence).min() ?? 0,
            volumeML: 0, sigmaV: 0, rho: 0, sigmaRho: 0, e: 0, sigmaE: 0,
            cFused: calories, sigmaCFused: items.reduce(0) { $0 + max(0, $1.sigmaCalories ?? 0) },
            protein: sum { $0.proteinG }, carbs: sum { $0.carbsG }, fats: sum { $0.fatG })
    }
}
