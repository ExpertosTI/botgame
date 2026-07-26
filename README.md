# CHADRINE

Juego hub multijugador / local (Godot 4.3) — **CHADRINE**.

**Versión:** 1.4.0 · Renace Tech / Expertos TI  
La versión sale de [autoload/game_brand.gd](autoload/game_brand.gd); `project.godot`
y este README deben coincidir (lo vigila `tests/cases/identity_test.gd`).

**Diseño:** [docs/GDD.md](docs/GDD.md) · **Marca y guion:** [docs/BIBLIA.md](docs/BIBLIA.md)  
**Legal:** [LEGAL.md](LEGAL.md) · **Assets:** [assets/CREDITS.md](assets/CREDITS.md)

## Modos

| Modo | Descripción |
|------|-------------|
| **Asimétrico** | Bestia vs Robots · online / campaña (core) |
| **Platformer** | Starter Kit Kenney 3D (capa opcional) |
| **FPS** | Starter Kit Kenney FPS (capa opcional) |
| **City Builder** | Starter Kit Kenney City (capa opcional) |

Mapas asimétricos: neon, contenedores, ruinas, reactor, skybridge, **castillo**, **cueva**, **bosque**.  
Personajes: Blocky/KayKit en lobby (roster GLB).

## Controles (asimétrico)

**PC:** WASD · Click · Q arma · 1–4 habilidades · G dash · Esc pausa · **F3 diagnóstico**  
**Táctil / web:** stick virtual y cámara lateral fija (apuntar con dos dedos era el
mayor problema de jugabilidad).  
Submodos Kenney: overlay **← Hub CHADRINE** / Esc (si el pack está instalado).

## Tests

```bash
./scripts/run_tests.sh          # suite headless completa (~0,3 s)
./scripts/run_tests.sh fx_pool  # una sola suite
```

Necesita Godot **4.3**: un binario más nuevo invalida `.godot/`, se pone a
reimportar los assets y la corrida se queda minutos sin decir nada. El script
comprueba la serie y se niega a arrancar con otra, y corta a los 180 s
(`TEST_TIMEOUT`) si algo se cuelga. El mismo gate corre en CI y bloquea el
deploy: [.github/workflows/quality.yml](.github/workflows/quality.yml).

El overlay **F3** muestra fps, peor frame, draw calls, nodos, huérfanos, memoria,
ocupación de `FxPool` y RTT real al servidor. En web también se abre con
`?debug=1` en la URL.

## Deploy (Renace)

```bash
# Mac
git push origin main

# VPS
cd /opt/botgame && FORCE_GODOT_EXPORT=1 ./deploy.sh update
```

El export en VPS incluye **vídeo intro + roster + props**; `modes/` queda fuera del PCK (botones N/A hasta capa modes). Timeout ~20 min la primera vez con GLB.
