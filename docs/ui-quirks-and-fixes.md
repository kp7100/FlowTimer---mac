# SwiftUI macOS Layout & UI Quirks

This document tracks specific SwiftUI layout quirks, unexpected behaviors, and their corresponding fixes in the FlowTimer macOS application. This acts as a reference to prevent these issues from being accidentally reintroduced during future refactors.

## 1. TextField Expanding Issue (Intrinsic Content Size)
**Bug**: A `TextField` inside an `HStack` inside a `ZStack` was shrinking to the intrinsic width of its placeholder text instead of expanding to fill the row, causing the placeholder to clip early.
**Cause**: The `TextField` inherited an unbounded or compressed frame from the parent stack, forcing it to shrink to its text content. Wrapping it in an `NSViewRepresentable` without providing proper compression resistance exacerbated the issue.
**Fix**: Apply `.frame(maxWidth: .infinity, alignment: .leading)` directly to the `TextField` or its container, and ensure the `.overlay(alignment: .trailing)` is attached to a view that spans the full row width, not just the text's intrinsic width.

## 2. macOS Menu Picker Submenu Bug
**Bug**: Clicking a `Menu` button containing a `Picker` (e.g. `TagSelectorMenu`) opened a dropdown with a single item labeled "Selected Tag" (the picker's label), requiring an extra click/hover to see the actual options.
**Cause**: By default, macOS SwiftUI renders a `Picker` inside a `Menu` as a nested submenu using the Picker's string label.
**Fix**: Apply `.pickerStyle(.inline)` directly to the `Picker` to force macOS to render the options directly in the primary menu list.

## 3. Keyboard Focus Not Dismissing on Window Click
**Bug**: Clicking empty space in the main timer window or todo list did not dismiss the active text field focus or text selection.
**Cause**: Unlike iOS, macOS does not automatically resign `firstResponder` when clicking empty window areas in SwiftUI.
**Fix**: Add an invisible, interactive background layer to the root container of the window:
```swift
.background(
    Color.white.opacity(0.0001)
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
)
```

## 4. MenuStyle(.borderlessButton) Clamping Icon Sizes
**Bug**: Applying `.font(.system(size: 19))` to an `Image` inside a `Menu` label had no effect; the icon remained small.
**Cause**: Using `.menuStyle(.borderlessButton)` forces macOS to clamp the internal label's size to the standard, small system menu button size.
**Fix**: Remove `.menuStyle(.borderlessButton)`, change it to `.buttonStyle(.plain)`, and apply custom styling (e.g., `.nativeToolbarIcon()`) directly to the label. This overrides the system clamp and allows for custom large icons with native hover states.

## 5. Row Hover Background Size (Bounding Box)
**Bug**: The rounded gray hover rectangle on a todo row appeared too small, tightly hugging the text instead of providing generous padding.
**Cause**: The hover background size is determined by the height of the elements *inside* the row's layout. Elements inside an `.overlay()` do not expand the row height.
**Fix**: Increase the frame of an element in the main layout stream (e.g., give the checkbox icon a `.frame(width: 30, height: 30)`) to mechanically expand the row height, allowing the background padding to render correctly.
