import Foundation
import UserNotifications

final class CheckInScheduler {
    static let shared = CheckInScheduler()

    /// Check-in time (24h clock). Change these to move the reminder.
    static let hour = 21
    static let minute = 0

    private let center = UNUserNotificationCenter.current()
    private let identifier = "daily-checkin"

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces the repeating daily notification with fresh text.
    func schedule(doneToday: Int, open: Int, streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Evening check-in"
        content.sound = .default

        let tasksLeft = "\(open) task\(open == 1 ? "" : "s") left"
        if open == 0 && doneToday > 0 {
            let soFar = streak > 0 ? " Streak so far: \(streak) 🔥" : ""
            content.body = "All done today! It counts toward your streak at midnight.\(soFar)"
        } else if open == 0 {
            content.body = "No tasks today. Add one to keep your streak going."
        } else if streak > 0 {
            content.body = "\(tasksLeft). Finish them to keep your \(streak)-day streak."
        } else {
            content.body = "\(doneToday) done, \(tasksLeft). Finish them all to start a streak."
        }

        var when = DateComponents()
        when.hour = Self.hour
        when.minute = Self.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
