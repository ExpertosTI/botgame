# Bestia vs Robots

Juego multijugador asimétrico 3D (Godot 4) — estilo cápsula cute, pensado para jugar en familia por **WebApp + APK** contra un **VPS**.

## Cómo se juega

| Rol | Meta |
|-----|------|
| **Bestia** (1) | Eliminar robots (2 vidas cada uno) |
| **Robots** (1–3) | Sabotear 5 núcleos antes de que los cacen |

- Tiempo típico: **4 minutos**
- 3 mapas: Laboratorio Neon, Ciudad de Contenedores, Ruinas del Núcleo
- Personajes originales estilo cápsula (inspiración visual tipo Among Us, **sin assets oficiales**)

## Controles

**PC**

| Tecla | Acción |
|-------|--------|
| WASD | Mover |
| Click izq. | Disparar / garras / sabotear (cerca de núcleo) |
| Click der. | Bomba / slam rápido |
| Q / E / rueda | Cambiar arma |
| 1 2 3 4 | Habilidades |
| G | Dash |
| Shift | Correr |
| Esc | Liberar ratón |

**Móvil:** joystick + DISPARO / BOMBA / ARMA / DASH / HAB 2-4

### Armamento

- **Robots:** Bláster, Escopeta, Granada, Plasma, Rayo Hielo
- **Bestia:** Garras, Escupitajo, Bomba Slam, Rugido
- **Habilidades robots:** Dash, Escudo, EMP, Turbo
- **Habilidades bestia:** Dash, Salto, Furia, Camuflaje o Púas

La bestia tiene barra de HP (disparos la debilitan; al llegar a 0 queda aturdida un momento).


## Probar en local (sin VPS)

1. Instala [Godot 4.3+](https://godotengine.org/download)
2. Abre esta carpeta en Godot
3. En el menú elige modo:
   - **ONLINE** → URL `wss://…` → Entrar · o **Sala local (LAN)** en PC
   - **CAMPAÑA** → práctica solitaria vs bots (progresión real)
4. Online: Instancia A sala local / Instancia B `ws://127.0.0.1:7777`
5. Lobby: una Bestia, resto Robot → Listo → Empezar

## Flujo de deploy (Renace — sin rsync ni passwords)

```bash
# Mac / CI
git add -A && git commit -m "..." && git push origin main

# VPS (ya logueado, o CI con deploy key)
cd /opt/botgame && ./deploy.sh update
```

`deploy.sh update` hace: `git pull` → **export Godot en el VPS** (Web + Linux) → Docker build → Swarm/Traefik.

No subas binarios por SSH. Los exports se generan en el servidor.


## Estructura

```
autoload/          NetworkManager (WebSocket), GameManager, InputManager
config/            server_config.tres (URL VPS)
scenes/            menú, lobby, game, players, touch UI
scripts/maps/      3 arenas procedurales
deploy/            docker-compose, nginx, Dockerfile
assets/            UI/SFX (Kenney si disponibles) + personajes propios
```

## Checklist partida lista

- [x] WebSocket + lobby con roles / mapa / variante
- [x] Personajes cápsula (robots de colores + bestia con cuernos)
- [x] 3 mapas
- [x] Controles táctiles
- [x] Rematch / menú
- [x] Docker + Nginx WSS path `/ws`
- [ ] Export Web/APK/Linux (hacer en Godot en tu máquina)
- [ ] Dominio + HTTPS en el VPS

## Notas legales

Los personajes son **originales**. La silueta “cápsula con visor” es solo inspiración estética; no uses assets ni marcas de Among Us / Innersloth.
