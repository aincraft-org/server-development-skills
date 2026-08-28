---
name: development-network
description: Use when setting up a local Velocity proxy development network — a proxy with a basic lobby server plus one or more isolated dev Paper servers behind it — so a user connects to ONE address (localhost:25565) and multiplexes between different plugin development environments with the built-in /server command instead of connecting to multiple servers. Triggers include booting a dev Velocity network, the runNetwork Gradle task and includeBuild wiring, per-plugin dev servers, drop-in runtime/auto backends, proxy multiplexing, the /server switch command, BACKENDS registration, connecting an external runServer to the network (EXTERNAL_BACKENDS), DEV_USERS operator setup and ops.json offline UUIDs, proxy permission nodes (velocity.command.*, /lpv), velocity.toml, forwarding.secret, paper-global.yml proxies.velocity, restarting one backend after a plugin rebuild, and cleanly stopping the whole network.
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
├── network/                    # Gradle plugin (io.github.development-network) — runNetwork task
│   ├── build.gradle.kts        #   java-gradle-plugin + Kotlin 2.4.0 (matches Gradle 9.7.1)
│   └── src/main/kotlin/…       #   DevNetworkPlugin + RunNetworkTask
└── bin/
    ├── dev-network.sh          # boot proxy + lobby + all registered backends
    ├── stop-dev-network.sh     # graceful per-pidfile stop of proxy, lobby, backends
    ├── restart-backend.sh      # stop ONE backend, install new plugin jar, boot it
    ├── boot-proxy.sh           # download+verify Velocity, generate velocity.toml
    ├── boot-lobby.sh           # download+verify Paper, configure, run lobby (30066)
    ├── boot-backend.sh         # download+verify Paper, configure, run ONE backend
    ├── boot-external.sh        # register+configure an ALREADY-RUNNING server (never starts it)
    ├── fetch-jar.sh            # atomic pinned download (tmp + sha256 + rename, flocked)
    ├── write-ops.sh            # write ops.json (level 4) for DEV_USERS (offline UUIDs)
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

## Port allocation

Ports are allocated in one shared mapping (the same math `boot-backend.sh`/`boot-external.sh` use, so they always agree with the proxy):

1. **Default**: `30067 + sorted-registry-index` — each backend's position in the sorted name list.
2. **Explicit override wins**: `PORT_<NAME>` (e.g. `PORT_DEMO=31001`) beats the default.
3. **Externals reserve their port** (explicit or default) and are **never reassigned** — a live server's port is fixed.
4. **Managed autos skip** anything occupied **or already reserved** (external or explicit), scanning upward from their default.

So `demo ext` with no overrides → demo `30067`, ext `30068`; if `30068` is taken by an external, a managed auto moves up to the next free port. The proxy, lobby (`30066`), and proxy port (`25565`) are checked up front and fail fast if in use.

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

## Gradle integration: `runNetwork` task

The harness ships as a Gradle plugin (`io.github.development-network`, module `network/`). Once wired, plugin projects spawn the whole network — proxy + lobby + their managed backend — with automatic port registration, instead of a bare `runServer`:

```kotlin
// settings.gradle.kts
includeBuild("/path/to/development-network/network")

// build.gradle.kts — inside the EXISTING plugins block (a second plugins block is illegal)
plugins {
    id("io.github.development-network")
}
```

```bash
./gradlew runNetwork
# -PnetworkBackend=<name>   backend name (default: project.name)
# -PnetworkBase=<dir>       network runtime dir (default: run/network)
# -PnetworkProxyPort=<n>    proxy port (default: 25565; 0 = auto-pick a free port)
# -PnetworkJarTask=<name>   Jar task to deploy (default: "jar")
# -PdevNetworkBin=<dir>     harness bin (default: $DEV_NETWORK_BIN, else ROOT/development-network/bin)
```

`runNetwork` builds the jar (its actual `archiveFile`, so shadowJar/archive overrides work), copies it into `runtime/auto/<name>/plugins/`, finds free ports, spawns the network with the harness, and blocks like run-paper; Ctrl-C tears it all down. The Kotlin pin is **2.4.0** (Gradle 9.7.1 bundles 2.4.0; older Kotlin fails the applied-script/Kotlin-module checks), and the task class must stay `abstract` (Gradle requirement).

## Repository structure

The harness and Gradle plugin ship **inside this repo** as a first-party skill directory — per repo precedent, only third-party content is vendored as a submodule (`superpowers`); first-party skills live as dirs and compose with the sibling skills they depend on (`project-setup`, `autonomous-testing`). Nobody needs to clone anything extra to use it: `includeBuild("./development-network/network")`.

**Future extraction** (only if the harness must live independently): do it only once a **new remote exists** — a submodule pointing at a not-yet-pushed repo breaks fresh clones (bootstrap order). Then: `git mv` the dir into the new repo, push it, `git submodule add <remote> development-network`, pin to a tag (like `superpowers`), and update the consumer `includeBuild` path in this section.

## Permissions & console admin

**Backend servers opp the developer automatically.** Every boot writes `ops.json` (operator level 4) for the accounts in `DEV_USERS` (space-separated, default `dev`):

```bash
DEV_USERS='dev jlo' BACKENDS='demo vanilla' ./development-network/bin/dev-network.sh
```

Each backend is OFFLINE mode, so ops use the **name-derived offline UUID** — the exact `java.util.UUID.nameUUIDFromBytes("OfflinePlayer:"+name)` algorithm — computed by `bin/write-ops.sh` (verified byte-for-byte against Java). Log into any backend as `dev` (or your name) and you are opped there.

**The proxy has NO ops.** Velocity is permission-node based, and the harness ships no proxy permission plugin, so proxy commands are governed by Velocity's defaults:

- gated by default: `/velocity plugins|info|reload|dump|heap` → `velocity.command.*`, `/glist` → `velocity.command.glist`, `/send` → `velocity.command.send` — all granted to **nobody** in the harness;
- open to everyone: `/server <name>` → `velocity.command.server` (default-all).

To open proxy admin commands, install a proxy permissions plugin (e.g. LuckPerms on the proxy — note its command is `/lpv` there, and `velocity.command.*` nodes are what matter) or add one via a plugin. Backend `*`/op does not carry to the proxy; the two permission systems are fully separate.

## Iterating: rebuild → restart ONE backend

```bash
# in the plugin project
./gradlew build
# deploy + restart just "demo" (lobby, proxy, other backends stay up)
./development-network/bin/restart-backend.sh demo /path/to/demo/plugin.jar
```

## Drop-in backends (fully managed, zero env vars)

The proxy itself is only a router — **it cannot start or stop servers**. The harness manages servers; drop-in mode makes that fully automatic. Put each plugin's server folder (with the built jar in its `plugins/`) under `runtime/auto/<name>/`:

```text
development-network/runtime/auto/
├── myplugin/plugins/myplugin.jar
└── other/plugins/other-<calver>.jar
```

Then just boot:

```bash
./development-network/bin/dev-network.sh
```

The harness discovers every `runtime/auto/*/` folder, generates its full config (Velocity modern-forwarding secret, `online-mode=false`, ops via `write-ops.sh`), picks a free port, registers it in `velocity.toml` `[servers]`/`try`, boots it, opps your `DEV_USERS`, and manages it (pidfile, restart via `restart-backend.sh <name> <jar>`, stop). No `BACKENDS`/`PLUGIN_*` env vars needed. When auto dirs exist they replace the default `dev` backend.

## Bring your own server (join an external server)

Don't want the harness to run your server? Join an **already-running** Paper server (e.g. your plugin's own `./gradlew runServer` launched in the plugin project) to the network as a backend. **The harness never modifies the external server's files and never starts/stops it** — it only registers it and verifies the forwarding config.

One-time external-server setup (in the plugin project's server dir):

```yaml
# config/paper-global.yml (keep the rest of the file; Paper merges)
proxies:
  velocity:
    enabled: true
    online-mode: false
    secret: "dev-local-forwarding-secret-change-me"
```

plus `online-mode=false` in `server.properties`, then **restart the external server once**. After that, join it:

```bash
EXTERNAL_DIR_NAMEPLUG=/path/to/plugin-project/run \
BACKENDS='dev' EXTERNAL_BACKENDS='nameplug' \
./development-network/bin/dev-network.sh
```

- `EXTERNAL_BACKENDS` names are merged into the registry, so the proxy's `[servers]` includes them (and port math covers them — `PORT_<NAME>` overrides still work).
- `boot-external.sh` verifies the forwarding config is present (prints the exact block + path if missing) and confirms the server is reachable; it writes only the `runtime/<name>.ready` marker.
- External servers are **not** auto-opped (`write-ops.sh` only runs for managed backends); op yourself with `/op <name>` or your normal plugin flow.
- The stop script never stops external servers — no pidfile means it leaves them alone; you stop `runServer` in the plugin project as usual.

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
- Jar downloads are atomic and race-safe: temp file in the same dir, SHA-256 verify, `mv` into place, per-jar `flock` — a fresh multi-backend boot cannot corrupt a jar that another booter is still writing.
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
| Logging in without ops and expecting console admin | Set `DEV_USERS` to your account before boot | Ops come from `ops.json` (offline UUIDs) written per boot |
| Computing offline UUIDs with `uuid3(nil, ...)` | Use `java.util.UUID.nameUUIDFromBytes("OfflinePlayer:"+name)` (raw md5) | The nil-namespace prefix yields a wrong UUID that never matches the player |
| Expecting `*`/op on a backend to grant proxy commands | Install a proxy permissions plugin (e.g. LuckPerms, `/lpv`) and grant `velocity.command.*` | Backend and proxy permission systems are fully separate |
| Using port 25565 on a backend | Backends bind 30067+; only the proxy owns 25565 | Only the proxy is reachable by the client |
| Expecting `/server` to work on a backend directly | `/server` is a Velocity built-in; it only exists on the proxy | Backends have no proxy command routing |
| Modifying a running server's config and expecting it to apply | Restart that component (or full `stop-dev-network.sh` + boot) | Velocity/Paper read configs at startup only |
| Hardcoding a production-grade forwarding secret | Use the fixed dev secret (or generate per-boot) | Local-dev secret; keep it out of any shared repo |