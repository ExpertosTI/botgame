#!/usr/bin/env bash
# CHADRINE — Deploy producción (Docker Swarm + Traefik / RenaceNet)
# Uso:  cd /opt/botgame && ./deploy.sh update
#       ./deploy.sh update --fg     # primer plano (muere si se corta SSH)
# Por defecto update/start corren detached (sobreviven al cierre de SSH).
set -euo pipefail

STACK_NAME="botgame"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE="/etc/botgame/botgame.env"
APP_DOMAIN="${APP_DOMAIN:-botgame.renace.tech}"
NETWORK_PUBLIC="RenaceNet"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
DEPLOY_LOG="${BOTGAME_DEPLOY_LOG:-/var/log/botgame-deploy.log}"
DEPLOY_PID_FILE="${BOTGAME_DEPLOY_PID:-/var/run/botgame-deploy.pid}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err()  { echo -e "${RED}$*${NC}" >&2; }
die()  { err "$*"; exit 1; }

banner() {
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     CHADRINE — Deploy                 ║${NC}"
    echo -e "${CYAN}║     RenaceNet / Swarm / Traefik       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
}

is_swarm_active() {
    docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qi active
}

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1091
        source "$ENV_FILE"
        set +a
    fi
    if [ -f "$ROOT/.env" ]; then
        set -a
        # shellcheck disable=SC1091
        source "$ROOT/.env"
        set +a
    fi
    export BOTGAME_DOMAIN="${BOTGAME_DOMAIN:-$APP_DOMAIN}"
    export APP_DOMAIN="$BOTGAME_DOMAIN"
}

refresh_git_sha() {
    export GIT_SHA
    GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo latest)"
}

ensure_renacenet() {
    if ! docker network inspect "$NETWORK_PUBLIC" >/dev/null 2>&1; then
        die "Red overlay '$NETWORK_PUBLIC' no existe. Traefik/RenaceNet debe estar activo."
    fi
    if ! is_swarm_active; then
        die "Docker Swarm no está activo. Ejecuta: docker swarm init"
    fi
}

kill_stale_godot() {
    local pids
    pids="$(pgrep -f 'Godot_v.*--(import|export-release|editor)' 2>/dev/null || true)"
    if [ -n "$pids" ]; then
        warn "→ Matando Godot huérfano: $pids"
        # shellcheck disable=SC2086
        kill $pids 2>/dev/null || true
        sleep 2
        # shellcheck disable=SC2086
        kill -9 $pids 2>/dev/null || true
    fi
}

maybe_detach() {
    local fg=0
    local a
    for a in "$@"; do
        case "$a" in
            --fg|--foreground) fg=1 ;;
        esac
    done
    if [ "$fg" = "1" ] || [ "${BOTGAME_DEPLOY_FOREGROUND:-0}" = "1" ]; then
        return 1
    fi
    if [ "${BOTGAME_DEPLOY_INNER:-0}" = "1" ]; then
        return 1
    fi
    if [ -n "${TMUX:-}" ] && [ "${BOTGAME_DEPLOY_FORCE_DETACH:-0}" != "1" ]; then
        log "→ Dentro de tmux: foreground OK (SSH puede cortar sin matar la sesión)"
        return 1
    fi
    return 0
}

run_detached() {
    local cmd="$1"
    mkdir -p "$(dirname "$DEPLOY_LOG")" 2>/dev/null || true
    touch "$DEPLOY_LOG" 2>/dev/null || DEPLOY_LOG="/tmp/botgame-deploy.log"
    log "→ Deploy en background (sobrevive si se corta SSH)"
    log "   log: $DEPLOY_LOG"
    log "   monitor: cd /opt/botgame && ./scripts/deploy_progress.sh"
    log "   seguir:  tail -f $DEPLOY_LOG"
    local env_export="BOTGAME_DEPLOY_INNER=1"
    env_export+=" FORCE_GODOT_EXPORT=${FORCE_GODOT_EXPORT:-0}"
    env_export+=" FORCE_GODOT_IMPORT=${FORCE_GODOT_IMPORT:-0}"
    env_export+=" SKIP_GODOT_IMPORT=${SKIP_GODOT_IMPORT:-1}"
    env_export+=" GODOT_IMPORT_TIMEOUT=${GODOT_IMPORT_TIMEOUT:-900}"
    # shellcheck disable=SC2086
    nohup setsid env $env_export bash "$ROOT/deploy.sh" "$cmd" --fg \
        >>"$DEPLOY_LOG" 2>&1 < /dev/null &
    local pid=$!
    echo "$pid" > "$DEPLOY_PID_FILE" 2>/dev/null || true
    log "   PID $pid"
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        err "El deploy background murió al arrancar. Mira $DEPLOY_LOG"
        tail -40 "$DEPLOY_LOG" || true
        exit 1
    fi
    log "Listo — puedes cerrar SSH. El deploy sigue."
    exit 0
}

build_images() {
    log "→ Export Godot en servidor (si hace falta)"
    chmod +x scripts/export_godot_linux.sh 2>/dev/null || true
    bash scripts/export_godot_linux.sh

    log "→ Build images (GIT_SHA=$GIT_SHA)"
    docker compose -f "$COMPOSE_FILE" build
    docker tag "botgame-web:${GIT_SHA}" "botgame-web:latest" 2>/dev/null || true
    docker tag "botgame-server:${GIT_SHA}" "botgame-server:latest" 2>/dev/null || true
}

stack_deploy() {
    log "→ docker stack deploy ($STACK_NAME)"
    docker stack deploy -c "$COMPOSE_FILE" --with-registry-auth "$STACK_NAME"
    wait_services || true
    log "→ Force recreate (imagen local ${GIT_SHA})"
    docker service update --detach --force --image "botgame-web:${GIT_SHA}" "${STACK_NAME}_web" >/dev/null || true
    docker service update --detach --force --image "botgame-server:${GIT_SHA}" "${STACK_NAME}_game-server" >/dev/null || true
    sleep 5
    wait_services || true
}

wait_services() {
    log "→ Esperando servicios 1/1..."
    local tries=60
    for i in $(seq 1 "$tries"); do
        local web ok_server
        web=$(docker service ls --format '{{.Name}} {{.Replicas}}' | awk -v n="${STACK_NAME}_web" '$1==n{print $2}')
        ok_server=$(docker service ls --format '{{.Name}} {{.Replicas}}' | awk -v n="${STACK_NAME}_game-server" '$1==n{print $2}')
        if [[ "$web" == 1/1* ]] && [[ "$ok_server" == 1/1* ]]; then
            log "Servicios OK ($web / $ok_server)"
            return 0
        fi
        echo "  web=$web  game-server=$ok_server  ($i/$tries)"
        sleep 3
    done
    warn "Timeout esperando réplicas. Revisa: ./deploy.sh status && ./deploy.sh logs"
    return 1
}

health() {
    local url="https://${BOTGAME_DOMAIN}/"
    log "→ Health $url"
    local i code
    for i in $(seq 1 18); do
        code=$(curl -sS -o /dev/null -w '%{http_code}' "$url" || echo "000")
        if [ "$code" = "200" ]; then
            curl -sSI "$url" | head -6
            log "Health OK"
            return 0
        fi
        echo "  HTTP $code — reintento $i/18"
        sleep 3
    done
    warn "Health aún no es 200 (último). Traefik puede estar reconectando."
    docker service ps "${STACK_NAME}_web" --no-trunc 2>/dev/null | head -5 || true
}

cmd_update() {
    if maybe_detach "$@"; then
        run_detached update
    fi
    banner
    trap '' HUP
    load_env
    ensure_renacenet
    kill_stale_godot
    if [ -d .git ]; then
        log "→ git fetch + reset origin/main"
        local before after
        before="$(git rev-parse HEAD 2>/dev/null || true)"
        git fetch --all --prune
        git checkout main 2>/dev/null || git checkout master
        git reset --hard "origin/$(git rev-parse --abbrev-ref HEAD)"
        after="$(git rev-parse HEAD 2>/dev/null || true)"
        if [ -n "$before" ] && [ -n "$after" ] && [ "$before" != "$after" ]; then
            log "→ Código actualizado; reiniciando deploy con script nuevo..."
            exec env BOTGAME_DEPLOY_INNER=1 bash "$ROOT/deploy.sh" start --fg
        fi
    fi
    load_env
    unset GIT_SHA
    refresh_git_sha
    build_images
    stack_deploy
    wait_services || true
    health
    log "Listo: https://${BOTGAME_DOMAIN}/"
    log "WebSocket: wss://${BOTGAME_DOMAIN}/ws"
}

cmd_start() {
    if maybe_detach "$@"; then
        run_detached start
    fi
    banner
    trap '' HUP
    load_env
    unset GIT_SHA
    refresh_git_sha
    ensure_renacenet
    kill_stale_godot
    build_images
    stack_deploy
    wait_services || true
    health
    log "Listo: https://${BOTGAME_DOMAIN}/"
    log "WebSocket: wss://${BOTGAME_DOMAIN}/ws"
}

cmd_status() {
    load_env
    if [ -f "$DEPLOY_PID_FILE" ]; then
        local pid
        pid="$(cat "$DEPLOY_PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log "Deploy background activo PID $pid"
        else
            warn "Sin deploy background activo"
        fi
    fi
    docker stack services "$STACK_NAME" 2>/dev/null || docker service ls | grep "$STACK_NAME" || true
    docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -30 || true
}

cmd_logs() {
    local svc="${1:-web}"
    if [ "$svc" = "deploy" ]; then
        tail -n 100 -f "$DEPLOY_LOG"
        return
    fi
    docker service logs -f "${STACK_NAME}_${svc}"
}

cmd_restart() {
    load_env
    docker service update --force "${STACK_NAME}_web" || true
    docker service update --force "${STACK_NAME}_game-server" || true
}

cmd_stop() {
    warn "Eliminando stack $STACK_NAME"
    docker stack rm "$STACK_NAME"
}

usage() {
    cat <<EOF
Uso: ./deploy.sh <comando> [--fg]

  update    git pull + export Godot (VPS) + build + stack deploy
  start     export Godot + build + stack deploy (sin git pull)
  status    estado Swarm (+ PID deploy bg)
  logs [web|game-server|deploy]
  restart   force update servicios
  stop      baja el stack
  health    curl HTTPS

Por defecto update/start van en background (nohup/setsid) para que un
corte de SSH NO mate el export. Usa --fg solo si estás en tmux/screen.

Flujo rápido:
  1) Mac:  git push origin main
  2) VPS:  cd /opt/botgame && ./deploy.sh update
  3) VPS:  ./scripts/deploy_progress.sh   # o: ./deploy.sh logs deploy

Forzar re-export (rápido, reusa .godot):
  FORCE_GODOT_EXPORT=1 ./deploy.sh start

Import completo solo si cache corrupta (lento):
  FORCE_GODOT_IMPORT=1 FORCE_GODOT_EXPORT=1 ./deploy.sh start --fg

Dominio: ${BOTGAME_DOMAIN:-botgame.renace.tech}
Env:     $ENV_FILE
Log:     $DEPLOY_LOG
EOF
}

case "${1:-}" in
    update)  cmd_update "${@:2}" ;;
    start)   cmd_start "${@:2}" ;;
    status)  cmd_status ;;
    logs)    cmd_logs "${2:-web}" ;;
    restart) cmd_restart ;;
    stop)    cmd_stop ;;
    health)  load_env; health ;;
    *)       usage; exit 1 ;;
esac
