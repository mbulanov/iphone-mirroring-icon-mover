# iPhone Mirroring Icon Mover

A small macOS Swift helper for controlled mouse drags in **iPhone Mirroring**, with practical instructions for rearranging **iPhone Home Screen icons**. Includes lessons about Accessibility permissions, app launch identity, screenshot coordinates, and edge dwell timing.

**Experimental release candidate:** automated checks pass, and live tests produced same-page, cross-page, and Spotlight moves. Recovery was required, and the complete layout was not restored: the first page and dock were restored, while the user accepted remaining secondary-page differences. Read the [validation record](docs/validation.md). The helper does not recognize apps, capture screenshots, verify placement, or provide rollback.

## Why this exists

In our session, manual dragging worked while an agent's ordinary UI drag did not reliably move an icon. Posting an actual `mouseDown → mouseDragged → mouseUp` sequence with a hold and controlled timing worked. We moved an app and a folder to another page, then placed three apps in a particular Home Screen row.

The useful part is both the helper and the record of what failed. These are observations from one setup, not a claim that every agent, macOS release, or iPhone behaves the same way.

## Quick start without controlling a phone

The build targets macOS 15 or later and requires Apple's Swift toolchain (`xcrun swiftc`, available with Xcode or Command Line Tools). Compatibility with the minimum target has not been tested; only the environment in the validation record has been exercised. There are no third-party package dependencies.

From the repository root:

```sh
./test.sh
./build.sh
./run.sh --help
./run.sh --dry-run --window-frame 100,80,346,762 \
  --from 127,360 --to 205,1077 --image-size 692,1524 \
  --hold 1 --duration 1.25 --dwell 0.6
```

The last command uses **synthetic window geometry**, prints a JSON plan, and sends no mouse input. Fixture geometry is rejected for live commands. Tests also send no live input and do not rebuild the `.app` in `dist/`.

`build.sh` creates `dist/iPhone Icon Mover RC.app`, ad-hoc signed, with bundle ID `local.iphone-mirroring-icon-mover.rc`. It does not install an app or change permissions. The separate candidate identity avoids overwriting an existing helper named “iPhone Icon Mover”. Build for the host architecture; other architectures have not been tested.

## Set up live use

1. Set up [Apple's iPhone Mirroring](https://support.apple.com/en-us/120421). Connect in the native app and keep the iPhone nearby and locked. Handle authentication yourself.
2. Finish building before granting permission. If you want a stable Applications location, copy **this candidate** to `/Applications/iPhone Icon Mover RC.app`, then use that same copy consistently:

   ```sh
   export ICON_MOVER_APP='/Applications/iPhone Icon Mover RC.app'
   ```

3. In System Settings → Privacy & Security, allow that `.app` under **Accessibility** (called **Device Control and Data Access** on the tested Mac). This permits UI control. Grant it deliberately; the helper does not grant or reset permissions.
4. Run `./run.sh --check`. This checks trust and window geometry without focusing the app or posting input. It cannot establish that the mirrored phone is connected: inspect the window yourself.
5. Capture a fresh image of the **entire Mirroring window**, including its Mac toolbar but excluding any outer screenshot shadow/padding. Record the `X,Y,W,H` frame from `--check` with that image; if the window moves or resizes during capture, start again. Use the exact image dimensions. A phone-content-only crop or a full-desktop image must not be passed as if it were the full window.
6. Compute and inspect a live-window `--dry-run` with `--expect-window-frame X,Y,W,H` from that capture. It requires the same Accessibility permission but sends no input. For the intended gesture, replace `--dry-run` with **`--live`** and keep the expected frame. A changed frame aborts the command.

Always launch the authorized `.app` through `./run.sh`, which uses `open -n -W -a … --args …`. Direct execution of the bundled binary can receive different macOS permission attribution. Rebuilding or re-signing an authorized copy may require renewing its permission; see [troubleshooting](docs/troubleshooting.md).

## Gesture command

The numbers below are **an example from one screenshot**, not coordinates to copy onto another layout:

```sh
./run.sh --dry-run \
  --from 127,360 --to 205,1077 --image-size 692,1524 \
  --hold 1 --duration 1.25 --dwell 0.6
```

For a real move, `--live` also requires `--expect-window-frame X,Y,W,H` recorded with the source image. The expected frame is in macOS screen points; `--from`, `--to`, and `--image-size` are in image pixels. Do not invent a frame or obtain a new one merely to bypass a mismatch.

For a page transition, `--to` is the point near the edge. Optional `--drop X,Y` moves away from the edge after the dwell and releases at that final position.

| Option | Meaning | Default / range |
| --- | --- | --- |
| `--from X,Y` | Source in screenshot pixels | Required |
| `--to X,Y` | Main target in screenshot pixels | Required |
| `--image-size W,H` | Full-window screenshot size | Required, positive |
| `--hold S` | Hold before movement | 0.3 s / 0–3 |
| `--duration S` | Main movement duration | 1.25 s / 0.05–5 |
| `--dwell S` | Remain held at the main target | 0.9 s / 0–1.5 |
| `--drop X,Y` | Optional final target | Main target |
| `--drop-duration S` | Duration of the final movement | 0.3 s / 0.05–2; requires `--drop` |
| `--window-title TITLE` | Observed exact window title | `iPhone Mirroring` |
| `--window-frame X,Y,W,H` | Synthetic frame in screen points | Only with `--dry-run` |
| `--expect-window-frame X,Y,W,H` | Frame recorded with the screenshot | Required with `--live`; can also guard a dry run |

All coordinates and times must be finite. Points must be inside the screenshot. Negative **window origins** are allowed for displays to the left of or above the primary display; negative **image coordinates** are rejected. This only validates the window rectangle, not whether the target is an icon rather than a toolbar button or another control.

Defaults are not calibrated presets. Every successful pickup in the recorded candidate session used `--hold 1`; the two attempts with `--hold 0.3` had an unwanted or absent result. This small sample does not establish a universal threshold. Timing values are nominal waits, and `totalSeconds` excludes activation, posting overhead, and sleep overshoot. An insertion gap can change as icons move, so it does not guarantee that a folder will not form.

The planner maps image pixels into Accessibility screen points, independently for each axis. It rejects an expected-frame mismatch and an image/window aspect-ratio difference over 2%. These checks cannot prove that the image is current or correctly cropped: proportional resizing, stale content, or a similar-aspect crop can evade the ratio check. The live sender allocates all events and a spare release before input, then checks trust, focus, frame, and the current left-button state before moving the pointer and again before pressing. The core runner attempts release after handled errors while holding the button. Forced termination or an OS failure can prevent cleanup. Do not move the window or pointer during a gesture; focus and geometry are not monitored continuously while dragging. The helper does not detect a disconnected phone or an authentication overlay.

## Observe the result

**“Mouse events posted” is not “icon moved”.** `CGEvent.post` provides no delivery acknowledgement. Inspect a new screenshot after every gesture and check the page indicator, icon identity, order, and whether a folder opened. Discard old coordinates after a page change or reflow.

`run.sh` returns the helper's recorded exit code, not just the exit status of `open`. If the helper exits without recording completion, the launcher reports an unknown result rather than success.

| Exit code | Meaning |
| --- | --- |
| 0 | Help/check/plan completed, or events posted; live placement still needs verification |
| 2 | Invalid arguments or geometry |
| 3 | Accessibility trust unavailable |
| 4 | Helper `.app` missing, or Mirroring app/window unavailable or ambiguous; read stderr for the distinction |
| 5 | Activation, focus, geometry, permission, or button-state preflight failed |
| 6 | Event preparation/execution or other runtime failure |
| 7 | Completion status unavailable/invalid; outcome unknown |

## Removing icons did not preserve empty slots

During our test session, removing an icon with **“Remove from Home Screen”** was followed by other icons occupying the available space. This did not reliably preserve an empty slot for the rearrangement task. **Move and reorder icons, then verify the resulting layout.** Live candidate tests also showed additional icons in vacated positions after moves, so moving is not a guarantee against reflow or a promise of reversible changes. We have not isolated the cause or established that this behavior occurs on every iOS version. See the [workflow note](docs/workflows.md#removal-is-not-an-empty-slot-strategy).

## For agents

Read [the skill](skills/iphone-home-screen-icons/SKILL.md) and the relevant [workflow](docs/workflows.md). Keep the whole repository available: the skill uses its launcher and documentation. It is not a self-contained skill archive and does not install an MCP server. Your client must independently provide screenshot/observation capability and permission to operate the computer. This repository does not grant access or override the client's rules.

## Related work and references

- [iphone-control](https://github.com/CHARLESMORGANSOFTWARE/iphone-control): an existing Codex skill and Swift controller for iPhone Mirroring gestures. It covers a broader set of controls.
- [iphone-mcp](https://github.com/yev-yev-yev/iphone-mcp): an MCP server offering mirrored-iPhone screenshots and input operations.
- [Codex drag issue #45198](https://github.com/openai/codex/issues/45198): a separate report of an automated drag failing while manual dragging worked, in an Instagram editor. It does not establish the cause of our Home Screen behavior.
- [Apple: iPhone Mirroring](https://support.apple.com/en-us/120421) and [moving Home Screen items](https://support.apple.com/guide/iphone/iphd2fc8ce30/ios).

This implementation was developed from our session's helper. No source from the related repositories was copied. This is not a claim to have invented CGEvent-based iPhone Mirroring control. Source is distributed under the [MIT license](LICENSE); no prebuilt binary is included.
