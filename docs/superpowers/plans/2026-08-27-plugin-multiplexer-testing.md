# Plugin Multiplexer Testing Workflow — Implementation Plan

**Design:** `docs/superpowers/specs/2026-08-27-plugin-multiplexer-testing-design.md`

## Goal

Implement the approved, dependency-free live-network verification and fast single-backend restart workflow. Preserve existing Velocity/Paper lifecycle behavior; use an authorized client login as the authoritative proof of `/server` routing.

## Shared contracts

- `development-network/bin/test-network.sh` is read-only. It requires a running network, reads `BASE/runtime/backends.txt` and persisted `BASE/runtime/<name>.port` files, invokes the existing status probe with those resolved ports, and inspects only managed backend artifacts/logs.
- A managed backend has a harness pidfile. An external backend has no harness pidfile and receives reachability-only verification. The check never guesses an external plugin identity.
- The check exits zero only when all automated checks pass; output follows sorted registry order and includes a manual `/server <name>` matrix.
- `networkTest` invokes `test-network.sh` without starting, stopping, or mutating the network.
- `restartNetwork` depends on the configured archive task, requires the configured managed backend to be live, and invokes `restart-backend.sh <name> <archive>` with the same base/bin/property precedence as `runNetwork`.

## Ordered tasks

- [ ] **Task 1** [FR-001, FR-002, FR-003, NFR-001, NFR-002, NFR-004] — Add `development-network/bin/test-network.sh`.
  1. Validate `BASE`, proxy pid/readiness markers, registry names, unique persisted ports, and port ranges without rewriting files.
  2. Resolve proxy port from `PROXY_PORT` or generated `velocity.toml`; pass each persisted backend port to the status probe without recomputing live ports.
  3. Preserve status-probe output and fail on any `UNREACHABLE` result.
  4. For managed backends, resolve normal or `.auto-dir` server directory, require exactly one plugin jar, read `plugin.yml` or `paper-plugin.yml` with `unzip`, extract a non-empty `name`, and find the matching Paper enable event in `logs/latest.log`.
  5. Report external backends as reachability-only, print the proxy address and `/server` commands, and return actionable non-zero failures.
  6. Verify with shell syntax checks and fixture scenarios for healthy, unreachable, missing/ambiguous jar, missing descriptor, and missing enable-log cases.
- Update `development-network/bin/dev-network-status.sh` so persisted `runtime/<name>.port` values take precedence over recomputed defaults (including names containing hyphens); preserve its existing output contract.

- [ ] **Task 2** [FR-004, FR-005, NFR-003] — Extend `DevNetworkPlugin.kt` with Gradle tasks.
  1. Extract shared harness-bin, base-directory, backend-name, proxy-port, developer-user, and archive resolution helpers while preserving existing `runNetwork` defaults and precedence.
  2. Register `networkTest` in the `network` group; run the check script with inherited output and propagate non-zero exit status as `GradleException`.
  3. Register `restartNetwork` in the same group; depend on `networkJarTask` (default `jar`), require a live configured backend process, and invoke `restart-backend.sh` with the exact archive output.
  4. Keep task classes abstract, add no runtime dependency, and leave proxy/lobby/unrelated backends untouched.
  5. Verify the plugin build and a minimal consumer fixture listing `runNetwork`, `networkTest`, and `restartNetwork`.

- [ ] **Task 3** [FR-006] — Update `development-network/SKILL.md`.
  1. Add the check script to layout and command sections.
  2. Document the two-terminal loop: `runNetwork`, `networkTest`, real-client proxy login plus `/server`, then `restartNetwork` for one plugin.
  3. Document managed versus external artifact verification and the explicit routing limitation.
  4. Add common mistakes for stale/multiple jars, using a backend port as the client address, and treating status as routing evidence.

- [ ] **Task 4** [FR-001–FR-006, NFR-001–NFR-004] — Perform final verification.
  1. Run syntax checks for changed scripts.
  2. Run the focused fixture and Gradle plugin build/consumer task listing.
  3. If Java 25 and pinned server jars are available, run a real network and execute `networkTest`; otherwise report the runtime smoke test as unavailable.
  4. Confirm unrelated user changes were not overwritten and update the todo ledger only after checks pass.

## File ownership

- `development-network/bin/dev-network-status.sh`: resolve persisted live ports for status probes.
- `development-network/bin/test-network.sh`: new read-only verification command.
- `development-network/network/src/main/kotlin/io/github/developmentnetwork/DevNetworkPlugin.kt`: shared Gradle helpers plus `networkTest` and `restartNetwork`.
- `development-network/SKILL.md`: user workflow and failure documentation.
- `development-network/tests/test-network.sh` (only if needed): deterministic local fixture test; it must not download or launch Paper/Velocity.

## Reuse and risks

- Reuse `dev-network-status.sh`, `restart-backend.sh`, persisted `.port` files, `.auto-dir`, and existing Gradle property names. Do not create a second registry or allocator.
- The status helper prints unreachable endpoints without a failing exit code; the new command must inspect its explicit output (or preserve any improved exit contract).
- Paper log formats vary by version. Match stable `[<plugin>] Enabling <plugin>` identity and fail closed when absent.
- External servers intentionally lack harness-owned artifacts; never inspect or mutate their project directories.

## Rollback

Remove the new check/test files and Gradle task registrations, then revert only the added skill sections. Existing startup, registration, reload, and restart behavior remains independently usable.

**Gate 2:** this plan requires explicit approval before implementation begins.
