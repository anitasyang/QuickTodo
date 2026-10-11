# QuickTodo

A small macOS menu bar to-do list with a global quick-add hotkey, daily streaks, and a 9pm summary notification. It lives in the menu bar (no Dock icon), stores everything locally, and needs no account.

<!-- Add a screenshot or GIF here, for example:
![QuickTodo menu bar popover](docs/screenshot.png)
-->

## Features

- **Menu bar at a glance:** the menu bar shows your open task count, today's completion percentage, and a mood emoji (for example `2 · 67% 💪`).
- **Quick-add from anywhere:** press `⌥Space` to open a floating bar, type a task, and press Return. The app you were using keeps its place.
- **Plan for tomorrow:** add tasks for tomorrow from the popover or the quick-add bar. They stay out of today's progress and become today's tasks at midnight.
- **Streaks:** a day counts toward your streak when every task for that day is finished, and it only counts once the day has ended.
- **9pm summary:** a daily notification with today's progress, what's left, your streak, and how many tasks you've planned for tomorrow.
- **Small touches:** a progress ring that completes with a short celebration, a bouncing checkbox, and a strikethrough that draws itself across finished tasks.
- **Private by design:** all data stays on your Mac in a local JSON file.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later to build from source

## Getting started

### Build from source

1. Clone the repository and open `QuickTodo.xcodeproj` in Xcode.
2. Wait for Xcode to download the [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) package (it resolves automatically).
3. Select the **QuickTodo** target, open **Signing & Capabilities**, and choose your Team (a free Apple ID works) or **Sign to Run Locally**.
4. Press `⌘R` to run. Allow notifications when macOS asks.

The checklist icon appears in the menu bar. There is no Dock icon by design.

### Install permanently

Running from Xcode stops the app when you stop the project. To keep it running:

1. In Xcode, choose **Product → Show Build Folder in Finder** and open **Products → Debug**.
2. Drag **QuickTodo.app** into your **Applications** folder.
3. Open it from Applications.

### Launch at login

The 9pm summary only fires with current numbers while the app is running, so add it to your login items:

1. Open **System Settings → General → Login Items & Extensions**.
2. Under **Open at Login**, click **+** and choose QuickTodo from Applications.

## Usage

| To do this | Do this |
| --- | --- |
| Add a task for today | Click the menu bar icon, type, press Return |
| Add a task for tomorrow | In the popover, switch the selector to **Tomorrow**, or press `Shift+Return` in the quick-add bar |
| Open the quick-add bar | Press `⌥Space` from any app |
| Complete a task | Click its circle |
| Delete a task | Click its trash icon |
| Move a tomorrow task into today | Click the up arrow next to it |
| Quit the app | Press `⌘Q` while the menu bar popover is open |

## How streaks work

- A day is **complete** when it ends with every task for that day finished and at least one task done.
- Today is never counted until the day is over, so you can keep adding tasks. Adding a task later in the day makes today incomplete again.
- Your streak is the number of consecutive complete days ending **yesterday**. The popover also shows your best streak.
- Tasks planned for tomorrow do not count toward today.

## The 9pm summary

A repeating notification fires at 21:00 with text like:

```
Today: 3 of 5 done (60%) 💪
2 tasks left. Finish them to keep your 4-day streak.
Tomorrow: 2 tasks planned.
```

macOS fixes a notification's text when it is scheduled, so the app reschedules it after every change and every 30 minutes. If the app is quit, the notification still fires, but with the text from the last time the app ran.

## Project structure

```
QuickTodo/
├── QuickTodo.xcodeproj
└── QuickTodo/
    ├── QuickTodoApp.swift          App entry point, menu bar item, launch setup
    ├── TodoItem.swift              Task model
    ├── TaskStore.swift             Shared data, persistence, streak and progress logic
    ├── MenuBarView.swift           Popover UI, progress ring, task rows, animations
    ├── QuickAddPanel.swift         Global hotkey and floating quick-add bar
    └── DailySummaryScheduler.swift 9pm summary notification
```

`TaskStore` is the single source of truth. The popover, the quick-add bar, and the app's launch timer all call into it, and SwiftUI redraws the screens automatically when its data changes.

## Customizing

| What | Where |
| --- | --- |
| Summary time | `DailySummaryScheduler.hour` and `.minute` (24-hour clock) |
| Default hotkey | `KeyboardShortcuts.Name.quickAdd` in `QuickAddPanel.swift` |
| Mood emoji and thresholds | `mood` in `TaskStore.swift` |
| Menu bar label | `label` in `QuickTodoApp.swift` |

## Data and privacy

Tasks and streak history are stored as JSON in the app's Application Support folder (inside its sandbox container). Nothing is sent anywhere, and the app makes no network requests.

## Known limitations

- Deleting an unfinished task counts as clearing it, so it will not block a day from completing.
- There is no sync across devices and no iPhone app.
- The hotkey can only be changed in code, not from inside the app.

## Acknowledgements

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus, used for the global hotkey.

## License

No license has been chosen yet. Add a `LICENSE` file (for example MIT) before sharing the code for reuse.
