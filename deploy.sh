#!/usr/bin/env bash
# CHADRINE — Deploy producción (Docker Swarm + Traefik / RenaceNet)
# Igual que RNV/ChatCE: en el VPS, primer plano.
# Uso:  cd /opt/botgame && ./deploy.sh update
set -euo pipefail

STACK_NAME="botgame"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE="/etc/botgame/botgame.env"
APP_DOMAIN="${APP_DOMAIN:-botgame.renace.tech}"
NETWORK_PUBLIC="RenaceNet"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

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

# Imágenes botgame-web/botgame-server viejas (por GIT_SHA) y cache de build
# nunca se liberaban → disco lleno ("no space left on device"). Se corre
# ANTES de build (libera espacio para el build) y DESPUÉS (recorta lo nuevo).
docker_gc() {
    log "→ Limpieza Docker (imágenes/cache viejos)"
    df -h / 2>/dev/null | tail -1 | awk '{print "  disco: " $3 " usados / " $2 " (" $5 " lleno)"}' || true
    for repo in botgame-web botgame-server; do
        local keep=("${repo}:latest" "${repo}:${GIT_SHA:-__none__}")
        local old_ids
        old_ids="$(docker images "$repo" --format '{{.Tag}} {{.ID}}' \
            | awk -v k1="${keep[0]#*:}" -v k2="${keep[1]#*:}" '$1!=k1 && $1!=k2 {print $2}' \
            | sort -u)"
        if [ -n "$old_ids" ]; then
            # shellcheck disable=SC2086
            docker rmi $old_ids >/dev/null 2>&1 || true
        fi
    done
    docker container prune -f >/dev/null 2>&1 || true
    docker image prune -f >/dev/null 2>&1 || true
    docker builder prune -f --filter "until=24h" >/dev/null 2>&1 || true
}

build_images() {
    docker_gc

    log "→ Export Godot en servidor (si hace falta)"
    chmod +x scripts/export_godot_linux.sh scripts/stage_landing_media.sh 2>/dev/null || true
    bash scripts/export_godot_linux.sh

    log "→ Staging media landing → deploy/landing/media/"
    bash scripts/stage_landing_media.sh

    log "→ Build images (GIT_SHA=$GIT_SHA)"
    docker compose -f "$COMPOSE_FILE" build
    docker tag "botgame-web:${GIT_SHA}" "botgame-web:latest" 2>/dev/null || true
    docker tag "botgame-server:${GIT_SHA}" "botgame-server:latest" 2>/dev/null || true

    docker_gc
}

# Antes de reemplazar imágenes, etiqueta lo que hay en producción como
# :previous. Es lo que usa cmd_rollback cuando el smoke sale en rojo.
tag_previous() {
    local repo
    for repo in botgame-web botgame-server; do
        local running
        running="$(docker images "$repo" --format '{{.Tag}}' | grep -v -e '^latest$' -e "^previous$" -e "^${GIT_SHA}$" | head -1)"
        if [ -n "$running" ]; then
            docker tag "${repo}:${running}" "${repo}:previous" >/dev/null 2>&1 || true
        elif docker image inspect "${repo}:latest" >/dev/null 2>&1; then
            docker tag "${repo}:latest" "${repo}:previous" >/dev/null 2>&1 || true
        fi
    done
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

# Un 200 en "/" solo dice que nginx vive: la landing puede servirse perfecta
# mientras el .pck falta o el WebSocket está caído y nadie puede jugar.
SMOKE_FAILURES=()

smoke_get() {
    local path="$1" expect="${2:-200}" label="${3:-$1}"
    local code
    code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "https://${BOTGAME_DOMAIN}${path}" || echo "000")
    if [ "$code" = "$expect" ]; then
        log "  ok   ${label} (HTTP $code)"
        return 0
    fi
    err "  FALLA ${label} → HTTP $code (esperado $expect)"
    SMOKE_FAILURES+=("${label}:HTTP_${code}")
    return 1
}

smoke() {
    load_env
    refresh_git_sha
    SMOKE_FAILURES=()
    log "→ Smoke https://${BOTGAME_DOMAIN}"

    smoke_get "/" 200 "landing" || true
    smoke_get "/play/index.html" 200 "juego (html)" || true
    smoke_get "/play/index.wasm" 200 "runtime wasm" || true
    smoke_get "/play/index.pck" 200 "paquete de datos (pck)" || true

    # version.json tiene que coincidir con el commit desplegado; si no, el
    # navegador seguirá cargando la build vieja desde caché.
    local served
    served=$(curl -sS -m 15 "https://${BOTGAME_DOMAIN}/version.json" 2>/dev/null \
        | sed -n 's/.*"build"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -z "$served" ]; then
        err "  FALLA version.json ilegible"
        SMOKE_FAILURES+=("version_json:vacio")
    elif [ "$served" != "$GIT_SHA" ]; then
        err "  FALLA version.json sirve '$served' y desplegamos '$GIT_SHA'"
        SMOKE_FAILURES+=("version_json:${served}")
    else
        log "  ok   version.json = $GIT_SHA"
    fi

    # Handshake WebSocket: 101 = el servidor de partidas acepta jugadores.
    # Reintentos: tras force-recreate Traefik puede devolver 502 unos segundos.
    # Importante: tras el 101 la conexión queda abierta y curl hace timeout (28).
    # Si usamos `|| echo 000`, queda "101000" y el smoke hace rollback en falso.
    local ws_code="000" ws_raw attempt
    for attempt in 1 2 3 4 5 6; do
        ws_raw=$(curl -sS -m 5 --http1.1 -o /dev/null -w '%{http_code}' \
            -H "Connection: Upgrade" -H "Upgrade: websocket" \
            -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: c2hha2VzcGVhcmUxMjM0" \
            "https://${BOTGAME_DOMAIN}/ws" 2>/dev/null || true)
        ws_code=$(printf '%s' "$ws_raw" | tr -cd '0-9' | head -c 3)
        [ -n "$ws_code" ] || ws_code="000"
        if [ "$ws_code" = "101" ]; then
            break
        fi
        warn "  WebSocket /ws → HTTP ${ws_raw:-?} (intento $attempt/6); reintento en 5s…"
        sleep 5
    done
    if [ "$ws_code" = "101" ]; then
        log "  ok   WebSocket /ws (HTTP 101)"
    else
        err "  FALLA WebSocket /ws → HTTP ${ws_raw:-$ws_code} (esperado 101)"
        SMOKE_FAILURES+=("websocket:HTTP_${ws_code}")
        docker service logs --tail 40 "${STACK_NAME}_game-server" 2>&1 | tail -40 || true
    fi

    smoke_get "/api/presence" 200 "presence" || true

    if [ ${#SMOKE_FAILURES[@]} -eq 0 ]; then
        log "Smoke OK — la build desplegada es jugable"
        return 0
    fi
    err "Smoke con ${#SMOKE_FAILURES[@]} fallo(s): ${SMOKE_FAILURES[*]}"
    return 1
}

cmd_rollback() {
    load_env
    if ! docker image inspect botgame-web:previous >/dev/null 2>&1; then
        die "No hay botgame-web:previous — nada a lo que volver"
    fi
    warn "→ Rollback a las imágenes :previous"
    docker service update --detach --force --image "botgame-web:previous" "${STACK_NAME}_web" >/dev/null || true
    docker service update --detach --force --image "botgame-server:previous" "${STACK_NAME}_game-server" >/dev/null || true
    sleep 5
    wait_services || true
    health
    warn "Rollback aplicado. Revisa logs antes de volver a desplegar."
}

cmd_update() {
    banner
    load_env
    ensure_renacenet
    if [ -d .git ]; then
        log "→ git fetch + reset origin/main"
        local before after
        before="$(git rev-parse HEAD 2>/dev/null || true)"
        # Si un export anterior dejó media aparcada, devolverla antes del reset
        # (si no, `git status` muestra cientos de D y el working tree queda a medias).
        PARK_DIR="${BOTGAME_GODOT_CACHE:-/var/cache/botgame-godot}/parked-media"
        if [ -d "$PARK_DIR" ] && [ -n "$(find "$PARK_DIR" -type f 2>/dev/null | head -1)" ]; then
            log "→ Restaurando media aparcada de export previo…"
            while IFS= read -r -d '' f; do
                rel="${f#"$PARK_DIR"/}"
                mkdir -p "$ROOT/$(dirname "$rel")"
                mv -f "$f" "$ROOT/$rel" 2>/dev/null || true
            done < <(find "$PARK_DIR" -type f -print0 2>/dev/null)
            find "$PARK_DIR" -type d -empty -delete 2>/dev/null || true
        fi
        git fetch --all --prune
        git checkout main 2>/dev/null || git checkout master
        git reset --hard "origin/$(git rev-parse --abbrev-ref HEAD)"
        after="$(git rev-parse HEAD 2>/dev/null || true)"
        if [ -n "$before" ] && [ -n "$after" ] && [ "$before" != "$after" ]; then
            log "→ Código actualizado; reiniciando deploy con script nuevo..."
            exec bash "$ROOT/deploy.sh" start
        fi
    fi
    load_env
    unset GIT_SHA
    refresh_git_sha
    tag_previous
    build_images
    stack_deploy
    wait_services || true
    health
    verify_or_rollback
}

cmd_start() {
    banner
    load_env
    unset GIT_SHA
    refresh_git_sha
    ensure_renacenet
    tag_previous
    build_images
    stack_deploy
    wait_services || true
    health
    verify_or_rollback
}

# El deploy no se declara bueno hasta que el smoke pasa. Si falla y hay una
# imagen :previous, se vuelve sola: producción no se queda rota esperando a que
# alguien mire los logs.
verify_or_rollback() {
    if smoke; then
        log "Listo: https://${BOTGAME_DOMAIN}/  (landing)"
        log "Juego:  https://${BOTGAME_DOMAIN}/play/"
        log "WebSocket: wss://${BOTGAME_DOMAIN}/ws"
        return 0
    fi
    if [ "${SKIP_ROLLBACK:-0}" = "1" ]; then
        die "Smoke en rojo (SKIP_ROLLBACK=1, se deja la build nueva puesta)"
    fi
    if docker image inspect botgame-web:previous >/dev/null 2>&1; then
        cmd_rollback
        die "Smoke en rojo → se revirtió a la build anterior"
    fi
    die "Smoke en rojo y sin imagen :previous para revertir"
}

cmd_status() {
    load_env
    docker stack services "$STACK_NAME" 2>/dev/null || docker service ls | grep "$STACK_NAME" || true
    docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -30 || true
}

cmd_logs() {
    local svc="${1:-web}"
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

cmd_gc() {
    load_env
    refresh_git_sha
    docker_gc
    log "→ Espacio libre tras limpieza:"
    df -h / 2>/dev/null || true
}

usage() {
    cat <<EOF
Uso: ./deploy.sh <comando>

  update    git pull + export Godot + build + stack deploy
  start     export Godot + build + stack deploy (sin git pull)
  status    estado Swarm
  logs [web|game-server]
  restart   force update servicios
  stop      baja el stack
  health    curl HTTPS
  smoke     verifica landing, wasm, pck, version.json, /ws y presence
  rollback  vuelve a las imágenes :previous
  gc        limpia imágenes/cache Docker viejos (libera disco ya)

Flujo Renace (sin rsync / sin passwords):
  1) En Mac:  git push origin main
  2) En VPS:  cd /opt/botgame && ./deploy.sh update

Forzar re-export: FORCE_GODOT_EXPORT=1 ./deploy.sh start

Dominio: ${BOTGAME_DOMAIN:-botgame.renace.tech}
Env:     $ENV_FILE
EOF
}

case "${1:-}" in
    update)  cmd_update ;;
    start)   cmd_start ;;
    status)  cmd_status ;;
    logs)    cmd_logs "${2:-web}" ;;
    restart) cmd_restart ;;
    stop)    cmd_stop ;;
    health)  load_env; health ;;
    smoke)   smoke ;;
    rollback) cmd_rollback ;;
    gc)      cmd_gc ;;
    *)       usage; exit 1 ;;
esac
