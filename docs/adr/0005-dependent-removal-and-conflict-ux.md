# ADR 0005: Removing a service others depend on, and resolving conflicts, require explicit confirmation

**Status:** Accepted

## Context

Spec decision point 4: *What happens when removing a service that others depend on?* For example, removing State Criminal while County Criminal is selected. Flow 3 also says that adding a 10-Panel while a 5-Panel is selected should "replace it (or show error)".

## Options

| Option | Problem |
|---|---|
| Block only | The user has to work out the right order to remove things |
| Cascade silently | Services disappear without the user agreeing to it |
| **Block, and offer the cascade with a clear explanation** | One extra click, but nothing changes without the user seeing exactly what will happen |

## Decision

**Removing a service that others depend on** opens a modal confirmation that names every affected service and the total count:

> **Remove State Criminal Search?**
> County Criminal Search and Federal Criminal Search require State Criminal Search, so they will be removed too. 3 services will be removed from your package in total.
>
> [Cancel - keep everything] [Remove 3 services]

**Adding a service that supersedes a selected one** (10-Panel over 5-Panel) uses the same pattern:

> **Replace Drug Test (5-Panel)?**
> Drug Test (10-Panel) conflicts with Drug Test (5-Panel) - the 10-Panel includes all 5-Panel tests. Adding Drug Test (10-Panel) will remove Drug Test (5-Panel) from your package.
>
> [Cancel - keep Drug Test (5-Panel)] [Replace with Drug Test (10-Panel)]

**Adding the lesser service while the greater one is selected** (5-Panel while a 10-Panel is selected) isn't offered as a replacement, because it would lose coverage. It shows the yellow "Service conflict detected" banner instead.

**Adding a service whose prerequisite is missing** shows the reason inline on the card ("⚠ Requires State Criminal Search"). The add button looks disabled but stays clickable (`aria-disabled`), and clicking it shows the red banner with the spec's wording: *"County Criminal Search requires State Criminal Search to be added first."*

Details:
- **Cancel** is focused first, and **Escape** or a click outside the dialog also cancels, so the safe choice is always the default.
- The domain follows the same rules. `Package#remove(code, cascade: false)` refuses with a `has_dependents` violation that lists the dependents, and `Package#add(code, replace_conflicts: false)` refuses a conflict. The confirmed choice is passed in as `cascade: true` or `replace_conflicts: true`.
- Dependents are found transitively, so a future chain of rules (A requires B requires C) cascades correctly.
