#!/usr/bin/env bash
# Boots a basic lobby Paper server on port 30066 behind the proxy.
# No plugins; just a stable lobby the user returns to.
# Developer accounts (DEV_USERS, default "dev") are opped via ops.json.
#
# Pins verified 2026-08-27 against https://fill.papermc.io/v3/projects/paper
# (Paper 26.2, build 119, Java 25 minimum) and the official docs at
# https://docs.papermc.io/velocity/player-information-forwarding.

set -eo pipefail

VERSION="26.2"
BUILD="119"
SHA256="a8c9140c3075bd7c04973e9cdc491b21bfe6bad472b674ef932a4ae0fec19629"
BASE="${BASE:-$PWD/development-network}"
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_PORT="${SERVER_PORT:-30066}"
TARGET_SERVER="${TARGET_SERVER:-localhost}"

[ -d "$BASE" ] || { echo "base dir missing: $BASE" >&2; exit 1; }
mkdir -p "$BASE/binaries" "$BASE/runtime"

JAR="$BASE/binaries/paper-$VERSION-$BUILD.jar"
if [ ! -f "$JAR" ]; then
  echo "   lobby: downloading paper-$VERSION-$BUILD.jar"
  curl -fsSL \
    "https://fill-data.papermc.io/v1/objects/$SHA256/paper-$VERSION-$BUILD.jar" \
    -o "$JAR"
  echo "$SHA256  $JAR" | sha256sum -c - >/dev/null
fi

WORKDIR="$BASE/runtime/lobby"
mkdir -p "$WORKDIR"

# --- config ---------------------------------------------------------------
cat > "$WORKDIR/server.properties" <<EOF
server-port=$SERVER_PORT
online-mode=false
level-name=world
motd=dev-network lobby
EOF

mkdir -p "$WORKDIR/config"
cat > "$WORKDIR/config/paper-global.yml" <<EOF
proxies:
  velocity:
    enabled: true
    online-mode: false
    secret: "dev-local-forwarding-secret-change-me"
EOF

cat > "$WORKDIR/eula.txt" <<EOF
eula=true
EOF

# Velocity modern forwarding (and offline mode) require BungeeCord forwarding off.
cat > "$WORKDIR/spigot.yml" <<EOF
settings:
  bungeecord: false
EOF

# Developer accounts get operator level 4 (offline UUIDs, DEV_USERS default "dev").
"$BIN_DIR/write-ops.sh" "$WORKDIR"

# --- run --------------------------------------------------------------------
cd "$WORKDIR"
java -Xms512M -Xmx1G -XX:+UseG1GC \
  -jar "$JAR" nogui &

SERVER_PID=$!
echo "$SERVER_PID" > "$BASE/runtime/lobby.pid"
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

for i in $(seq 1 240); do
  if (exec 3<>"/dev/tcp/127.0.0.1/$SERVER_PORT") 2>/dev/null; then
    exec 3>&- 3<&-
    touch "$BASE/runtime/lobby.ready"
    break
  fi
  kill -0 "$SERVER_PID" 2>/dev/null || { echo "lobby process died" >&2; exit 1; }
  sleep 1
done

[ -f "$BASE/runtime/lobby.ready" ] || { echo "lobby did not open port $SERVER_PORT" >&2; exit 1; }

# Let the server print its Done banner before the proxy starts probing it.
sleep 2
wait "$SERVER_PID"