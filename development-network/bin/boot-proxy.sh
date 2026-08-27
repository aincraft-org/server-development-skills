#!/usr/bin/env bash
# Boots the Velocity proxy (4.1.1, build 24) with a generated velocity.toml.
# Writes $BASE/runtime/proxy.ready when the proxy is accepting connections.
#
# Backends come from the registry (BACKENDS env or $BASE/runtime/backends.txt):
# one [servers] entry each, try = lobby + backends, deterministic ports
# (30067 + sorted-name index; override with PORT_<NAME>=<port>).
#
# Pins verified 2026-08-27 against https://fill.papermc.io/v3/projects/velocity
# and the official docs at https://docs.papermc.io/velocity/getting-started.

set -eo pipefail

VERSION="4.1.1"
BUILD="24"
SHA256="846411d2d0560fed0f23496ffb89681be528d2c0650ecdcf21724d2d7bd9c1ee"
BASE="${BASE:-$PWD/development-network}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PORT="${PROXY_PORT:-25565}"
TARGET_SERVER="${TARGET_SERVER:-localhost}"

[ -d "$BASE" ] || { echo "base dir missing: $BASE" >&2; exit 1; }
mkdir -p "$BASE/binaries" "$BASE/runtime"

# --- backend registry --------------------------------------------------------
if [ -f "$BASE/runtime/backends.txt" ] && [ -z "${BACKENDS+x}" ]; then
  BACKENDS="$(cat "$BASE/runtime/backends.txt")"
fi
BACKENDS="${BACKENDS:-dev}"
BACKENDS_SORTED="$(printf '%s\n' $BACKENDS | sort -u | tr '\n' ' ')"

backend_port() {
  local n="$1" key idx=0 x
  key="PORT_${n^^}"
  if [ -n "${!key:-}" ]; then
    echo "${!key}"
    return
  fi
  for x in $BACKENDS_SORTED; do
    if [ "$x" = "$n" ]; then
      echo $((30067 + idx))
      return
    fi
    idx=$((idx + 1))
  done
  echo 30067
}

for n in $BACKENDS_SORTED; do
  [[ "$n" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "invalid backend name: $n" >&2; exit 1; }
done

JAR="$BASE/binaries/velocity-$VERSION-$BUILD.jar"
"$BIN_DIR/fetch-jar.sh" \
  "https://fill-data.papermc.io/v1/objects/$SHA256/velocity-$VERSION-$BUILD.jar" \
  "$SHA256" "$JAR"

# --- write velocity.toml ----------------------------------------------------
# Modern forwarding needs: offline mode + a shared secret, mirrored in
# paper-global.yml on each backend. The secret is a dev secret, not a credential.
SECRET="dev-local-forwarding-secret-change-me"
FORWARDING_FILE="$BASE/runtime/forwarding.secret"
printf '%s\n' "$SECRET" > "$FORWARDING_FILE"

{
  cat <<EOF
config-version = "2.8"
bind = "0.0.0.0:$PROXY_PORT"
motd = "<#09add3>dev-network"
show-max-players = 20
online-mode = false
force-key-authentication = true
prevent-client-proxy-connections = false
player-info-forwarding-mode = "modern"
forwarding-secret-file = "$FORWARDING_FILE"
announce-forge = false
kick-existing-players = false
ping-passthrough = "DISABLED"
sample-players-in-ping = false
enable-player-address-logging = true

[servers]
EOF
  printf 'lobby = "%s:30066"\n' "$TARGET_SERVER"
  for n in $BACKENDS_SORTED; do
    printf '%s = "%s:%s"\n' "$n" "$TARGET_SERVER" "$(backend_port "$n")"
  done
  printf 'try = ["lobby"'
  for n in $BACKENDS_SORTED; do
    printf ', "%s"' "$n"
  done
  printf ']\n'
  cat <<EOF

[forced-hosts]

[advanced]
compression-threshold = 256
compression-level = -1
login-ratelimit = 3000
connection-timeout = 5000
read-timeout = 30000
haproxy-protocol = false
tcp-fast-open = false
bungee-plugin-message-channel = true
show-ping-requests = false
failover-on-unexpected-server-disconnect = true
announce-proxy-commands = true
log-command-executions = false
log-player-connections = true
accepts-transfers = false
enable-reuse-port = false
command-rate-limit = 50
forward-commands-if-rate-limited = true
kick-after-rate-limited-commands = 0
tab-complete-rate-limit = 10
kick-after-rate-limited-tab-completes = 0

[query]
enabled = false
port = 25565
map = "dev-network"
show-plugins = false
EOF
} > "$BASE/runtime/velocity.toml"

# --- run --------------------------------------------------------------------
cd "$BASE/runtime"
java -Xms256M -Xmx512M -XX:+UseG1GC -XX:G1HeapRegionSize=4M \
  -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch -XX:MaxInlineLevel=15 \
  -jar "$JAR" &

PROXY_PID=$!
echo "$PROXY_PID" > "$BASE/runtime/proxy.pid"
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT

for i in $(seq 1 120); do
  if (exec 3<>"/dev/tcp/127.0.0.1/$PROXY_PORT") 2>/dev/null; then
    exec 3>&- 3<&-
    touch "$BASE/runtime/proxy.ready"
    break
  fi
  kill -0 "$PROXY_PID" 2>/dev/null || { echo "proxy process died" >&2; exit 1; }
  sleep 1
done

[ -f "$BASE/runtime/proxy.ready" ] || { echo "proxy did not open port $PROXY_PORT" >&2; exit 1; }

# Give the JVM a moment to finish booting and log its banner.
sleep 2
wait "$PROXY_PID"