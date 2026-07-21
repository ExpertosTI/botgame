#!/usr/bin/env bash
# Export Godot en el VPS vía imagen godot-ci (templates incluidos).
# Sin rsync / sin passwords. Llamado por deploy.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_CI_IMAGE="${GODOT_CI_IMAGE:-barichello/godot-ci:4.3}"
export GODOT_SILENCE_ROOT_WARNING=1

log() { echo "[export-godot] $*"; }
die() { echo "[export-godot] ERROR: $*" >&2; exit 1; }

need_export() {
  if [ ! -f export/web/index.html ]; then return 0; fi
  if ! ls export/web/*.wasm >/dev/null 2>&1; then return 0; fi
  if [ ! -f export/server/BestiaVsRobots.x86_64 ]; then return 0; fi
  if head -1 export/server/BestiaVsRobots.x86_64 2>/dev/null | grep -q '^#!'; then return 0; fi
  if [ "${FORCE_GODOT_EXPORT:-0}" = "1" ]; then return 0; fi
  return 1
}

prepare_dirs() {
  mkdir -p export/web export/server
  if [ -f export/server/BestiaVsRobots.x86_64 ] && head -1 export/server/BestiaVsRobots.x86_64 | grep -q '^#!'; then
    rm -f export/server/BestiaVsRobots.x86_64
  fi
  # Placeholder web no debe confundir al export
  if [ -f export/web/index.html ] && ! ls export/web/*.wasm >/dev/null 2>&1; then
    rm -f export/web/index.html
  fi
}

export_with_docker() {
  command -v docker >/dev/null 2>&1 || die "docker no está en PATH"
  [ -f "$ROOT/export_presets.cfg" ] || die "Falta export_presets.cfg"

  log "Pull imagen $GODOT_CI_IMAGE (si hace falta)..."
  docker pull "$GODOT_CI_IMAGE"

  log "Export Web + Linux dentro de godot-ci..."
  # HOME del contenedor ya trae export_templates/4.3.stable
  docker run --rm \
    -e GODOT_SILENCE_ROOT_WARNING=1 \
    -v "$ROOT:/project" \
    -w /project \
    "$GODOT_CI_IMAGE" \
    bash -lc '
      set -euo pipefail
      echo "[ci] Godot: $(godot --version 2>/dev/null || true)"
      echo "[ci] Templates:"
      ls -la /root/.local/share/godot/export_templates/ 2>/dev/null || ls -la "$HOME/.local/share/godot/export_templates/" 2>/dev/null || true
      TPL=$(ls -d /root/.local/share/godot/export_templates/*.stable 2>/dev/null | head -1 || true)
      if [ -z "$TPL" ]; then
        TPL=$(ls -d "$HOME"/.local/share/godot/export_templates/*.stable 2>/dev/null | head -1 || true)
      fi
      echo "[ci] Using templates dir: ${TPL:-NONE}"
      ls -la "${TPL:-/nonexistent}" 2>/dev/null | head -20 || true

      rm -rf /project/.godot
      mkdir -p /project/export/web /project/export/server

      godot --headless --path /project --import > /tmp/import.log 2>&1 || true
      godot --headless --path /project --editor --quit-after 2 > /tmp/editor.log 2>&1 || true
      if grep -qiE "SCRIPT ERROR|Parse Error|Compile Error" /tmp/import.log /tmp/editor.log 2>/dev/null; then
        echo "[ci] Script errors:"
        grep -iE "SCRIPT ERROR|Parse Error|Compile Error" /tmp/import.log /tmp/editor.log | head -40
      fi

      echo "[ci] Export Web..."
      if ! godot --headless --path /project --export-release "Web" /project/export/web/index.html > /tmp/web.log 2>&1; then
        echo "[ci] WEB EXPORT FAILED"
        cat /tmp/web.log
        # Reintentar con thread_support forzado vía sed en preset
        exit 1
      fi

      echo "[ci] Export Linux..."
      if ! godot --headless --path /project --export-release "Linux" /project/export/server/BestiaVsRobots.x86_64 > /tmp/linux.log 2>&1; then
        echo "[ci] LINUX EXPORT FAILED"
        cat /tmp/linux.log
        exit 1
      fi

      chmod +x /project/export/server/BestiaVsRobots.x86_64 || true
      echo "[ci] Results:"
      ls -lh /project/export/web/ | head -20
      ls -lh /project/export/server/ | head -10
      ls /project/export/web/*.wasm >/dev/null
    '

  ls export/web/*.wasm >/dev/null 2>&1 || die "Export Web sin .wasm tras docker"
  [ -f export/server/BestiaVsRobots.x86_64 ] || die "Falta binario Linux"
  log "Export OK (godot-ci)"
}

main() {
  if ! need_export; then
    log "Exports ya presentes — omitiendo (FORCE_GODOT_EXPORT=1 para forzar)"
    return 0
  fi
  prepare_dirs
  export_with_docker
}

main "$@"
