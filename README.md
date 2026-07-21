# Bestia vs Robots

Juego multijugador asimétrico 3D (Godot 4) — estilo cápsula original, pensado para **Web + tiendas** (APK) contra un **VPS**.

**Versión:** 1.0.0 · **Editor:** Renace Tech · **Dev:** Expertos TI / Renace  
**Legal:** [LEGAL.md](LEGAL.md) · **Privacidad:** [PRIVACY.md](PRIVACY.md) / https://botgame.renace.tech/privacy

## Cómo se juega

| Rol | Meta |
|-----|------|
| **Bestia** (1) | Eliminar robots (2 vidas cada uno) |
| **Robots** (1–3) | Sabotear núcleos antes de que los cacen |

- **Online** (VPS) o **Campaña solitaria** (8 niveles vs bots)
- 3 mapas · arsenales desbloqueables · pausa / ajustes
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

Cada deploy publica `version.json` y fuerza build fresca en el cliente.

## Tiendas (checklist MVP)

- [x] Nombre, versión, autor en `project.godot`
- [x] Créditos + disclaimer in-game
- [x] Privacidad pública (`/privacy`)
- [x] Pausa + mute + sensibilidad
- [x] Campaña 8 niveles + tip de nivel
- [x] Desconexión con mensaje claro
- [ ] Export Android/iOS (keystore / Apple team — configurar en Godot)
- [ ] Audio SFX/música definitivos

## Notas legales

Personajes **originales**. Silueta cápsula = inspiración estética; sin assets ni marcas de Among Us / Innersloth.
