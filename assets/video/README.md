# Videos CHADRINE

## Dónde poner los archivos

Copia desde **Descargas** a estas carpetas del proyecto:

| Tipo | Carpeta |
|------|---------|
| Intro / tráiler | `assets/video/intro/` |
| Inicio partida, campaña, lore | `assets/video/cinematics/` |
| Vertical móvil 9:16 | `assets/video/mobile/` |
| Key art / posters PNG | `assets/art/` |

### Nombres sugeridos

```
assets/video/intro/chadrine_intro.mp4
assets/video/cinematics/match_start.mp4
assets/video/cinematics/campaign_start.mp4
assets/video/cinematics/lore_01.mp4
assets/art/chadrine_keyart.png
```

## Resolución

- Intro / cinemáticas PC+Web: **1280×720** o **1920×1080**
- Móvil fullscreen: **720×1280**
- Estilo hijas: rosa pastel + amarillo, personajes lindos, Bestia menos aterradora

## Formato Web (Godot HTML5)

MP4 funciona en editor/escritorio. Para la web conviene WebM:

```bash
ffmpeg -i assets/video/intro/chadrine_intro.mp4 \
  -c:v libvpx-vp9 -b:v 2M -c:a libopus \
  assets/video/intro/chadrine_intro.webm
```

Cuando tengas más MP4 en Descargas, avisa y los copiamos / cableamos al menú.
