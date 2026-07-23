#!/usr/bin/env bash
# Prepara deploy/landing/media/ (arte, vídeo, roster GLB, mapas) para la landing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/deploy/landing/media"
PARK="${PARK_DIR:-/var/cache/botgame-godot/parked-media}"
MIN_ART_BYTES=100000
MIN_VIDEO_BYTES=200000

mkdir -p "$OUT/roster" "$OUT/maps" "$OUT/ui"

is_big_enough() {
  local f="$1" min="$2"
  [ -f "$f" ] && [ "$(wc -c <"$f" | tr -d ' ')" -ge "$min" ]
}

git_extract() {
  local rel="$1" dest="$2"
  if git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null; then
    mkdir -p "$(dirname "$dest")"
    git -C "$ROOT" show "HEAD:$rel" >"$dest"
    return 0
  fi
  return 1
}

copy_file() {
  local dest="$1" min="$2"
  shift 2
  local src
  for src in "$@"; do
    if is_big_enough "$src" "$min"; then
      mkdir -p "$(dirname "$dest")"
      cp -f "$src" "$dest"
      echo "[landing-media] $(basename "$dest") ← $src ($(du -h "$dest" | awk '{print $1}'))"
      return 0
    fi
  done
  return 1
}

echo "[landing-media] diagnóstico working tree:"
ls -lah "$ROOT/assets/art/" 2>/dev/null | head -8 || echo "  (sin assets/art/)"
ls -lah "$ROOT/assets/video/intro/" 2>/dev/null | head -8 || echo "  (sin intro/)"
roster_n=0
shopt -s nullglob
for _g in "$ROOT/assets/characters/roster/"*.glb; do roster_n=$((roster_n + 1)); done
echo "  roster glbs en tree: $roster_n"

# Restaurar blobs al working tree si faltan
for rel in \
  assets/art/chadrine_keyart.png \
  assets/art/chadrine_keyart_2.png \
  assets/art/chadrine_ref.jpeg \
  assets/video/intro/chadrine_intro.mp4 \
  assets/video/intro/chadrine_intro.webm
do
  if ! is_big_enough "$ROOT/$rel" 1000; then
    if git_extract "$rel" "$ROOT/$rel"; then
      echo "[landing-media] git → $rel"
    elif [ -f "$PARK/$rel" ]; then
      mkdir -p "$ROOT/$(dirname "$rel")"
      cp -f "$PARK/$rel" "$ROOT/$rel" || true
    fi
  fi
done

# —— Arte / vídeo ——
if git_extract "assets/art/chadrine_keyart.png" "$OUT/chadrine_keyart.png" \
  && is_big_enough "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES"; then
  echo "[landing-media] keyart ← git ($(du -h "$OUT/chadrine_keyart.png" | awk '{print $1}'))"
else
  copy_file "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES" \
    "$ROOT/assets/art/chadrine_keyart.png" \
    "$PARK/assets/art/chadrine_keyart.png" || true
fi

git_extract "assets/art/chadrine_keyart_2.png" "$OUT/chadrine_keyart_2.png" || \
  copy_file "$OUT/chadrine_keyart_2.png" "$MIN_ART_BYTES" \
    "$ROOT/assets/art/chadrine_keyart_2.png" \
    "$PARK/assets/art/chadrine_keyart_2.png" \
    "$OUT/chadrine_keyart.png" || true

git_extract "assets/art/chadrine_ref.jpeg" "$OUT/chadrine_ref.jpeg" || \
  copy_file "$OUT/chadrine_ref.jpeg" 50000 \
    "$ROOT/assets/art/chadrine_ref.jpeg" \
    "$OUT/chadrine_keyart.png" || true

if git_extract "assets/video/intro/chadrine_intro.mp4" "$OUT/chadrine_intro.mp4" \
  && is_big_enough "$OUT/chadrine_intro.mp4" "$MIN_VIDEO_BYTES"; then
  echo "[landing-media] intro.mp4 ← git ($(du -h "$OUT/chadrine_intro.mp4" | awk '{print $1}'))"
elif copy_file "$OUT/chadrine_intro.mp4" "$MIN_VIDEO_BYTES" \
  "$ROOT/assets/video/intro/chadrine_intro.mp4" \
  "$PARK/assets/video/intro/chadrine_intro.mp4"; then
  true
elif git_extract "assets/video/intro/chadrine_intro.webm" "$OUT/chadrine_intro.webm"; then
  echo "[landing-media] intro.webm ← git"
else
  echo "[landing-media] AVISO: sin vídeo intro"
fi

# —— Roster GLB (personajes descargados) ——
ROSTER_IDS=(
  blocky_a blocky_b blocky_c
  kay_knight kay_mage kay_rogue kay_barbarian kay_ranger
  forest_archer skel_warrior skel_mage
)
roster_ok=0
for id in "${ROSTER_IDS[@]}"; do
  rel="assets/characters/roster/${id}.glb"
  dest="$OUT/roster/${id}.glb"
  if git_extract "$rel" "$dest" && [ -s "$dest" ]; then
    roster_ok=$((roster_ok + 1))
  elif [ -f "$ROOT/$rel" ]; then
    cp -f "$ROOT/$rel" "$dest"
    roster_ok=$((roster_ok + 1))
  elif [ -f "$PARK/$rel" ]; then
    cp -f "$PARK/$rel" "$dest"
    roster_ok=$((roster_ok + 1))
  fi
done
echo "[landing-media] roster GLB: $roster_ok / ${#ROSTER_IDS[@]}"

# —— Texturas externas de Blocky / forest (GLB no embebidos) ——
# Tras el export Godot el working tree suele estar vacío: SIEMPRE sacar de git.
TEX_OUT="$OUT/roster/Textures"
mkdir -p "$TEX_OUT"
tex_ok=0
for tex in texture-a texture-b texture-c texture-d texture-e texture-f colormap; do
  dest="$TEX_OUT/${tex}.png"
  rel="assets/characters/roster/Textures/${tex}.png"
  if git_extract "$rel" "$dest" && [ -s "$dest" ]; then
    tex_ok=$((tex_ok + 1))
    continue
  fi
  for src in \
    "$ROOT/$rel" \
    "$ROOT/assets/kenney/blocky-characters_20/Models/GLB format/Textures/${tex}.png" \
    "$ROOT/assets/kenney/mini-forest_1.0/Models/GLB format/Textures/${tex}.png" \
    "$PARK/$rel"
  do
    if [ -f "$src" ] && [ -s "$src" ]; then
      mkdir -p "$(dirname "$dest")"
      cp -f "$src" "$dest"
      tex_ok=$((tex_ok + 1))
      break
    fi
  done
done
echo "[landing-media] roster Textures: $tex_ok"
if [ "$tex_ok" -lt 6 ]; then
  echo "[landing-media] ERROR: faltan texturas Blocky ($tex_ok/7) — Blocky A/B fallarán en Three.js" >&2
  ls -lah "$TEX_OUT" || true
  exit 1
fi

# Limpiar basura de Godot .import dentro de media (no deben ir a nginx)
find "$OUT" -name '*.import' -type f -delete 2>/dev/null || true

# —— Mapas UI ——
for map in map_neon map_containers map_ruins; do
  rel="assets/ui/${map}.jpg"
  dest="$OUT/maps/${map}.jpg"
  git_extract "$rel" "$dest" || copy_file "$dest" 5000 "$ROOT/$rel" || true
done

# —— Iconos robot reales (no emoji) ——
for skin in robot_azul robot_rosa robot_verde robot_amarillo beast_classic beast_mecha beast_shadow; do
  rel="assets/ui/${skin}.png"
  dest="$OUT/ui/${skin}.png"
  git_extract "$rel" "$dest" || copy_file "$dest" 500 "$ROOT/$rel" || true
done

# Fallbacks arte
if ! is_big_enough "$OUT/chadrine_keyart.png" "$MIN_ART_BYTES"; then
  echo "[landing-media] ERROR: keyart ausente o demasiado pequeño" >&2
  ls -lah "$OUT" || true
  exit 1
fi
[ -f "$OUT/chadrine_keyart_2.png" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_keyart_2.png"
[ -f "$OUT/chadrine_ref.jpeg" ] || cp -f "$OUT/chadrine_keyart.png" "$OUT/chadrine_ref.jpeg"

if [ "$roster_ok" -lt 3 ]; then
  echo "[landing-media] ERROR: pocos GLB de roster ($roster_ok)" >&2
  exit 1
fi

echo "[landing-media] resumen:"
ls -lah "$OUT" | head -20
echo "  roster files: $(ls "$OUT/roster" 2>/dev/null | wc -l | tr -d ' ')"
ls "$OUT/maps" 2>/dev/null || true
echo "[landing-media] OK"
