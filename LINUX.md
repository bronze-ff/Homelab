# 🐧 Homelab no Linux (Debian / Docker)

Versão **Linux** do homelab — uma stack **enxuta** adaptada do setup Windows
(este [README.md](README.md)) para rodar em hardware modesto. O servidor atual é
um **Debian 13 (trixie)** num **Celeron J1800 com 4 GB de RAM**, por isso cada
serviço tem `mem_limit` definido no Compose.

> **Arquivos desta versão:** [`docker-compose.linux.yml`](docker-compose.linux.yml)
> + [`.env.linux.example`](.env.linux.example). O `docker-compose.yml` (sem sufixo)
> é a versão **Windows / Docker Desktop**.

## Diferenças em relação à versão Windows

| | Windows (`docker-compose.yml`) | Linux (`docker-compose.linux.yml`) |
|---|---|---|
| Engine | Docker Desktop (WSL2) | Docker Engine nativo |
| Perfis de qualidade | **Recyclarr** (`config/recyclarr`) | **Configarr** (`config/configarr`) |
| Mídia montada como | `/data` (`/data/media`, `/data/torrents`) | `/media` (pasta única, hardlink) |
| Limites de RAM | não | sim (`mem_limit` por serviço) |
| Extras | Nextcloud, Immich, Stirling-PDF, IT-Tools, vaultwarden-backup | **UpSnap** (Wake-on-LAN), **Vaultwarden** |
| Banco do Jellyfin | volume nativo (evita lock no 9p) | bind mount normal (ext4, sem lock) |

## 📦 Serviços e portas

| Serviço | Porta | Função |
|---|---|---|
| **Homarr** | 7575 | Dashboard central |
| **Jellyfin** | 8096 | Streaming |
| **Jellyseerr** | 5055 | Pedidos de filmes/séries |
| **Radarr** | 7878 | Filmes |
| **Sonarr** | 8989 | Séries + anime |
| **Prowlarr** | 9696 | Indexadores |
| **Bazarr** | 6767 | Legendas PT-BR |
| **qBittorrent** | 8080 | Download (torrent: 6881 TCP/UDP) |
| **Portainer** | 9000 | Gerência dos containers — *opcional (comentado por padrão)* |
| **Uptime-Kuma** | 3001 | Monitor de status — *opcional (comentado por padrão)* |
| **UpSnap** | 8090 | Wake-on-LAN (rede do host) |
| **Vaultwarden** | 8222 | Gerenciador de senhas |
| **FlareSolverr** | 8191 | Bypass Cloudflare — *opcional (comentado por padrão; ative só com indexador Cloudflare)* |
| Configarr | — | Perfis de qualidade TRaSH (roda sob demanda) |

> ⚙️ **Por padrão, FlareSolverr, Portainer e Uptime-Kuma vêm comentados** no
> `docker-compose.linux.yml` para economizar RAM/CPU no hardware modesto. Para
> ligar qualquer um, descomente o bloco e rode `docker compose -f
> docker-compose.linux.yml up -d`.

---

## 1️⃣ Pré-requisitos

```bash
# Docker Engine + plugin compose (Debian/Ubuntu)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # rode docker sem sudo (reentre na sessão depois)

# Tailscale (acesso remoto) — VPN privada entre seus dispositivos
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

## 2️⃣ Pastas e `.env`

```bash
# pastas de mídia (tudo no mesmo filesystem -> hardlink instantâneo)
mkdir -p ~/media/{filmes,series,animes,downloads/incomplete,torrents}
mkdir -p ~/config

# pegue os arquivos deste repo, depois:
cp .env.linux.example .env
# edite MEDIA_PATH/CONFIG_PATH (use o caminho real, ex.: /home/SEU_USUARIO/...),
# gere o HOMARR_SECRET (openssl rand -hex 32) e o VAULTWARDEN_ADMIN_TOKEN.
```

## 3️⃣ Subir tudo

```bash
docker compose -f docker-compose.linux.yml up -d
docker compose -f docker-compose.linux.yml ps      # status
```

---

## 4️⃣ Configuração pós-deploy (na ordem)

> Todos os apps começam **vazios**. Os *arr (Radarr/Sonarr/Prowlarr) já geram a
> API key sozinhos em `config/<app>/config.xml`. As URLs internas usam o **nome do
> container** na rede `homelab` (ex.: `http://radarr:7878`).

1. **qBittorrent** (`:8080`) — usuário `admin`; a senha temporária aparece em
   `docker logs qbittorrent`. Troque em *Tools → Options → Web UI*. Default save
   path `/media/downloads`; crie as categorias `radarr` → `/media/downloads/radarr`
   e `sonarr` → `/media/downloads/sonarr`.
2. **Prowlarr** (`:9696`) — *Settings → Indexers → Add Proxy* tipo **FlareSolverr**,
   host `http://flaresolverr:8191`, tag `flaresolverr`. Adicione indexadores
   públicos (The Pirate Bay, YTS, LimeTorrents; anime: Nyaa.si, Tokyo Toshokan,
   SubsPlease). Em *Settings → Apps* conecte **Radarr** (`http://radarr:7878`) e
   **Sonarr** (`http://sonarr:8989`) com as API keys → *Sync App Indexers*.
3. **Radarr** (`:7878`) — Root Folder `/media/filmes`; Download Client qBittorrent
   (host `qbittorrent`, porta 8080, categoria `radarr`).
4. **Sonarr** (`:8989`) — Root Folders `/media/series` e `/media/animes`; Download
   Client qBittorrent (categoria `sonarr`). Para anime: *Series Type = Anime*.
5. **Configarr** (perfis TRaSH) — edite `config/configarr/config/config.yml` e
   `secrets.yml` (API keys), depois rode uma vez:
   ```bash
   docker compose -f docker-compose.linux.yml run --rm configarr
   ```
6. **Bazarr** (`:6767`) — *Settings → Sonarr/Radarr* (address `sonarr`/`radarr`,
   API keys) → Test → Save. *Languages*: perfil **Portuguese (Brazil)** como padrão.
   *Providers*: habilite os sem conta (Podnapisi, Subf2m) — opcional: OpenSubtitles.com.
7. **Jellyfin** (`:8096`) — assistente: idioma Português (BR), crie o admin, e
   bibliotecas **Filmes** → `/media/filmes`, **Séries** → `/media/series`,
   **Animes** → `/media/animes` (tipo *Shows*).
8. **Jellyseerr** (`:5055`) — "Sign in with Jellyfin", URL `http://jellyfin:8096`.
   *Settings → Services* → adicione Radarr (`http://radarr:7878`) e Sonarr
   (`http://sonarr:8989`) com API key, root folder e quality profile.
9. **Portainer** (`:9000`) / **Uptime-Kuma** (`:3001`) — crie o admin no 1º acesso.
10. **Homarr** (`:7575`) — crie o admin; adicione os apps. **Veja a dica de URL
    abaixo** para os tiles funcionarem dentro E fora de casa.

---

## 🌐 Mapa de acesso (LAN + Tailscale)

Servidor atual: **LAN `192.168.15.39`** · **Tailscale `100.91.54.116`**
(hostname MagicDNS `debian`). Tudo é **HTTP**.

| Serviço | Local (LAN) | Tailscale (de fora) |
|---|---|---|
| Homarr | http://192.168.15.39:7575 | http://100.91.54.116:7575 |
| Jellyfin | http://192.168.15.39:8096 | http://100.91.54.116:8096 |
| Jellyseerr | http://192.168.15.39:5055 | http://100.91.54.116:5055 |
| Radarr | http://192.168.15.39:7878 | http://100.91.54.116:7878 |
| Sonarr | http://192.168.15.39:8989 | http://100.91.54.116:8989 |
| Prowlarr | http://192.168.15.39:9696 | http://100.91.54.116:9696 |
| Bazarr | http://192.168.15.39:6767 | http://100.91.54.116:6767 |
| qBittorrent | http://192.168.15.39:8080 | http://100.91.54.116:8080 |
| Portainer | http://192.168.15.39:9000 | http://100.91.54.116:9000 |
| Uptime-Kuma | http://192.168.15.39:3001 | http://100.91.54.116:3001 |
| UpSnap | http://192.168.15.39:8090 | http://100.91.54.116:8090 |
| Vaultwarden | http://192.168.15.39:8222 | http://100.91.54.116:8222 |

### 💡 Homarr: tiles que funcionam dentro E fora da rede

O clique num tile abre **uma URL fixa** — o Homarr não troca de URL conforme a
rede. Por isso, use o **IP do Tailscale** (`100.91.54.116`) nos tiles:

- **Fora de casa:** o Tailscale roteia até o servidor. ✅
- **Em casa:** o Tailscale também funciona (conexão direta na LAN ou via DERP),
  desde que o dispositivo esteja com o Tailscale ligado. ✅

Ou seja, **um IP Tailscale serve nos dois cenários**, enquanto o IP LAN
(`192.168.15.39`) só funciona dentro de casa. (Dispositivos sem Tailscale na LAN —
ex.: uma TV — precisariam do IP LAN; nesse caso, ou instale o Tailscale neles, ou
publique a LAN como *subnet route* no Tailscale.)

> As **integrações** do Homarr (widgets de status/fila) são feitas pelo backend
> do servidor → podem usar `http://<container>:porta` ou o IP LAN; não precisam do
> Tailscale.

---

## 🔐 Vaultwarden — restaurar de um backup `ttionya/vaultwarden-backup`

O backup é um `.7z` (AES-256, nomes ocultos) com `db.<data>.sqlite3` +
`rsakey.<data>.tar` (contém `rsa_key.pem`).

```bash
# 1) extrair (precisa da VAULTWARDEN_BACKUP_PASSWORD; container avulso com 7z)
docker run --rm -v "$PWD":/w alpine sh -c \
  "apk add --no-cache 7zip >/dev/null && 7z x -p'SENHA_DO_BACKUP' /w/backup.AAAAMMDD.7z -o/w/vw_restore"

# 2) montar o data dir do Vaultwarden
mkdir -p ~/config/vaultwarden
cp ~/vw_restore/db.*.sqlite3 ~/config/vaultwarden/db.sqlite3
tar xf ~/vw_restore/rsakey.*.tar -C ~/config/vaultwarden    # rsa_key.pem

# 3) subir e CONFERIR (deve listar seu usuário)
docker compose -f docker-compose.linux.yml up -d vaultwarden
# apague a extração em TEXTO CLARO depois:  rm -rf ~/vw_restore
```

### HTTPS via Tailscale (para o cofre WEB no navegador)

O cofre **web** exige contexto seguro (HTTPS). Habilite uma vez:

```bash
sudo tailscale set --operator="$USER"
tailscale serve --bg 8222
# fica em https://<seu-host>.tailXXXX.ts.net
```

> Os apps Bitwarden (celular/desktop/extensão) **não** precisam disso — apontam
> direto para `http://IP_TAILSCALE:8222`.

---

## 🧠 Notas de hardware (4 GB RAM)

- Os `mem_limit` mantêm a soma dentro de ~3,7 GB. Evite adicionar serviços pesados
  (Nextcloud/Immich) sem aumentar a RAM.
- **Serviços opcionais desligados:** FlareSolverr (sobe um Chrome headless e pesa),
  Portainer e Uptime-Kuma vêm **comentados** por padrão. Reative só se precisar.
- **Jellyfin (CPU é o gargalo):** o J1800 não tem transcode por hardware —
  **transcodar trava tudo**. Deixe o *throttling* de transcode ligado (Dashboard →
  Playback) e prefira **Direct Play**: use o app do Jellyfin (não o navegador),
  legendas em **texto (SRT)** — não imagem/PGS, que força transcode — e qualidade
  "Original" no cliente. Evite 4K nesse hardware.
- **DNS:** alguns indexadores (1337x, EZTV) podem dar *"Name does not resolve"* por
  bloqueio de DNS do provedor. Resolva apontando DNS público nos containers
  afetados (ex.: `dns: [1.1.1.1, 8.8.8.8]` no serviço) ou no daemon do Docker.

## 🔧 Comandos úteis

```bash
docker compose -f docker-compose.linux.yml up -d        # sobe tudo
docker compose -f docker-compose.linux.yml ps           # status
docker compose -f docker-compose.linux.yml logs -f sonarr
docker compose -f docker-compose.linux.yml pull         # atualiza imagens
docker compose -f docker-compose.linux.yml run --rm configarr   # re-sincroniza perfis
```
