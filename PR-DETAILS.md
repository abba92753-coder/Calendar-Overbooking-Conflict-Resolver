# Calendar Overbooking Contracts

This pull request introduces two independent Clarity smart contracts that together model how calendar overbookings can be reasoned about in a "parallel timeline" style, without any cross-contract calls or trait usage.

## Summary of Changes

- Added `maybe-attend-speculator` contract to manage probabilistic RSVP states for calendar events.
- Added `meeting-escape-hatch` contract to manage polite, auditable excuses for skipping or exiting meetings.
- Updated `Clarinet.toml` to register both contracts with the Clarinet workspace.
- Added TypeScript test scaffolding for each contract under `tests/`.

## Contract: maybe-attend-speculator

This contract focuses on RSVP management for events.

**Key behaviors**

- Allows any principal to register an event by identifier, with a title and conceptual start/end block window.
- Stores per-event metadata, including organizer and the time window.
- Lets participants submit:
  - `rsvp-maybe` with a confidence value from `0` to `100`.
  - `rsvp-yes` and `rsvp-no` as definitive responses.
- Supports canceling an RSVP, returning the participant to an uncommitted state.

**Core data structures**

- `events` map keyed by `{ event-id: uint }` storing organizer and event metadata.
- `rsvps` map keyed by `{ event-id: uint, attendee: principal }` storing:
  - `status` string (`"maybe"`, `"yes"`, or `"no"`).
  - `confidence` score as `uint`.
  - `updated-at` marker used as a simple revision indicator.

**Public entrypoints**

- `register-event` – create a new event; fails if the ID already exists or the time window is invalid.
- `rsvp-maybe` – record or update a probabilistic RSVP with an explicit confidence value.
- `rsvp-yes` – record a definitive yes RSVP with confidence implicitly set to `100`.
- `rsvp-no` – record a definitive no RSVP with confidence implicitly set to `0`.
- `cancel-rsvp` – remove the sender's RSVP for an event.

**Read-only entrypoints**

- `get-event` – look up an event by id.
- `get-rsvp` – look up a specific attendee's RSVP for an event.
- `get-confidence` – retrieve the stored confidence for a given attendee/event pair.

## Contract: meeting-escape-hatch

This contract models escape hatches for meetings, allowing participants to pre-commit to polite excuses.

**Key behaviors**

- Lets a participant declare an escape hatch for a given `meeting-id` along with a UTF-8 reason string.
- Records a simple declaration marker that can later be triggered.
- Allows the same participant to trigger their escape hatch once, making the excuse "active".
- Allows a participant to clear an existing escape hatch if it is no longer needed.

**Core data structures**

- `escape-hatches` map keyed by `{ meeting-id: uint, participant: principal }` storing:
  - `reason` as a `string-utf8` explanation.
  - `declared-at` marker for when the hatch was recorded.
  - `triggered` boolean flag.
  - `triggered-at` optional marker for when the hatch was used.

**Public entrypoints**

- `declare-escape` – create a new escape hatch for the sender and meeting; fails if one already exists.
- `trigger-escape` – mark an existing escape hatch as triggered; subsequent calls are no-ops that return `false`.
- `clear-escape` – delete an existing escape hatch for the sender and meeting.

**Read-only entrypoints**

- `get-escape` – look up the current escape hatch record for a participant and meeting.
- `has-active-escape?` – check whether a participant has a declared but untriggered escape hatch.

## Testing and Validation

- Both contracts are registered in `Clarinet.toml` and validated with `clarinet check`.
- The project includes TypeScript test stubs for each contract, which can be extended and executed using Clarinet's testing tools.

## Notes

- There are no cross-contract calls between `maybe-attend-speculator` and `meeting-escape-hatch`.
- No traits are defined or used.
- All core state is managed via maps and simple helper functions to keep the implementation explicit and readable.
