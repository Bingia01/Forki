import Foundation

func goalFromUserData(_ ud: UserData) -> Int {
    let goalText = ud.goal.lowercased()
    if goalText.contains("lose") || goalText.contains("slim") || goalText.contains("cut") {
        return 1800
    } else if goalText == "strong" || goalText.contains("gain") || goalText.contains("bulk") || goalText.contains("muscle") {
        return 2600
    } else if goalText == "content" || goalText.contains("maintain") {
        return 2200
    }
    // Fallback: 2000 is the FDA reference daily intake
    return 2000
}
