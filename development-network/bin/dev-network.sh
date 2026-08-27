#!/usr/bin/env bash
# Dev Velocity network harness: one proxy, one lobby, N isolated dev backends.
# The user connects to ONE address (localhost:25565) and multiplexes with
# the built-in /server command.
#
# Backends:   BACKENDS="name1 name2 ..." (or backends.txt persists the registry).
#             Each managed backend is a fully isolated Paper server
#             (runtime/<name>/), one plugin per backend via PLUGIN_<NAME>.
# External:   EXTERNAL_BACKENDS="name ..." joins ALREADY-RUNNING servers
#             (e.g. a plugin's own runServer) without managing their lifecycle;
#             boot-external.sh configures + registers them.
# Runtime:    $BASE (default ./development-network).
# Teardown:  Ctrl-C here (SIGINT to all booters; their EXIT traps stop java),
#            or ./bin/stop-dev-network.sh.

set -eo pipefail

BASE="${BASE:-$PWD/development-network}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$BASE/logs" "$BASE/runtime"

# Auto-discovery FIRST: any folder in runtime/auto/<NAME>/ (with your plugin
# jar in its plugins/ dir) is a MANAGED backend — the harness generates its
# config (forwarding secret, ops), picks its port, and boots it. Zero env
# vars. The proxy cannot start servers; the harness does, and it manages them.
AUTO_NAMES=""
if [ -d "$BASE/runtime/auto" ]; then
  for d in "$BASE/runtime/auto"/*/; do
    [ -d "$d" ] || continue
    AUTO_NAMES="$AUTO_NAMES $(basename "$d")"
  done
fi
AUTO_NAMES="$(printf '%s\n' $AUTO_NAMES | sort -u | tr '\n' ' ')"

# Resolve registry: explicit BACKENDS wins; else persisted file; else default
# dev — UNLESS auto-discovered dirs exist, which replace the default.
if [ -n "${BACKENDS:-}" ]; then
  printf '%s\n' $BACKENDS > "$BASE/runtime/backends.txt"
else
  if [ -f "$BASE/runtime/backends.txt" ]; then
    BACKENDS="$(cat "$BASE/runtime/backends.txt")"
  elif [ -z "$AUTO_NAMES" ]; then
    printf '%s\n' dev > "$BASE/runtime/backends.txt"
    BACKENDS=dev
  else
    BACKENDS=""
  fi
fi

REGISTRY="$(printf '%s\n' $BACKENDS $AUTO_NAMES ${EXTERNAL_BACKENDS:-} | sort -u)"
printf '%s\n' $REGISTRY > "$BASE/runtime/backends.txt"

echo "== auto-discovered backends: ${AUTO_NAMES:-none}"

echo "== dev-network: launching components (logs in $BASE/logs) =="
echo "== backends: $BACKENDS"
echo "== external backends: ${EXTERNAL_BACKENDS:-none}"

PIDS=()
spawn() {
  "$@" &
  PIDS+=("$!")
}

teardown() {
  echo "== dev-network: shutting down =="
  kill "${PIDS[@]}" 2>/dev/null || true
  for p in "${PIDS[@]}"; do
    wait "$p" 2>/dev/null || true
  done
  exit 0
}
trap teardown INT TERM EXIT

cd "$BASE"
spawn "$BIN_DIR/boot-lobby.sh"
spawn env BACKENDS="$REGISTRY" "$BIN_DIR/boot-proxy.sh"
for name in $REGISTRY; do
  if printf '%s\n' ${EXTERNAL_BACKENDS:-} | grep -qx "$name"; then
    spawn env BACKENDS="$REGISTRY" "$BIN_DIR/boot-external.sh" "$name"
  elif [ -d "$BASE/runtime/auto/$name" ]; then
    spawn env BACKENDS="$REGISTRY" SERVER_DIR="$BASE/runtime/auto/$name" \
      "$BIN_DIR/boot-backend.sh" "$name"
  else
    spawn env BACKENDS="$REGISTRY" "$BIN_DIR/boot-backend.sh" "$name"
  fi
done

echo "== waiting for components to become ready =="
for c in proxy lobby $REGISTRY; do
  ok=0
  for _ in $(seq 1 240); do
    if [ -f "$BASE/runtime/$c.ready" ]; then
      ok=1
      break
    fi
    sleep 1
  done
  if [ "$ok" = 1 ]; then
    echo "== $c ready =="
  else
    echo "!! $c did not become ready; check $BASE/logs/$c.log" >&2
    sed 's/^/    /' "$BASE/logs/$c.log" >&2 || true
    exit 1
  fi
done

echo
echo "== network is up =="
echo "    Connect Minecraft to  localhost:25565"
echo "    Initial server:       lobby"
echo "    Switch with:          /server <name>"
for name in $BACKENDS; do
  echo "                          /server $name  (backend $name)"
done
echo "    Console admin:        log in as ${DEV_USERS:-dev} (opped on every server)"
echo "    Component logs:       $BASE/logs/{proxy,lobby,<name>}.log"
echo "    Rebuild + restart a backend:"
echo "        ./bin/restart-backend.sh <name> /path/to/plugin.jar"
echo "    Stop everything:      Ctrl-C here, or ./bin/stop-dev-network.sh"

# Blocks until all booters exit (booter exit = proxy/backend shutdown).
# A regular `wait` includes every child; killing is done by the trap above.
wait