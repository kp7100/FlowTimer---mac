# ADR 003: Settings Window Lifecycle and Memory Optimization

## Context
Initially, the Settings window (which hosts the `SettingsView` and `StatisticsView`) was managed via a hide-and-retain pattern. Closing the window programmatically called `orderOut(nil)`, keeping the window, `NSHostingController`, and the entire SwiftUI view hierarchy alive in memory indefinitely.

Because Settings is an infrequently accessed portion of the app, retaining this view hierarchy (which grows in size as session history accumulates in the statistics tab) is not worth the instant-reopen memory trade-off.

## Decision
We elected to transition the Settings window to a **release-on-close** lifecycle.

1. **ARC Safety**: In Swift/ARC, setting `isReleasedWhenClosed = true` is highly prone to over-release crashes if a strong reference to the window is held and subsequently nil-ed out. We configure `isReleasedWhenClosed = false` so that ARC is the sole owner of the window's memory.
2. **Unified Close Path**: We changed the programmatic closing method (`hideSettingsWindow()`) to call `.close()` instead of `.orderOut(nil)`. This unifies both the window's traffic-light close button and programmatic close actions to trigger `NSWindow.willCloseNotification`.
3. **Deallocation**: Inside the notification observer, we set `self.settingsWindow = nil`, dropping the last strong reference and allowing ARC to fully deallocate the entire window and view hierarchy.

## Consequences
- **Positive**: Memory is fully reclaimed when the Settings window is closed, dropping the app's memory footprint back to its baseline (~23MB).
- **Positive**: Consistent state lifecycle; closing the settings window guarantees that opening it next time starts with a fresh, clean-slate state.
- **Negative**: Reopening the Settings window incurs a minor layout and rendering initialization overhead.
