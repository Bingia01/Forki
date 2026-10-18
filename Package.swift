// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ForkiCore",
    platforms: [.macOS(.v13), .iOS("18.5")],
    products: [.library(name: "ForkiCore", targets: ["ForkiCore"])],
    targets: [
        .target(name: "ForkiCore", path: "HabitPet", sources: [
            "Models.swift", "NutritionState.swift", "GoalCalculator.swift",
            "USDAConfig.swift", "USDAFoodModels.swift", "USDAFoodService.swift",
            "BackendConfiguration.swift"
        ]),
        .testTarget(name: "ForkiCoreTests", dependencies: ["ForkiCore"],
                    path: "HabitPetTests", sources: ["NutritionStateTests.swift", "USDAFoodServiceTests.swift"])
    ]
)
