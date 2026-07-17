# Architectural Decisions

This document records the overarching architectural decisions made for FlowTimer. Detailed, individual decisions are recorded as ADRs (Architecture Decision Records) in the `docs/adr/` folder.

## 1. Why `NSPanel` instead of `NSPopover`?
The original UI was built as an `NSPopover` attached to an `NSStatusItem`. While `NSPopover` handles the popover tail and automatic positioning well, it severely limits window lifecycle control. Crucially, its internal text-input proxy windows (`SPRoundedWindow`) fail to respect `.fullScreenAuxiliary` collection behaviors, leading to aggressive and uncontrollable Space switching bugs when editing text fields. `NSPanel` is a first-class citizen of the Window Server that natively supports auxiliary floating behaviors and focus management.

## 2. Why `LSUIElement` (`.accessory`)?
FlowTimer is a utility app designed to assist focus, not dominate the desktop. Running as an `.accessory` prevents the app from appearing in the Dock or the Cmd+Tab switcher. It ensures that interacting with the Mini Timer or Menu Bar Panel does not pull the user out of their active workspace context (like Xcode or Safari).

## 3. Why a separate `FlowPanel` and `MenuBarPanel`?
`FlowPanel` is explicitly designed for the "Mini Timer"—a persistent, floating window that stays on screen until dismissed, and often demands `NSApp.activate` to become the main interactive window for deeper tasks.
`MenuBarPanel` is explicitly designed for transient interactions from the status bar. It hides on `resignKey` and never demands app activation.
Combining them into a single class resulted in tangled `if isMiniTimer` lifecycle logic. Separate subclasses allow distinct defaults (e.g., `hidesOnDeactivate` behaviors, animations, shadows, and collection masks).

## 4. Why disabled `hidesOnDeactivate` on `MenuBarPanel`?
Because `LSUIElement` apps are usually deactivated. Setting `hidesOnDeactivate = true` causes the Window Server to instantly suppress the panel upon creation because it assumes the window should not be visible while the app is inactive.

## 5. Why does `cycleAccumulatedWork` use `engine.accumulatedSeconds` rather than summing history fragments?
Session splits (`accumulatedDurationAtLastSplit`) exist purely to produce non-overlapping history records. The engine's `accumulatedDuration` is never reset by a split — it grows continuously from the moment Flow begins until Flow ends. Using `engineSnapshot.accumulatedSeconds` therefore captures the correct total elapsed work time in one value, with no risk of omitting pre-split time. Subtracting `accumulatedDurationAtLastSplit` would cause an undercount. See **ADR-009** for the full execution trace.

## 6. Why does skipping a Flow Extension not credit cycle work?
Skip is treated as session abandonment, consistent with skipping a Focus session (which also earns zero cycle credit). Only a "Take Break" action terminates Flow naturally and commits work toward Long Break eligibility. This follows the product rule: *only naturally completed work earns Long Break credit.* The user still receives a correctly-sized adaptive break. See **ADR-009** for the full rationale and the code locations to change if this decision is ever revisited.

## 7. Long Break Cycle Redesign
The Long Break system was redesigned from a session-count model to a work-duration model in full. The complete feature specification, state model, accumulation rules, dot behaviour, persistence contract, and verified design decisions are documented in `docs/long-break-cycle-redesign.md`.
