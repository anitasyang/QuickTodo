import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var completedAt: Date? = nil
    /// Start of the day this task is planned for. nil means "today" (or carried over).
    var plannedFor: Date? = nil

    var isDone: Bool { completedAt != nil }

    /// True while the task is planned for a day after today.
    /// At midnight it automatically becomes a normal task for the new day.
    var isFuture: Bool {
        guard let day = plannedFor else { return false }
        return day > Calendar.current.startOfDay(for: Date())
    }
}
