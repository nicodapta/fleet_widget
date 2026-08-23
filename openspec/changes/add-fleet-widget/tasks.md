## 1. Project Scaffold

- [x] 1.1 Create a Swift package producing a macOS app target (`FleetWidget`), no third-party dependencies, with a deployment target covering the current macOS release
- [x] 1.2 Configure the bundle as an accessory app (no Dock icon, no menu bar presence) so it never appears in the app switcher
- [x] 1.3 Add a `Makefile` or script for `build` and `run` during development, and a step that produces a launchable `.app`
- [x] 1.4 Record build and run commands in `CLAUDE.md`

## 2. Session Discovery

- [x] 2.1 Define the `SessionRecord` model matching the observed registry schema, with every field optional except `pid`, `sessionId`, and `cwd`
- [x] 2.2 Implement registry enumeration over `~/.claude/sessions/*.json`, returning an empty set when the directory is absent
- [x] 2.3 Implement per-record JSON decoding that skips malformed or partially written records without affecting other sessions
- [x] 2.4 Implement PID liveness checking, including the `startedAt` versus process-start-time comparison that rejects recycled PIDs, failing toward exclusion when process start time is unavailable
- [x] 2.5 Implement status normalization to `busy` / `idle` / `waiting` / `shell` / `unknown`
- [x] 2.6 Implement display-label derivation from `name`, falling back to the basename of `cwd`
- [x] 2.7 Implement elapsed-time derivation from `statusUpdatedAt`, reporting unavailable rather than zero when the field is missing or unparseable
- [x] 2.8 Wire the 500ms poll timer driving the above into a published live-session set
- [x] 2.9 Unit-test discovery against fixture directories: healthy records, stale record with dead PID, recycled PID, truncated JSON, missing required fields, unknown status value, absent directory

## 3. Turn Alerts

- [x] 3.1 Implement per-session status diffing across ticks, retaining last-known status for sessions skipped due to malformed reads
- [x] 3.2 Implement your-turn classification: `busy → idle` yields `done`, any status `→ waiting` yields `blocked` carrying `waitingFor`
- [x] 3.3 Ensure `idle → busy`, transitions into `shell`, and transitions involving `unknown` raise nothing
- [x] 3.4 Implement the 750ms debounce requiring a status to hold before its alert is raised
- [x] 3.5 Implement first-tick baselining so pre-existing statuses at launch raise no alerts
- [x] 3.6 Implement alert latching, clearing a session's latch when it leaves the alerting status
- [x] 3.7 Implement sound playback on alert and a mute toggle persisted across launches
- [x] 3.8 Unit-test the transition table with a scripted status sequence: silent start, done, blocked-then-done in one turn, sub-debounce flicker, long idle without repeat, re-alert after reuse

## 4. Fleet HUD

- [x] 4.1 Create the `NSPanel` with floating level, non-activating borderless style mask, and `[.canJoinAllSpaces, .stationary]` collection behavior
- [x] 4.2 Verify the panel stays above other windows and does not steal focus on click
- [x] 4.3 Implement default corner placement, drag-to-move, position persistence, and off-screen fallback to the default corner
- [x] 4.4 Build the pixel-bitmap renderer that draws string-literal sprites as a grid of rects with no interpolation
- [x] 4.5 Author multi-frame sprites for `busy`, `waiting`, and `idle`, plus a static sprite for `shell` and `unknown`
- [x] 4.6 Implement frame advancement driven off a display-linked or timeline source
- [x] 4.7 Build the per-session row: sprite, display label, status caption, elapsed time, and the `waitingFor` reason when blocked
- [x] 4.8 Implement stable row ordering so a session does not move when its status changes
- [x] 4.9 Implement opacity tiering across alerting, busy, and idle rows
- [x] 4.10 Implement the empty state shown when no live sessions are found
- [x] 4.11 Implement the quit and mute affordances reachable without a Dock or menu bar item

## 5. Verification

- [x] 5.1 Run the widget against real concurrent Claude Code sessions and confirm each status renders correctly
- [x] 5.2 Confirm a `done` alert fires on turn completion and a `blocked` alert fires on a permission prompt
- [x] 5.3 Confirm opening a local slash-command dialog does not produce a false alert
- [x] 5.4 Confirm a force-killed session disappears from the widget
- [ ] 5.5 Confirm cross-Space persistence, always-on-top behavior over a fullscreen window, and position restore across a relaunch
  - [x] Always-on-top over ordinary windows — verified above the editor
  - [x] Position restore across relaunch, and fallback to the default corner when the saved position is off every display
  - [ ] Cross-Space persistence and behavior over a fullscreen window — set via `collectionBehavior`
        (`.canJoinAllSpaces`, `.fullScreenAuxiliary`) but not exercised; needs a human to switch Spaces
- [x] 5.6 Note the Claude Code version verified against in `CLAUDE.md`, alongside a pointer to the registry format this depends on
