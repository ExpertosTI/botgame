# CHADRINE

Juego multijugador asimétrico 3D (Godot 4) — **CHADRINE**: Bestia vs Robots, campaña y online.

**Versión:** 1.1.0 · **Editor:** Renace Tech · **Dev:** Expertos TI / Renace  
**Legal:** [LEGAL.md](LEGAL.md) · **Privacidad:** [PRIVACY.md](PRIVACY.md) / https://botgame.renace.tech/privacy

## Cómo se juega

| Rol | Meta |
|-----|------|
| **Bestia** (1) | Eliminar robots (2 vidas cada uno) |
| **Robots** (1–3) | Sabotear núcleos antes de que los cacen |

- **Online** (VPS) o **Campaña solitaria** (12 niveles vs bots)
- 5 mapas · powerups · hazards · scoreboard MVP
- Arsenales con railgun / vacío / minas · audio procedural
- Controles táctiles en móvil/Web

## Controles

**PC:** WASD · Click · Q arma · 1–4 habilidades · G dash · Esc pausa  
**Móvil:** joystick + DISPARO / BOMBA / ARMA / DASH / HAB · ⏸

## Probar en local

1. Instala [Godot 4.3+](https://godotengine.org/download)
2. Abre esta carpeta
3. Menú: **ONLINE** (LAN/VPS) o **CAMPAÑA** (práctica)

## Deploy (Renace)

```bash
git push origin main
# VPS:
cd /opt/botgame && FORCE_GODOT_EXPORT=1 ./deploy.sh update
```

## Tiendas (checklist)

- [x] Nombre **CHADRINE**, versión, autor
- [x] Créditos + disclaimer in-game
- [x] Privacidad pública (`/privacy`)
- [x] Pausa + mute + sensibilidad
- [x] Campaña 12 niveles + 5 mapas
- [x] Stats / MVP / VFX / audio procedural
- [ ] Export Android/iOS (keystore / Apple team)
- [ ] Audio SFX/música con assets finales

## Notas legales

**CHADRINE** y sus personajes son **originales**. Silueta cápsula = inspiración estética; sin assets ni marcas de Among Us / Innersloth.
