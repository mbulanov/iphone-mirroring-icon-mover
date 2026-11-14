---
name: iphone-home-screen-icons
description: Rearrange iPhone Home Screen icons and folders through macOS iPhone Mirroring using controlled held mouse drags. Use when the user requests icon placement and a connected mirrored phone is available; includes Spotlight insertion and recovery from page reflow.
---

# Rearrange Home Screen icons

Keep this repository available, including `run.sh` and `docs/`. This skill alone is not an installable controller. Read [validation](../../docs/validation.md) before relying on the candidate's tested status, and [workflows](../../docs/workflows.md) for the requested gesture type.

Use your client's observation tools for screenshots and ordinary native UI. The helper only posts a planned mouse gesture; it cannot recognize icons, take a screenshot, or verify success. Follow the client's policy for any separate input mechanism and new system permission. A skill file is not authorization.

## Procedure

1. Confirm the desired apps/folders, page, and order from the request. Record every page whose restoration matters. Do not promise a reversible trial: the live candidate restored the first page and dock but left accepted differences elsewhere. Open the connected Mirroring session; leave authentication to the user and keep the physical phone locked.
2. Use the authorized app copy through the repository's `run.sh`. Inspect its `--check` result. Do not rebuild a working authorized copy just to run it. A separate candidate may need its own grant.
3. Observe a fresh image matching the **whole AX window**, including its toolbar and excluding external screenshot padding. Record the frame from `--check` with that image; restart capture if the window changes. Determine image dimensions and source/destination points, and check the image/window aspect ratios. Never transplant example coordinates to an unobserved layout.
4. Plan with `--dry-run --expect-window-frame X,Y,W,H` using the recorded frame. Use an insertion gap rather than another icon's center when a folder is not intended. Default timing is an example; a short approach to an edge can cross two pages. Consider movement duration as well as dwell.
5. Execute one intended gesture with explicit `--live` and the same expected frame, then obtain fresh state. Check exact app identity, page dots, folder state, and order. Discard all old coordinates after a reflow, page transition, resize, interruption, or reconnect. One failed attempt is a reason to inspect and revise, not replay blindly.
6. For an installed app, Spotlight insertion is an available workflow. Similar names may identify different apps. Inserting several apps at one position in reverse order can produce the desired final row.
7. Finish outside editing mode and verify the requested layout visually. Report any mismatch. Preserve the user's decision about keeping or revoking existing helper access.

## Important findings

If a folder unexpectedly opens, inspect its contents and get fresh state. Check whether the moved icon entered the folder; if it did, recover that icon to an observed destination using fresh observations before resuming the requested transfer. Preserve pre-existing folder contents and do not delete apps/folders as a repair. Follow [the recovery procedure](../../docs/workflows.md#if-a-folder-unexpectedly-opens-or-forms); its successful recovery examples are not universal presets. If successive recovery gestures create further differences, stop, report the exact remaining changes, and resolve the acceptable scope with the user.

- Use real held `mouseDown → mouseDragged → mouseUp` input when an ordinary client drag fails. An exit code only reports command execution; it never proves the phone accepted the gesture.
- Do not remove icons merely to keep empty slots. In the recorded session, other icons filled freed positions after removals and moves. Prefer moving/reordering for layout changes, but do not promise immunity from reflow. Treat this as an observed workflow limitation, not a universal iOS rule; remove an icon only when requested or explicitly included in an approved test.
- If permission appears enabled but access fails after a rebuild, inspect the exact app copy and launch identity. See [troubleshooting](../../docs/troubleshooting.md); never reset all permissions as a shortcut.
- A disconnected phone or authentication overlay can still occupy a correctly sized window. A successful `--check` is insufficient without visual confirmation.

Named arguments and timing bounds are documented in [README](../../README.md#gesture-command). Run commands from the repository root or use absolute paths to its launcher. No command in this skill installs software, grants system access, deletes apps, or publishes content automatically.
