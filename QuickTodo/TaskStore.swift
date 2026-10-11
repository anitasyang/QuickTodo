import Foundation
import SwiftUI
import Combine

final class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var items: [TodoItem] = []
    /// "yyyy-MM-dd" -> number of tasks completed that day.
    @Published private(set) var dayCounts: [String: Int] = [:]
    /// Days that have ENDED with every task finished. Only these count toward the streak.
    @Published private(set) var completedDays: Set<String> = []

    /// The most recent day the list changed, and whether that day looked "all done"
    /// at that moment. When a new day begins, this is finalized into `completedDays`.
    private var pendingDay: String?
    private var pendingComplete = false

    private struct Snapshot: Codable {
        var items: [TodoItem]
        var dayCounts: [String: Int]
        var completedDays: Set<String>?   // optional so older save files still load
        var pendingDay: String?
        var pendingComplete: Bool?
    }

    private let fileURL: URL
    private let formatter: DateFormatter

    private init() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        formatter = f

        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")

        load()
    }

    // MARK: - Actions

    func add(_ title: String, forTomorrow: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = TodoItem(title: trimmed)
        if forTomorrow {
            let cal = Calendar.current
            item.plannedFor = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))
        }
        items.append(item)
        didChange()
    }

    /// Pulls a task planned for tomorrow into today's list.
    func moveToToday(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].plannedFor = nil
        didChange()
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        if let completedAt = items[i].completedAt {
            // Un-complete: take the credit back from the day it was completed.
            let k = key(for: completedAt)
            dayCounts[k] = max(0, (dayCounts[k] ?? 0) - 1)
            items[i].completedAt = nil
        } else {
            let now = Date()
            items[i].completedAt = now
            dayCounts[key(for: now), default: 0] += 1
        }
        didChange()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        didChange()
    }

    // MARK: - Derived data

    /// Open tasks that belong to today. Tasks planned for tomorrow are excluded,
    /// so they never affect today's progress, percentage, or streak.
    var openItems: [TodoItem] { items.filter { !$0.isDone && !$0.isFuture } }

    /// Open tasks planned for tomorrow.
    var tomorrowItems: [TodoItem] { items.filter { !$0.isDone && $0.isFuture } }

    var doneTodayItems: [TodoItem] {
        items.filter {
            guard let d = $0.completedAt else { return false }
            return Calendar.current.isDateInToday(d)
        }
    }

    /// Open tasks first, then what you finished today.
    var visibleItems: [TodoItem] { openItems + doneTodayItems }

    var openCount: Int { openItems.count }

    var completedToday: Int { dayCounts[key(for: Date())] ?? 0 }

    /// True when everything is done right now. Today only becomes official at midnight.
    var todayLooksComplete: Bool { openCount == 0 && completedToday > 0 }

    /// Tasks finished today plus tasks still open.
    var totalToday: Int { completedToday + openCount }

    /// 0...1 share of today's tasks that are done.
    var progress: Double {
        totalToday == 0 ? 0 : Double(completedToday) / Double(totalToday)
    }

    var percentText: String { "\(Int((progress * 100).rounded()))%" }

    /// Emoji + headline that follow how far along the day is.
    var mood: (emoji: String, headline: String) {
        if totalToday == 0 { return ("🌱", "No tasks today.") }
        if progress >= 1 { return ("🎉", "All done! Great day.") }
        if progress >= 0.75 { return ("🔥", "Almost there!") }
        if progress >= 0.5 { return ("💪", "More than halfway.") }
        if progress > 0 { return ("🙂", "Good start. Keep going.") }
        return ("😴", "Nothing done yet. Pick one small thing.")
    }

    /// Consecutive finished days ending yesterday. Today is never included until it ends.
    var currentStreak: Int {
        let cal = Calendar.current
        let days = effectiveCompletedDays
        guard var day = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) else { return 0 }

        var streak = 0
        while days.contains(key(for: day)) {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var longestStreak: Int {
        let cal = Calendar.current
        let days = effectiveCompletedDays
            .compactMap { formatter.date(from: $0) }
            .sorted()

        var best = 0, run = 0
        var previous: Date?
        for d in days {
            if let p = previous,
               let next = cal.date(byAdding: .day, value: 1, to: p),
               cal.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = d
        }
        return best
    }

    // MARK: - Notifications / day rollover

    /// Called at launch and every 30 minutes: finalizes finished days and rewrites
    /// the pending 9pm summary so its text reflects the latest numbers.
    func refreshSchedule() {
        finalizePastDay()
        save()
        scheduleSummary()
    }

    /// Pushes the latest numbers into the pending 9pm summary notification.
    private func scheduleSummary() {
        DailySummaryScheduler.shared.schedule(
            DaySummary(
                done: completedToday,
                open: openCount,
                tomorrow: tomorrowItems.count,
                streak: currentStreak,
                percent: percentText,
                emoji: mood.emoji
            )
        )
    }

    // MARK: - Day tracking

    private func didChange() {
        finalizePastDay()
        updatePendingToday()
        save()
        scheduleSummary()
    }

    /// Records how today looks right now. This can change as many times as you like
    /// until the day ends.
    private func updatePendingToday() {
        pendingDay = key(for: Date())
        pendingComplete = todayLooksComplete
    }

    /// Once a new day has started, the previous day's last known state becomes final.
    private func finalizePastDay() {
        guard let day = pendingDay, day != key(for: Date()) else { return }
        if pendingComplete { completedDays.insert(day) }
        pendingDay = nil
        pendingComplete = false
    }

    /// Finalized days plus a past day that is complete but not yet finalized
    /// (e.g. the app has been running across midnight).
    private var effectiveCompletedDays: Set<String> {
        var days = completedDays
        if let day = pendingDay, pendingComplete, day != key(for: Date()) {
            days.insert(day)
        }
        return days
    }

    // MARK: - Persistence

    private func key(for date: Date) -> String { formatter.string(from: date) }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        // Keep open tasks and anything finished today; older finished tasks are dropped.
        items = snap.items.filter { ($0.completedAt ?? startOfToday) >= startOfToday }
        dayCounts = snap.dayCounts
        completedDays = snap.completedDays ?? []
        pendingDay = snap.pendingDay
        pendingComplete = snap.pendingComplete ?? false

        // Today isn't official yet, even if an earlier version saved it as complete.
        completedDays.remove(key(for: Date()))

        finalizePastDay()
        if pendingDay == nil { updatePendingToday() }
    }

    private func save() {
        let snap = Snapshot(
            items: items,
            dayCounts: dayCounts,
            completedDays: completedDays,
            pendingDay: pendingDay,
            pendingComplete: pendingComplete
        )
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
