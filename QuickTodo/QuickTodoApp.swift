import SwiftUI
import AppKit
import UserNotifications
import KeyboardShortcuts

@main
struct QuickTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                if store.totalToday > 0 {
                    Text(store.openCount > 0
                         ? "\(store.openCount) · \(store.percentText) \(store.mood.emoji)"
                         : "\(store.percentText) \(store.mood.emoji)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon, no app switcher entry.
        NSApp.setActivationPolicy(.accessory)

        UNUserNotificationCenter.current().delegate = self
        DailySummaryScheduler.shared.requestPermission()

        Task { @MainActor in TaskStore.shared.refreshSchedule() }

        // Global hotkey (default ⌥Space) toggles the floating quick-add panel.
        KeyboardShortcuts.onKeyUp(for: .quickAdd) {
            Task { @MainActor in QuickAddPanelController.shared.toggle() }
        }

        // Keeps the summary text accurate across midnight.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task { @MainActor in TaskStore.shared.refreshSchedule() }
        }
    }

    // Show the banner even while the app is running.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
