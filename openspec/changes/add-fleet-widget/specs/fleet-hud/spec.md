## ADDED Requirements

### Requirement: Always-On-Top Non-Activating Panel

The widget SHALL present as a borderless panel that floats above all ordinary application
windows, and SHALL NOT take keyboard focus from the frontmost application when clicked. The
widget's purpose is to be glanceable while the user works in a terminal; stealing focus
would defeat it.

#### Scenario: Another app is fullscreen or frontmost

- **WHEN** any application window is raised in front of others
- **THEN** the widget remains visible above it

#### Scenario: The user clicks the widget

- **WHEN** the user clicks anywhere on the widget
- **THEN** the previously active application retains keyboard focus

### Requirement: Cross-Space Persistence

The widget SHALL remain visible when the user switches macOS Spaces, and SHALL NOT animate
or migrate between Spaces as a normal window would.

#### Scenario: The user switches Spaces

- **WHEN** the user moves to a different Space
- **THEN** the widget is already present in the new Space

### Requirement: Corner Placement And Position Persistence

The widget SHALL open in a screen corner, SHALL be repositionable by dragging, and SHALL
restore its last position on launch. If the stored position is off-screen — for example
after a display is disconnected — the widget SHALL fall back to its default corner.

#### Scenario: The user moves the widget

- **WHEN** the user drags the widget and relaunches it later
- **THEN** it reopens at the dragged position

#### Scenario: The stored position is no longer on any display

- **WHEN** the stored position lies outside the bounds of all connected displays
- **THEN** the widget opens in its default corner instead

### Requirement: Per-Session Row Rendering

The widget SHALL render one row per live session, each showing a pixel-art sprite for the
session's status, the session's display label, a short status caption, and the elapsed time
in the current status. Rows SHALL be ordered stably so that a session does not jump position
when its status changes.

#### Scenario: Multiple sessions are live

- **WHEN** three sessions are live with statuses `busy`, `waiting`, and `idle`
- **THEN** three rows render, each with the sprite and caption for its own status

#### Scenario: A session changes status

- **WHEN** a session transitions from `busy` to `idle`
- **THEN** its row updates in place without changing position in the list

#### Scenario: A blocked session shows why

- **WHEN** a session is `waiting` with `waitingFor` of `"input needed"`
- **THEN** its caption conveys both that the session needs the user and the reason text

### Requirement: Visual Prominence Tiering

The widget SHALL render sessions at different visual prominence by status, so the eye is
drawn to sessions needing attention: alerting sessions fully opaque with motion, `busy`
sessions clearly visible, and `idle` sessions dimmed. Idle is the common resting state, so
undimmed idle rows would make the widget uniform and easy to stop noticing.

#### Scenario: A mix of statuses is displayed

- **WHEN** one session is alerting and two are idle
- **THEN** the alerting row is rendered at full opacity with motion and the idle rows are
  visibly dimmed relative to it

### Requirement: Finished State Presentation

The widget SHALL present a finished session — one that has raised a `done` alert and that
the user has not returned to — in Claude's orange, distinct from every other state's colour.
This is the state the user is most often looking for, so it is given the one colour that
identifies the tool itself.

The finished state SHALL be visually distinguishable from the blocked state even though both
sit at full prominence, since they call for different urgency.

#### Scenario: A session finishes and has not been revisited

- **WHEN** a session is idle and latched from a `done` alert
- **THEN** its sprite and caption render in Claude's orange

#### Scenario: A finished session and a blocked session are both listed

- **WHEN** one row is finished and another is blocked
- **THEN** the two are distinguishable by colour, by caption, and by whether the sprite moves

#### Scenario: The user returns to a finished session

- **WHEN** the session leaves idle and its alert latch clears
- **THEN** it stops rendering as finished and returns to its status colour and prominence

### Requirement: Sprite Animation

The widget SHALL animate sprites per presentation state using multi-frame pixel-art bitmaps,
with a distinct animation for working, blocked, finished, and idle. Sprites SHALL be defined
as string-literal bitmaps in source code and rendered without interpolation, so that the
8-bit look is preserved at any scale and no binary art assets are required.

#### Scenario: A session is working

- **WHEN** a session's status is `busy`
- **THEN** its sprite animates continuously to convey activity

#### Scenario: A session needs the user

- **WHEN** a session is in an alerting state
- **THEN** its sprite animates distinctly from the working animation

#### Scenario: A finished session waits to be noticed

- **WHEN** a session has been rendering as finished for several seconds
- **THEN** its sprite periodically glances to each side and blinks, holding still between
  glances so the movement reads as occasional rather than constant

#### Scenario: Sprites are scaled

- **WHEN** a sprite is rendered at any size
- **THEN** its pixels have hard edges with no smoothing or antialiasing between them

### Requirement: Header Identity Mark

The widget SHALL show a pixel-art starburst mark in its header, drawn from the same
string-bitmap idiom as the session sprites, and SHALL tint it with the same colour as the
header title so the mark reports fleet urgency rather than acting as static decoration.

#### Scenario: Nothing needs the user

- **WHEN** no session is blocked or finished
- **THEN** the mark and title render in the resting header colour

#### Scenario: A session is blocked

- **WHEN** any session is blocked
- **THEN** the mark and title both take the blocked colour, which outranks finished

#### Scenario: A session is finished

- **WHEN** a session is finished and none is blocked
- **THEN** the mark and title both take Claude's orange

### Requirement: Empty State

The widget SHALL render a legible empty state when no live sessions are found, rather than
collapsing to nothing, so that it remains findable and its absence of content is
distinguishable from a crash.

#### Scenario: No Claude Code sessions are running

- **WHEN** the live session set is empty
- **THEN** the widget remains visible showing an empty-state indication

### Requirement: Quit Affordance

The widget SHALL provide a way to quit and to toggle mute without requiring a Dock icon or
menu bar application, since it runs as a non-activating accessory panel.

#### Scenario: The user wants to dismiss the widget

- **WHEN** the user invokes the widget's quit affordance
- **THEN** the application terminates
