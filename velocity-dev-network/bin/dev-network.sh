#!/usr/bin/env bash
# Dev Velocity network harness: one proxy, one lobby, N isolated dev backends.
# The user connects to ONE address (localhost:25565) and multiplexes with
# the built-in /server command.
#
# Backends:  BACKENDS="name1 name2 ..." (or $BASE/runtime/backends.txt persists
#            the registry). Each backend is a fully isolated Paper server
#            (runtime/<name>/), one plugin per backend via PLUGIN_<NAME>.
# Runtime:   $BASE (default ./velocity-dev-network).
# Teardown:  Ctrl-C here (SIGINT to all booters; their EXIT traps stop java),
#            or ./bin/stop-dev-network.sh.

set -eo pipefail

BASE="${BASE:-$PWD/velocity-dev-network}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$BASE/logs" "$BASE/runtime"

# Resolve registry: explicit BACKENDS wins; else persisted file; else default.
if [ -n "${BACKENDS:-}" ]; then
  printf '%s\n' $BACKENDS > "$BASE/runtime/backends.txt"
else
  if [ ! -f "$BASE/runtime/backends.txt" ]; then
    printf '%s\n' dev > "$BASE/runtime/backends.txt"
  fi
  BACKENDS="$(cat "$BASE/runtime/backends.txt")"
fi

echo "== dev-network: launching components (logs in $BASE/logs) =="
echo "== backends: $BACKENDS"

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
spawn "$BIN_DIR/boot-proxy.sh"
for name in $(printf '%s\n' $BACKENDS | sort -u); do
  spawn env BACKENDS="$BACKENDS" "$BIN_DIR/boot-backend.sh" "$name"
done

echo "== waiting for components to become ready =="
for c in proxy lobby $BACKENDS; do
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
echo "    Component logs:       $BASE/logs/{proxy,lobby,<name>}.log"
echo "    Rebuild + restart a backend:"
echo "        ./bin/restart-backend.sh <name> /path/to/plugin.jar"
echo "    Stop everything:      Ctrl-C here, or ./bin/stop-dev-network.sh"

# Blocks until all booters exit (booter exit = proxy/backend shutdown).
# A regular `wait` includes every child; killing is done by the trap above.
wait