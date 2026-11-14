# Home Screen workflows

These recipes started with the **prototype** and were exercised with mixed results in the candidate's [live validation](validation.md). Timings and coordinates require calibration against a fresh image; they are not device-independent presets. Do not describe a trial as fully reversible: record every affected page first, and agree on what to do if recovery produces further changes.

## Before a gesture

Observe the complete Mirroring window, confirm the connected phone's visible state, and identify the exact app or folder. Decide the desired destination and what should happen to any displaced icons. Do not use stale screenshots, a phone-only crop, or a full-desktop image as full-window coordinates.

The tested window image was 692 × 1524 pixels; Accessibility reported a 346 × 762-point window. Each image coordinate therefore scaled by 0.5 before adding the window's screen origin. The helper calculates both axis scales from the supplied dimensions, including on another display. Record the window frame with the image, compare their aspect ratios, and pass that frame with `--expect-window-frame`. An image/frame ratio difference over 2% or an expected-frame mismatch is rejected. This cannot prove image freshness or detect every crop. A dry run shows what will be calculated.

The original controller obtained the window position and size through Accessibility, avoiding dependence on CGWindowList titles for this lookup. The current selector still matches an exact title: use the observed localized title with `--window-title` if needed.

## Reorder within a page

1. Find the icon and a gap where insertion should occur. A destination at another icon's center can create a folder.
2. Enter Home Screen editing through the native UI, or use a sufficiently long initial hold to start dragging. In the prototype, a 1-second hold worked for one same-page move outside editing mode.
3. Plan the move with `--dry-run`. Select source/destination from the current image.
4. Execute one intended gesture with explicit `--live` and the captured `--expect-window-frame`, then inspect the settled screen. Correct unexpected folder creation or page changes before continuing.

If inserting several apps at the same position, reverse order can be useful. In the session, putting Grok Bot after Clock, then Claude before Grok Bot, then X before Claude produced **Clock → X → Claude → Grok Bot**. Verify the order after each insertion rather than assuming the remaining icons stay fixed.

### If a folder unexpectedly opens or forms

Stop and observe the folder contents. Determine whether the moved icon actually entered it. If it did, take a fresh image of the open folder and move that icon out to an observed destination, verifying the result before resuming the original page transfer. If the folder already existed, preserve its other contents. Do not delete a folder or app to repair the layout, and do not assume the folder disappears automatically. When the icon's location is unclear, resolve that uncertainty before another drag.

In the candidate test, extraction with a 0.3-second hold had no visible effect; a 1-second hold followed by movement below the open folder and a 0.9-second dwell extracted the app. After another extraction, the remaining single app appeared individually and the first-page layout was restored. These are observed outcomes, not universal timing or folder-dissolution rules. A gap selected from a still image also did not prevent an unexpected folder during an attempted same-page return.

## Move to another page

1. Start in editing mode with the target app or folder visible.
2. Approach the appropriate screen edge while holding the icon.
3. Dwell only long enough for the intended page transition. The prototype cannot observe the transition while holding, and neither can this candidate.
4. If useful, provide `--drop` to move away from the edge before release. This can reduce edge exposure but is not a guarantee of exactly one page transition.
5. Verify the page dots and the final position. Move a folder as one item when that is the request.

### Edge exposure matters

The original controller fixed the movement duration at 1.25 seconds. A short movement starting close to an edge spent much of that time in the edge zone, then added the dwell. It sometimes crossed two pages. A long approach from the opposite side, using a 0.3-second hold and 0.9-second dwell, crossed one page in a verified case.

This candidate exposes `--duration`, but changing it requires live calibration. Do not assume the same hold/dwell pair gives the same result for an icon in another column. Do not repeatedly replay a failed command using stale coordinates.

| Prototype observation | Full-window image | Source → target | Hold / movement / dwell |
| --- | --- | --- | --- |
| Notes moved one page right in editing mode | 692 × 1524 | (119,1077) → (662,1077) | 0.3 / 1.25 / 0.9 s |
| Spotlight app inserted before the second icon in the bottom row | 692 × 1524 | (127,360) → (205,1077) | 1.0 / 1.25 / 0.6 s |

These coordinates are historical evidence, not commands to run on an unobserved screen.

## Add an installed app from Spotlight

1. Return to the intended Home Screen page.
2. Open Spotlight with the native **View → Spotlight** menu or Command+3. Allow the transition to finish before typing.
3. Search for the app and inspect the result. Similar names can identify different apps: Grok Bot and Grok were separate results in our session.
4. Drag the result to the desired insertion gap. The prototype used a 1-second hold and 0.6-second dwell.
5. If the search overlay remains visible, use the native Home Screen toolbar button and inspect again. In our session, the first click sometimes only restored focus; a second was needed.
6. Confirm the app is present on the intended page and not inside a newly created folder.

The helper does not type or search. In the observation client, checking the keyboard layout and sending individual keys with a 100 ms hold worked when `typeText` did not. This is a client-specific workaround, not a requirement of all iPhones.

## Removal is not an empty-slot strategy

We tried **Remove App → Remove from Home Screen**, preserving the installed apps. Other icons subsequently occupied the freed positions during the same rearrangement session. Removing an icon did not reliably keep a chosen slot empty.

For this workflow, use actual moves and insertions, then inspect the reflow. Remove an icon from Home Screen only when removal is requested or is explicitly part of an approved test; do not use it merely to reserve a blank slot. Candidate testing also observed other icons in positions vacated by moves. Moving is therefore not a guarantee of reversible changes. The observed refill might depend on previous moves, overflow, or other state; those causes were not isolated. We did not establish a universal iOS rule or a universal way to disable it.

The inspected Home Screen settings did not expose a relevant switch. “App Library Only” concerns where newly downloaded apps appear; it was not tested as a remedy for this behavior.

## Finish

Exit editing mode and inspect the normal Home Screen. Verify each requested icon/folder and its page. Report any remaining mismatch. Do not change the helper's existing permission merely as cleanup if the user wants to continue using it.
