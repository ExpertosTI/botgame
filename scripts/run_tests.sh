#!/usr/bin/env bash
# Suite headless de CHADRINE. Sale != 0 si algo falla (gate de CI).
#
#   ./scripts/run_tests.sh              # todo
#   ./scripts/run_tests.sh progression  # solo una suite
#
# Env:
#   GODOT_BIN      binario a usar (si no, se busca en rutas habituales)
#   TEST_TIMEOUT   segundos antes de matar la corrida (por defecto 180)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# El proyecto declara features "4.6". Un binario de otra serie invalida .godot/,
# ignora global_script_class_cache.cfg y se pone a reimportar assets: ningún
# class_name resuelve y la corrida se queda minutos sin decir nada.
REQUIRED_SERIES="4.6"

godot_series() {
  # --version sale al instante y no abre el proyecto.
  "$1" --version 2>/dev/null | head -1 | cut -d. -f1,2
}

find_godot() {
  local c
  if [ -n "${GODOT_BIN:-}" ]; then
    [ -x "${GODOT_BIN}" ] || {
      echo "[tests] ERROR: GODOT_BIN='${GODOT_BIN}' no es ejecutable" >&2
      return 1
    }
    echo "$GODOT_BIN"; return 0
  fi
  for c in \
    "$HOME/.cache/chadrine-godot/Godot.app/Contents/MacOS/Godot" \
    "/var/cache/botgame-godot/Godot_v4.3-stable_linux.x86_64" \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
    # Sin GODOT_BIN se descartan los candidatos de otra serie en silencio: da
    # igual el orden de las rutas, solo se elige un 4.3.
    if [ -x "$c" ] && [ "$(godot_series "$c")" = "$REQUIRED_SERIES" ]; then
      echo "$c"; return 0
    fi
  done
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1 \
      && [ "$(godot_series "$(command -v "$c")")" = "$REQUIRED_SERIES" ]; then
      command -v "$c"; return 0
    fi
  done
  return 1
}

GODOT="$(find_godot)" || {
  echo "[tests] ERROR: no encuentro un Godot ${REQUIRED_SERIES}." >&2
  echo "[tests] Exporta GODOT_BIN=/ruta/al/Godot ${REQUIRED_SERIES} o instálalo en" >&2
  echo "[tests]   \$HOME/.cache/chadrine-godot/Godot.app (macOS)" >&2
  exit 127
}

SERIES="$(godot_series "$GODOT")"
if [ "$SERIES" != "$REQUIRED_SERIES" ]; then
  echo "[tests] ERROR: '$GODOT' es Godot ${SERIES:-desconocido} y el proyecto es ${REQUIRED_SERIES}." >&2
  echo "[tests] Con otra serie la suite no arranca: se cuelga reimportando assets." >&2
  echo "[tests] Si de verdad quieres intentarlo: ALLOW_GODOT_MISMATCH=1 $0" >&2
  [ "${ALLOW_GODOT_MISMATCH:-0}" = "1" ] || exit 3
  echo "[tests] AVISO: sigo con ${SERIES} porque ALLOW_GODOT_MISMATCH=1" >&2
fi

export GODOT_SILENCE_ROOT_WARNING=1
ONLY=""
[ $# -gt 0 ] && ONLY="--only=$1"

echo "[tests] Godot: $GODOT"
# Los class_name del proyecto (PlayerBase, GameTheme, CombatVfx…) tienen que
# resolver. Se derivan del código en vez de reimportar ~190 MB de assets.
python3 "$ROOT/scripts/gen_class_cache.py" "$ROOT"

LOG=/tmp/chadrine-tests.log
TIMEOUT="${TEST_TIMEOUT:-180}"

# La suite entera tarda menos de un segundo. Si pasa de TEST_TIMEOUT es que algo
# se colgó (reimportación, un await que no vuelve, un peer esperando red) y hay
# que cortar con el log en la mano, no dejarlo corriendo hasta que alguien mire.
set +e
"$GODOT" --headless --audio-driver Dummy --path "$ROOT" \
  res://tests/test_runner.tscn -- $ONLY >"$LOG" 2>&1 &
GODOT_PID=$!

TIMED_OUT=0
WAITED=0
while kill -0 "$GODOT_PID" 2>/dev/null; do
  if [ "$WAITED" -ge "$TIMEOUT" ]; then
    TIMED_OUT=1
    kill -9 "$GODOT_PID" 2>/dev/null
    break
  fi
  sleep 1
  WAITED=$((WAITED + 1))
done
# El aviso de "Killed: 9" lo imprime el propio shell al recoger el trabajo y
# parece un error del script; el diagnóstico bueno lo damos nosotros más abajo.
{ wait "$GODOT_PID"; STATUS=$?; } 2>/dev/null
set -e

cat "$LOG"
if [ "$TIMED_OUT" = "1" ]; then
  echo "[tests] ERROR: la corrida pasó de ${TIMEOUT}s y se mató. Log en $LOG" >&2
  exit 124
fi
OUT="$(cat "$LOG")"

# Godot puede salir 0 aunque el script devuelva error; confiamos en el marcador.
if echo "$OUT" | grep -q "^\[tests\] OK$"; then
  exit 0
fi
[ "$STATUS" -eq 0 ] && STATUS=1
exit "$STATUS"
