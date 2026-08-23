## ADDED Requirements

### Requirement: Session Registry Polling

The system SHALL discover live Claude Code sessions by reading `*.json` files in
`~/.claude/sessions/` on a fixed interval of 500ms. The system SHALL NOT use filesystem
event watching, because the registry files are replaced by atomic rename and a watch bound
to an individual file's inode would silently stop receiving updates.

#### Scenario: A new session starts

- **WHEN** a new Claude Code session writes `~/.claude/sessions/<pid>.json`
- **THEN** the session appears in the live set within 500ms of the next poll tick

#### Scenario: A session exits cleanly

- **WHEN** a session's registry file is removed
- **THEN** the session is removed from the live set on the next poll tick

#### Scenario: The registry directory does not exist

- **WHEN** `~/.claude/sessions/` is absent, for example before Claude Code has ever run
- **THEN** the live set is empty and the system continues polling without error

### Requirement: Process Liveness Verification

For each registry file discovered, the system SHALL verify that the process identified by
the filename's PID is still alive, and SHALL exclude sessions whose process is dead. A
crashed session leaves its registry file behind, so file presence alone is not sufficient
evidence of a live session.

#### Scenario: A session's process has died without cleanup

- **WHEN** `~/.claude/sessions/47462.json` exists but PID 47462 is not running
- **THEN** the session is excluded from the live set

#### Scenario: A PID has been recycled by another process

- **WHEN** the PID in a registry filename is alive but the record's `startedAt` predates the
  process's own start time
- **THEN** the session is excluded from the live set

### Requirement: Malformed Record Tolerance

The system SHALL tolerate unreadable, partially written, or schema-violating registry files
by skipping the affected record for that tick, without affecting other sessions and without
crashing. Registry files are written by a separate process and may be observed mid-write.

#### Scenario: A record is read mid-write

- **WHEN** a registry file contains truncated or invalid JSON at poll time
- **THEN** that session retains its previously known state and other sessions update normally

#### Scenario: A record is missing required fields

- **WHEN** a registry file parses as JSON but lacks `pid`, `sessionId`, or `cwd`
- **THEN** the record is skipped for that tick

### Requirement: Status Normalization

The system SHALL normalize each record's `status` field to one of `busy`, `idle`, `waiting`,
or `shell`. A record whose `status` is absent or holds an unrecognized value SHALL be
normalized to `unknown` and rendered without triggering alerts, so that a future Claude Code
release adding a status value degrades visibly rather than producing false alerts.

#### Scenario: A known status is read

- **WHEN** a record carries `"status": "waiting"`
- **THEN** the session's normalized status is `waiting`

#### Scenario: An unrecognized status is read

- **WHEN** a record carries a `status` value outside the known set
- **THEN** the session's normalized status is `unknown` and no alert is raised for it

### Requirement: Session Display Identity

The system SHALL derive a display label for each session from the record's `name` field,
falling back to the basename of `cwd` when `name` is absent or empty.

#### Scenario: A session has a derived name

- **WHEN** a record carries `"name": "claude-widget-43"`
- **THEN** the session is labeled `claude-widget-43`

#### Scenario: A session has no name

- **WHEN** a record has no `name` and `cwd` is `/Users/x/Dev/invoice_sync`
- **THEN** the session is labeled `invoice_sync`

### Requirement: Transition Timestamps

The system SHALL expose, for each live session, the elapsed time since its last status
change, derived from the record's `statusUpdatedAt` field. This supports rendering how long
a session has been working or has been waiting on the user.

#### Scenario: A session has been busy for some time

- **WHEN** a session's `statusUpdatedAt` was 42 seconds ago and its status is `busy`
- **THEN** the session reports an elapsed time of 42 seconds in its current state

#### Scenario: A record omits the timestamp

- **WHEN** `statusUpdatedAt` is absent or unparseable
- **THEN** elapsed time is reported as unavailable rather than as zero
