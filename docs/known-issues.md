# Known Issues & Accepted Behaviors

This document tracks known quirks and accepted limitations in the current FlowTimer architecture.

## 1. Mission Control Dismissal
- **Behavior:** Triggering Mission Control (F3) causes the MenuBarPanel to dismiss.
- **Reason:** Mission Control automatically causes most non-main windows to resign key status. Our `didResignKeyNotification` observer intentionally hides the panel when this happens to simulate native macOS utility behavior (like Spotlight or Alfred).
- **Future:** If a "Pinned Mode" is ever requested, we will need to bypass the `didResignKey` dismissal when pinned.

## 2. Global Space Transitions
- **Behavior:** If the panel is open and the user swipes to a different Space using the trackpad, the panel follows the user to the new Space.
- **Reason:** `MenuBarPanel` is configured with `.canJoinAllSpaces` and `.fullScreenAuxiliary`.
- **Accepted State:** This is the intended behavior for floating utility panels. However, rapid space switching while animating might occasionally interrupt visual flow.

## 3. Legacy Popover Hacks Maintained
- **Behavior:** Some global and local `NSEvent` monitors (used previously to simulate popover click-outside behavior and spacebar text entry) are currently commented out in `MenuBarPanelManager.swift`.
- **Reason:** Retained temporarily as a safety net while the new `NSPanel` architecture undergoes field testing across edge cases (multi-monitor, sleep/wake, etc.). They will be purged in a future cleanup commit.
