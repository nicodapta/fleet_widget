## Why

Running several Claude Code terminals at once means constantly tabbing around to answer
one question: **is any of them waiting on me?** A session that finishes, or that stalls on a
permission prompt, burns wall-clock until it is noticed. The cost is highest for the blocked
case — a session sitting on an unanswered dialog does nothing at all.

Claude Code already publishes everything needed to answer this. Each running session writes
`~/.claude/sessions/<pid>.json` containing its `cwd`, a derived `name`, and a live `status`
field (`busy` | `idle` | `waiting` | `shell`), rewritten on every state transition. Nothing
consumes this locally today.

This change adds a small always-on-top macOS widget that reads that registry and renders
each live session as an 8-bit character, alerting when a session becomes the user's turn.

## What Changes

- **New macOS app** (`FleetWidget`) — a borderless, non-activating always-on-top panel that
  sits in a screen corner, floats above all windows, and follows the user across Spaces.
- **Session polling** — reads `~/.claude/sessions/*.json` on a 500ms tick, verifies each PID
  is alive, and maintains the live session set.
- **Your-turn alerting** — detects the two transitions that mean "go look at this terminal"
  (`busy → idle` = done, `* → waiting` = blocked) and raises a visual alert plus an
  optional sound.
- **8-bit rendering** — each session is drawn as a pixel-art sprite with per-state animation.
  Sprites are defined as string-literal bitmaps in source; there is no asset pipeline.

Explicitly **not** in this change: token/rate-limit gauges. Those are only reachable via the
`statusLine` hook payload, which would require the widget to own the user's `statusLine`
setting. Deferred so v1 stays a pure read-only observer with zero configuration.

## Capabilities

### New Capabilities

- `session-discovery`: Reading the Claude Code session registry, verifying process liveness,
  and maintaining the current set of live sessions with normalized status.
- `turn-alerts`: Detecting the state transitions that mean the user's attention is required,
  debouncing transient flicker, and raising alerts.
- `fleet-hud`: The always-on-top pixel-art panel — window behavior, per-session rows,
  sprite animation, and visual prominence tiering.

### Modified Capabilities

None. This is a greenfield repository.

## Impact

- **New code**: a Swift package producing a macOS `.app`. No third-party dependencies.
- **External contract consumed**: `~/.claude/sessions/<pid>.json`, an undocumented internal
  file format of Claude Code (observed on 2.1.240). Read-only.
- **No writes outside the app's own domain.** The widget never modifies `~/.claude`,
  `settings.json`, hooks, or the user's `statusLine`. It cannot break a Claude Code install.
- **Permissions**: none beyond default (no Accessibility, no Screen Recording, no network).
