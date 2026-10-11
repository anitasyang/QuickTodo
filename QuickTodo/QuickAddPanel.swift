import SwiftUI
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default: ⌥Space.
    static let quickAdd = Self("quickAdd", default: .init(.space, modifiers: [.option]))
}

/// A borderless panel that can take keyboard input without activating the app,
/// so the app you were using keeps its place and gets focus back when the panel closes.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickAddPanelController {
    static let shared = QuickAddPanelController()

    private var panel: FloatingPanel?
    private var resignObserver: NSObjectProtocol?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Fresh view each time so the text field starts empty.
        panel.contentView = NSHostingView(
            rootView: QuickAddView(
                onSubmit: { [weak self] text, forTomorrow in
                    TaskStore.shared.add(text, forTomorrow: forTomorrow)
                    self?.hide()
                },
                onCancel: { [weak self] in
                    self?.hide()
                }
            )
        )

        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Private

    private func makePanel() -> FloatingPanel {
        let p = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 64),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Clicking elsewhere dismisses the panel.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: p,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        return p
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + frame.height * 0.68
        )
        panel.setFrameOrigin(origin)
    }
}

struct QuickAddView: View {
    /// (title, forTomorrow)
    let onSubmit: (String, Bool) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)

            TextField("Add a task…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 22))
                .focused($focused)
                .onSubmit {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    // Return = today, Shift+Return = tomorrow.
                    let forTomorrow = NSEvent.modifierFlags.contains(.shift)
                    onSubmit(trimmed, forTomorrow)
                }
                .onExitCommand(perform: onCancel)

            Text("↩ today · ⇧↩ tomorrow")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .frame(width: 520, height: 64)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }
}
