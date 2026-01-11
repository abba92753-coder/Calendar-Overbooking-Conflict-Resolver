# Calendar Overbooking Conflict Resolver

This project is a Clarinet-based Clarity smart contract workspace for experimenting with calendar overbooking and "parallel timeline" resolution patterns.

The system is centered around two independent smart contracts:

- `maybe-attend-speculator`: manages probabilistic RSVP state for events, allowing users to signal "maybe" attendance with an explicit confidence score.
- `meeting-escape-hatch`: manages polite, pre-committed escape hatches for meetings, recording on-chain reasons and timestamps to make excused absences verifiable.

## Project Structure

- `Clarinet.toml` – Clarinet workspace configuration for this project.
- `contracts/` – Clarity smart contracts.
- `tests/` – Clarinet test files for the contracts.
- `settings/` – Network configuration for Devnet, Testnet, and Mainnet.
- `package.json` – Node configuration used by Clarinet tooling and tests.

## Design Goals

1. **Resolve double-bookings conceptually** by:
   - Capturing "maybe" responses with confidence levels, not just binary yes/no.
   - Tracking per-event RSVP state for each user.
2. **Provide cryptographically-plausible excuses** via:
   - On-chain records of escape-hatch reasons for meetings.
   - Timestamps that show when a user registered their intent to skip or leave a meeting.
3. **Keep contracts independent**:
   - No cross-contract calls.
   - No trait definitions or usage.

## Planned Contracts

### 1. `maybe-attend-speculator`

This contract focuses on RSVP management for events. It will:

- Let organizers register events with identifiers and basic metadata.
- Allow participants to submit a `maybe` RSVP with a confidence score.
- Allow upgrading or downgrading RSVP decisions (e.g., from maybe → yes or maybe → no).
- Expose read-only accessors to inspect RSVP state per event and per participant.

### 2. `meeting-escape-hatch`

This contract manages escape hatches for meetings. It will:

- Allow users to register a potential escape-hatch for a given meeting identifier.
- Store a structured record that describes why and when the escape hatch was declared.
- Allow the user to finalize or "trigger" an escape hatch, making it obvious that they opted out.
- Provide read-only queries to retrieve excuse details by meeting and participant.

## Development Workflow

1. Use `clarinet contract new maybe-attend-speculator` and `clarinet contract new meeting-escape-hatch` on the development branch to scaffold the contracts.
2. Implement the business logic in `.clar` files using:
   - Strict, explicit Clarity types (e.g. `uint`, `bool`, `principal`).
   - Simple, composable public functions.
3. Run `clarinet check` frequently to validate syntax and type correctness.
4. Use `npm test` or `clarinet test` (if configured) to exercise the contracts.

## Branching Model

- `main` branch:
  - Contains only the Clarinet project initialization files and this `README.md`.
  - Serves as the stable base for development and pull requests.
- `development` branch:
  - Contains the actual contract implementations and related tests.
  - Used to open pull requests back into `main`.

## Requirements Summary

- Two independent `.clar` contracts: `maybe-attend-speculator` and `meeting-escape-hatch`.
- No cross-contract calls or trait usage.
- Clean, readable Clarity code with appropriate data types for event IDs, RSVPs, and excuses.
- All changes validated with `clarinet check` before merging.
