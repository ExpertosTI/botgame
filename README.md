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

## Deploy

```bash
git push origin main
cd /opt/botgame && FORCE_GODOT_EXPORT=1 ./deploy.sh update
```

Nota Web: packs crudos (`assets/descargas`, KayKit, kits Kenney) tienen `.gdignore` y no se importan en el export del VPS.

Deploy VPS (rápido, sobrevive a corte SSH):

```bash
cd /opt/botgame && ./deploy.sh update
./scripts/deploy_progress.sh   # otra sesión
# o: ./deploy.sh logs deploy
```

`FORCE_GODOT_EXPORT=1` re-exporta reutilizando `.godot`. Solo usa `FORCE_GODOT_IMPORT=1` si la cache está corrupta.
