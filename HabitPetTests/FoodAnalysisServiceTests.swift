import XCTest
@testable import HabitPet

final class FoodAnalysisServiceTests: XCTestCase {
    func testPictureTotalsArePreservedForAllItems() throws {
        let data = Data(#"{"items":[{"label":"Apple","confidence":0.9,"calories":78,"totalMacros":{"proteinG":0.4,"carbsG":20.7,"fatG":0.3}},{"label":"Yogurt","confidence":0.9,"calories":100,"totalMacros":{"proteinG":10,"carbsG":8,"fatG":2}}]}"#.utf8)
        let result = try FoodAnalysisService.decode(data)
        XCTAssertEqual(result.cFused, 178)
        XCTAssertEqual(result.protein, 10.4)
        XCTAssertEqual(result.label, "Apple, Yogurt")
    }
    func testLowConfidenceEmptyAndNegativeResponsesAreRejected() {
        for json in [#"{"items":[]}"#, #"{"items":[{"label":"Food","confidence":0.1,"calories":200}]}"#, #"{"items":[{"label":"Food","confidence":0.9,"calories":-1}]}"#] {
            XCTAssertThrowsError(try FoodAnalysisService.decode(Data(json.utf8)))
        }
    }
}
