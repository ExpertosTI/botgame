#!/usr/bin/env bash
# Prepara deploy/landing/media/ para el Dockerfile.web.
# En el VPS a veces assets/ no está en el working tree → se extrae del blob git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/deploy/landing/media"
PARK="${PARK_DIR:-/var/cache/botgame-godot/parked-media}"
MIN_ART_BYTES=100000   # keyart real ~7MB; evita caer en icono Godot 21K
MIN_VIDEO_BYTES=200000

mkdir -p "$OUT"

is_big_enough() {
  local f="$1" min="$2"
  [ -f "$f" ] && [ "$(wc -c <"$f" | tr -d ' ')" -ge "$min" ]
}

# Extrae path del índice git a destino (aunque falte en el working tree)
git_extract() {
  local rel="$1" dest="$2"
  if git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null; then
    mkdir -p "$(dirname "$dest")"
    git -C "$ROOT" show "HEAD:$rel" >"$dest"
    return 0
  fi
  return 1
}

copy_one() {
  local dest_name="$1"
  local min_bytes="$2"
  shift 2
  local src
  for src in "$@"; do
    if is_big_enough "$src" "$min_bytes"; then
      cp -f "$src" "$OUT/$dest_name"
      echo "[landing-media] $dest_name ← $src ($(du -h "$OUT/$dest_name" | awk '{print $1}'))"
      return 0
    fi
  done
  return 1
}

echo "[landing-media] diagnóstico:"
ls -lah "$ROOT/assets/art/" 2>/dev/null | head -10 || echo "  (sin assets/art/)"
ls -lah "$ROOT/assets/video/intro/" 2>/dev/null | head -10 || echo "  (sin assets/video/intro/)"
ls -lah "$PARK/assets/art/" 2>/dev/null | head -10 || true

# 1) Restaurar working tree desde git si faltan
for rel in \
  assets/art/chadrine_keyart.png \
  assets/art/chadrine_keyart_2.png \
  assets/art/chadrine_ref.jpeg \
  assets/video/intro/chadrine_intro.mp4 \
  assets/video/intro/chadrine_intro.webm
do
  if [ ! -f "$ROOT/$rel" ] || ! is_big_enough "$ROOT/$rel" 1000; then
    if git_extract "$rel" "$ROOT/$rel"; then
      echo "[landing-media] git checkout blob → $rel ($(du -h "$ROOT/$rel" | awk '{print $1}'))"
    elif [ -f "$PARK/$rel" ]; then
      mkdir -p "$ROOT/$(dirname "$rel")"
      cp -f "$PARK/$rel" "$ROOT/$rel"
      echo "[landing-media] park → $rel"
    fi
  fi
done

ok=0

# 2) Preferir git → OUT directo (más fiable que el working tree)
if git_extract "assets/art/chadrine_keyart.png" "$OUT/chadrine_keyart.png" \
  && is_big_enough "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES"; then
  echo "[landing-media] chadrine_keyart.png ← git ($(du -h "$OUT/chadrine_keyart.png" | awk '{print $1}'))"
  ok=$((ok + 1))
elif copy_one chadrine_keyart.png "$MIN_ART_BYTES" \
  "$ROOT/assets/art/chadrine_keyart.png" \
  "$PARK/assets/art/chadrine_keyart.png"; then
  ok=$((ok + 1))
fi

if git_extract "assets/art/chadrine_keyart_2.png" "$OUT/chadrine_keyart_2.png" \
  && is_big_enough "$OUT/chadrine_keyart_2.png" "$MIN_ART_BYTES"; then
  echo "[landing-media] chadrine_keyart_2.png ← git ($(du -h "$OUT/chadrine_keyart_2.png" | awk '{print $1}'))"
  ok=$((ok + 1))
elif copy_one chadrine_keyart_2.png "$MIN_ART_BYTES" \
  "$ROOT/assets/art/chadrine_keyart_2.png" \
  "$PARK/assets/art/chadrine_keyart_2.png" \
  "$OUT/chadrine_keyart.png"; then
  ok=$((ok + 1))
fi

if git_extract "assets/art/chadrine_ref.jpeg" "$OUT/chadrine_ref.jpeg" \
  && is_big_enough "$OUT/chadrine_ref.jpeg" 50000; then
  echo "[landing-media] chadrine_ref.jpeg ← git ($(du -h "$OUT/chadrine_ref.jpeg" | awk '{print $1}'))"
  ok=$((ok + 1))
elif copy_one chadrine_ref.jpeg 50000 \
  "$ROOT/assets/art/chadrine_ref.jpeg" \
  "$PARK/assets/art/chadrine_ref.jpeg" \
  "$OUT/chadrine_keyart.png"; then
  ok=$((ok + 1))
fi

if git_extract "assets/video/intro/chadrine_intro.mp4" "$OUT/chadrine_intro.mp4" \
  && is_big_enough "$OUT/chadrine_intro.mp4" "$MIN_VIDEO_BYTES"; then
  echo "[landing-media] chadrine_intro.mp4 ← git ($(du -h "$OUT/chadrine_intro.mp4" | awk '{print $1}'))"
  ok=$((ok + 1))
elif copy_one chadrine_intro.mp4 "$MIN_VIDEO_BYTES" \
  "$ROOT/assets/video/intro/chadrine_intro.mp4" \
  "$PARK/assets/video/intro/chadrine_intro.mp4"; then
  ok=$((ok + 1))
elif git_extract "assets/video/intro/chadrine_intro.webm" "$OUT/chadrine_intro.webm" \
  && is_big_enough "$OUT/chadrine_intro.webm" "$MIN_VIDEO_BYTES"; then
  cp -f "$OUT/chadrine_intro.webm" "$OUT/chadrine_intro.mp4" 2>/dev/null || true
  echo "[landing-media] intro webm ← git"
  ok=$((ok + 1))
elif copy_one chadrine_intro.webm "$MIN_VIDEO_BYTES" \
  "$ROOT/assets/video/intro/chadrine_intro.webm" \
  "$PARK/assets/video/intro/chadrine_intro.webm"; then
  cp -f "$OUT/chadrine_intro.webm" "$OUT/chadrine_intro.mp4" 2>/dev/null || true
  ok=$((ok + 1))
else
  echo "[landing-media] AVISO: sin vídeo intro"
fi

# Fallbacks mínimos (solo si git también falló)
if ! is_big_enough "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES"; then
  if is_big_enough "$ROOT/export/web/index.png" 1000; then
    cp -f "$ROOT/export/web/index.png" "$OUT/chadrine_keyart.png"
    echo "[landing-media] AVISO: keyart fallback index.png (sin blob git)"
  else
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' >"$OUT/chadrine_keyart.png"
  fi
fi
[ -f "$OUT/chadrine_keyart_2.png" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_keyart_2.png"
[ -f "$OUT/chadrine_ref.jpeg" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_ref.jpeg"

ls -lah "$OUT"
echo "[landing-media] listo (fuentes OK contadas≈$ok)"
if ! is_big_enough "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES"; then
  echo "[landing-media] ERROR: keyart sigue siendo demasiado pequeño" >&2
  exit 1
fi
