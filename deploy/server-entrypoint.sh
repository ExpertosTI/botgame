#!/bin/sh
# Arranque estable del servidor dedicado Godot en Swarm.
set -eu
cd /app

BIN="./BestiaVsRobots.x86_64"
if [ ! -x "$BIN" ]; then
  echo "[botgame-server] ERROR: no hay binario ejecutable $BIN"
  ls -la /app || true
  sleep 30
  exit 1
fi

# Diagnóstico ligero (no falla si falta ldd)
if command -v ldd >/dev/null 2>&1; then
  if ldd "$BIN" 2>/dev/null | grep -qi "not found"; then
    echo "[botgame-server] AVISO: faltan librerías:"
    ldd "$BIN" 2>/dev/null | grep -i "not found" || true
  fi
fi

PORT="${BOTGAME_WS_PORT:-7777}"
echo "[botgame-server] starting headless (port ${PORT})..."
# --headless + display/audio drivers explícitos (Godot 4.6 en Docker sin X11)
export BOTGAME_WS_PORT="$PORT"
exec "$BIN" --headless --display-driver headless --audio-driver Dummy -- --server
