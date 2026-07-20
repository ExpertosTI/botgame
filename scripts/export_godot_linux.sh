#!/usr/bin/env bash
# Export Godot en el VPS (Linux). Sin rsync / sin passwords.
# Llamado por deploy.sh. Cache en /var/cache/botgame-godot
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VER="${GODOT_VER:-4.3-stable}"
CACHE="${BOTGAME_GODOT_CACHE:-/var/cache/botgame-godot}"
GODOT_BIN="$CACHE/Godot_v${GODOT_VER}_linux.x86_64"
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER}"
# Godot 4.x Linux también busca en:
TPL_DIR_ALT="$HOME/.local/share/godot/export_templates/4.3.stable"

log() { echo "[export-godot] $*"; }
die() { echo "[export-godot] ERROR: $*" >&2; exit 1; }

# unzip no siempre está en el VPS minimal
ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then
    return 0
  fi
  log "Instalando unzip..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip
  else
    die "No hay unzip y no se pudo instalar (apt/dnf)"
  fi
  command -v unzip >/dev/null 2>&1 || die "unzip sigue sin estar disponible"
}

extract_zip() {
  local zip="$1"
  local dest="$2"
  ensure_unzip
  unzip -qo "$zip" -d "$dest"
}

need_export() {
  # ¿Hay export web real (wasm) y binario linux no-shell?
  if [ ! -f export/web/index.html ]; then return 0; fi
  if ! ls export/web/*.wasm >/dev/null 2>&1; then return 0; fi
  if [ ! -f export/server/BestiaVsRobots.x86_64 ]; then return 0; fi
  if head -1 export/server/BestiaVsRobots.x86_64 2>/dev/null | grep -q '^#!'; then return 0; fi
  if [ "${FORCE_GODOT_EXPORT:-0}" = "1" ]; then return 0; fi
  return 1
}

install_godot() {
  if [ -x "$GODOT_BIN" ]; then
    log "Godot OK: $GODOT_BIN"
    return
  fi
  log "Descargando Godot $GODOT_VER (linux.x86_64)..."
  mkdir -p "$CACHE"
  local zip="$CACHE/godot.tgz"
  curl -fsSL -o "$zip" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  extract_zip "$zip" "$CACHE"
  # El binario puede llamarse Godot_v4.3-stable_linux.x86_64
  local found
  found="$(find "$CACHE" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' | head -1)"
  [ -n "$found" ] || die "No se encontró binario Godot tras unzip"
  chmod +x "$found"
  GODOT_BIN="$found"
  log "Godot instalado: $GODOT_BIN"
}

install_templates() {
  local dest="$HOME/.local/share/godot/export_templates/4.3.stable"
  if [ -f "$dest/web_release.zip" ] || [ -f "$dest/linux_release.x86_64" ]; then
    log "Templates OK: $dest"
    return
  fi
  log "Descargando export templates..."
  mkdir -p "$HOME/.local/share/godot/export_templates"
  local tpz="$CACHE/export_templates.tpz"
  mkdir -p "$CACHE"
  curl -fsSL -o "$tpz" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_export_templates.tpz"
  local tmp="$CACHE/tpl_extract"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  extract_zip "$tpz" "$tmp"
  rm -rf "$dest"
  mv "$tmp/templates" "$dest"
  log "Templates en $dest"
}

run_export() {
  [ -f "$ROOT/export_presets.cfg" ] || die "Falta export_presets.cfg en el repo"

  mkdir -p export/web export/server
  # Quitar placeholder shell del server
  if [ -f export/server/BestiaVsRobots.x86_64 ] && head -1 export/server/BestiaVsRobots.x86_64 | grep -q '^#!'; then
    rm -f export/server/BestiaVsRobots.x86_64
  fi

  log "Importando proyecto..."
  "$GODOT_BIN" --headless --path "$ROOT" --import >/tmp/botgame-godot-import.log 2>&1 || true
  "$GODOT_BIN" --headless --path "$ROOT" --editor --quit-after 2 >/tmp/botgame-godot-editor.log 2>&1 || true

  log "Export Web → export/web/index.html"
  "$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$ROOT/export/web/index.html" \
    >/tmp/botgame-export-web.log 2>&1 || {
      tail -40 /tmp/botgame-export-web.log >&2
      die "Export Web falló (ver /tmp/botgame-export-web.log)"
    }

  log "Export Linux → export/server/BestiaVsRobots.x86_64"
  "$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux" "$ROOT/export/server/BestiaVsRobots.x86_64" \
    >/tmp/botgame-export-linux.log 2>&1 || {
      tail -40 /tmp/botgame-export-linux.log >&2
      die "Export Linux falló (ver /tmp/botgame-export-linux.log)"
    }

  chmod +x export/server/BestiaVsRobots.x86_64 || true
  ls -lh export/web/ | head -15
  ls -lh export/server/ | head -10
  ls export/web/*.wasm >/dev/null 2>&1 || die "Export Web sin .wasm"
  log "Export OK"
}

main() {
  if ! need_export; then
    log "Exports ya presentes — omitiendo (FORCE_GODOT_EXPORT=1 para forzar)"
    return 0
  fi
  install_godot
  # Re-resolver bin por si find cambió
  if [ ! -x "$GODOT_BIN" ]; then
    GODOT_BIN="$(find "$CACHE" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' | head -1)"
  fi
  [ -x "$GODOT_BIN" ] || die "Godot no ejecutable"
  install_templates
  run_export
}

main "$@"
