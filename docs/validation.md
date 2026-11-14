# Validation record

Date: 2026-11-14. One local Mac/iPhone setup. This is an evidence record, not a compatibility guarantee.

## Environment recorded during candidate preparation

| Item | Recorded value |
| --- | --- |
| macOS | 27.2.1, build 26B131 |
| Architecture | arm64 |
| Swift | Apple Swift 6.4.2 |
| iPhone Mirroring | 2.1, build 126.12.5.2 |
| Mirroring UI title | English: `iPhone Mirroring` |
| iOS / iPhone model | Not recorded in the original experiment |

Version values above came from local system/tool output, not inferred from a release schedule. Other systems, UI languages, Intel builds, resized windows, and multi-display live gestures have not been tested.

## Prototype: visually verified on the connected phone

- Moved Notes and an entire Music folder from the first Home Screen page to the second.
- Reordered a bottom-row icon within the first page.
- Inserted installed apps from Spotlight and verified the final row: Clock, X, Claude, Grok Bot.
- Observed a two-page overshoot with short edge approaches.
- Observed other icons fill freed positions after “Remove from Home Screen”. No clean causal experiment was performed for that behavior.

These observations predate the new parser, planner, launcher protocol, error handling, and adjustable duration. They do **not** establish the revised candidate's live behavior.

## Revised candidate: automated / no-input checks

- Swift compilation and ad-hoc `.app` signature verification passed.
- 21 Swift tests passed: pixel-to-screen scaling, bounds, press/drag/release ordering, timing, final drop, fixture restriction, invalid/duplicate/malformed arguments, non-finite numbers, explicit live mode and expected-frame checks, aspect-ratio mismatch rejection, prepared-event mapping and spare release, preflight failure, focus change before press, release after injected send/wait failures, explicit cleanup failure, absence of duplicate release, CLI help, offline JSON plan, and completion-status recording.
- 6 shell tests passed: missing/malformed completion, helper failure propagation, successful output, missing helper, and reserved status-file rejection. These tests source the launcher's functions and use temporary fixtures; they do not invoke LaunchServices.
- The event tests use an injected sender. CLI tests use help, invalid arguments, or offline dry-run. They do not activate Mirroring or send real mouse events.
- LaunchServices launcher checks passed: offline dry-run produced the expected mapped points; an unknown flag returned exit 2; `--check` without the candidate's grant returned exit 3. No permission was granted by these checks.
- The skill frontmatter validator passed, and local documentation links were checked.

## Candidate live validation: mixed results

Live testing was performed on 2026-11-14 with the user's permission. The tested installed executable had SHA-256 `d8579d0473453b81f734c17e731be55fe9e7c7ef9b315a5f0796001452294aee`. Its source and signature were not changed during the device tests. The iOS version and hardware model were not independently verified; a device's editable name is not reliable model evidence.

**All three gesture types produced visually verified moves, but full rollback failed.** The first Home Screen page and dock were restored to their recorded starting arrangement. Secondary pages retained differences, including a displaced folder and additional icons in vacated positions. The user explicitly chose to keep those differences and stop further gestures. This is experimental functionality, not deterministic or unattended layout restoration.

| Check | Observed result |
| --- | --- |
| Accessibility and launcher | An enabled toggle initially still produced exit 3. Removing/re-adding only the intended candidate from Applications repaired access. With Mirroring closed, `--check` then returned 4; after opening and authenticating Mirroring it returned 0. No global permission reset was used. |
| Live-window dry run | Passed with the frame recorded alongside a fresh full-window screenshot. No input was posted. |
| Same-page move | Moving Claude before Instagram worked. The attempted return formed a folder containing three apps. Extracting Instagram and then Grok Bot recovered the original first-page arrangement; the remaining Claude icon appeared individually. These were two successful extractions after one unsuccessful extraction attempt. This is not a clean round-trip pass. |
| Cross-page move | Clock moved from page 1 to page 2 and back. Shorter return timing initially produced no page transition. Other icons subsequently occupied freed positions and required additional recovery. This is not a full-layout rollback pass. |
| Folder recovery and edge behavior | A later folder transfer overshot by one page despite a final `--drop` away from the edge. Recovery placed it on the intended page. `--drop` does not guarantee a single-page transition. |
| Spotlight insertion | Only Clock's Home Screen icon was removed, leaving the app installed. Dragging its exact Spotlight result restored its original first-page position. The overlay required two native Home Screen clicks to dismiss. No duplicate Clock icon was observed on the three inspected pages; this was not an exhaustive library-wide audit. |
| Final observation | First page and dock matched the initial arrangement outside editing mode. Secondary-page differences remained and were accepted by the user. No apps were uninstalled. |

### Timing evidence, not presets

All points below refer to one 692 × 1524 full-window image with a 346 × 762-point AX frame. Coordinates must be re-derived from a fresh image on another run.

The following table lists all 14 candidate live gesture invocations in execution order. Native clicks, page-navigation swipes, search typing, and the explicitly approved removal of Clock's Home Screen icon are separate observation-client actions, not helper gestures. App names irrelevant to the method are omitted.

| # / Gesture | Image source → target | Hold / duration / dwell (seconds) | Optional drop / duration | Observed outcome |
| --- | --- | --- | --- | --- |
| 1. Same-page insertion | (422,1077) → (205,1077) | 1 / 1.25 / 0.6 | None | Claude inserted before Instagram |
| 2. Attempted same-page return | (270,1077) → (505,1077) | 0.3 / 1.25 / 0.6 | None | Unexpected three-app folder |
| 3. Instagram extraction attempt | (498,607) → (205,1170) | 0.3 / 1.25 / 0.6 | None | No visible effect |
| 4. Instagram extraction | (498,607) → (205,1170) | 1 / 1.25 / 0.9 | None | App extracted to first page |
| 5. Grok Bot extraction | (194,607) → (575,1170) | 1 / 1.25 / 0.9 | None | App extracted; remaining Claude appeared individually; first page restored |
| 6. Clock, page 1 → 2 | (119,1077) → (662,1077) | 1 / 1.25 / 0.9 | None | One-page transition |
| 7. Clock return attempt | (119,1077) → (30,1077) | 1 / 0.65 / 0.6 | None | No page transition |
| 8. Clock return | (119,1077) → (24,1077) | 1 / 1.25 / 1.2 | None | Returned to page 1; secondary-page differences discovered |
| 9. Additional app, page 2 → 3 | (119,258) → (662,258) | 1 / 1.25 / 0.9 | None | One-page transition; another icon appeared in the vacated page-2 position |
| 10. Folder, intended page 3 → 2 | (270,258) → (24,1077) | 1 / 1.25 / 1.2 | (575,1170) / 0.4 | Overshot to page 1 |
| 11. Folder, page 1 → 2 attempt | (574,1077) → (662,1077) | 1 / 0.4 / 0.6 | (575,1170) / 0.25 | No page transition |
| 12. Folder, page 1 → 2 | (574,1077) → (662,1077) | 1 / 0.4 / 0.9 | (575,1170) / 0.25 | One-page transition |
| 13. Displaced Grok Bot return | (119,258) → (24,1077) | 1 / 1.25 / 0.9 | (575,1170) / 0.25 | Original first-page position restored |
| 14. Clock from Spotlight | (127,360) → (60,1170) | 1 / 1.25 / 0.6 | None | Original first-page position restored after dismissing search |

For gesture 1, the planned waits totaled **0.15 s pointer settling + 1 s hold + 1.25 s movement + 0.6 s dwell = 3.0 seconds**; the entire launcher invocation took 3.63 seconds. The latter includes launch, activation, event handling, and process overhead. It is **not** a measurement of the gesture alone. Activation preflight did not fail during these observed live attempts; this does not establish reliability on other systems.

### Open validation limits

- The cause of the unexpected folder, refill behavior, and secondary-page differences has not been isolated. Do not call these a confirmed iOS defect or claim a universal remedy.
- A fixed event sequence cannot inspect a page transition while the button is held. Timing and a final drop point do not provide a guaranteed destination page.
- There is no automatic layout snapshot, transaction, rollback, or semantic success detector. Record all pages whose exact restoration matters before testing; this session did not record a complete initial layout of every page.
- The user ended device testing after accepting the remaining differences. Do not treat acceptance as evidence that rollback worked.

### Non-posting timestamp probe

A separate local probe created a `CGEvent` without posting it, read its timestamp, waited about 205 ms, and read it again. Both reads returned **0**. Explicitly assigning a monotonic nanosecond value could be read back unchanged. No input events were posted, and the candidate was not modified.

This observation does not support the assumption that event construction automatically stores the current clock value. Apple defines [CGEventTimestamp](https://developer.apple.com/documentation/coregraphics/cgeventtimestamp) in nanoseconds since startup, but this probe does not establish how a zero timestamp is handled on posting or what Mirroring consumes. It therefore neither establishes nor excludes a timestamp-related input issue. There is no evidence that timestamp changes would fix the observed folder or reflow behavior; no speculative patch was made.
