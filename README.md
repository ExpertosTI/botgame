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
3. Instancia A: **Probar en local (servidor en este PC)**
4. Instancia B: URL `ws://127.0.0.1:7777` → **Entrar a la partida**
5. En lobby: una persona elige Bestia, el resto Robot → Listo → Empezar

## Despliegue en VPS (WebApp + servidor)

Stack **RenaceNet**: Docker Swarm + Traefik. Ver guía completa: [`DEPLOY.md`](DEPLOY.md)

- URL: `https://botgame.renace.tech`
- WS: `wss://botgame.renace.tech/ws`
- Repo: https://github.com/ExpertosTI/botgame

```bash
cd /opt/botgame && sudo ./deploy.sh update
```

### Consumo aproximado

| | Límite | Típico (4 jugadores) |
|--|--------|----------------------|
| RAM total stack | ~900 MB | **300–550 MB** |
| CPU | 1.25 vCPU | bajo en idle / medio en partida |
| Disco | — | < 1 GB imágenes + export |

Recomendado en el host RenaceNet: **~1 GB libres**. Solo botgame: VPS **1 vCPU / 1 GB**.


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
