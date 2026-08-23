## Context

Claude Code maintains an on-disk registry of its own running sessions that nothing local
consumes. Each interactive session writes `~/.claude/sessions/<pid>.json`:

```json
{
  "pid": 25075,
  "sessionId": "57b44880-8bed-43f1-a459-d4805a334e8a",
  "cwd": "/Users/x/Dev/claude_widget",
  "startedAt": 1787434303472,
  "version": "2.1.240",
  "kind": "interactive",
  "entrypoint": "cli",
  "messagingSocketPath": "/tmp/cc-socks/25075.sock",
  "name": "claude-widget-43",
  "nameSource": "derived",
  "status": "busy",
  "updatedAt": 1787434308766,
  "statusUpdatedAt": 1787434308766
}
```

This file is the entire data source for v1. The behaviour recorded below was established by
observing these records across many sessions on Claude Code 2.1.240. None of it is
documented, and all of it is load-bearing for this design, so it is written down here —
as observed behaviour, which is the only thing the widget is entitled to rely on.

**The status vocabulary is closed and small.** Only four values were ever observed:
`busy`, `shell`, `idle`, `waiting`.

**`waiting` outranks `busy`.** A session that is both working and blocked on the user
reports `waiting`. Absent anything to wait on, a session reports `busy` while a turn is in
flight — including while only a delegated subagent is running — and `idle` otherwise.

**`waitingFor` has a fixed vocabulary**, resolved in a stable priority order. The observed
values, in that order:

| `waitingFor` | raised by |
| --- | --- |
| `sandbox request` | a sandbox permission prompt |
| `input needed` | an `AskUserQuestion` prompt |
| *(dialog-supplied string)* | permission prompts, which name what they want |
| `worker request` | a worker awaiting approval |
| `dialog open` | any local slash-command UI holding the screen |

Treat the list as open in code: an unrecognised string is displayed verbatim rather than
mapped, so a new prompt kind degrades to a label instead of a crash.

**The record is rewritten on every transition.** Writes track changes to the status and
`waitingFor` pair, so transitions are not sampled or coalesced at the source — every state
change reaches disk. Debouncing is the widget's job, not something inherited for free.

**`shell` is a refinement of `idle`, not of `busy`.** It appears when the model's turn is
over while a background command is still running. That is not a state that needs the user,
and the widget tiers it accordingly.

Two facts shaped scope. First, rate-limit utilization is **never persisted to disk**; it
arrives as `anthropic-ratelimit-unified-*` response headers, lives in session memory, and
exits only through the `statusLine` hook payload as
`rate_limits.{five_hour,seven_day}.used_percentage`. Second, consuming that would require
the widget to own the user's `statusLine` setting. Both pushed the token gauge out of v1.

## Goals / Non-Goals

**Goals:**

- Answer "does any terminal need me right now?" at a glance, without tabbing.
- Alert on the two transitions that mean the user's turn: finished, and blocked.
- Zero configuration. Works on first launch with nothing installed or edited.
- Read-only with respect to Claude Code. The widget cannot break a Claude install.
- 8-bit character, with an art budget appropriate to a personal toy.

**Non-Goals:**

- Token consumption and rate-limit gauges. Deferred; requires owning `statusLine`.
- Click-to-focus the originating terminal. Requires walking the process tree to the terminal
  app and then using Accessibility APIs to raise the right window — disproportionate for v1.
- Focus-aware alert suppression. macOS can report the frontmost application but not which
  terminal *pane* holds a given session, so suppression would be unreliable.
- Interacting with sessions — answering prompts, sending input, driving the peer socket.
- Cross-machine or remote sessions. Local registry only.
- Historical data, trends, or persistence of past sessions.

## Decisions

### Poll on a timer rather than watch the filesystem

Registry files are replaced by atomic rename. A watch bound to a single file's inode keeps
watching the old, now-unlinked inode and silently stops receiving updates — a failure mode
that presents as "the widget froze" with no error. Directory-level watching avoids that but
adds coalescing and re-arming logic.

Polling `readdir` plus a handful of small JSON reads every 500ms is negligible work, has no
such failure mode, and makes the tick a natural place to also run liveness checks and
transition diffing. For a personal toy this is the correct engineering call, not a shortcut.

**Trade-off:** up to 500ms of added alert latency. Irrelevant against the human response
time this is competing with.

### Collapse "done" and "blocked" into one alert concept, with two kinds

From the user's chair both mean *go look at this terminal*, so they share one detection path,
one debounce, one latch, and one sound. They differ only in presentation, because a blocked
session is making no progress while a finished one is merely waiting. Modelling them as two
kinds of one event, rather than two independent features, keeps the alerting logic single.

### Debounce transitions by 750ms

Opening any local slash-command UI reports as `waiting`, so a menu the user dismisses at
once would alert. Requiring a status to hold before it alerts eliminates that false positive
along with any other transient flicker, at the cost of latency well under human reaction
time. 750ms is comfortably longer than a UI frame and shorter than a deliberate pause.

### Verify liveness by PID, and guard against PID reuse

A crashed session leaves its registry file behind indefinitely, so file presence is not
evidence of a live session. Checking the PID is alive handles the common case. Because
macOS recycles PIDs, a stale file can also collide with an unrelated new process; comparing
the record's `startedAt` against the process's actual start time rejects that. Without the
second check a dead session could appear live indefinitely.

### Normalize unknown statuses instead of rejecting or guessing

The status enum is closed today but is an internal detail that may grow. Mapping unrecognized
values to an explicit `unknown` that renders but never alerts means a future Claude Code
release degrades to a visibly-odd row rather than to spurious chimes or a vanished session.

### Baseline the first tick

Alerting is defined on transitions, and at startup there is no previous state to transition
from. Treating the first tick as a baseline avoids chiming once per already-idle session at
launch — which is the normal case, since most sessions are idle most of the time.

### Swift with an `NSPanel`, no dependencies

The always-on-top, non-activating, all-Spaces behavior is a direct expression of three
`NSPanel` properties:

```swift
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
panel.styleMask = [.nonactivatingPanel, .borderless]
panel.isFloatingPanel = true
```

Electron and Tauri were considered and rejected. Their advantage is CSS-driven animation,
which this design does not need; their cost is a runtime and a toolchain. A ~180MB Electron
process whose job is to be an unobtrusive background observer is a poor trade for a toy.

### Sprites as string-literal bitmaps in source

```swift
let busyFrame0 = ["..████..",
                  ".█○..○█.",
                  "█......█",
                  "█.▄▄▄▄.█",
                  ".██████."]
```

Rendered as a grid of filled rects with no interpolation. This gives authentic hard-edged
pixels at any scale, keeps art diffable in git and editable in the same file as the logic,
and removes the asset pipeline entirely. Adding an animation frame is a matter of seconds.

### Prominence by opacity rather than by collapsing rows

Most sessions are idle most of the time, so an untiered widget is a mostly-static block that
the eye learns to skip. Dimming idle rows and reserving full opacity plus motion for
attention-needing ones achieves the same "quiet by default" effect as a collapse/expand
mechanism, with no interaction state to manage.

## Risks / Trade-offs

**The registry format is an undocumented internal contract.** `~/.claude/sessions/*.json` is
not a public API; field names, the status vocabulary, and the directory itself may change in
any Claude Code release. Observed against 2.1.240. Mitigations: tolerate malformed and
partial records, normalize unknown statuses rather than failing, and render an empty state
rather than crashing when the directory is missing. The realistic failure mode is that a
future release makes the widget show nothing — annoying, and recoverable, but not silent
data corruption. Accepted knowingly; this is the only route to the data without hooks.

**Alerts fire for the terminal the user is already looking at.** Focus-aware suppression is a
non-goal because macOS cannot attribute focus to a terminal pane. If this proves irritating
in daily use, the mute toggle is the escape hatch and per-session muting is the natural
follow-up. Starting with visual-plus-soft-sound rather than an assertive alert limits the
damage.

**Polling wakes the CPU on a 500ms cadence.** The work per tick is trivial, but a timer that
never idles has a small persistent power cost on battery. Not addressed in v1; coalescing the
timer or backing off when no session has been busy for some time is an available lever.

**750ms debounce could mask a genuinely fast transition.** A session that enters and leaves
`waiting` within the window produces no alert. This is the intended trade — such a
transition resolved without the user — but it does mean the alert stream is not a complete
record of every dialog that ever opened.

**PID-reuse detection depends on reading process start times.** If that is unavailable or
unreliable for some process, the check must fail toward excluding the session rather than
including it, so that a stale record cannot masquerade as live.
