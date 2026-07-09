# ADR 001: Migrate from NSPopover to NSPanel

## Context
FlowTimer initially used `NSPopover` to present its main menu interface from the `NSStatusItem`. This was chosen for ease of implementation, as `NSPopover` automatically handles the status bar tail and edge alignment. However, as the product evolved to include inline text editing (a `TextField` for renaming the session title), a critical bug emerged: clicking the text field while FlowTimer was overlaid on a fullscreen application caused macOS to aggressively and uncontrollably switch Spaces.

## Problem
`NSPopover` does not handle deep focus management gracefully. Specifically, when a `TextField` inside an `NSPopover` attempts to become the first responder, AppKit spawns a private `SPRoundedWindow` text-input helper. Because this system helper is detached from our `NSPopover`'s collection behavior (`.fullScreenAuxiliary`), the Window Server tries to present it in the primary desktop space, causing an aggressive Space transition away from the user's active fullscreen app. Workarounds like `NSApp.activate(ignoringOtherApps: true)` and custom `NSTextField` overrides failed to intercept this behavior.

## Options Considered
1. **Remove inline editing**: Move text editing to a separate modal window. (Rejected: harms UX).
2. **Hack the `_NSPopoverWindow`**: Attempt to reflectively inject `.fullScreenAuxiliary` into the private popover window hierarchy. (Rejected: brittle, didn't affect the separate `SPRoundedWindow` helper anyway).
3. **Custom `NSPanel`**: Abandon `NSPopover` entirely and rebuild the menu bar interface using a custom `.nonactivatingPanel` `NSPanel`.

## Decision
We elected to migrate to a custom `NSPanel` (`MenuBarPanel`).

## Consequences
- **Positive**: The Space switching bug is completely eliminated. `NSPanel` is a first-class window that cleanly hosts the SwiftUI responder chain without spinning up unstable private text-input overlays.
- **Positive**: We gain absolute control over the window lifecycle, shadowing, animation, and level positioning.
- **Negative**: We lose the automatic `NSPopover` tail and alignment logic, requiring manual edge-clamping and coordinate calculations against `NSStatusBarButton` frames.
