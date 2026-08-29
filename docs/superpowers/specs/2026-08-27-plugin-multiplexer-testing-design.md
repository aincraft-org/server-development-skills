# Plugin Multiplexer Navigation and Testing

## Goal

The development network already multiplexes isolated Paper servers behind one Velocity proxy, but a player must remember and type `/server <name>` and the workflow does not verify that the proxy-side navigation tool is installed. Add a small development-only Velocity plugin that exposes a clickable chat server list and a `/hub` action from every backend, then wire its deployment and verification into the existing harness. Keep the read-only network checks and single-backend restart loop so plugin behavior can be tested without restarting unrelated servers.

## Scope

### In scope

- A standalone `dev-network-navigator` Velocity plugin built with the repository's Gradle composite.
- Proxy commands `/servers` (aliases `/serverlist`, `/play`) and `/hub` (alias `/lobby`).
- Sorted clickable chat entries for every server currently registered in the live proxy; clicking an entry executes the existing `/server <name>` route.
- Direct `/hub` connection to the configured `lobby` server.
- Proxy bootstrap deployment through `PROXY_PLUGIN_JAR`, with a stable harness-owned filename and descriptor validation.
- Gradle wiring for `-PnetworkProxyPluginJar` and the existing `networkTest`/`restartNetwork` workflow.
- Automated checks for artifact/load evidence and an authorized real-client smoke path proving clickable switching and `/hub`.

### Out of scope

- Inventory GUIs, compass items, Paper-side plugins, or plugin-message protocols.
- Automated Minecraft authentication or client clicking; a real client remains required for the final routing proof.
- Remote networks, production permissions policy, persistent player state, or non-development deployment.
- Replacing Velocity's built-in `/server` command or changing forwarding, port allocation, registration, or lifecycle semantics.

## Functional requirements

### FR-001 — Build the navigator as a proxy plugin

The repository shall contain a separate Java Gradle subproject for a Velocity plugin with a stable id `dev-network-navigator`, a verified Velocity API dependency compatible with the pinned proxy, and a `velocity-plugin.json` descriptor.

- **AC-1:** Building the navigator produces one jar containing the descriptor and no Paper-only classes.
- **AC-2:** The descriptor id is exactly `dev-network-navigator`; malformed or missing metadata fails the build/check.
- **AC-3:** The API version and Java target are verified against official Velocity documentation before the implementation is committed, with the verification date recorded in the skill.

### FR-002 — Provide clickable server navigation

The plugin shall register `/servers`, `/serverlist`, and `/play` for players and render the current live `ProxyServer.getAllServers()` set in deterministic name order.

- **AC-1:** A player running `/servers` receives one entry per registered server, with the current server visibly marked.
- **AC-2:** Each entry is a clickable Adventure chat component whose action invokes `/server <name>`; names are displayed safely without command-string interpolation from untrusted input.
- **AC-3:** The command works from the lobby and every backend and reflects hot-added or removed servers on the next invocation without a plugin restart.
- **AC-4:** A source that is not a player receives a readable non-clickable list or an explicit source limitation, never an exception.

### FR-003 — Provide a hub action

The plugin shall register `/hub` and `/lobby` and connect the invoking player directly to the registered server named `lobby`.

- **AC-1:** From any backend, `/hub` results in a connection request to `lobby`.
- **AC-2:** If `lobby` is not registered or the connection fails, the player receives an actionable error and the plugin logs the failure without crashing.
- **AC-3:** The command does not require a Paper plugin or backend-side command handler.

### FR-004 — Deploy the plugin through the existing proxy bootstrap

`boot-proxy.sh` shall accept `PROXY_PLUGIN_JAR`, validate that it is a readable navigator jar with `dev-network-navigator` metadata, and copy it to the harness-owned `$BASE/runtime/plugins/dev-network-navigator.jar` before starting Velocity. It shall not delete unrelated proxy plugins.

- **AC-1:** A valid jar is installed before the proxy JVM starts and Velocity enables it from the generated runtime.
- **AC-2:** A missing, unreadable, or wrong-id jar fails fast with the source path and remediation; the proxy is not started with a falsely reported plugin.
- **AC-3:** Rebooting with a newer jar replaces only the harness-owned navigator file; unrelated files in `runtime/plugins` remain untouched.
- **AC-4:** `dev-network.sh` and the Gradle task pass the configured jar through without changing registry/port behavior.

### FR-005 — Verify the live multiplexer and navigator

The read-only `test-network.sh` command shall validate the running registry, persisted ports, endpoint status, managed backend plugin identity/load evidence, and the deployed navigator jar/load evidence. It shall print the real-client routing matrix.

- **AC-1:** A healthy network with the navigator reports proxy, lobby, every backend, and `dev-network-navigator` as ready/loaded.
- **AC-2:** Missing navigator metadata or its Velocity enable event fails with a proxy-specific remediation.
- **AC-3:** Managed backends require exactly one valid plugin jar and a matching Paper enable event; external backends remain reachability-only.
- **AC-4:** The output explicitly says status is reachability evidence and instructs the player to connect to the proxy, run `/servers`, click a backend, and run `/hub`.

### FR-006 — Provide the fast Gradle loop

The `io.github.development-network` Gradle plugin shall expose `networkTest` and `restartNetwork`, preserve existing property precedence, and accept `-PnetworkProxyPluginJar` (falling back to `DEV_NETWORK_PROXY_PLUGIN_JAR`) for `runNetwork`.

- **AC-1:** `./gradlew networkTest` checks the configured live base without starting/stopping any process.
- **AC-2:** `PROXY_PLUGIN_JAR=/path/to/navigator.jar ./gradlew runNetwork` starts the proxy with the navigator and the current project backend.
- **AC-3:** `./gradlew restartNetwork -PnetworkBackend=<name>` rebuilds/deploys only that backend and leaves proxy/lobby/other backends running.
- **AC-4:** `tasks --all` lists `runNetwork`, `networkTest`, and `restartNetwork`.

### FR-007 — Document the in-game workflow

The skill shall document building/installing the navigator, starting the network, joining `localhost:<proxy-port>`, using `/servers` and `/hub`, verifying hot registration, and restarting one backend during plugin iteration.

- **AC-1:** Documentation gives both shell and Gradle commands with the exact `PROXY_PLUGIN_JAR`/`-PnetworkProxyPluginJar` wiring.
- **AC-2:** Documentation distinguishes proxy plugin load, backend plugin load, endpoint reachability, and real-client routing evidence.
- **AC-3:** Common mistakes cover installing the navigator into a backend instead of the proxy, stale navigator jars, using a backend port as the client address, and treating status as routing proof.

## Non-functional requirements

- **NFR-001 — Bounded checks:** endpoint probes use the existing finite five-second status timeout; plugin checks never wait indefinitely.
- **NFR-002 — Safe deployment:** installation writes only `$BASE/runtime/plugins/dev-network-navigator.jar` and never mutates external backend directories.
- **NFR-003 — Dynamic routing:** command output reads the live proxy server registry on every invocation; no duplicated backend registry is persisted by the plugin.
- **NFR-004 — Deterministic UX:** server entries are sorted by Velocity server name and use stable labels/commands.
- **NFR-005 — Minimal dependencies:** the navigator has only the verified Velocity API as compile-time dependency and uses Adventure types supplied by Velocity.

## Failure handling

- Reject malformed navigator jars before proxy startup and identify the expected plugin id/path.
- If the navigator is not installed, `networkTest` fails clearly rather than claiming the clickable workflow is available.
- If a player requests `/hub` without a registered lobby, send a user-facing error and log the condition at warning level.
- If a connection request fails, report failure to the player and continue serving future commands.
- If a backend is unreachable or its managed plugin evidence is absent, fail the automated check while still printing all collected diagnostics.
- Treat external backend files as unavailable by design; only prove their network reachability.

## Verification policy

1. Verify the selected Velocity API/version and plugin descriptor contract against official Velocity sources before coding; record the date and URLs.
2. Run Gradle compilation and descriptor checks for the navigator and included Gradle plugin.
3. Run shell syntax checks and a deterministic fixture for registry/port/status/plugin-load failure paths.
4. Launch a local network with the navigator jar, run `networkTest`, and observe the proxy log showing navigator enablement.
5. With an authorized client, join the proxy, run `/servers`, click each backend, confirm the destination identity, run `/hub` from a backend, and repeat after a hot add/remove.
6. Rebuild one backend, run `restartNetwork`, and confirm the proxy/lobby/other backend processes remain available.

## Alternatives

An inventory GUI would require a Paper plugin on the lobby/every backend plus a proxy connection-message contract; it is intentionally deferred. An Azalea bot could automate the client proof but adds a Rust/protocol dependency and is not required for the first usable workflow. The clickable proxy chat path exercises the actual built-in multiplexer with the least additional runtime machinery.

## Approval state

The earlier diagnostics-only design was superseded by the user's clarification that navigation must happen in-game from the proxy. The chosen interface is clickable proxy chat; implementation of this revised design requires a fresh Gate 1 approval.
