#!/usr/bin/env bash
# Export Godot en el VPS (Linux). Sin rsync / sin passwords.
# Llamado por deploy.sh. Cache en /var/cache/botgame-godot
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VER="${GODOT_VER:-4.3-stable}"
CACHE="${BOTGAME_GODOT_CACHE:-/var/cache/botgame-godot}"
GODOT_BIN="$CACHE/Godot_v${GODOT_VER}_linux.x86_64"
# Godot 4.3 busca plantillas en: ~/.local/share/godot/export_templates/4.3.stable
TPL_DEST="$HOME/.local/share/godot/export_templates/4.3.stable"

export GODOT_SILENCE_ROOT_WARNING=1

log() { echo "[export-godot] $*"; }
die() { echo "[export-godot] ERROR: $*" >&2; exit 1; }

ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then
    return 0
  fi
  log "Instalando unzip..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip
  else
    die "No hay unzip y no se pudo instalar"
  fi
}

extract_zip() {
  ensure_unzip
  unzip -qo "$1" -d "$2"
}

need_export() {
  if [ ! -f export/web/index.html ]; then return 0; fi
  if ! ls export/web/*.wasm >/dev/null 2>&1; then return 0; fi
  if [ ! -f export/server/BestiaVsRobots.x86_64 ]; then return 0; fi
  if head -1 export/server/BestiaVsRobots.x86_64 2>/dev/null | grep -q '^#!'; then return 0; fi
  if [ "${FORCE_GODOT_EXPORT:-0}" = "1" ]; then return 0; fi
  return 1
}

install_godot() {
  local found
  found="$(find "$CACHE" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' 2>/dev/null | head -1 || true)"
  if [ -n "$found" ] && [ -x "$found" ]; then
    GODOT_BIN="$found"
    log "Godot OK: $GODOT_BIN"
    return
  fi
  log "Descargando Godot $GODOT_VER (linux.x86_64)..."
  mkdir -p "$CACHE"
  local zip="$CACHE/godot.zip"
  curl -fsSL -o "$zip" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  extract_zip "$zip" "$CACHE"
  found="$(find "$CACHE" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' | head -1)"
  [ -n "$found" ] || die "No se encontró binario Godot tras unzip"
  chmod +x "$found"
  GODOT_BIN="$found"
  log "Godot instalado: $GODOT_BIN"
}

templates_ok() {
  # thread_support=false → web_nothreads_*; Linux dedicado → linux_release.x86_64
  [ -f "$TPL_DEST/web_nothreads_release.zip" ] && [ -f "$TPL_DEST/linux_release.x86_64" ]
}

install_templates() {
  if templates_ok && [ "${FORCE_GODOT_TEMPLATES:-0}" != "1" ]; then
    log "Templates OK: $TPL_DEST"
    ls "$TPL_DEST" | head -20
    return
  fi
  log "Descargando export templates $GODOT_VER..."
  mkdir -p "$HOME/.local/share/godot/export_templates" "$CACHE"
  local tpz="$CACHE/export_templates.tpz"
  curl -fsSL -o "$tpz" \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_export_templates.tpz"
  local tmp="$CACHE/tpl_extract"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  extract_zip "$tpz" "$tmp"
  [ -d "$tmp/templates" ] || die "El .tpz no contiene carpeta templates/"
  rm -rf "$TPL_DEST"
  mv "$tmp/templates" "$TPL_DEST"
  log "Templates en $TPL_DEST:"
  ls -lh "$TPL_DEST" | head -30
  templates_ok || die "Faltan web_nothreads_release.zip o linux_release.x86_64 en $TPL_DEST"
}

run_export() {
  [ -f "$ROOT/export_presets.cfg" ] || die "Falta export_presets.cfg"

  mkdir -p export/web export/server
  if [ -f export/server/BestiaVsRobots.x86_64 ] && head -1 export/server/BestiaVsRobots.x86_64 | grep -q '^#!'; then
    rm -f export/server/BestiaVsRobots.x86_64
  fi

  log "Importando proyecto (.godot)..."
  "$GODOT_BIN" --headless --path "$ROOT" --import >/tmp/botgame-godot-import.log 2>&1 || true
  # Segunda pasada: asegura que los scripts compilan
  "$GODOT_BIN" --headless --path "$ROOT" --editor --quit-after 3 >/tmp/botgame-godot-editor.log 2>&1 || true

  if grep -qiE 'SCRIPT ERROR|Parse Error|Compile Error' /tmp/botgame-godot-editor.log /tmp/botgame-godot-import.log 2>/dev/null; then
    warn_scripts=1
    log "AVISO: hay errores de script en import — dump:"
    grep -iE 'SCRIPT ERROR|Parse Error|Compile Error' /tmp/botgame-godot-editor.log /tmp/botgame-godot-import.log 2>/dev/null | head -20 || true
  fi

  log "Export Web → export/web/index.html"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$ROOT/export/web/index.html" \
      >/tmp/botgame-export-web.log 2>&1; then
    echo "----- /tmp/botgame-export-web.log -----" >&2
    cat /tmp/botgame-export-web.log >&2
    echo "----- templates dir -----" >&2
    ls -la "$TPL_DEST" >&2 || true
    die "Export Web falló"
  fi

  log "Export Linux → export/server/BestiaVsRobots.x86_64"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux" "$ROOT/export/server/BestiaVsRobots.x86_64" \
      >/tmp/botgame-export-linux.log 2>&1; then
    echo "----- /tmp/botgame-export-linux.log -----" >&2
    cat /tmp/botgame-export-linux.log >&2
    die "Export Linux falló"
  fi

  chmod +x export/server/BestiaVsRobots.x86_64 || true
  ls -lh export/web/ | head -20
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
  [ -x "$GODOT_BIN" ] || die "Godot no ejecutable: $GODOT_BIN"
  install_templates
  run_export
}

main "$@"
