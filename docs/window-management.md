# Window Management Quirks & Lessons Learned

FlowTimer heavily relies on precise AppKit window management to achieve its seamless floating experience. Below are the quirks, traps, and lifecycle behaviors discovered during development.

## 1. SwiftUI `NSHostingController` Sizing inside `NSPanel`
**The Trap:** `NSPanel` (unlike `NSPopover`) does not automatically calculate its geometry before layout if it's placed off-screen. If you inject a SwiftUI view into an `NSPanel` using `.intrinsicContentSize` and then attempt to calculate its positioning via `setFrameTopLeftPoint`, the frame will evaluate to `0x0`. AppKit calculates the bottom-left origin as `y = topLeft.y - height`. If `height` is `0`, the panel is placed at the top of the screen. A split-second later, SwiftUI renders its content, the panel expands upwards, and the UI flies off the top of the screen.
**The Fix:** Before setting the panel's origin, explicitly force the `NSHostingController` to calculate its size using `sizeThatFits(in:)` and manually assign that size to the panel's frame.

## 2. WindowServer Suppression (`hidesOnDeactivate`)
**The Trap:** `NSWindow.hidesOnDeactivate = true` is dangerous in `LSUIElement` apps. If you attempt to show a panel using `makeKeyAndOrderFront(nil)` while the app is inactive, the window receives focus internally, but Window Server silently intercepts it and sets `occlusionState = false` and removes it from `orderedWindows`. It becomes an invisible "ghost" key window.
**The Fix:** Never use `hidesOnDeactivate = true` unless you intend to explicitly call `NSApp.activate(ignoringOtherApps: true)` every time the window opens. We use `false` and handle dismissal manually via `NSWindow.didResignKeyNotification`.

## 3. `isReleasedWhenClosed`
**The Trap:** By default, `NSWindow.isReleasedWhenClosed` is `true`. If the panel is closed or ordered out in a way that AppKit interprets as a closure, the underlying `CGSWindow` is destroyed. Holding a strong reference to the Swift object will result in a zombie window that silently ignores `makeKeyAndOrderFront`.
**The Fix:** Always set `isReleasedWhenClosed = false` on reusable custom panels.

## 4. The Responder Chain & Fullscreen Spaces
**The Trap:** The original `NSPopover` implementation used `makeFirstResponder` and manual `NSApp.activate` hacks to allow deep text editing of a `TextField` inside the popover. Because `NSPopover` creates private, system-owned `SPRoundedWindow` text-input helpers, interacting with the text field while another app was in a fullscreen Space caused Window Server to forcibly switch Spaces in an attempt to present the system helper window.
**The Fix:** Migrating to a first-class `NSPanel` (`MenuBarPanel`) bypasses the `NSPopover` text-input helper bug. The panel is a standard auxiliary window that natively accepts focus (`.nonactivatingPanel`).

## 5. `NSPanel.becomesKeyOnlyIfNeeded`
This is a superpower exclusive to `NSPanel`. It allows the floating panel to sit on screen without stealing focus from the user's active application (e.g., Xcode). The instant the user clicks the session title text field, the panel dynamically accepts keyboard focus natively without forcing FlowTimer to activate as the primary app.
