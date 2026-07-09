# Debugging Log

An engineering journal of difficult bugs, root causes, and resolutions.

## 2026-07-08
**Problem:** MenuBarPanel became key but never appeared on screen.
**Symptoms:**
- `isVisible == true`
- `windowDidBecomeKey` fired.
- `makeKeyAndOrderFront()` succeeded.
- BUT `NSApp.orderedWindows == []`
- AND `occlusionState.contains(.visible) == false`
**Root Cause:**
`hidesOnDeactivate = true` suppresses `LSUIElement` windows. Because FlowTimer is a background app, it doesn't activate when the menu bar icon is clicked. The WindowServer intercepted the window presentation and instantly hid it because the app was "deactivated."
**Fix:**
Removed `hidesOnDeactivate` and relied purely on `didResignKeyNotification` for dismissal.

## 2026-07-08
**Problem:** MenuBarPanel frequently switched to fullscreen Spaces when clicking the inline title text field.
**Symptoms:**
- Editing the session title inside the `NSPopover` caused the Window Server to jump to a fullscreen Space containing another app.
- Forcing `.fullScreenAuxiliary` collection behavior on the popover did not fix it.
**Root Cause:**
`NSPopover` manages its own private `_NSPopoverWindow`, which spins up private system text-input helper windows (`SPRoundedWindow`). These system windows do not inherit the parent's collection behavior. When the text field demanded focus, the OS tried to present the system window, failed to do so in the active floating context, and fell back to switching Spaces.
**Fix:**
Migrated the entire interface from `NSPopover` to a custom `NSPanel` (`MenuBarPanel`). `NSPanel` is a first-class window that cleanly hosts the SwiftUI responder chain without spinning up unstable private text-input overlays.
