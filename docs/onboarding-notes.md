# Onboarding Notes

This document is not the final onboarding copy.

It is a living design document containing concepts that should be explained to new users when onboarding is eventually implemented.

Each entry should answer:
* **What is the feature?**
* **Why does it exist?**
* **Does the user need to know about it?**
* **When should it be introduced?**
* **Should it appear during onboarding, as a tooltip, or be discovered naturally?**

---

## Flow Extension

**Status**: Planned for onboarding

**Explain**:
* The timer does not stop at zero.
* If you’re still focused, keep working.
* FlowTimer automatically enters Flow Extension.
* The controls are simplified during this state: the Pause button is removed, leaving only a centered "Take Break" button.
* You decide when to stop.

---

## Adaptive Recovery Breaks

**Status**: Planned for onboarding

**Explain**:
* Short recovery breaks adapt to how long you actually worked.
* Long breaks remain fixed, as they are a scheduled deeper recovery.
* The calculation respects the work/break ratio chosen in Settings.
* Longer Flow sessions result in proportionally longer recovery.
* Users do not need to configure anything else.

**Example**:
“Worked twice as long? You’ll receive roughly twice the recovery time you originally chose.”

---

## Goals

**Status**: Refined / Live

**Explain**:
* Users can set daily goals (either Focus Time or Completed Sessions).
* The menu bar displays progress on these goals when the timer is paused (e.g., showing remaining time like `1h 32m / 2h left` or total time like `Focused 2h 10m` once the goal is met).
* This keeps users informed without needing to open the full app panel.

---

## Tags
*(To be detailed when feature is implemented/refined)*

---

## Session History
*(To be detailed when feature is implemented/refined)*

---

## Wellness Features
*(To be detailed when feature is implemented/refined)*

---

## Keyboard Shortcuts
*(To be detailed when feature is implemented/refined)*

---

## Menu Bar Mode

**Status**: Refined / Live

**Explain**:
* When active, the menu bar displays the current session title (or break phase) to maintain focus.
* When paused, it switches to displaying goal progress to summarize the day's achievements.
* Resuming immediately restores the session title context.

---

## Mini Timer
*(To be detailed when feature is implemented/refined)*

---

## Future Features
*(Add as development continues.)*
