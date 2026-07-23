#!/usr/bin/env bash
# Prepara deploy/landing/media/ para el Dockerfile.web (contexto Docker fiable).
# En el VPS assets/ a veces está aparcado o fuera del build context.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/deploy/landing/media"
PARK="${PARK_DIR:-/var/cache/botgame-godot/parked-media}"

mkdir -p "$OUT"

copy_one() {
  local dest_name="$1"
  shift
  local src
  for src in "$@"; do
    if [ -f "$src" ] && [ -s "$src" ]; then
      cp -f "$src" "$OUT/$dest_name"
      echo "[landing-media] $dest_name ← $src ($(du -h "$OUT/$dest_name" | awk '{print $1}'))"
      return 0
    fi
  done
  return 1
}

# Restaurar aparcados críticos si faltan en el tree
for rel in \
  assets/art/chadrine_keyart.png \
  assets/art/chadrine_keyart_2.png \
  assets/art/chadrine_ref.jpeg \
  assets/video/intro/chadrine_intro.mp4 \
  assets/video/intro/chadrine_intro.webm
do
  if [ ! -f "$ROOT/$rel" ] && [ -f "$PARK/$rel" ]; then
    mkdir -p "$ROOT/$(dirname "$rel")"
    cp -f "$PARK/$rel" "$ROOT/$rel" || mv -f "$PARK/$rel" "$ROOT/$rel" || true
    echo "[landing-media] restaurado $rel"
  fi
done

ok=0
copy_one chadrine_keyart.png \
  "$ROOT/assets/art/chadrine_keyart.png" \
  "$PARK/assets/art/chadrine_keyart.png" \
  "$ROOT/export/web/index.png" && ok=$((ok + 1)) || true

copy_one chadrine_keyart_2.png \
  "$ROOT/assets/art/chadrine_keyart_2.png" \
  "$PARK/assets/art/chadrine_keyart_2.png" \
  "$OUT/chadrine_keyart.png" && ok=$((ok + 1)) || true

copy_one chadrine_ref.jpeg \
  "$ROOT/assets/art/chadrine_ref.jpeg" \
  "$PARK/assets/art/chadrine_ref.jpeg" \
  "$OUT/chadrine_keyart.png" && ok=$((ok + 1)) || true

# Vídeo: preferir mp4; si no, webm (landing acepta mp4 en <source>; añadimos webm como fallback en HTML si hace falta)
if copy_one chadrine_intro.mp4 \
  "$ROOT/assets/video/intro/chadrine_intro.mp4" \
  "$PARK/assets/video/intro/chadrine_intro.mp4"; then
  ok=$((ok + 1))
elif copy_one chadrine_intro.webm \
  "$ROOT/assets/video/intro/chadrine_intro.webm" \
  "$PARK/assets/video/intro/chadrine_intro.webm"; then
  # Landing busca .mp4 — duplicar nombre como mp4 no sirve; copiar webm y symlink/nombre extra
  cp -f "$OUT/chadrine_intro.webm" "$OUT/chadrine_intro.mp4" 2>/dev/null || true
  ok=$((ok + 1))
  echo "[landing-media] AVISO: usando webm como intro (sin mp4)"
else
  echo "[landing-media] AVISO: sin vídeo intro — hero usará poster"
fi

# Placeholders mínimos si falta todo (evita fallo de COPY)
if [ ! -f "$OUT/chadrine_keyart.png" ]; then
  # 1x1 PNG
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' >"$OUT/chadrine_keyart.png"
  echo "[landing-media] placeholder keyart"
fi
[ -f "$OUT/chadrine_keyart_2.png" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_keyart_2.png"
[ -f "$OUT/chadrine_ref.jpeg" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_ref.jpeg"

# Lista para el Dockerfile (siempre hay carpeta no vacía)
ls -lah "$OUT"
echo "[landing-media] listo ($ok fuentes reales)"
