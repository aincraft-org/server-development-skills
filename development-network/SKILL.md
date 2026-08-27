---
name: development-network
description: Use when setting up a local Velocity proxy development network — a proxy with a basic lobby server plus one or more isolated dev Paper servers behind it — so a user connects to ONE address (localhost:25565) and multiplexes between different plugin development environments with the built-in /server command instead of connecting to multiple servers. Triggers include booting a dev Velocity network, per-plugin dev servers, proxy multiplexing, /server switching, BACKENDS registration, velocity.toml, forwarding.secret, paper-global.yml proxies.velocity, restarting one backend after a plugin rebuild, and cleanly stopping the whole network.
---

# Velocity Dev Network

A local harness: **one Velocity proxy, one basic lobby Paper server, N isolated dev Paper backends**. The user connects Minecraft to `localhost:25565` only, and hops between backends with the built-in `/server` command — no reconnecting to multiple ports, no port juggling.

Version pins verified 2026-08-27 against the official PaperMC fill API (https://fill.papermc.io/v3/projects/velocity, .../projects/paper), the getting-started guide, and the [player information forwarding](https://docs.papermc.io/velocity/player-information-forwarding/) docs.

## Pinned versions

| Component | Version | SHA-256 (pinned artifact) |
|---|---|---|
| Velocity | **4.1.1, build 24** (Java 25+; `config-version = "2.8"`) | `846411d2d0560fed0f23496ffb89681be528d2c0650ecdcf21724d2d7bd9c1ee` |
| Paper | **26.2, build 119** (Java 25+; lobby and every backend) | `a8c9140c3075bd7c04973e9cdc491b21bfe6bad472b674ef932a4ae0fec19629` |

Stale versions must be updated together in every `boot-*.sh` (version, build, SHA-256) — a proxy newer than the backends or mismatched paper-api can break forwarding unexpectedly.

## Layout

```
development-network/
├── SKILL.md
└── bin/
    ├── dev-network.sh          # boot proxy + lobby + all registered backends
    ├── stop-dev-network.sh     # graceful per-pidfile stop of proxy, lobby, backends
    ├── restart-backend.sh      # stop ONE backend, install new plugin jar, boot it
    ├── boot-proxy.sh           # download+verify Velocity, generate velocity.toml
    ├── boot-lobby.sh           # download+verify Paper, configure, run lobby (30066)
    ├── boot-backend.sh         # download+verify Paper, configure, run ONE backend
    └── dev-network-status.sh   # status-ping all endpoints; proves reachability
```

Runtime (default `./development-network`): `logs/` per component, worlds under `runtime/<name>/`, generated configs in `runtime/`, jars cached in `binaries/`. Jars are only downloaded when missing; checksums are always verified.

## Requirements

- Java **25** (Velocity and Paper 26.2 both require it)
- `curl`, `sha256sum`, `python3` (status probe), a POSIX `bash`

## Backend registry

Backends are plain names (`[A-Za-z0-9_-]+`). The registry persists in `runtime/backends.txt`; bootstrap sets it explicitly or falls back to that file.

```bash
# two isolated dev servers named "demo" and "vanilla"
BACKENDS='demo vanilla' ./development-network/bin/dev-network.sh

# default (no BACKENDS set): a single backend named "dev"
./development-network/bin/dev-network.sh
```

Ports: proxy `25565`, lobby `30066`, backends `30067 + index` in the sorted name list (so `demo vanilla` → demo `30067`, vanilla `30068`). Override with `PORT_<NAME>` (e.g. `PORT_DEMO=31001`). `TARGET_SERVER=host.docker.internal` points the proxy at host-run servers from inside a container.

## Start

```bash
BACKENDS='demo vanilla' ./development-network/bin/dev-network.sh
```

Brings up proxy, lobby, and every registered backend; waits for all ready markers; prints the connection banner. Connect Minecraft to **`localhost:25565`**.

- Landing server: **lobby** (basic Paper server, no plugins — a stable hub).
- Switch with the built-in command: **`/server demo`**, **`/server vanilla`**, **`/server lobby`**.

## Per-backend plugins

Each backend is a fully isolated Paper server (`runtime/<name>/`); plugins load from `runtime/<name>/plugins/`. Install on boot with the per-backend env var (falls back to `PLUGIN_JAR` for single-backend use):

```bash
PLUGIN_DEMO=/path/to/demo/plugin.jar \
PLUGIN_VANILLA=/path/to/other/plugin.jar \
BACKENDS='demo vanilla' ./development-network/bin/dev-network.sh
```

Backends without a plugin run vanilla Paper — multiplexing still proves the harness works.

## Iterating: rebuild → restart ONE backend

```bash
# in the plugin project
./gradlew build
# deploy + restart just "demo" (lobby, proxy, other backends stay up)
./development-network/bin/restart-backend.sh demo /path/to/demo/plugin.jar
```

`restart-backend.sh` SIGTERMs that backend (world save), clears stale CalVer jars from its `plugins/`, installs the new jar, and boots it. Players on the restarted backend are kicked back to the lobby by the proxy.

## Verifying reachability

```bash
./development-network/bin/dev-network-status.sh
```

Status-pings the proxy and every endpoint with a correct protocol handshake:

```
proxy                  reachable  motd='dev-network' version=Velocity 1.7.2-26.2
lobby                  reachable  motd='dev-network lobby' version=Paper 26.2
backend:30067 (30067)  reachable  motd='dev-network demo' version=Paper 26.2
backend:30068 (30068)  reachable  motd='dev-network vanilla' version=Paper 26.2
```

**Labeling caveat:** the proxy replies with its OWN status (its `motd`; `ping-passthrough = "DISABLED"`), and the backends are probed directly. So the probe proves **reachability**, not routing. Routing/multiplexing is proven by a real login: join `localhost:25565`, land on lobby, `/server demo`, `/server vanilla`.

## Architecture notes

- **Velocity modern forwarding**: `player-info-forwarding-mode = "modern"` in `velocity.toml`, `online-mode=false`, shared secret in `runtime/forwarding.secret` mirrored into every backend's `config/paper-global.yml` → `proxies.velocity.secret`. Offline mode keeps dev accounts (and a Rust Azalea bot from `autonomous-testing`) connectable without Mojang auth.
- **Every backend** sets `server.properties` `online-mode=false` and `spigot.yml` `settings.bungeecord: false` (modern forwarding REQUIRES BungeeCord forwarding off).
- `forwarding.secret` is generated per boot with a fixed dev secret string — a dev secret, never a production credential.
- The `try` list for login/kick failover is `["lobby", <backends…>]` — lobby first.
- Configs are generated on every boot; worlds persist in the backend's runtime dir.
- Teardown: `Ctrl-C` on the launcher SIGINTs all booters (their EXIT traps stop java), or `stop-dev-network.sh` SIGTERMs each Java PID by pidfile — so Paper's world-save hooks always run. Never `pkill` patterns.

## Stopping

```bash
./development-network/bin/stop-dev-network.sh
```

Stops proxy, lobby, and every registered backend by pidfile (Java PID, so Paper's save hooks run), escalates to SIGKILL after 30s, clears ready markers.

## Common mistakes (observed)

| Wrong | Right | Why |
|---|---|---|
| Running the network without Java 25 | Install Java 25 first | Velocity 4.1.1 and Paper 26.2 both require Java 25+; older JDKs fail to start |
| Waiting for ready markers before the servers finish booting | Ready markers are written AFTER the port opens; poll the port, not the marker, for instant checks | A marker can exist while java is still booting (or be stale from a previous run) |
| Using `settings.bungeecord: true` on backends with modern forwarding | Keep `spigot.yml` `settings.bungeecord: false` | Modern forwarding requires BungeeCord forwarding OFF; legacy mode is less secure |
| Updating only one `boot-*.sh` version pin | Update version+build+SHA-256 in every `boot-*.sh` | Stale backends/proxy drift breaks forwarding |
| Killing the booter shell expecting the network to die | Use `stop-dev-network.sh` (pidfiles point at the Java PIDs) | `Ctrl-C` only kills that booter; java keeps running and rebinding ports |
| Leaving stale CalVer plugin jars in `plugins/` | `restart-backend.sh` clears `*.jar` before installing | Old versions with a newer CalVer stay loaded; both get enabled at boot |
| Naming a backend with spaces/special chars | `[A-Za-z0-9_-]+` only | Names become server names in velocity.toml and runtime dirs |
| Expecting the status probe to prove routing | Read it as reachability; prove routing with a real login + `/server` | The proxy answers pings itself (`ping-passthrough = DISABLED`) |
| Using port 25565 on a backend | Backends bind 30067+; only the proxy owns 25565 | Only the proxy is reachable by the client |
| Expecting `/server` to work on a backend directly | `/server` is a Velocity built-in; it only exists on the proxy | Backends have no proxy command routing |
| Modifying a running server's config and expecting it to apply | Restart that component (or full `stop-dev-network.sh` + boot) | Velocity/Paper read configs at startup only |
| Hardcoding a production-grade forwarding secret | Use the fixed dev secret (or generate per-boot) | Local-dev secret; keep it out of any shared repo |