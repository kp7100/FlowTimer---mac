# FlowTimer Architecture

FlowTimer is a macOS menu bar application designed as an `LSUIElement`. It provides a completely floating, keyboard-friendly interface for managing timers and focus sessions without activating as a traditional desktop application or occupying space in the dock.

## Core Components

### `FlowTimerApp` (Entry Point)
- Configures the application lifecycle.
- Forces `.accessory` activation policy.
- Initializes managers.

### `MenuBarPanelManager`
- Manages the primary user interface: a floating `MenuBarPanel` anchored to the system status bar.
- Responsible for panel lifecycle, native animation, positioning logic, and avoiding Window Server suppression traps.
- Contains the `PanelState` state machine to prevent race conditions during rapid toggle interactions.

### `WindowManager`
- Manages secondary floating surfaces like the `FlowPanel` (Mini Timer) and Settings window.
- Handles `NSApp.activate(ignoringOtherApps: true)` when required (since `LSUIElement` apps don't activate by default).

### `TimerManager`
- The core business logic and state machine for the Pomodoro timer.
- Handles phase transitions (Work, Break, Flow Extension).
- Dispatches state updates to SwiftUI views.

### `ShortcutDispatcher`
- Maps global keyboard shortcuts to specific manager actions without requiring the app to be active.

## Design Philosophy
1. **Utility First:** FlowTimer behaves like a native macOS utility (e.g., Spotlight, Raycast). It floats above the workspace and vanishes when you click away.
2. **Minimal Activation:** The app avoids stealing focus. It relies on `NSPanel`'s `.nonactivatingPanel` feature to accept keyboard input for its text fields without pulling the user out of their current application.
