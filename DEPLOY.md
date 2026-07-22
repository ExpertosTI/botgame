# Deploy — CHADRINE (RenaceNet)

Stack igual que el resto de RENACE: **Docker Swarm + Traefik** en la red overlay `RenaceNet`.

Repo: [ExpertosTI/botgame](https://github.com/ExpertosTI/botgame)  
URL pública prevista: **https://botgame.renace.tech**  
WebSocket: **wss://botgame.renace.tech/ws**

## Consumo del servidor (estimado)

Partida típica familiar: **2–4 jugadores**, 1 mapa, 1 servidor dedicado.

| Servicio | CPU (límite) | RAM (límite) | RAM real típica | Notas |
|----------|--------------|--------------|-----------------|-------|
| `web` (nginx + HTML5) | 0.25 | 128 MB | 20–40 MB | Estáticos Godot |
| `game-server` (Godot headless) | 1.0 | 768 MB | 250–500 MB | Pico al spawnear / explosiones |
| **Total stack** | **~1.25** | **~900 MB** | **~300–550 MB** | |

### Recomendación de VPS / slice

| Escenario | Spec recomendada |
|-----------|------------------|
| **Solo botgame** (VPS dedicado chico) | 1 vCPU / **1 GB RAM** / 10 GB disco |
| **En el mismo host RenaceNet** (con Traefik + otros stacks) | Reserva **512 MB–1 GB libres** + 1 vCPU disponible |
| **Torneos / 2 instancias** | 2 vCPU / 2 GB RAM |

Red:

- Tráfico web: bajo (descarga WASM/PCK una vez ~20–80 MB según export).
- WebSocket partida: **~5–30 KB/s por jugador** (muy ligero).
- Ancho de banda: irrelevante frente a ChatCE/ECF; un enlace doméstico/VPS básico basta.

Disco:

- Imágenes Docker: ~300–800 MB.
- Export web + server: ~50–200 MB.
- Sin base de datos.

## DNS

En el panel DNS de `renace.tech`:

```
botgame.renace.tech  →  A  →  IP del nodo Swarm (Traefik)
```

Traefik saca el certificado Let’s Encrypt solo (labels del compose).

## Flujo (sin rsync / sin contraseñas)

```bash
# 1) Código → GitHub
git push origin main

# 2) VPS (sesión ya abierta o CI)
cd /opt/botgame && ./deploy.sh update
```

El VPS descarga Godot headless, exporta Web+Linux a `export/`, construye imágenes y hace `docker stack deploy` en **RenaceNet**.

## Comandos

```bash
./deploy.sh update    # git pull + build + stack deploy
./deploy.sh start     # sin git pull
./deploy.sh status
./deploy.sh logs web
./deploy.sh logs game-server
./deploy.sh restart
./deploy.sh stop
./deploy.sh health
```

## CI (GitHub Actions)

Workflow: [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)

Secrets en el repo `ExpertosTI/botgame`:

| Secret | Ejemplo |
|--------|---------|
| `BOTGAME_DEPLOY_HOST` | IP o hostname VPS |
| `BOTGAME_DEPLOY_USER` | `deploy` / `root` |
| `BOTGAME_DEPLOY_SSH_KEY` | clave privada |
| `BOTGAME_DEPLOY_PATH` | `/opt/botgame` (opcional) |
| `BOTGAME_HEALTH_URL` | `https://botgame.renace.tech/` (opcional) |
| `BOTGAME_DEPLOY_PORT` | `22` (opcional) |

Mismo patrón que [ChatCE](https://github.com/ExpertosTI/chatce) (`appleboy/ssh-action` + script en servidor).

## Arquitectura

```
Internet
   → Traefik (RenaceNet, TLS)
        → Host(botgame.renace.tech)           → web:80      (HTML5)
        → Host(...) && PathPrefix(/ws)        → game-server:7777  (WebSocket Godot)
```

Clientes (WebApp / APK) conectan a `wss://botgame.renace.tech/ws` ([`config/server_config.tres`](config/server_config.tres)).

## Checklist antes de jugar con las niñas

1. [ ] DNS `botgame.renace.tech` apuntando al VPS  
2. [ ] `export/web/` y `export/server/` generados en Godot 4.3+  
3. [ ] `./deploy.sh update` → servicios `1/1`  
4. [ ] Abrir https://botgame.renace.tech → menú  
5. [ ] 2 dispositivos → Bestia + Robot → partida  
