# 🪟🐧 Homelab no PC de casa (Windows 11 + WSL2 + Docker)

Terceira versão deste repo: a stack roda **no PC de jogos**, num Debian dentro do WSL2 com
**Docker Engine nativo** (sem Docker Desktop). O Windows continua sendo o sistema principal,
porque o CS2 com FACEIT não roda em Linux nem em máquina virtual.

> **Arquivos:** [`docker-compose.wsl.yml`](docker-compose.wsl.yml) + [`.env.wsl.example`](.env.wsl.example).
> O painel (status, links, modo jogo, CPU/GPU/discos) é a aba **Lab** da
> [Casa Local](https://github.com/bronze-ff/casa-local). Por isso o Homarr fica desligado aqui (perfil `extras`).

| | |
|---|---|
| Hardware | Ryzen 5 5600G · 16 GB · RTX 5060 8 GB |
| Distro | WSL `homelab` (Debian 13) em `E:\WSL\homelab` (SSD) |
| Configs | `~/homelab-config/<app>` (ext4 dentro do disco do WSL: sem `database is locked`) |
| Mídia | `D:\Homelab\media` → `/media` (HD 1 TB; `filmes/ series/ animes/ torrents/`, hardlink ok) |
| Rede | WSL em modo **mirrored**: as portas aparecem no Windows, na LAN e no Tailscale |
| Transcode | NVENC na RTX 5060 (NVIDIA Container Toolkit no WSL) |

## Serviços

| Serviço | Porta | Pelo Tailscale |
|---|---|---|
| Jellyfin | 8096 | `https://<host>.ts.net:10000` |
| Jellyseerr | 5055 | `http://<host>:5055` |
| **openGym** (treinos) | 8090 | `https://<host>.ts.net:8443` (passkeys exigem HTTPS) |
| qBittorrent | 8080 | |
| Radarr / Sonarr / Prowlarr / Bazarr | 7878 / 8989 / 9696 / 6767 | |
| Filebrowser | 8081 | |
| FlareSolverr | só interno (`http://flaresolverr:8191`) | |

### Avisos, monitoramento e câmeras (fase 1–2)

| Serviço | Onde | Para quê |
|---|---|---|
| **ntfy** | `https://<host>.ts.net:10000` | Push no iPhone (tópicos `casa-pessoas`, `casa-cameras`, `casa-sistema`, `casa-casa`) |
| **Uptime Kuma** | `http://<host>:3001` | Painel, câmeras, DVR, internet, ntfy, Vaultwarden e openGym; avisa no `casa-sistema` |
| **Frigate** | `https://<host>:8971` (login) | Pessoas, carros e rostos em 4 câmeras, na RTX |
| **Vaultwarden** | `https://<host>.ts.net/vault` | Senhas (app Bitwarden) |
| **Dozzle** | `http://<host>:8888` | Logs dos containers |
| Diun, Unpackerr | — | Aviso de atualização; extrair .rar |
| AdGuard Home | desligado | A porta 53 do Windows já é de um serviço do sistema (svchost) |

O Jellyfin passou para `https://<host>.ts.net/jellyfin` (BaseUrl `/jellyfin`) para liberar a porta 10000 ao ntfy.

**Modo jogo:** param só os pesados (mídia, downloads, Frigate); ntfy, Uptime Kuma, Vaultwarden,
Diun, Dozzle e openGym continuam. **Frigate** liga só com você fora de casa (localização na Casa
Local), ou sempre/nunca pela aba Lab.

**Frigate, notas do que deu certo:**
- Imagem `0.18.2-tensorrt`, detector `onnx` com YOLOv9-s 320 gerado pelo comando oficial da
  documentação (`~/homelab-config/frigate/model_cache/yolo.onnx`): ~10 ms por quadro na RTX.
- Lê o RTSP **direto do DVR** (`FRIGATE_DVR_USER/PASS/HOST` no `.env`). Pelo go2rtc do Windows o
  vídeo trava na rede espelhada do WSL (o handshake passa, o RTP não).
- Só 4 câmeras (portão na principal para rostos, garagem, entrada e rua no substream). Com 12 o DVR
  derrubava conexões e a CPU ia a 700%. Com 4: ~0,5 núcleo, ~2 GB de RAM e ~25% da GPU.
- O go2rtc interno do Frigate muda para 1985/8556/8557 (1984/8554 são do go2rtc da Casa Local).
- Senhas geradas (qBittorrent, Uptime Kuma, Frigate, admin do Vaultwarden) ficam só no `.env` do PC.

**Memória:** teto do WSL em **6 GB** e 6 processadores (`.wslconfig`). Com 8 GB, o Frigate e o cache
de imagens/builds deixaram o Windows com 2 GB livres e o PC travando.

## Instalação (o que foi feito, em ordem)

```powershell
# 1. Recursos do Windows (admin) e reinício
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# 2. WSL (MSI assinado da Microsoft: github.com/microsoft/WSL/releases) e a distro no SSD E:
wsl --install -d Debian --name homelab --location E:\WSL\homelab --no-launch --web-download
```

`%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
memory=6GB
swap=4GB
processors=6
vmIdleTimeout=-1

[experimental]
autoMemoryReclaim=dropCache
sparseVhd=true
hostAddressLoopback=true
```

```powershell
# Entrada liberada para a VM do WSL (senão a LAN/Tailscale não alcança os containers)
Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
```

Dentro do Debian (root): usuário `filippe` (1000), `/etc/wsl.conf` com `systemd=true`, Docker Engine
e `docker-compose-plugin` do repositório oficial, `nvidia-container-toolkit` +
`nvidia-ctk runtime configure --runtime=docker`, logs do Docker limitados (`log-driver: local`, 10 MB × 3) e:

```bash
# /etc/sysctl.d/99-wsl-loopback.conf — o Windows (Tailscale Serve, Casa Local) chega nos
# containers por 127.0.0.1; sem isso o kernel descarta o tráfego do loopback espelhado.
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.default.route_localnet=1
```

Subir:

```bash
git clone https://github.com/bronze-ff/Homelab.git ~/homelab && cd ~/homelab
cp .env.wsl.example .env   # gere o HOMARR_SECRET; ajuste o host do openGym
docker compose up -d
```

## Manter ligado e modo jogo

- **Sem cliente, o WSL desliga a distro** (e os containers caem). A tarefa agendada
  `CasaLocal-homelab` (no login, sem janela) roda
  `conhost --headless wsl -d homelab --exec /bin/sleep infinity` e a mantém de pé.
- **Modo jogo** (aba Lab, menu da bandeja, ou sozinho ao abrir `cs2.exe`):
  `docker compose stop` → para a tarefa → `wsl --shutdown` (devolve toda a RAM do WSL).
  Ao sair: roda a tarefa e `docker compose up -d`. Entrar leva ~20 s e sair ~15 s.

## Tailscale Serve (HTTPS)

```powershell
tailscale serve --bg --https=8443 http://127.0.0.1:8090   # openGym
tailscale serve --bg --https=10000 http://127.0.0.1:8096  # Jellyfin
```

O `/` (443) continua sendo a Casa Local. O Serve só aceita HTTPS nas portas 443, 8443 e 10000.

## Ligação entre os serviços (feita pelas APIs)

- **qBittorrent:** senha própria (no `.env` deste PC), sem seed (ratio/tempo 0 → parar), 1 download por vez,
  200 conexões, DHT/PeX/LSD, trackers do `ngosang/trackerslist`, categorias `radarr`, `sonarr` e `anime`.
- **Radarr/Sonarr:** pastas `/media/filmes`, `/media/series` e `/media/animes`, qBittorrent com "remover
  concluídos", hardlinks e Propers "Do not Prefer". Perfis TRaSH pelo Configarr + **Dublado PT-BR** (CF score 10000).
- **Prowlarr:** FlareSolverr (tag `flaresolverr`), Knaben, The Pirate Bay, YTS, Torrent Downloads,
  Nyaa.si, Tokyo Toshokan, SubsPlease e 1337x, sincronizados com Radarr/Sonarr. DNS público
  (`1.1.1.1`) no Prowlarr e FlareSolverr: o DNS do provedor bloqueia alguns indexadores.
- **Bazarr:** Sonarr/Radarr conectados e perfil padrão Português (Brasil) → Português.

## Falta fazer à mão (pede conta/senha sua)

1. **Jellyfin:** assistente do 1º acesso (criar o admin) e bibliotecas `/media/filmes`, `/media/series`,
   `/media/animes`. Em *Dashboard → Playback → Transcoding*: **NVIDIA NVENC**.
2. **Jellyseerr:** entrar com a conta do Jellyfin e apontar para Radarr/Sonarr.
3. **Radarr/Sonarr/Prowlarr/Bazarr:** na 1ª visita pedem para criar o login (Forms).
4. **Bazarr:** provedor **OpenSubtitles.com** (usuário, não e-mail).
5. **openGym:** criar o 1º perfil com passkey em `https://<host>.ts.net:8443` — o primeiro vira admin.
   Depois, se quiser, `OPENGYM_INVITE_ONLY=1` no `.env`.
6. **Filebrowser:** senha inicial do admin no log (`docker compose logs filebrowser`); troque no 1º acesso.

## Comandos

```bash
docker compose ps
docker compose logs -f sonarr
docker compose pull && docker compose up -d           # atualizar
docker compose run --rm configarr                     # re-sincroniza perfis
```
