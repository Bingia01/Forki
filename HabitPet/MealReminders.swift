import Foundation
import UserNotifications

struct MealReminders {
    static let identifiers = ["forki-breakfast", "forki-lunch", "forki-dinner"]
    static func configure(enabled: Bool, center: UNUserNotificationCenter = .current()) async throws -> Bool {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard enabled else { return false }
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return false }
        do {
            for (index, hour) in [9, 13, 19].enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Time to feed your Forki"
                content.body = "Log your meal and check in with your pet."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
                try await center.add(UNNotificationRequest(identifier: identifiers[index], content: content, trigger: trigger))
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            throw error
        }
        return true
    }
}
