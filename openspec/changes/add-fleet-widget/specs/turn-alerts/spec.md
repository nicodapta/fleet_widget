## ADDED Requirements

### Requirement: Your-Turn Transition Detection

The system SHALL raise a your-turn alert for a session when it observes either of these
status transitions:

- `busy → idle` — the session finished its turn (**done**)
- any status `→ waiting` — the session is blocked on the user (**blocked**)

Both transitions mean the same thing from the user's perspective: this terminal now needs
attention. The system SHALL distinguish them in presentation, since a blocked session is
making no progress while a finished one is merely idle.

#### Scenario: A session finishes its turn

- **WHEN** a session transitions from `busy` to `idle`
- **THEN** a your-turn alert of kind `done` is raised for that session

#### Scenario: A session hits a permission prompt mid-turn

- **WHEN** a session transitions from `busy` to `waiting`
- **THEN** a your-turn alert of kind `blocked` is raised for that session, carrying the
  record's `waitingFor` text as the reason

#### Scenario: A single turn blocks and then completes

- **WHEN** a session goes `busy → waiting`, the user answers, and it goes `busy → idle`
- **THEN** two alerts are raised — one `blocked`, then one `done` — because the user's
  attention was genuinely required twice

### Requirement: Silent Transitions

The system SHALL NOT raise an alert for transitions that do not require user attention,
specifically `idle → busy` (the user just submitted the prompt), any transition into
`shell`, and any transition involving `unknown`.

#### Scenario: The user submits a prompt

- **WHEN** a session transitions from `idle` to `busy`
- **THEN** no alert is raised and the session's visual state updates silently

#### Scenario: A background shell command outlives the turn

- **WHEN** a session transitions from `idle` to `shell`
- **THEN** no alert is raised

### Requirement: Transition Debounce

The system SHALL require a new status to remain stable for at least 750ms before raising an
alert for it. Claude Code derives `waiting` from any open dialog — including transient
local slash-command UI, which reports `waitingFor: "dialog open"` — so undebounced
transitions would alert on ordinary UI that the user opened deliberately.

#### Scenario: A dialog opens and closes quickly

- **WHEN** a session enters `waiting` and returns to its prior status within 750ms
- **THEN** no alert is raised

#### Scenario: A dialog stays open

- **WHEN** a session enters `waiting` and remains there beyond 750ms
- **THEN** a `blocked` alert is raised once the debounce elapses

### Requirement: Baseline Snapshot On Startup

The system SHALL treat the first poll tick after launch as a baseline and SHALL NOT raise
alerts for the statuses observed in it. Without this, launching the widget while sessions
are already idle would immediately chime for every one of them.

#### Scenario: The widget launches with existing idle sessions

- **WHEN** the widget starts and finds three sessions already in `idle`
- **THEN** all three are rendered in their idle state and no alerts are raised

#### Scenario: A session changes after the baseline

- **WHEN** one of those sessions later transitions `busy → idle`
- **THEN** a `done` alert is raised normally

### Requirement: Alert Latching

The system SHALL raise at most one alert per transition and SHALL NOT re-raise while a
session remains in the same status. A session's alert state SHALL clear when it leaves the
alerting status, re-arming it for the next transition.

#### Scenario: A session sits idle for a long time

- **WHEN** a session has been `idle` for ten minutes after a `done` alert
- **THEN** no further alerts are raised for that session

#### Scenario: A session is used again

- **WHEN** that session goes `idle → busy → idle`
- **THEN** exactly one new `done` alert is raised

### Requirement: Sound Output And Mute

The system SHALL emit a short sound on a your-turn alert and SHALL provide a mute toggle
that suppresses sound while leaving visual alerting fully active. The mute setting SHALL
persist across launches.

#### Scenario: An alert fires while unmuted

- **WHEN** a your-turn alert is raised and sound is enabled
- **THEN** a short sound plays and the session's row enters its alerting visual state

#### Scenario: An alert fires while muted

- **WHEN** a your-turn alert is raised and sound is muted
- **THEN** no sound plays and the session's row still enters its alerting visual state

#### Scenario: Mute survives a restart

- **WHEN** the user mutes the widget and relaunches it
- **THEN** sound remains muted
