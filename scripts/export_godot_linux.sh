#!/usr/bin/env bash
# Export Godot en el VPS (Linux). Optimizado para ciclos cortos.
# Llamado por deploy.sh. Cache en /var/cache/botgame-godot
#
# Env:
#   FORCE_GODOT_EXPORT=1   fuerza re-export aunque el stamp coincida
#   FORCE_GODOT_IMPORT=1   borra .godot y reimporta (lento; solo si cache corrupta)
#   SKIP_GODOT_IMPORT=1    no pasa --import; el export importa lo sucio (rápido)
#   GODOT_IMPORT_TIMEOUT=900  segundos máx para --import (0 = sin límite)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VER="${GODOT_VER:-4.3-stable}"
CACHE="${BOTGAME_GODOT_CACHE:-/var/cache/botgame-godot}"
GODOT_BIN="$CACHE/Godot_v${GODOT_VER}_linux.x86_64"
TPL_DEST="$HOME/.local/share/godot/export_templates/4.3.stable"
STAMP_FILE="$CACHE/export.stamp"
IMPORT_TIMEOUT="${GODOT_IMPORT_TIMEOUT:-900}"

export GODOT_SILENCE_ROOT_WARNING=1

log() { echo "[export-godot] $*"; }
die() { echo "[export-godot] ERROR: $*" >&2; exit 1; }

set_status() {
  printf '%s\n%s\n' "$1" "$(date -Is 2>/dev/null || date)" > /tmp/botgame-export-status.txt
}

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

# Packs crudos / dupes: no deben vivir en el árbol del proyecto en el VPS.
prune_import_junk() {
  local removed=0
  local d
  for d in \
    assets/descargas \
    assets/kaykit \
    assets/kenney/animated-characters-protagonists \
    assets/kenney/animated-characters-retro \
    assets/kenney/blocky-characters_20 \
    assets/kenney/mini-characters \
    assets/kenney/monster-builder-pack \
    assets/kenney/retro-fantasy-kit \
    assets/kenney/retro-textures-fantasy \
    assets/kenney/castle-kit \
    assets/kenney/modular-cave-kit_1.0 \
    assets/kenney/mini-forest_1.0 \
    assets/video/cinematics \
    _tmp_kits
  do
    if [ -d "$ROOT/$d" ]; then
      # Conservar si hay .gdignore (Godot ya lo ignora); borrar zips sueltos
      find "$ROOT/$d" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.tpz' \) -delete 2>/dev/null || true
      # Si el directorio es solo pack crudo gitignored y pesa >5MB sin props útiles, no tocar props/
      removed=1
    fi
  done
  # Asegurar .gdignore aunque el pull sea viejo / packs locales residuales
  mkdir -p "$ROOT/assets/descargas" "$ROOT/assets/kaykit"
  for d in \
    assets/descargas \
    assets/kaykit \
    assets/kenney/animated-characters-protagonists \
    assets/kenney/animated-characters-retro \
    assets/kenney/blocky-characters_20 \
    assets/kenney/mini-characters \
    assets/kenney/monster-builder-pack \
    assets/kenney/retro-fantasy-kit \
    assets/kenney/retro-textures-fantasy \
    assets/kenney/castle-kit \
    assets/kenney/modular-cave-kit_1.0 \
    assets/kenney/mini-forest_1.0 \
    assets/video/cinematics
  do
    if [ -d "$ROOT/$d" ] && [ ! -f "$ROOT/$d/.gdignore" ]; then
      echo "ignore" > "$ROOT/$d/.gdignore"
    fi
  done
  if [ "$removed" = "1" ]; then
    log "Junk de import preparado (.gdignore / zips)"
  fi
}

fingerprint() {
  # Huella de lo que afecta al export (rápida, sin hashear binarios enteros)
  local sha files
  sha="$(git rev-parse HEAD 2>/dev/null || echo nogit)"
  files="$(git ls-files -z -- \
    'project.godot' 'export_presets.cfg' \
    '*.gd' '*.tscn' '*.tres' '*.glb' '*.gltf' \
    '*.png' '*.svg' '*.ogg' '*.wav' '*.mp3' '*.mp4' '*.webm' \
    '*.ttf' '*.otf' '*.json' \
    2>/dev/null | wc -c | tr -d ' ')"
  # mtime reciente de assets usados + modes
  local mt
  mt="$(find assets/characters assets/kenney/props assets/art assets/ui assets/fonts assets/video/intro modes \
    scripts autoload scenes \
    -type f 2>/dev/null | head -5000 | xargs stat -c %Y 2>/dev/null | sort -n | tail -1 || echo 0)"
  printf '%s|files:%s|mt:%s|godot:%s' "$sha" "$files" "$mt" "$GODOT_VER"
}

exports_ok() {
  [ -f export/web/index.html ] || return 1
  grep -q 'Falta el export Web' export/web/index.html 2>/dev/null && return 1
  grep -qiE 'godot|Godot|engine\.js|loadPromise' export/web/index.html 2>/dev/null || return 1
  ls export/web/*.wasm >/dev/null 2>&1 || return 1
  [ -f export/server/BestiaVsRobots.x86_64 ] || return 1
  head -1 export/server/BestiaVsRobots.x86_64 2>/dev/null | grep -q '^#!' && return 1
  return 0
}

need_export() {
  if [ "${FORCE_GODOT_EXPORT:-0}" = "1" ]; then return 0; fi
  exports_ok || return 0
  local fp
  fp="$(fingerprint)"
  if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$fp" ]; then
    return 1
  fi
  return 0
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
  [ -f "$TPL_DEST/web_nothreads_release.zip" ] && [ -f "$TPL_DEST/linux_release.x86_64" ]
}

prune_unused_templates() {
  [ -d "$TPL_DEST" ] || return 0
  local before after
  before="$(du -sm "$TPL_DEST" 2>/dev/null | awk '{print $1}')"
  rm -f "$TPL_DEST"/android_* \
    "$TPL_DEST"/ios.zip \
    "$TPL_DEST"/macos.zip \
    "$TPL_DEST"/windows_* \
    "$TPL_DEST"/web_dlink_* \
    "$TPL_DEST"/linux_debug.* \
    "$TPL_DEST"/linux_release.arm* \
    "$TPL_DEST"/linux_release.x86_32 \
    "$TPL_DEST"/web_debug.zip \
    "$TPL_DEST"/web_release.zip \
    "$TPL_DEST"/web_nothreads_debug.zip \
    2>/dev/null || true
  after="$(du -sm "$TPL_DEST" 2>/dev/null | awk '{print $1}')"
  if [ -n "$before" ] && [ -n "$after" ] && [ "$before" != "$after" ]; then
    log "Templates podados: ${before}MB → ${after}MB (solo Web+Linux)"
  fi
}

install_templates() {
  if templates_ok && [ "${FORCE_GODOT_TEMPLATES:-0}" != "1" ]; then
    log "Templates OK: $TPL_DEST"
    prune_unused_templates
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
  prune_unused_templates
  log "Templates en $TPL_DEST:"
  ls -lh "$TPL_DEST" | head -30
  templates_ok || die "Faltan web_nothreads_release.zip o linux_release.x86_64 en $TPL_DEST"
}

run_godot_timeout() {
  # usage: run_godot_timeout <logfile> <args...>
  local logfile="$1"; shift
  if [ "${IMPORT_TIMEOUT}" = "0" ] || ! command -v timeout >/dev/null 2>&1; then
    "$GODOT_BIN" "$@" >"$logfile" 2>&1
    return $?
  fi
  timeout --signal=KILL "${IMPORT_TIMEOUT}" "$GODOT_BIN" "$@" >"$logfile" 2>&1
}

run_export() {
  [ -f "$ROOT/export_presets.cfg" ] || die "Falta export_presets.cfg"
  prune_import_junk

  mkdir -p export/web export/server "$CACHE"
  if [ -f export/server/BestiaVsRobots.x86_64 ] && head -1 export/server/BestiaVsRobots.x86_64 | grep -q '^#!'; then
    rm -f export/server/BestiaVsRobots.x86_64
  fi

  local need_import=0
  if [ "${FORCE_GODOT_IMPORT:-0}" = "1" ]; then
    log "FORCE_GODOT_IMPORT=1 → borrando .godot/"
    rm -rf "$ROOT/.godot"
    need_import=1
  elif [ ! -d "$ROOT/.godot/imported" ]; then
    need_import=1
    log "Sin .godot/imported → hace falta import inicial"
  else
    # Import interrumpido (SSH kill) suele dejar .godot diminuto e inutilizable
    local gsz
    gsz="$(du -sm "$ROOT/.godot" 2>/dev/null | awk '{print $1}')"
    if [ "${gsz:-0}" -lt 12 ]; then
      log ".godot=${gsz}MB (sospechoso de import cortado) → reiniciando import"
      rm -rf "$ROOT/.godot"
      need_import=1
    fi
  fi
  # Por defecto en re-exports: NO hacer --import completo (duplicaba trabajo y
  # se colgaba horas). Godot --export-release importa solo lo sucio.
  if [ "${SKIP_GODOT_IMPORT:-1}" = "1" ] && [ "${FORCE_GODOT_IMPORT:-0}" != "1" ]; then
    if [ -d "$ROOT/.godot/imported" ]; then
      need_import=0
      log "SKIP_GODOT_IMPORT (default) → export con import incremental"
    fi
  fi

  if [ "$need_import" = "1" ]; then
    set_status "IMPORT"
    log "Importando proyecto (.godot)... timeout=${IMPORT_TIMEOUT}s  [monitor: ./scripts/deploy_progress.sh]"
    local rc=0
    run_godot_timeout /tmp/botgame-godot-import.log --headless --path "$ROOT" --import || rc=$?
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      set_status "ERROR_IMPORT_TIMEOUT"
      die "Import superó ${IMPORT_TIMEOUT}s. Revisa packs sin .gdignore o sube GODOT_IMPORT_TIMEOUT=0"
    fi
    # Validación rápida de scripts (3s editor) solo tras import limpio
    set_status "EDITOR_COMPILE"
    run_godot_timeout /tmp/botgame-godot-editor.log --headless --path "$ROOT" --editor --quit-after 2 || true
    if grep -qiE 'SCRIPT ERROR|Parse Error|Compile Error' /tmp/botgame-godot-editor.log /tmp/botgame-godot-import.log 2>/dev/null; then
      set_status "ERROR_SCRIPTS"
      log "ERROR: scripts rotos — abortando export:"
      grep -iE 'SCRIPT ERROR|Parse Error|Compile Error' /tmp/botgame-godot-editor.log /tmp/botgame-godot-import.log 2>/dev/null | head -40 || true
      die "Corrige los Parse/Script Error antes de desplegar"
    fi
  else
    log "Reusando .godot/ (sin --import completo). FORCE_GODOT_IMPORT=1 para forzar."
  fi

  set_status "EXPORT_WEB"
  log "Export Web → export/web/index.html"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$ROOT/export/web/index.html" \
      >/tmp/botgame-export-web.log 2>&1; then
    set_status "ERROR_WEB"
    echo "----- /tmp/botgame-export-web.log -----" >&2
    cat /tmp/botgame-export-web.log >&2
    die "Export Web falló"
  fi

  set_status "EXPORT_LINUX"
  log "Export Linux → export/server/BestiaVsRobots.x86_64"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux" "$ROOT/export/server/BestiaVsRobots.x86_64" \
      >/tmp/botgame-export-linux.log 2>&1; then
    set_status "ERROR_LINUX"
    echo "----- /tmp/botgame-export-linux.log -----" >&2
    cat /tmp/botgame-export-linux.log >&2
    die "Export Linux falló"
  fi

  chmod +x export/server/BestiaVsRobots.x86_64 || true
  ls -lh export/web/ | head -20
  ls -lh export/server/ | head -10
  ls export/web/*.wasm >/dev/null 2>&1 || die "Export Web sin .wasm"
  set_status "CACHE_BUST"
  log "Export OK"
  fingerprint > "$STAMP_FILE" || true
}

cache_bust() {
  local sha
  sha="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
  chmod +x "$ROOT/scripts/cache_bust_web.sh" 2>/dev/null || true
  bash "$ROOT/scripts/cache_bust_web.sh" "$ROOT/export/web" "$sha"
  printf '%s\n%s\n' "DONE" "$(date -Is 2>/dev/null || date)" > /tmp/botgame-export-status.txt
}

main() {
  prune_import_junk
  if need_export; then
    install_godot
    [ -x "$GODOT_BIN" ] || die "Godot no ejecutable: $GODOT_BIN"
    install_templates
    run_export
  else
    set_status "SKIP_EXPORT"
    log "Exports al día (stamp OK) — omitiendo. FORCE_GODOT_EXPORT=1 para forzar"
  fi
  cache_bust
}

main "$@"
