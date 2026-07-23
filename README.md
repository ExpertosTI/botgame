# CHADRINE

Juego hub multijugador / local (Godot 4.3) — **CHADRINE**.

**Versión:** 1.2.0 · Renace Tech / Expertos TI  
**Legal:** [LEGAL.md](LEGAL.md) · **Assets:** [assets/CREDITS.md](assets/CREDITS.md)

## Modos

| Modo | Descripción |
|------|-------------|
| **Asimétrico** | Bestia vs Robots · online / campaña |
| **Platformer** | Starter Kit Kenney 3D (local) |
| **FPS** | Starter Kit Kenney FPS (local) |
| **City Builder** | Starter Kit Kenney City (local) |

Mapas asimétricos: neon, contenedores, ruinas, reactor, skybridge, **castillo**, **cueva**, **bosque**.  
Personajes: cápsulas + Blocky/KayKit (catálogo en lobby).

## Controles (asimétrico)

**PC:** WASD · Click · Q arma · 1–4 habilidades · G dash · Esc pausa  
Submodos Kenney: ver overlay **← Hub CHADRINE** / Esc.

## Deploy (Renace)

```bash
# Mac
git push origin main

# VPS
cd /opt/botgame && ./deploy.sh update
```

Forzar re-export Godot: `FORCE_GODOT_EXPORT=1 ./deploy.sh start`
