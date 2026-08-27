# Named Player Homes Design

**Date:** 2026-08-21
**Status:** Proposed — Gate 1 approval required

## Goal

Add a `/homes` player command to the Paper plugin so each player can save up to five named home locations and teleport to a selected home safely after restarts.

## Scope

### In scope

- Player-only `/homes` command handling.
- Saving the sender's current location under a validated name.
- Updating an existing home without consuming another slot.
- Teleporting to a named home.
- A maximum of five homes per player.
- Persistence across plugin/server restarts.
- Clear permission, validation, capacity, missing-home, unavailable-world, and persistence-error feedback.

### Out of scope

- Listing homes in a dedicated subcommand (players use the names they chose when teleporting).
- Deleting or renaming homes after creation.
- Cross-server synchronization.
- Home sharing or public homes.
- GUI management.
- Economy, cooldown, warmup, or teleport-cancellation systems unless an existing project-wide command policy requires them.
- Administrative commands for editing another player's homes.
- Migration of unrelated player data.

## Command contract

The command shall use the existing project command-registration and message conventions. The logical operations are:

- `/homes set <name>` — create or update a home at the player's current location.
- `/homes go <name>` — teleport to a saved home.

Names shall be normalized consistently for lookup and display according to existing project conventions; if no convention exists, names shall be case-insensitive, trimmed, non-empty, and limited to a conservative documented character/length rule. The exact rule shall be recorded after repository inspection before implementation.

## Functional requirements

### FR-001 — Save or update a named home

The plugin shall let an authorized player save their current valid location under a valid home name.

- **AC-1:** Saving a new valid name creates one persisted home.
- **AC-2:** Saving an existing name updates that home's location and does not increase the player's home count.
- **AC-3:** A non-player sender is rejected without accessing player location state.
- **AC-4:** An unauthorized player is rejected using the established permission behavior.

### FR-002 — Enforce the five-home limit

The plugin shall reject creation of a sixth distinct home for a player.

- **AC-1:** The fifth distinct home succeeds.
- **AC-2:** A sixth distinct home fails with no mutation to existing homes.
- **AC-3:** Updating an existing home succeeds even when the player already has five homes.

### FR-003 — Teleport to a named home

The plugin shall teleport an authorized player to the selected saved location.

- **AC-1:** A valid existing home resolves to its persisted location and invokes the project's established teleport mechanism.
- **AC-2:** An unknown name is rejected without teleporting.
- **AC-3:** A home whose world is unavailable is rejected clearly and its stored record is not silently replaced or deleted.

### FR-004 — Persist homes safely

The plugin shall load and save homes using the repository's established persistence mechanism and lifecycle.

- **AC-1:** Homes survive a normal plugin/server restart.
- **AC-2:** A persistence write failure reports an error and does not claim success.
- **AC-3:** A malformed or unreadable homes record is handled according to existing startup error policy without corrupting unrelated player data.

## Non-functional requirements

### NFR-001 — Main-thread safety

Command-facing Bukkit/Paper API operations, including player location reads and teleports, shall occur on the server thread; any existing asynchronous persistence mechanism shall be used without blocking command execution beyond the project's documented command policy.

### NFR-002 — Deterministic capacity behavior

The home-count decision shall be atomic with the in-memory mutation for each command invocation, so no successful invocation can leave more than five distinct homes for a player.

### NFR-003 — Verification coverage

The focused behavioral verification shall complete successfully in the repository's standard test/build command and shall cover the five-home boundary, update-at-capacity behavior, name validation, persistence round-trip, unknown homes, and unavailable worlds.

## Failure handling

- Invalid syntax or unknown subcommand: show existing command usage/help format; do not mutate state.
- Invalid name: explain the accepted rule; do not mutate state.
- Capacity exceeded: explain the five-home limit; preserve all existing homes.
- Unknown home: explain that the named home does not exist; do not teleport or mutate state.
- Missing world/unusable location: report that the destination is unavailable; preserve the stored record for later recovery.
- Permission failure: use the established denial response; do not reveal or alter private home data.
- Non-player sender for player-only operations: reject using established sender handling.
- Persistence read failure: follow existing startup policy and avoid overwriting unrelated data.
- Persistence write failure: report failure and define whether in-memory state is rolled back according to the repository's existing persistence transaction convention; implementation must not report a successful save when durable storage failed.

## Repository decisions to record before implementation

The implementation plan shall document the observed answers for:

1. Command registration and permission naming.
2. Existing player command syntax/help/message conventions.
3. Existing player-data persistence format and lifecycle.
4. Whether the project has an established teleport safety/warmup policy.
5. Name normalization and validation rules if no current convention exists.
6. The exact focused and full verification commands.

## Alternatives considered

1. **One command with subcommands (recommended):** `/homes set|go`; minimal surface aligned with the request while leaving room for future operations.
2. **Separate commands (`/sethome`, `/home`):** familiar to players but adds registrations, duplicated help, and more permission surface.
3. **GUI-only management:** visually discoverable but unsuitable as the only interface for command-driven server administration and harder to test headlessly.

The recommended subcommand design is selected unless repository conventions require an existing alternate command shape.

## Verification policy

Before implementation, repository inspection shall identify the exact supported commands. After implementation, verification shall include:

- the focused homes behavior test command, with expected success for all approved acceptance criteria;
- the repository's full quality/build command, expected to exit zero;
- a real Paper/plugin smoke path when the repository provides one, exercising set, go, capacity rejection, and restart persistence;
- inspection that no test or verification asset was changed merely to make a check pass.

All deviations discovered during implementation shall update this specification and the implementation plan before code changes continue.
