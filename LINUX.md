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
| **Homarr** | 7575 (localhost) | Dashboard central |
| **Jellyfin** | 8096 (pública) | Streaming |
| **Jellyseerr** | 5055 (pública) | Pedidos de filmes/séries |
| **Radarr** | 7878 (localhost) | Filmes |
| **Sonarr** | 8989 (localhost) | Séries + anime |
| **Prowlarr** | 9696 (localhost) | Indexadores |
| **Bazarr** | 6767 (localhost) | Legendas PT-BR |
| **qBittorrent** | 18080 (localhost) | Download (torrent: 6881 TCP/UDP) |
| **Portainer** | 9000 | Gerência dos containers — *opcional (comentado por padrão)* |
| **Uptime-Kuma** | 3001 | Monitor de status — *opcional (comentado por padrão)* |
| **UpSnap** | 8090 | Wake-on-LAN (rede do host) |
| **Vaultwarden** | 8222 | Gerenciador de senhas |
| **FlareSolverr** | 8191 (localhost) | Bypass Cloudflare — ativo para indexadores que exigem desafio |
| Configarr | — | Perfis de qualidade TRaSH (roda sob demanda) |

> ⚙️ **FlareSolverr fica ativo** porque há indexadores configurados que usam
> Cloudflare. As interfaces administrativas ficam presas ao `localhost` da VPS;
> somente Jellyfin, Jellyseerr e Vaultwarden são publicados. Portainer e
> Uptime-Kuma continuam comentados para evitar expor novas interfaces.

### Acesso administrativo seguro na VPS

Para abrir os painéis administrativos no computador local, use um túnel SSH
(os containers continuam conversando normalmente pela rede Docker):

```powershell
ssh -i "$HOME\.ssh\olume-vps" -N `
  -L 7575:127.0.0.1:7575 -L 7878:127.0.0.1:7878 `
  -L 8989:127.0.0.1:8989 -L 9696:127.0.0.1:9696 `
  -L 6767:127.0.0.1:6767 -L 18080:127.0.0.1:18080 `
  -L 8081:127.0.0.1:8081 root@179.198.105.75
```

Depois, use `http://localhost:<porta>`. A porta `6881` permanece pública apenas
para o tráfego de pares BitTorrent; ela não expõe o painel do qBittorrent.

### Monitoramento automático de episódios no Sonarr

Para séries em lançamento, mantenha a série como **Monitored**, use
**Monitor New Episodes = All** e marque os episódios futuros como monitorados.
Com os indexadores sincronizados pelo Prowlarr, o Sonarr consulta o feed RSS
periodicamente e envia automaticamente releases aprovados para o qBittorrent
na categoria `sonarr`; depois do download, importa o vídeo e o Bazarr procura a
legenda PT-BR.

Na implantação atual, **The Early Spring (2026)** está com os episódios
S01E15–S01E24 monitorados, perfil **HD-1080p • Audio Original (≤2.4GB/ep)**,
áudio original e legenda PT-BR. O RSS do Sonarr está configurado para sincronizar
a cada 15 minutos. A busca automática e o RSS estão habilitados nos indexadores
ativos; um episódio só entra na fila quando existe um release elegível, então a
ausência de um torrent não é erro de monitoramento.

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

1. **qBittorrent** (`:18080`) — usuário `admin`; a senha temporária aparece em
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

## 📱 Jellyfin no iPhone

O acesso remoto do Jellyfin usa a porta `8096`. Para o aplicativo oficial do
iOS, arquivos MKV com E-AC-3/Dolby Atmos podem gerar o erro
`AVFoundationErrorDomain -11850` quando o Native Video Player tenta tocar o
áudio diretamente. O servidor já mantém o FFmpeg e a transcodificação de áudio
habilitados; no iPhone, desative **Native Video Player** nas configurações do
app ou use o Swiftfin. Isso preserva o áudio original em mandarim e permite ao
servidor entregar AAC compatível, com a legenda PT-BR selecionada no player.

Para acesso fora da rede, prefira Tailscale ou um domínio com HTTPS. Não
publique as interfaces de administração (qBittorrent, Sonarr, Radarr,
Prowlarr e Bazarr) diretamente na internet.

## 🌐 Mapa de acesso atual

A VPS atual não tem Tailscale instalado. Tudo é **HTTP**: somente Jellyfin,
Jellyseerr e Vaultwarden estão publicados externamente; Sonarr, Radarr,
Prowlarr, Bazarr, Homarr, Filebrowser e o painel do qBittorrent escutam apenas
em `127.0.0.1` e devem ser acessados pelo túnel SSH acima.

| Serviço | Acesso externo atual | Acesso administrativo |
|---|---|---|
| Jellyfin | `http://179.198.105.75:8096` | público para streaming |
| Jellyseerr | `http://179.198.105.75:5055` | público para pedidos |
| Vaultwarden | `http://179.198.105.75:8222` | público; prefira HTTPS/Tailscale |
| Sonarr | não publicado | `http://localhost:8989` via túnel |
| Radarr | não publicado | `http://localhost:7878` via túnel |
| Prowlarr | não publicado | `http://localhost:9696` via túnel |
| Bazarr | não publicado | `http://localhost:6767` via túnel |
| Homarr | não publicado | `http://localhost:7575` via túnel |
| Filebrowser | não publicado | `http://localhost:8081` via túnel |
| qBittorrent | não publicado | `http://localhost:18080` via túnel |

### 💡 Acesso privado futuro

Se Tailscale for instalado no futuro, ele é a opção preferível para publicar os
serviços privados entre dispositivos confiáveis, sem abrir as interfaces de
administração na internet. Até lá, use o túnel SSH para os painéis.

> As **integrações** do Homarr (widgets de status/fila) são feitas pelo backend
> do servidor → podem usar `http://<container>:porta` ou o IP LAN; não precisam do
> Tailscale.

---

## ⚙️ qBittorrent — rápido, sem seed, 1 por vez, auto-limpeza

Configuração recomendada (TRaSH + comunidade), aplicada em *Tools → Options*:

**BitTorrent → Seeding Limits:**
- *When ratio reaches* **`0`** e *When seeding time reaches* **`0`** → ação
  **"Stop torrent" (pausar)**. ⚠️ **Não** use "remover" aqui — quem remove é o
  Radarr/Sonarr, depois de importar (evita apagar o arquivo antes do import).

**BitTorrent → Torrent Queueing (1 por vez):**
- Queueing **ligado**, *Max active downloads* = **`1`**, *Max active torrents* = `2`,
  *Max active uploads* = `2`, "Do not count slow torrents" = on.
  (1 download por vez = banda concentrada = mais rápido.)

**Connection (velocidade):**
- *Global max connections* = **`200`**, *per torrent* = **`100`**, upload slots `10`/`4`.
- *Download/Upload rate limit* = **`0` (ilimitado)**.
- **DHT + PeX + Local Peer Discovery = ligados** (mais peers nos trackers públicos).
- *Encryption* = **Allow** (mais peers). *Pre-allocate disk space* = **off**.

**Radarr/Sonarr → Settings → Download Clients → qBittorrent (advanced):**
- **Remove Completed Downloads = ON** (+ Remove Failed) → após importar (hardlink),
  removem o torrent e o arquivo do `/media/downloads`; o hardlink na biblioteca fica.

> Resultado: 1 download por vez, **zero seed** ao terminar, e **limpeza automática**
> do `/downloads` após o import. Conexões em 200 (não no talo) pra não estressar a
> CPU/roteador do J1800. Se o upload saturar o link e atrapalhar, cape o *upload*
> em ~70-80% da banda de subida.

---

## 🎯 Seleção de releases (tamanho, seeds, qualidade)

Ajustes pra **pegar os melhores torrents**: não muito grande, boa qualidade e
seeds reais.

### Faixa de tamanho — Radarr/Sonarr → Settings → Quality (Quality Definitions)
Para 1080p (todas as fontes WEB/Bluray):

| | MB/min | ≈ filme 2h |
|---|---|---|
| **Minimum** | `5` | ~0.6 GB (deixa passar encode **pequeno e bem-seedado**) |
| **Preferred** | `145` | ~17 GB (mira boa qualidade) |
| **Maximum** | `150` | ~18 GB (bloqueia remux / 4K-bitrate / multi-áudio gigante) |

> ⚠️ **Comente o `quality_definition` no `config/configarr/config/config.yml`** —
> senão o **Configarr reseta esses tamanhos** (de volta ao TRaSH) toda vez que roda.

### Mínimo de seeders — Radarr/Sonarr → Settings → Indexers → (cada) → Minimum Seeders
- **`3`** → ignora torrents quase mortos.
- ⚠️ A contagem de seeds **reportada** pelo indexador às vezes é fantasma (diz "8",
  mas tem 0 reais). Não existe filtro perfeito. Por isso o **Minimum baixo (5 MB/min)**:
  pra conteúdo antigo/nicho, uma versão **menor com muitos seeds reais** (ex.: BRRip
  2 GB com 600+ seeds) baixa bem — não deixe o tamanho mínimo barrá-la.

### Trackers públicos — qBittorrent → Options → BitTorrent
- ✅ **"Automatically add these trackers to new downloads"** + colar uma lista de
  trackers públicos (ex.: `ngosang/trackerslist` → `trackers_best.txt`).
- Resolve torrent preso em **"Downloading metadata"** / `0 (0)` peers (o release até
  tem seeds, mas o qBit não os acha sem trackers). DHT + PeX + LSD também ligados.

### Propers/Repacks — Radarr/Sonarr → Settings → Media Management
- **"Do not Prefer"** (recomendação TRaSH) — evita re-download à toa.

### Qualidade
- Quality Profiles + Custom Formats do **TRaSH** (via Configarr) preferem boas fontes
  e penalizam CAM/LQ/x265-ruim/etc.

> 📌 Regra geral: o sistema **prefere** uma boa versão (~15 GB), mas **aceita** uma
> menor bem-seedada quando é só o que tem com seeds reais — e **nunca** pega gigante.

---

## 🏷️ Padrão de nomes de arquivos (Sonarr + Radarr)

Para os arquivos saírem organizados e na ordem certa (em vez do nome cru do
release), ative o **rename** e use estes formatos.

### Sonarr — Settings → Media Management → Episode Naming
- **Rename Episodes:** ✅ *(vinha **desligado** por padrão — era o motivo dos nomes bagunçados/fora de ordem)*
- **Standard Episode Format:**
  `{Series Title} - S{season:00}E{episode:00} - {Episode Title} [{Quality Full}]`
- **Anime Episode Format:** *(inclui o número **absoluto** — essencial p/ a ordem do anime)*
  `{Series Title} - S{season:00}E{episode:00} - {absolute:000} - {Episode Title} [{Quality Full}]`
- **Series Folder:** `{Series Title}` · **Season Folder:** `Season {season:00}`
- **Multi Episode Style:** Prefixed Range (`S01E01-E03`)

Exemplos:
```
Breaking Bad/Season 01/Breaking Bad - S01E05 - Gray Matter [WEBDL-1080p].mkv
One Piece/Season 21/One Piece - S21E1093 - 1093 - <titulo> [WEBDL-1080p].mkv
```

> ⚠️ **Ao adicionar um anime, marque `Series Type: Anime`** (root `/media/animes`).
> É isso que ativa a numeração absoluta; se adicionar como *Standard*, a ordem
> bagunça. Séries normais = `Standard`.

### Radarr — Settings → Media Management
- **Rename Movies:** ✅ *(também vinha desligado)*
- **Standard Movie Format:** `{Movie Title} ({Release Year}) [{Quality Full}]`
- **Movie Folder Format:** `{Movie Title} ({Release Year})`

Exemplo: `Interestelar (2014)/Interestelar (2014) [Bluray-1080p].mkv`

---

## 🇧🇷 Dublado PT-BR sem FlareSolverr (leve, p/ hardware fraco)

Raspar sites BR (Comando/BluDV) via `felipemarinho97/torrent-indexer` exige
**FlareSolverr** (Chrome headless) — **inviável no J1800** (testado: load 13+, Chrome
crasha). A alternativa que **funciona e não pesa**: indexadores públicos agregadores
+ um Custom Format que prioriza releases dublados.

1. **Indexadores (Prowlarr → Add Indexer — públicos, sem FlareSolverr):**
   **Knaben** (meta-search, agrega vários sites), **The Pirate Bay** (tem releases
   `Dual`), **Torrent Downloads**. Depois *Sync App Indexers* p/ Radarr/Sonarr.

2. **Custom Format `PT-BR Dublado`** (Radarr **e** Sonarr → Settings → Custom Formats):
   condição *Release Title* com a regex abaixo.
   ```json
   {
     "name": "PT-BR Dublado",
     "includeCustomFormatWhenRenaming": false,
     "specifications": [
       {
         "name": "PT-BR",
         "implementation": "ReleaseTitleSpecification",
         "negate": false,
         "required": false,
         "fields": [
           { "name": "value", "value": "(?i)\\b(portugu[eê]s|pt[-._ ]?br|dublado|nacional|dual|bludv|comando)\\b" }
         ]
       }
     ]
   }
   ```

3. **Perfil `Dublado PT-BR`** (Settings → Profiles):
   - **Language = Any** ⚠️ (NÃO `Portuguese (Brazil)` — senão o Radarr rejeita o
     release dual/dublado por "idioma não é o desejado").
   - Custom Format **`PT-BR Dublado` → score `10000`**.
   - **Minimum Custom Format Score = `10000`** → só passam releases que casam o CF
     (as pontuações normais do TRaSH não chegam a 10000, então conteúdo só-inglês é
     barrado e só dublado/dual entra).
   - Qualidades só até **1080p** (sem 4K).

> O perfil **`Original + Legenda`** continua com **Language = Original** + legenda
> PT-BR automática do Bazarr. No Jellyseerr, *Advanced → Quality Profile* escolhe
> entre os dois por pedido (padrão = Original + Legenda).

---

## 💬 Legendas PT-BR (Bazarr)

- **Idioma:** perfil **Portuguese (Brazil)** como padrão (filmes + séries).
- **Provider que funciona: OpenSubtitles.com** (conta grátis). Em *Settings →
  Providers → OpenSubtitles.com*:
  - ⚠️ **É o USERNAME, não o e-mail!** O OpenSubtitles.com loga pelo **nome de
    usuário** (ex.: `filippe`). Usuário errado → `AuthenticationError` e **zero
    legendas** — parece "não tem legenda", mas é o **login falhando**.
  - Preencha usuário + senha. (O Bazarr já traz uma api_key embutida; não precisa.)
- **Providers que NÃO funcionam aqui — mantenha DESATIVADOS:** `podnapisi`
  (domínio inacessível, ConnectionError) e `subf2m` (ConfigurationError). Se ficarem
  ligados, entopem a busca com *"All providers are throttled"* (= 0 legendas).
- **Minimum Score:** padrão 90 (séries) / 70 (filmes) — ok.

> 🩺 Diagnóstico: `GET /api/providers` (header `X-API-KEY`) mostra o status real
> (`Good` / `AuthenticationError` / `ConfigurationError`). Para limpar throttle:
> *Settings → Providers* → reset, ou `POST /api/providers?action=reset`.
>
> As legendas baixam **depois do import** do vídeo (não durante o download). Anime
> em lançamento tem bem menos legenda PT-BR que séries/filmes.

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
- **Serviços opcionais desligados:** Portainer e Uptime-Kuma vêm **comentados** por
  padrão. O FlareSolverr está ativo nesta implantação porque é usado pelos
  indexadores que enfrentam Cloudflare; desligue-o apenas se esses indexadores
  forem removidos.
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
