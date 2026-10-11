import Foundation
import UserNotifications

/// Everything the 9pm summary needs to describe the day.
struct DaySummary {
    var done: Int
    var open: Int
    var tomorrow: Int
    var streak: Int
    var percent: String
    var emoji: String
}

final class DailySummaryScheduler {
    static let shared = DailySummaryScheduler()

    /// Summary time (24h clock). Change these to move the reminder.
    static let hour = 21
    static let minute = 0

    private let center = UNUserNotificationCenter.current()
    private let identifier = "daily-summary"

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces the repeating daily notification with fresh text.
    func schedule(_ summary: DaySummary) {
        let content = UNMutableNotificationContent()
        content.title = "Evening summary"
        content.body = body(for: summary)
        content.sound = .default

        var when = DateComponents()
        when.hour = Self.hour
        when.minute = Self.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        // "daily-checkin" is the old identifier from the previous version; clearing it
        // stops you from getting two notifications at 9pm.
        center.removePendingNotificationRequests(withIdentifiers: ["daily-checkin", identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private func body(for s: DaySummary) -> String {
        var lines: [String] = []
        let total = s.done + s.open

        if total == 0 {
            if s.streak > 0 {
                lines.append("No tasks for today. Add and finish one to keep your \(s.streak)-day streak.")
            } else {
                lines.append("No tasks for today.")
            }
        } else {
            lines.append("Today: \(s.done) of \(total) done (\(s.percent)) \(s.emoji)")
            if s.open == 0 {
                lines.append("All done. It counts toward your streak at midnight.")
            } else {
                let left = "\(s.open) task\(s.open == 1 ? "" : "s") left"
                if s.streak > 0 {
                    lines.append("\(left). Finish them to keep your \(s.streak)-day streak.")
                } else {
                    lines.append("\(left). Finish them all to start a streak.")
                }
            }
        }

        if s.tomorrow > 0 {
            lines.append("Tomorrow: \(s.tomorrow) task\(s.tomorrow == 1 ? "" : "s") planned.")
        } else {
            lines.append("Nothing planned for tomorrow yet.")
        }

        return lines.joined(separator: "\n")
    }
}
