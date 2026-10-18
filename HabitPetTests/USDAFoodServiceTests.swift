import XCTest
import Combine
#if SWIFT_PACKAGE
@testable import ForkiCore
#else
@testable import HabitPet
#endif

final class USDAFoodServiceTests: XCTestCase {
    func decode(_ json: String) throws -> USDAFood { try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8)) }
    func testAccountRoutesUseExactlyOneSlash() throws {
        let config = BackendConfiguration(functionsURL: URL(string: "https://project.invalid/functions/v1")!, publicKey: "public")
        XCTAssertEqual(try config.accountURL(path: "auth/v1/token?grant_type=password").absoluteString, "https://project.invalid/auth/v1/token?grant_type=password")
        XCTAssertEqual(try config.accountURL(path: "rest/v1/forki_backups?select=*").path, "/rest/v1/forki_backups")
    }
    func testFoundationNumericIdentifierAndAtwaterEnergy() throws {
        let food = try decode(#"{"fdcId":1,"description":"Fuji apple","ndbNumber":9504,"foodNutrients":[{"nutrientId":2047,"value":64.7},{"nutrientId":2048,"value":58.2},{"nutrientId":1003,"value":0.2}]}"#)
        XCTAssertEqual(food.ndbNumber, "9504")
        XCTAssertEqual(food.toFoodItem().calories, 58)
        XCTAssertEqual(food.toFoodItem().protein, 0.2)
        let saved = try JSONEncoder().encode(food)
        XCTAssertEqual(try JSONDecoder().decode(USDAFood.self, from: saved).ndbNumber, "9504")
    }
    func testLegacyEnergyAndOptionalIdentifier() throws {
        let food = try decode(#"{"fdcId":2,"description":"Apple","foodCategory":"Fruit","foodNutrients":[{"nutrientId":1008,"value":52}]}"#)
        XCTAssertNil(food.ndbNumber)
        XCTAssertEqual(food.toFoodItem().calories, 52)
        XCTAssertEqual(food.toFoodItem().category, "Fruit")
    }
    func testNestedNutrientsAndStringIdentifier() throws {
        let food = try decode(#"{"fdcId":3,"description":"Food","ndbNumber":"123","foodNutrients":[{"amount":125,"nutrient":{"id":1008,"number":"208","name":"Energy","rank":100,"unitName":"kcal"}}]}"#)
        XCTAssertEqual(food.toFoodItem().calories, 125)
    }
    func testSearchUsesRelevanceAndBoundsPagination() {
        let params = USDAConfig.buildSearchQueryParameters(query: "apple", pageSize: 999)
        XCTAssertNil(params["sortBy"])
        XCTAssertEqual(params["pageSize"], "200")
        XCTAssertNil(params["api_key"])
    }
    func testEmptySearchFailsWithoutNetwork() {
        let done = expectation(description: "validation")
        let token = USDAFoodService().searchFoods(query: "  ").sink(receiveCompletion: { completion in
            if case .failure = completion { done.fulfill() }
        }, receiveValue: { _ in XCTFail("Empty query must fail") })
        wait(for: [done], timeout: 1); token.cancel()
    }
    func testBuiltInFoodsAvailableOffline() {
        let foods = USDAFoodService().getMockFoods()
        XCTAssertEqual(foods.count, 11)
        XCTAssertEqual(foods.first(where: { $0.name.contains("Apple") })?.calories, 52)
    }
}
