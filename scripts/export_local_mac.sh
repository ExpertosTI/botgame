#!/usr/bin/env bash
# Solo export LOCAL opcional (Mac). Deploy = git push + VPS ./deploy.sh
# NO usa rsync ni pide contraseñas.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_DIR="${GODOT_DIR:-$HOME/.local/share/godot-botgame}"
GODOT_BIN="$GODOT_DIR/Godot.app/Contents/MacOS/Godot"
GODOT_VER="4.3-stable"

die() { echo "ERROR: $*" >&2; exit 1; }

if [ ! -x "$GODOT_BIN" ]; then
  echo "Instala Godot 4.3 o deja que el VPS exporte solo:"
  echo "  git push && en el VPS: cd /opt/botgame && ./deploy.sh update"
  exit 1
fi

mkdir -p export/web export/server
"$GODOT_BIN" --headless --path "$ROOT" --import || true
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "export/web/index.html"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux" "export/server/BestiaVsRobots.x86_64"
echo "Export local OK. Siguiente: git add/commit/push (no rsync)."
echo "En VPS: cd /opt/botgame && ./deploy.sh update"
