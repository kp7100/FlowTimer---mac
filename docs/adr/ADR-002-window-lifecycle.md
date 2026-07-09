# ADR 002: Window Lifecycle and HidesOnDeactivate

## Context
During the migration to the `MenuBarPanel`, a bug emerged where the panel would successfully instantiate, calculate its frame, become the key window in AppKit, but completely fail to appear on screen. The Window Server logs showed `NSApp.orderedWindows == []` and `occlusionState.contains(.visible) == false`.

## Problem
The `MenuBarPanel` was initialized with `hidesOnDeactivate = true`. 
FlowTimer is an `LSUIElement` (accessory) app. Accessory apps do not "activate" in the traditional sense when their menu bar icons are clicked (unless `NSApp.activate()` is explicitly called). 
When we instructed AppKit to `makeKeyAndOrderFront()`, the Window Server noticed two conflicting facts:
1. The app is currently deactivated.
2. The window is explicitly configured to hide when the app is deactivated.
Consequently, the Window Server instantly suppressed the panel, dropping it from the ordered window list to enforce the `hidesOnDeactivate` rule.

## Options Considered
1. **Reintroduce `NSApp.activate(ignoringOtherApps: true)`**: Force the app to activate on every menu bar click. (Rejected: Steals focus from the user's current workspace, defeating the purpose of an unobtrusive utility).
2. **Remove `hidesOnDeactivate` and handle dismissal manually**: Disable the AppKit automated suppression and write our own logic to close the panel when it loses focus.

## Decision
We elected to disable `hidesOnDeactivate = false` on `MenuBarPanel` and rely on `NSWindow.didResignKeyNotification` to trigger the `hidePanel()` sequence.

## Consequences
- **Positive**: The panel now reliably opens regardless of the active application or Space.
- **Positive**: We retain the non-intrusive `LSUIElement` behavior without stealing focus.
- **Negative**: We must carefully manage the `didResignKey` lifecycle to ensure the panel always dismisses correctly when the user clicks away.
