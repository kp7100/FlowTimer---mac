# Menu Bar App Architecture Rules

- **Ban NSApp.activate() in popover flows**: A menu bar (`LSUIElement`) app should never activate the entire application just because a user interacted with a popover (like clicking a text field). Doing so forces macOS to bring all app windows to the front, which violently switches the user's Space if they are working in another fullscreen app. Rely on native AppKit/SwiftUI focus management instead.

## Onboarding Documentation Rule
From now on, whenever we implement a feature that changes user behavior or introduces a concept that may not be immediately obvious, automatically append a concise entry to docs/onboarding-notes.md. Do not write onboarding screens—only maintain this knowledge base for future onboarding design.
