# Troubleshooting

Keep observations separate from explanations. A remedy that worked in one session is not proof of the underlying OS cause.

| Symptom | What to check / what helped | Evidence and limits |
| --- | --- | --- |
| Manual dragging works, an agent's drag does not | Use an actual held `mouseDown → mouseDragged → mouseUp` sequence; verify hold and movement timing | Worked with the prototype; ordinary UI drag behavior varies by client |
| Accessibility toggle is enabled but the helper reports no access | Check the exact app copy, bundle identity, and LaunchServices launch path; consider whether it was rebuilt or re-signed | In our session, removing only that helper's permission entry and adding the intended app again repaired access; do not reset all TCC permissions |
| Window lookup fails | Open and connect Mirroring; use its observed exact title; ensure exactly one matching window is available | App lookup uses bundle ID, window selection uses its title; localization is not automatic |
| A CGWindowList-based lookup cannot read the needed window title | Use Accessibility window geometry for this helper | This avoids a Screen Recording request solely for geometry; a separate screenshot tool may still need its own permission |
| A command exits successfully but the icon stays put | Inspect the UI and connection state; success means events were posted, not that iOS accepted them | The helper cannot acknowledge remote delivery or app placement |
| Icon crosses two pages | Reduce time in the edge zone; account for approach distance, movement duration, and dwell; optionally move away before release | Prototype and candidate overshoots were observed. A candidate transfer overshot despite `--drop`; it is not a one-page guarantee |
| A folder opens or forms | Stop using old coordinates, inspect the new state, and select an insertion gap | The helper only knows a window rectangle, not icon/folder semantics |
| Clicking a menu action opens an underlying icon's menu | Use a short click for menu selection, not a long press | Approximately 100 ms worked for selection in our observation client |
| Search text is missing or in the wrong alphabet | Verify focus and input language; in our client, individual keypresses worked after checking the layout | This may be a client/input-bridge behavior |
| Screenshot shows the old screen or an animation | Observe again after the transition; do not blindly repeat the action | Observed during native app and Spotlight transitions |
| Removing or moving an icon leaves another in its former space | Inspect all affected pages; do not repeat removals to reserve a blank slot or promise automatic rollback | Observed during prototype and candidate work; cause and portability were not established. Candidate testing ended with accepted secondary-page differences |

## App identity and rebuilds

Build the `.app`, choose its stable location, grant the intended copy access, and launch that copy through `run.sh`/`open`. Do not rebuild the installed working helper as part of an unrelated test. The candidate has a distinct bundle ID from the prototype.

Ad-hoc builds have a changing code signature when their executable changes. Our access problem followed rebuilds, but we did not isolate every aspect of macOS permission attribution. If re-adding permission is necessary, do it for the single intended app with user authorization. This repository does not edit the TCC database or provide a blanket reset command.

`test.sh` compiles test executables under `.build/`; it does not rebuild, re-sign, or install the app in `dist/`. `build.sh` does rebuild the candidate and should be run before granting that copy access.

## Launcher completion

`open -W` alone does not relay the helper's exit status. `run.sh` gives the helper a temporary status file and reads its exit code after completion. It also prints the helper's stdout/stderr. A missing status file is an unknown outcome (exit 7), never evidence that the move succeeded.

On the tested Mac, a very short-lived invocation sometimes made `open` print “Unable to block on application (GetProcessPID() returned …)”. The completed helper status was still recorded; offline dry-run returned 0, invalid input returned 2, and missing trust returned 3. The launcher uses that completed status when present. Without it, inspect the result instead of assuming success.

For manual diagnosis, inspect the reported error and get a new screenshot before any retry. The sender prepares all CGEvents before mouse-down; allocation errors therefore occur before input. The generic runner also attempts a release after handled errors during a gesture. It cannot recover from every forced termination or OS failure, and it does not continuously monitor focus or disconnects while dragging.

## Remove the candidate

When the user wants to stop using it, revoke **iPhone Icon Mover RC** in the relevant System Settings list and remove that candidate app copy. This is separate from any previously installed **iPhone Icon Mover**. Do not revoke or remove the older helper unless that is also requested.
