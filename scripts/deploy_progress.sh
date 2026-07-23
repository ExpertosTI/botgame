#!/usr/bin/env bash
# CHADRINE — Monitor detallado del deploy / export Godot en el VPS
# Uso (en otra sesión SSH mientras corre el deploy):
#   cd /opt/botgame && ./scripts/deploy_progress.sh
# Una sola captura:
#   ./scripts/deploy_progress.sh --once
set -euo pipefail

ROOT="${BOTGAME_ROOT:-/opt/botgame}"
INTERVAL="${INTERVAL:-3}"
ONCE=0
[[ "${1:-}" == "--once" ]] && ONCE=1

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

hr() { printf '%s\n' "────────────────────────────────────────────────────────"; }

size_of() {
  local p="$1"
  if [[ -e "$p" ]]; then du -sh "$p" 2>/dev/null | awk '{print $1}'; else echo "—"; fi
}

file_age() {
  local p="$1"
  if [[ -f "$p" ]]; then
    local sec
    sec=$(( $(date +%s) - $(stat -c %Y "$p" 2>/dev/null || echo 0) ))
    if (( sec < 60 )); then echo "${sec}s"
    elif (( sec < 3600 )); then echo "$((sec/60))m"
    else echo "$((sec/3600))h"; fi
  else echo "—"; fi
}

lines_of() {
  local p="$1"
  [[ -f "$p" ]] && wc -l <"$p" | tr -d ' ' || echo 0
}

detect_stage() {
  # Prioridad: procesos vivos → status file → artefactos
  if pgrep -af 'Godot.*--export-release.*Web' >/dev/null 2>&1; then
    echo "EXPORT_WEB"; return
  fi
  if pgrep -af 'Godot.*--export-release.*Linux' >/dev/null 2>&1; then
    echo "EXPORT_LINUX"; return
  fi
  if pgrep -af 'Godot.*--import' >/dev/null 2>&1; then
    echo "IMPORT"; return
  fi
  if pgrep -af 'Godot.*--editor|--quit-after' >/dev/null 2>&1; then
    echo "EDITOR_COMPILE"; return
  fi
  if pgrep -af 'docker compose.*build|docker build' >/dev/null 2>&1; then
    echo "DOCKER_BUILD"; return
  fi
  if pgrep -af 'deploy\.sh|export_godot_linux' >/dev/null 2>&1; then
    if [[ -f /tmp/botgame-export-status.txt ]]; then
      head -1 /tmp/botgame-export-status.txt
      return
    fi
    echo "DEPLOY_SCRIPT"; return
  fi
  if [[ -f /tmp/botgame-export-status.txt ]]; then
    head -1 /tmp/botgame-export-status.txt
    return
  fi
  echo "IDLE"
}

stage_label() {
  case "$1" in
    IMPORT) echo "① Importando .godot (assets/GLB — la etapa más larga)" ;;
    EDITOR_COMPILE) echo "② Compilando scripts (editor quit)" ;;
    EXPORT_WEB) echo "③ Export Web (wasm/pck)" ;;
    EXPORT_LINUX) echo "④ Export Linux dedicado" ;;
    CACHE_BUST) echo "⑤ Cache-bust version.json" ;;
    DOCKER_BUILD) echo "⑥ docker compose build" ;;
    STACK_DEPLOY) echo "⑦ Swarm stack deploy" ;;
    DONE) echo "✅ Export/deploy terminado" ;;
    ERROR*) echo "❌ Error — revisa logs" ;;
    DEPLOY_SCRIPT) echo "↻ deploy.sh activo (esperando subpaso)" ;;
    IDLE) echo "⏸ Sin proceso de export activo" ;;
    *) echo "$1" ;;
  esac
}

eta_hint() {
  case "$1" in
    IMPORT) echo "≈ 8–25 min (hub+modos+GLB; VPS a ~89% disco puede alargar)" ;;
    EDITOR_COMPILE) echo "≈ 1–3 min" ;;
    EXPORT_WEB) echo "≈ 3–10 min" ;;
    EXPORT_LINUX) echo "≈ 1–4 min" ;;
    DOCKER_BUILD) echo "≈ 1–5 min" ;;
    STACK_DEPLOY) echo "≈ 30–90 s" ;;
    DONE) echo "listo" ;;
    *) echo "variable" ;;
  esac
}

show() {
  clear 2>/dev/null || true
  local now stage gitsha disk godot_procs
  now="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  stage="$(detect_stage)"
  gitsha="—"
  [[ -d "$ROOT/.git" ]] && gitsha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo —)"

  echo -e "${CYAN}${BOLD}CHADRINE · Deploy progress${NC}  ${DIM}${now}${NC}"
  hr
  echo -e "Repo:     ${BOLD}$ROOT${NC}"
  echo -e "Git SHA:  ${GREEN}${gitsha}${NC}  (esperado hub: 84c0aec+)"
  echo -e "Etapa:    ${YELLOW}$(stage_label "$stage")${NC}"
  echo -e "ETA tip:  ${DIM}$(eta_hint "$stage")${NC}"
  hr

  # Disco
  disk="$(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')"
  echo -e "${BOLD}Disco /${NC}:  $disk"
  echo -e "  .godot/          $(size_of "$ROOT/.godot")"
  echo -e "  export/web/      $(size_of "$ROOT/export/web")"
  echo -e "  export/server/   $(size_of "$ROOT/export/server")"
  echo -e "  modes/           $(size_of "$ROOT/modes")"
  echo -e "  assets/          $(size_of "$ROOT/assets")"
  hr

  # Status file
  if [[ -f /tmp/botgame-export-status.txt ]]; then
    echo -e "${BOLD}Status file${NC} (/tmp/botgame-export-status.txt):"
    sed 's/^/  /' /tmp/botgame-export-status.txt | head -8
    hr
  fi

  # Procesos Godot / docker
  echo -e "${BOLD}Procesos relevantes${NC}:"
  godot_procs="$(pgrep -af 'Godot_v|export_godot|deploy\.sh|docker compose build' 2>/dev/null | grep -v 'deploy_progress' | head -8 || true)"
  if [[ -z "$godot_procs" ]]; then
    echo -e "  ${DIM}(ninguno)${NC}"
  else
    echo "$godot_procs" | sed 's/^/  /'
  fi
  hr

  # Logs
  echo -e "${BOLD}Logs Godot${NC} (líneas / edad / última actividad):"
  for f in \
    /tmp/botgame-godot-import.log \
    /tmp/botgame-godot-editor.log \
    /tmp/botgame-export-web.log \
    /tmp/botgame-export-linux.log
  do
    local name lines age
    name="$(basename "$f")"
    lines="$(lines_of "$f")"
    age="$(file_age "$f")"
    if [[ -f "$f" ]]; then
      echo -e "  ${GREEN}${name}${NC}: ${lines} líneas · hace ${age}"
    else
      echo -e "  ${DIM}${name}: (aún no)${NC}"
    fi
  done
  hr

  # Tail del log más reciente activo
  local active_log=""
  case "$stage" in
    IMPORT) active_log=/tmp/botgame-godot-import.log ;;
    EDITOR_COMPILE) active_log=/tmp/botgame-godot-editor.log ;;
    EXPORT_WEB) active_log=/tmp/botgame-export-web.log ;;
    EXPORT_LINUX) active_log=/tmp/botgame-export-linux.log ;;
  esac
  if [[ -n "$active_log" && -f "$active_log" ]]; then
    echo -e "${BOLD}Últimas líneas · $(basename "$active_log")${NC}:"
    tail -n 12 "$active_log" 2>/dev/null | sed 's/^/  /' || true
  else
    # fallback: el log más grande/reciente
    local newest
    newest="$(ls -t /tmp/botgame-godot-*.log /tmp/botgame-export-*.log 2>/dev/null | head -1 || true)"
    if [[ -n "$newest" ]]; then
      echo -e "${BOLD}Últimas líneas · $(basename "$newest")${NC}:"
      tail -n 12 "$newest" 2>/dev/null | sed 's/^/  /' || true
    else
      echo -e "${DIM}Sin logs todavía — el import puede estar arrancando.${NC}"
    fi
  fi
  hr

  # Artefactos
  echo -e "${BOLD}Artefactos export${NC}:"
  if [[ -f "$ROOT/export/web/index.html" ]]; then
    echo -e "  web index.html: ${GREEN}sí${NC} ($(size_of "$ROOT/export/web/index.html")) · $(file_age "$ROOT/export/web/index.html")"
  else
    echo -e "  web index.html: ${YELLOW}no${NC}"
  fi
  local wasm
  wasm="$(ls "$ROOT"/export/web/*.wasm 2>/dev/null | head -1 || true)"
  if [[ -n "$wasm" ]]; then
    echo -e "  web .wasm:      ${GREEN}sí${NC} ($(size_of "$wasm"))"
  else
    echo -e "  web .wasm:      ${YELLOW}no${NC}"
  fi
  if [[ -f "$ROOT/export/server/BestiaVsRobots.x86_64" ]]; then
    echo -e "  server bin:     ${GREEN}sí${NC} ($(size_of "$ROOT/export/server/BestiaVsRobots.x86_64"))"
  else
    echo -e "  server bin:     ${YELLOW}no${NC}"
  fi
  if [[ -f "$ROOT/export/web/version.json" ]]; then
    echo -e "  version.json:   ${GREEN}$(cat "$ROOT/export/web/version.json" 2>/dev/null | tr -d '\n' | head -c 120)${NC}"
  else
    echo -e "  version.json:   ${DIM}pendiente${NC}"
  fi
  hr

  # Live URL
  local ver
  ver="$(curl -sS --max-time 3 https://botgame.renace.tech/version.json 2>/dev/null || echo '')"
  echo -e "${BOLD}Live${NC} https://botgame.renace.tech/version.json:"
  if [[ -n "$ver" ]]; then
    echo -e "  $ver"
  else
    echo -e "  ${DIM}(sin respuesta / aún viejo)${NC}"
  fi
  hr
  echo -e "${DIM}Ctrl+C para salir · refresco cada ${INTERVAL}s · --once = una vez${NC}"
  echo -e "${DIM}Si se queda >30 min en IMPORT con disco >95%: limpia Docker/Godot cache.${NC}"
}

main() {
  if [[ ! -d "$ROOT" ]]; then
    echo "No existe $ROOT — exporta BOTGAME_ROOT=/ruta o corre en el VPS." >&2
    exit 1
  fi
  while true; do
    show
    [[ "$ONCE" -eq 1 ]] && break
    sleep "$INTERVAL"
  done
}

main "$@"
