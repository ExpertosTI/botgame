# CHADRINE

Juego hub multijugador / local (Godot 4.3) — **CHADRINE**.

**Versión:** 1.2.2 · Renace Tech / Expertos TI  
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

**PC:** WASD · Click · Q arma · 1–4 habilidades · G dash · Esc pausa  
Submodos Kenney: overlay **← Hub CHADRINE** / Esc (si el pack está instalado).

## Deploy (Renace)

```bash
# Mac
git push origin main

# VPS
cd /opt/botgame && FORCE_GODOT_EXPORT=1 ./deploy.sh update
```

El export en VPS incluye **vídeo intro + roster + props**; `modes/` queda fuera del PCK (botones N/A hasta capa modes). Timeout ~20 min la primera vez con GLB.
