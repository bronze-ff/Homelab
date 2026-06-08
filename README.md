# 🏠 Homelab de Mídia (Docker)

Stack completa de download e streaming automatizado, orquestrada por Docker
Compose, rodando em **Windows 11 + Docker Desktop (backend WSL2)**.

Fluxo: você **pede** um filme/série → o sistema **encontra** nos indexadores →
**baixa** via torrent → **organiza** na biblioteca → **legenda em PT-BR** →
fica disponível para **assistir** no Jellyfin. Tudo acessível de fora via
**Tailscale** e centralizado no **dashboard Homarr**.

---

## 📦 Serviços

| Serviço | URL local | Função |
|---|---|---|
| **Homarr** (dashboard) | http://localhost:7575 | Painel central de tudo |
| **Jellyfin** | http://localhost:8096 | Servidor de streaming |
| **Jellyseerr** | http://localhost:5055 | Pedidos de filmes/séries |
| **Radarr** | http://localhost:7878 | Gerencia filmes |
| **Sonarr** | http://localhost:8989 | Gerencia séries **e anime** |
| **Prowlarr** | http://localhost:9696 | Indexadores (busca) |
| **Bazarr** | http://localhost:6767 | Legendas PT-BR |
| **qBittorrent** | http://localhost:8080 | Cliente de download |
| **Flaresolverr** | http://localhost:8191 | Bypass Cloudflare |
| **Portainer** | http://localhost:9000 | Gerência dos containers |
| Watchtower | — | Auto-update (3h da manhã) |
| Recyclarr | — | Perfis de qualidade (TRaSH) |

---

## 🔄 Reconstruir após formatar a máquina (resumo)

Este repositório é a "fonte da verdade" do homelab. Depois de formatar:

```powershell
# 1. Instale os pré-requisitos (seção 1): WSL2, Docker Desktop, Tailscale, Git.
# 2. Clone o repositório (privado):
git clone git@github.com:bronze-ff/Homelab.git
cd Homelab

# 3. O .env já vem versionado (repo privado). Confira os caminhos/segredos.
#    Se preferir partir do zero:  Copy-Item .env.example .env  e edite.

# 4. Crie as pastas de mídia (seção 1d) e suba tudo:
docker compose up -d

# 5. Sincronize os perfis de qualidade (Custom Formats TRaSH + Anime):
#    edite as API keys em config/recyclarr/recyclarr.yml e rode:
docker compose run --rm recyclarr sync
```

> ⚠️ O appdata em `config/` **não** é versionado (pesado e recriado sozinho).
> Por isso as **API keys mudam** num rebuild do zero: siga a configuração
> pós-deploy (seção 4) para reconectar os apps. Os perfis de qualidade voltam
> via Recyclarr; os indexadores você re-adiciona no Prowlarr (incluindo anime).

---

## 1️⃣ Pré-requisitos (instalar uma vez)

> Estes passos exigem **PowerShell como Administrador** e **reinicializações**.

### a) WSL2
```powershell
wsl --install
```
Reinicie o PC quando pedir. Isso instala o WSL2 + uma distro Ubuntu.

### b) Docker Desktop
1. Baixe em https://www.docker.com/products/docker-desktop/
2. Instale marcando **"Use WSL 2 instead of Hyper-V"**.
3. Abra o Docker Desktop → Settings → **General**: confirme *Use the WSL 2 based engine*.
4. Settings → **Resources → WSL Integration**: habilite a integração.
5. Deixe o Docker Desktop **iniciar junto com o Windows** (Settings → General).

### c) Tailscale (acesso remoto)
1. Baixe em https://tailscale.com/download/windows
2. Instale e faça login (Google/Microsoft/GitHub).
3. Anote a IP da máquina (algo como `100.x.x.x`) — é por ela que você acessa
   de fora: `http://100.x.x.x:7575`.

### d) Git (para clonar este repositório)
Baixe em https://git-scm.com/download/win e instale (aceitando os padrões).
Para clonar via SSH (`git@github.com:...`), gere uma chave e adicione no GitHub:
```powershell
ssh-keygen -t ed25519 -C "seu-email"
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub   # cole em GitHub → Settings → SSH keys
```
> Sem configurar SSH, use a URL HTTPS: `git clone https://github.com/bronze-ff/Homelab.git`.

### e) Pasta de mídia
Crie a estrutura no drive **D:** (o `docker compose up` também cria, mas é bom garantir):
```powershell
mkdir D:\Media\data\torrents\movies
mkdir D:\Media\data\torrents\tv
mkdir D:\Media\data\torrents\anime
mkdir D:\Media\data\media\movies
mkdir D:\Media\data\media\tv
mkdir D:\Media\data\media\anime
```
> ⚠️ Se quiser usar outro drive/pasta, edite `MEDIA_PATH` no arquivo `.env`.

---

## 2️⃣ Configurar o `.env`

Abra o arquivo [`.env`](.env) e ajuste:

- `TZ` — já está `America/Sao_Paulo`.
- `HOMARR_SECRET` — gere um hex de 64 caracteres. No PowerShell:
  ```powershell
  -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
  ```
  Copie o resultado e cole no valor de `HOMARR_SECRET`.

---

## 3️⃣ Subir tudo

Dentro da pasta do projeto:
```powershell
docker compose up -d
```
Acompanhe:
```powershell
docker compose ps          # status
docker compose logs -f     # logs ao vivo (Ctrl+C p/ sair)
```
Todos devem aparecer como **running**. Pronto — agora é a configuração de cada um.

---

## 4️⃣ Configuração pós-deploy (na ordem)

### 4.1 qBittorrent — http://localhost:8080
1. A senha temporária do admin aparece no log:
   ```powershell
   docker compose logs qbittorrent | Select-String "password"
   ```
   Usuário: `admin`. Faça login e **troque a senha** em *Tools → Options → Web UI*.
2. *Options → Downloads → Default Save Path*: `/data/torrents`
3. Crie as **categorias** (botão direito na aba Categories, ou serão criadas pelo
   Radarr/Sonarr automaticamente):
   - `radarr` → `/data/torrents/movies`
   - `sonarr` → `/data/torrents/tv`

### 4.2 Prowlarr — http://localhost:9696
1. Crie usuário/senha na primeira tela (*Authentication*).
2. **Flaresolverr**: *Settings → Indexers → Add Proxy* → tipo **FlareSolverr**,
   Host: `http://flaresolverr:8191`, Tag: `flaresolverr`.
3. **Adicionar indexadores** (*Indexers → Add Indexer*):
   - Gerais (público): **1337x**, **The Pirate Bay**, **TorrentGalaxy**, **YTS**.
   - **Brasileiros / dublado / dual áudio**: procure por **Comando Torrents**,
     **BluDV**, **Lapumia**, **Comando.la** e similares. Marque a tag
     `flaresolverr` nos que usam Cloudflare.
   - **🍥 Anime (público)** — já adicionados neste homelab:
     - **Nyaa.si** — o maior tracker de anime (sub/dual/raw). Essencial.
     - **Tokyo Toshokan** — feed de anime/dorama, ótimo p/ automação no Sonarr.
     - **SubsPlease** — releases semanais legendados.
     - Opcionais: **Anidex** (estava em 502 na configuração — re-adicione quando
       o site voltar) e **AnimeBytes** *(privado, exige conta)*.
     > ⚠️ O **AnimeTosho.org** público não consta nas definições atuais do
     > Prowlarr; só existe o `animetosho-xyz`, que **exige API key** (conta).
     > Estes indexadores **não** precisam de Flaresolverr.
   - Em cada indexador clique em **Test** antes de salvar.
4. **Conectar ao Radarr e Sonarr** (*Settings → Apps → Add*):
   - Radarr: Server `http://radarr:7878`, API key do Radarr (passo 4.3).
   - Sonarr: Server `http://sonarr:8989`, API key do Sonarr.
   - Prowlarr → *Sync App Indexers* envia todos os indexadores automaticamente.

> 💡 As **API keys** ficam em *Settings → General* de cada app.

### 4.3 Radarr (filmes) — http://localhost:7878 / Sonarr (séries) — http://localhost:8989
Para cada um dos dois:
1. Crie usuário/senha.
2. **Media Management → Root Folders → Add**:
   - Radarr: `/data/media/movies`
   - Sonarr: `/data/media/tv`
3. **Media Management**: ative **Use Hardlinks** (evita cópia, importa instantâneo).
4. **Download Clients → Add → qBittorrent**:
   - Host: `qbittorrent`, Port: `8080`, usuário/senha do qBittorrent.
   - Category: `radarr` (no Radarr) / `sonarr` (no Sonarr).

#### 🎬 Os perfis "Dublado" vs "Original" (o que você pediu)
A escolha é feita por **Quality Profile** na hora de adicionar o título.

**Opção A — automática (recomendada), via Recyclarr:**
1. Edite [`config/recyclarr/recyclarr.yml`](config/recyclarr/recyclarr.yml) e cole
   as API keys do Radarr e Sonarr.
2. Rode:
   ```powershell
   docker compose run --rm recyclarr sync
   ```
   Isso importa os Custom Formats (incluindo **Brazilian Portuguese** e **Multi
   Audio**) e cria os perfis-base.
3. Em *Settings → Profiles*, **duplique** o perfil gerado e configure os dois:
   - **`Dublado PT-BR`** → em *Language* escolha **Portuguese (Brazil)**; mantenha
     os scores altos para os formatos PT-BR/Multi.
   - **`Original + Legenda`** → *Language* = **Original** (ou English); zere os
     scores de áudio PT (a legenda virá do Bazarr).

**Opção B — manual (sem Recyclarr):**
- *Settings → Profiles → Add* dois perfis, definindo o campo **Language** como
  *Portuguese (Brazil)* num e *Original* no outro.

➡️ **No dia a dia:** ao adicionar um filme/série (ou aprovar no Jellyseerr), você
escolhe o **Quality Profile** → é assim que decide, caso a caso, dublado ou original.

### 4.3.1 🍥 Anime (no mesmo Sonarr)
Anime usa **numeração absoluta** (ep. 1..1000+, sem temporadas), por isso o
Sonarr tem um tipo de série dedicado. Você **não precisa de outro container** —
é o mesmo Sonarr de séries.

1. **Root folder de anime** — *Sonarr → Settings → Media Management → Root
   Folders → Add* → `/data/media/anime`.
2. **Categoria de download** — no qBittorrent (ou deixe o Sonarr criar) uma
   categoria `sonarr-anime` apontando para `/data/torrents/anime`. No Sonarr,
   *Settings → Download Clients → qBittorrent* → campo **Category**: você pode
   usar a mesma `sonarr` ou separar com `anime` (opcional).
3. **Perfil de qualidade** — se rodou o Recyclarr (passo 4.3), já existe o perfil
   **`Remux-1080p - Anime`** (com formatos de dual-áudio e fansub). Senão, crie um
   Quality Profile simples e, em *Settings → Profiles*, ajuste o idioma.
4. **Ao adicionar um anime** (*Series → Add New*):
   - **Series Type: `Anime`**  ← passo mais importante (ativa numeração absoluta).
   - **Root Folder:** `/data/media/anime`.
   - **Quality Profile:** `Remux-1080p - Anime` (ou o que você criou).
5. **Release Profile (já criado neste homelab)** — *Settings → Profiles → Release
   Profiles*: existe o perfil **"Bloquear audio dublado (manter original)"**, que
   em **Must Not Contain** bloqueia áudio dublado (`FRENCH`, `VF`, `GERMAN`, `ITA`,
   `SPANISH`, grupo `Tsundere-Raws`). Mantém VOSTFR/SUBFRENCH (áudio japonês
   original + legenda). Edite os termos se quiser ajustar.
6. **Indexadores**: garanta que **Nyaa.si** e **AnimeTosho** estão no Prowlarr
   (passo 4.2) e foram sincronizados (*Sync App Indexers*).

> 💡 No Jellyseerr, ao pedir um anime, escolha o Sonarr e a Root Folder
> `/data/media/anime`. Veja a biblioteca de anime no Jellyfin no passo 4.5.

### 4.4 Bazarr — http://localhost:6767
1. *Settings → Sonarr*: Address `sonarr`, Port `8989`, API key → Test → Save.
2. *Settings → Radarr*: Address `radarr`, Port `7878`, API key → Test → Save.
3. *Settings → Languages*: crie um **Languages Profile** com **Portuguese (Brazil)**
   (e *Portuguese* como segunda opção/fallback). Marque como padrão.
4. *Settings → Providers*: adicione **OpenSubtitles.com**, **Subdl**, **Podnapisi**,
   **Gestdown** etc. (alguns pedem conta gratuita).
5. *Settings → Subtitles*: ative *Automatic Subtitles Download* e *Use embedded subs*.

### 4.5 Jellyfin — http://localhost:8096
1. Assistente inicial: crie o usuário admin, idioma **Português (Brasil)**.
2. **Add Media Library**:
   - Tipo **Movies** → pasta `/data/media/movies`
   - Tipo **Shows** → pasta `/data/media/tv`
   - Tipo **Shows** (nome "Anime") → pasta `/data/media/anime`. Em *Metadata
     downloaders*, suba **AniDB**/**TheTVDB** para títulos de anime corretos.
   - Idioma preferido de metadados: **Português (BR)**.
3. (Opcional) *Dashboard → Playback*: transcode por hardware. No WSL2 isso é
   limitado — veja a seção **Transcode** mais abaixo. Comece com software.

### 4.6 Jellyseerr — http://localhost:5055
1. Faça login com a conta do **Jellyfin** (Sign in with Jellyfin) → Server URL
   `http://jellyfin:8096`.
2. *Settings → Services*:
   - **Radarr**: `http://radarr:7878` + API key; escolha a Root Folder e o
     **Quality Profile padrão** (ex.: `Original + Legenda`).
   - **Sonarr**: `http://sonarr:8989` + API key + Root Folder + Quality Profile.
3. Dica: você pode habilitar a opção de o usuário **escolher o perfil** ao pedir,
   ou criar perfis avançados mapeando "Dublado" e "Original".

### 4.7 Homarr (dashboard) — http://localhost:7575
1. Crie o usuário admin na primeira tela.
2. *Edit mode* → **Add tile / Add app** para cada serviço (use as URLs da tabela
   acima; com Tailscale, use a IP `100.x.x.x`).
3. Para os widgets de status (fila de download, etc.), em cada tile adicione a
   **integração** correspondente com a API key do app.
4. Defina o Homarr como sua **página inicial** do homelab.

---

## 5️⃣ Verificação (teste ponta a ponta)

1. `docker compose ps` → todos **running**.
2. Prowlarr → *Test All Indexers* passa; *Sync App Indexers* preenche Radarr/Sonarr.
3. **Dublado:** adicione um filme no Radarr com perfil **`Dublado PT-BR`** → ele
   pega release com áudio PT/dual, baixa no qBittorrent e importa (hardlink) em
   `D:\Media\data\media\movies`.
4. **Original:** adicione outro com **`Original + Legenda`** → Bazarr baixa a
   legenda PT-BR automaticamente.
5. O título aparece no **Jellyfin** e roda com legenda PT-BR.
6. **Anime:** adicione um anime no Sonarr com **Series Type: Anime**, Root Folder
   `/data/media/anime` → ele busca no **Nyaa/AnimeTosho**, baixa e importa em
   `D:\Media\data\media\anime`, aparecendo na biblioteca **Anime** do Jellyfin.
7. Faça um pedido no **Jellyseerr** e veja cair no Radarr/Sonarr.
7. Acesse `http://100.x.x.x:7575` (IP do Tailscale) de outro dispositivo.

---

## 🔧 Comandos úteis

```powershell
docker compose up -d            # sobe tudo
docker compose down             # para tudo (mantém dados em config/)
docker compose pull             # baixa versões novas das imagens
docker compose restart radarr   # reinicia um serviço
docker compose logs -f sonarr   # logs de um serviço
docker compose run --rm recyclarr sync   # ressincroniza perfis TRaSH
```

---

## 🎞️ Transcode por hardware no Jellyfin (opcional, avançado)

No Docker Desktop/WSL2 a aceleração por GPU **não é automática**:
- **NVIDIA**: instale o driver Windows + NVIDIA Container Toolkit no WSL2 e adicione
  `deploy.resources` com `gpu` ao serviço `jellyfin`. (Requer WSL2 atualizado.)
- **Intel QSV / iGPU**: passagem de `/dev/dri` não é exposta de forma confiável pelo
  WSL2; geralmente fica em **software**.

➡️ Para transcode de hardware sério, o ideal é rodar este mesmo `docker-compose.yml`
num **servidor Linux** (passa `/dev/dri` direto). Por enquanto, software dá conta de
streams 1080p tranquilamente em CPU moderna.

---

## 🔐 Backup do Vaultwarden (senhas)

O serviço `vaultwarden-backup` faz, **todo dia às 04:00**, um dump consistente do
cofre (`db.sqlite3` + chaves) e compacta com **senha (7-Zip AES-256, nomes ocultos)**
na pasta **`D:\Backups\vaultwarden`**. A cópia **na nuvem** é feita pelo app
**Google Drive para Desktop** sincronizando essa pasta.

> 💡 **Por que não escrever direto no Google Drive (G:)?** O Docker Desktop não
> consegue escrever no disco virtual G: (testado — vira um mount fantasma). Então o
> container grava no D: (disco real) e o app do Google sobe pra nuvem. Bônus: não
> precisa de login/OAuth nenhum.

> 🔑 **Duas camadas de segurança:** o cofre já é criptografado com a sua
> **senha-mestra** (o servidor nunca a conhece) e o arquivo de backup ganha uma
> **segunda senha** (`VAULTWARDEN_BACKUP_PASSWORD` no `.env`). Mesmo que invadam o
> Google Drive, pegam um arquivo embaralhado duas vezes.
>
> ⚠️ **Nunca esqueça a senha-mestra** — sem ela, nem o backup recupera as senhas.
> Anote-a num papel guardado em local físico seguro.

### Passo único: sincronizar a pasta no Google Drive para Desktop
1. Instale o **Google Drive para Desktop** e faça login (já feito — disco **G:**).
2. Clique no ícone do Google Drive (bandeja) → ⚙️ **Preferências** → **Meu computador**
   → **Adicionar pasta** → escolha **`D:\Backups\vaultwarden`** → opção
   **"Sincronizar com o Google Drive"** → **Salvar**.
3. Pronto: tudo que o container gravar no D: sobe automaticamente pra nuvem.

> O remote `dlocal` (rclone tipo *local*) já está criado — **nenhum OAuth é
> necessário**. No rebuild, recrie-o com:
> `docker compose run --rm vaultwarden-backup rclone config create dlocal local`

### Testar agora
```powershell
docker compose run --rm vaultwarden-backup backup   # roda um backup na hora
```
Confira o `.7z` em `D:\Backups\vaultwarden` (e, alguns segundos depois, na pasta
**Backups\vaultwarden** do seu Google Drive na web). Para conferir a criptografia:
`7z l D:\Backups\vaultwarden\backup.AAAAMMDD.7z` deve **pedir senha**.

### Restaurar (se precisar)
```powershell
# lista as opções de restauração
docker compose run --rm vaultwarden-backup restore --help
```
Pare o Vaultwarden, restaure o `.7z` (ele pede a `VAULTWARDEN_BACKUP_PASSWORD`) para
`config/vaultwarden`, e suba de novo. Detalhes: https://github.com/ttionya/vaultwarden-backup

---

## ➕ Serviços extras (já no compose, comentados)

Descomente no `docker-compose.yml` se quiser:
- **Unpackerr** — extrai `.rar` automaticamente antes do import.
- **Lidarr** — música (porta 8686).
- **Readarr** — livros/audiobooks (porta 8787).

---

## ⚠️ Avisos

- **Você é responsável** pelo conteúdo que baixa. Verifique a legalidade na sua região.
- Sem VPN, seu **IP fica visível** nos torrents (decisão sua). Se mudar de ideia, dá
  para adicionar um container **Gluetun** e rotear o qBittorrent por ele.
- **Indexadores privados** podem exigir cadastro/convite — não há como automatizar
  sem suas credenciais.
- Nunca exponha as portas direto na internet (port-forward). Use **Tailscale**.
