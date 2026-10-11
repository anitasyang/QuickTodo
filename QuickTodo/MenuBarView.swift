import SwiftUI

enum AddTarget: String, CaseIterable, Identifiable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    var id: String { rawValue }
}

struct MenuBarView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var newTitle = ""
    @State private var target: AddTarget = .today
    @State private var pulse: CGFloat = 1
    @State private var showNote = false
    @FocusState private var inputFocused: Bool

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A ScrollView has no natural height inside a menu bar window and collapses to zero,
    /// so give it an explicit height based on how many rows (and section headers) there are.
    private var listHeight: CGFloat {
        let todayRows = max(store.visibleItems.count, 1)
        let tomorrowRows = store.tomorrowItems.count
        let header: CGFloat = tomorrowRows > 0 ? 28 : 0
        return min(CGFloat(todayRows + tomorrowRows) * 34 + header, 300)
    }

    private var ringProgress: Double { store.progress }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 8) {
                HStack {
                    TextField(target == .today ? "Add a task for today…" : "Add a task for tomorrow…",
                              text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(!canAdd)
                }
                Picker("", selection: $target) {
                    ForEach(AddTarget.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if store.visibleItems.isEmpty && store.tomorrowItems.isEmpty {
                Text("Nothing here yet. Add your first task above.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if store.visibleItems.isEmpty {
                            Text("No tasks for today.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .frame(height: 26)
                        } else {
                            ForEach(store.visibleItems) { item in
                                TaskRow(item: item)
                            }
                        }

                        if !store.tomorrowItems.isEmpty {
                            Text("TOMORROW")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                            ForEach(store.tomorrowItems) { item in
                                TomorrowRow(item: item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: listHeight)
            }
        }
        .padding(14)
        .frame(width: 330)
        .background(quitShortcut)
        .onAppear {
            inputFocused = true
            showNote = store.todayLooksComplete   // no animation if it was already done
        }
        .onChange(of: store.todayLooksComplete) { isComplete in
            if isComplete {
                celebrate()
            } else {
                withAnimation(.easeOut(duration: 0.25)) { showNote = false }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ProgressRing(progress: ringProgress, complete: store.todayLooksComplete)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentStreak > 0 ? "🔥 \(store.currentStreak)-day streak" : "No streak yet")
                    .font(.headline)
                Text("Best: \(store.longestStreak) · Done today: \(store.completedToday)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if showNote {
                    Label("Counts toward your streak at midnight", systemImage: "moon.stars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            Spacer()

            // Mood emoji: pops in whenever your progress crosses into a new mood.
            ZStack {
                Text(store.mood.emoji)
                    .font(.system(size: 30))
                    .id(store.mood.emoji)
                    .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: store.mood.emoji)
            .help(store.mood.headline)
        }
        .scaleEffect(pulse, anchor: .leading)
    }

    /// Sequence: ring fills (handled by the ring itself) -> header pulses -> note fades in.
    private func celebrate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { pulse = 1.06 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pulse = 1 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if store.todayLooksComplete {
                withAnimation(.easeIn(duration: 0.6)) { showNote = true }
            }
        }
    }

    /// Invisible: pressing ⌘Q while this menu is open quits the app.
    private var quitShortcut: some View {
        Button("") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
            .frame(width: 0, height: 0)
            .opacity(0)
    }

    private func add() {
        store.add(newTitle, forTomorrow: target == .tomorrow)
        newTitle = ""
        inputFocused = true
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    let complete: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(complete ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if complete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 38, height: 38)
        .animation(.easeOut(duration: 0.6), value: progress)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: complete)
    }
}

// MARK: - Task rows

struct TaskRow: View {
    let item: TodoItem
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        HStack(spacing: 8) {
            CheckButton(done: item.isDone) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    store.toggle(item)
                }
            }

            StrikeText(text: item.title, done: item.isDone)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { store.delete(item) }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }
}

/// A task planned for tomorrow: no checkbox yet, but you can pull it into today or delete it.
struct TomorrowRow: View {
    let item: TodoItem
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)

            Text(item.title)
                .lineLimit(2)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    store.moveToToday(item)
                }
            } label: {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Move to today")

            Button {
                withAnimation(.easeOut(duration: 0.2)) { store.delete(item) }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }
}

/// Circle that fills with a green check and bounces when you complete a task.
struct CheckButton: View {
    let done: Bool
    let action: () -> Void
    @State private var scale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? Color.green : Color.secondary)
                .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .onChange(of: done) { isDone in
            guard isDone else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { scale = 1.4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1 }
            }
        }
    }
}

/// Title whose strikethrough sweeps in from the left when `done` becomes true.
struct StrikeText: View {
    let text: String
    let done: Bool

    var body: some View {
        Text(text)
            .lineLimit(2)
            .foregroundColor(done ? .secondary : .primary)
            .overlay(alignment: .leading) {
                // Same text with a strikethrough, revealed left-to-right by a growing mask.
                Text(text)
                    .lineLimit(2)
                    .strikethrough(true)
                    .foregroundColor(.secondary)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(width: done ? geo.size.width : 0)
                        }
                    }
            }
            .animation(.easeOut(duration: 0.4), value: done)
    }
}
