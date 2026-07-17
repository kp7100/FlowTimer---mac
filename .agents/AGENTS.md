# Menu Bar App Architecture Rules

- **Ban NSApp.activate() in popover flows**: A menu bar (`LSUIElement`) app should never activate the entire application just because a user interacted with a popover (like clicking a text field). Doing so forces macOS to bring all app windows to the front, which violently switches the user's Space if they are working in another fullscreen app. Rely on native AppKit/SwiftUI focus management instead.

- **Standard Toolbar Icon & Checkbox Sizing**: Default to native macOS toolbar proportions: size 19pt, `.medium` weight for SF Symbols, and a bounding frame of `30x30`pt (or `.nativeToolbarIcon()`). Do not hardcode smaller icon sizes (like 12-14pt) on checkboxes or action buttons unless explicitly requested, as this shrinks the row height and restricts the click hit area.

- **Keyboard Focus Dismissal**: Ensure the root layer of main windows (like `MenuBarPanelView`) contains a background tap gesture wrapper resolving `NSApp.keyWindow?.makeFirstResponder(nil)`. This makes sure clicking any empty region in the UI properly resigns keyboard focus and clears active text selections.

- **Dropdown Menu Pickers**: In SwiftUI on macOS, when placing a selection `Picker` inside a `Menu` button, always apply `.pickerStyle(.inline)`. Failing to do so causes macOS to cluster the options into a single "Selected Tag" submenu, requiring an extra interaction.

## Onboarding Documentation Rule
From now on, whenever we implement a feature that changes user behavior or introduces a concept that may not be immediately obvious, automatically append a concise entry to docs/onboarding-notes.md. Do not write onboarding screens—only maintain this knowledge base for future onboarding design.

## Maintaining AGENTS.md Rule
When a bug fix or implementation reveals a reusable project-wide rule that is likely to prevent future regressions, suggest an update to AGENTS.md. 

Examples of what qualifies:
* macOS framework quirks
* SwiftUI/AppKit layout pitfalls
* Standard UI sizing and spacing rules
* Git safety practices
* Development workflow improvements

Do not update AGENTS.md automatically. Instead:
1. Briefly explain why the rule is worth preserving.
2. Show the exact Markdown snippet to add.
3. Wait for approval before modifying AGENTS.md.

Do not add feature-specific, temporary, or one-off rules.

### Commit & Push Policy

- Never create a Git commit unless I explicitly ask you to commit.
- Never run `git push` unless I explicitly say "git push", "push", or otherwise clearly authorize pushing.
- Completing a coding task does NOT imply permission to commit or push.
- After finishing work, suggest an atomic commit message and wait for my approval.
- After committing, wait again for explicit approval before pushing.


