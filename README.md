# FleetWidget

An always-on-top 8-bit widget for macOS that shows the live state of every running
Claude Code session, and makes a noise when one of them needs you.

## Quickstart

Requires macOS 12+ and a Swift toolchain (Xcode or the Command Line Tools).

```bash
git clone https://github.com/nicodapta/fleet_widget.git
cd fleet_widget
make install                        # build and copy FleetWidget.app to /Applications
open /Applications/FleetWidget.app
```

The widget appears top-right and starts tracking immediately. There is nothing to
configure and nothing to install into Claude Code — it finds your sessions on its own.

Drag the panel anywhere, `SND`/`MUTE` toggles the alert sound, `X` quits. Position and
mute state persist across relaunches. ⌘Q works too, and clicking the Dock icon snaps the
panel back to the top-right corner if it was left on a display you have disconnected.

To try it without installing:

```bash
make run        # runs from the build products, no bundle
```

To update an installed copy after pulling changes, run `make install` again — the running
copy is not hot-reloaded. `make uninstall` removes it from `/Applications`.

## What it does

If you run several sessions across several terminals, the expensive part is not the
waiting — it is discovering, two minutes late, that a session finished or stopped on a
permission prompt. FleetWidget puts that on screen.

```
  ✳ FLEET                 SND  X
  ────────────────────────────────
  ▞  api-gateway      busy   0:42
  ▚  invoice-sync     input needed
  ▚  atlas-sts        done   0:08
  ▘  spotify-snips    idle  12:34
  ▖  mad-libs-game    shell  1:10
```

- **One row per live session**, labeled by session name or working-directory basename.
- **Five states** — busy, blocked (waiting on you), done, idle, and shell (turn over,
  background command still running).
- **Alerts on the two transitions that mean it is your turn**: a session finishing, and
  a session becoming blocked. Debounced by 750ms so a slash-command menu does not fire
  one, baselined at startup so pre-existing states do not, and latched so a held state
  alerts once rather than every poll.
- **Prominence tiering** — your-turn rows are drawn at full strength, idle ones recede,
  and the header takes the colour of the most urgent thing in the list.

## How it works

Claude Code writes a small JSON record per interactive session to
`~/.claude/sessions/<pid>.json` and rewrites it on every state change. FleetWidget polls
that directory every 500ms, rejects stale records by checking each PID is alive *and*
started when the record says it did (so a reused PID cannot resurrect a dead session),
and runs the resulting status stream through a transition table.

**The widget is strictly read-only.** It never writes to `~/.claude`, never installs a
hook, and never touches your `statusLine` setting, so it cannot break a Claude Code
install. It makes no network requests of any kind. The only things it writes are its own
`UserDefaults` (mute state and panel position).

The registry format is an **undocumented internal contract**. Field names and the status
vocabulary can change in any Claude Code release. Everything this build relies on was
observed against 2.1.240:

- The status vocabulary is small and closed: `busy`, `shell`, `idle`, `waiting`.
- `waiting` outranks `busy` — a session both working and blocked reports `waiting`.
- `shell` is a refinement of `idle`, not of `busy`: the turn is over while a background
  command runs. It does not need you, and is tiered down accordingly.
- `waitingFor` carries a short reason — `sandbox request`, `input needed`, `worker
  request`, `dialog open`, or a string supplied by a permission dialog.
- Records are rewritten on every state change, so no transition is coalesced at the
  source. Debouncing is the widget's job.

Only `pid`, `sessionId` and `cwd` are treated as required; every other field is optional
and its absence degrades the row rather than rejecting it. An unrecognised status renders
as `unknown` rather than crashing. Still, expect to need an update when the format moves.

## Development

```bash
make build     # debug build
make test      # unit tests (FleetWidgetCore, no AppKit needed)
make selftest  # checks header control hit regions against the drawn glyphs
make verify    # test + selftest
make app       # assemble .build/FleetWidget.app
make icon      # regenerate AppIcon.icns from the pixel mark
```

Render the widget to a PNG without a screenshot or a live fleet:

```bash
./.build/debug/FleetWidget --render-preview /tmp/preview.png
```

The logic lives in `FleetWidgetCore`, which is free of AppKit so it can be unit tested
headlessly; `FleetWidget` is a thin AppKit shell over it. There is no binary art in the
repo — sprites, the header mark and the app icon are all generated from the same
string-literal bitmaps, so the icon cannot drift from the widget.

The toolchain target is **Swift 5.6 / Xcode 13.4.1**. Avoid syntax added in 5.7+
(`if let x {` shorthand, regex literals, `Duration`/`Clock`, `@Observable`).

## Not in v1

Token and rate-limit gauges. Utilization never touches disk — it arrives as response
headers and leaves only through the `statusLine` hook payload, so consuming it would mean
owning your `statusLine` setting. Also out: click-to-focus the originating terminal,
cross-machine sessions, and any interaction with a session.

## License

MIT — see [LICENSE](LICENSE).

FleetWidget is an independent personal project. It is not affiliated with, endorsed by, or
sponsored by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic, used here
only to describe what this tool interoperates with.
