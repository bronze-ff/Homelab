# 🔐 Guia de Acesso e Passos Manuais — Homelab

> Gerado após a configuração automática. Tudo que está em **"Configurado
> automaticamente"** já funciona. As seções **"PASSO MANUAL"** dependem de você
> (criar conta/senha ou ter login de terceiros).

---

## 🌐 Endereços de acesso

| Serviço | Local (neste PC) | Remoto (Tailscale) |
|---|---|---|
| **Homarr** (dashboard) | http://localhost:7575 | http://100.124.35.68:7575 |
| **Jellyfin** (streaming) | http://localhost:8096 | http://100.124.35.68:8096 |
| **Jellyseerr** (pedidos) | http://localhost:5055 | http://100.124.35.68:5055 |
| **Radarr** (filmes) | http://localhost:7878 | http://100.124.35.68:7878 |
| **Sonarr** (séries) | http://localhost:8989 | http://100.124.35.68:8989 |
| **Prowlarr** (indexadores) | http://localhost:9696 | http://100.124.35.68:9696 |
| **Bazarr** (legendas) | http://localhost:6767 | http://100.124.35.68:6767 |
| **qBittorrent** (download) | http://localhost:8080 | http://100.124.35.68:8080 |
| **Portainer** (containers) | http://localhost:9000 | http://100.124.35.68:9000 |
| **Flaresolverr** | http://localhost:8191 | (uso interno) |

> IP do Tailscale deste PC: **100.124.35.68** (acesse de qualquer dispositivo
> logado na sua conta Tailscale).

---

## 🔑 Credenciais e chaves

### Logins
| Serviço | Usuário | Senha |
|---|---|---|
| **qBittorrent** | `admin` | `***REMOVED***` |
| Jellyfin | *(você cria no 1º acesso)* | *(você define)* |
| Jellyseerr | *(login do Jellyfin)* | — |
| Homarr | *(você cria no 1º acesso)* | — |
| Radarr / Sonarr / Prowlarr / Bazarr | *(sem login — rede local)* | — |

### API Keys (necessárias nos formulários de conexão)
| Serviço | API Key |
|---|---|
| **Radarr** | `***REMOVED***` |
| **Sonarr** | `***REMOVED***` |
| **Prowlarr** | `***REMOVED***` |
| **Bazarr** | `***REMOVED***` |

> Onde achar de novo: em cada app → **Settings → General → API Key**.

### URLs internas (use nos formulários "conectar serviço a serviço")
Dentro da rede Docker os serviços se enxergam pelo **nome**, não por localhost:
- Radarr → `http://radarr:7878`
- Sonarr → `http://sonarr:8989`
- Jellyfin → `http://jellyfin:8096`
- Prowlarr → `http://prowlarr:9696`

---

## ✅ Já configurado automaticamente (não precisa mexer)
- qBittorrent: senha, pasta de download, categorias `radarr`/`sonarr`
- Prowlarr: Flaresolverr + apps (Radarr/Sonarr) + indexadores públicos, incluindo
  os de **anime** (Nyaa.si, Tokyo Toshokan, SubsPlease)
- Radarr/Sonarr: root folder, download client, e os perfis **Dublado PT-BR** e **Original + Legenda**
- Bazarr: conectado ao Radarr/Sonarr, PT-BR habilitado, perfil de idioma padrão

---

# 🛠️ PASSOS MANUAIS (faça nesta ordem)

## PASSO 1 — Jellyfin (≈3 min)  → http://localhost:8096
1. Escolha o idioma **Português (Brasil)** e avance.
2. **Crie sua conta admin** (usuário + senha — anote!).
3. Na tela "Configurar bibliotecas de mídia", clique **Adicionar Biblioteca**:
   - Tipo **Filmes** → pasta `/data/media/movies`
   - Tipo **Programas de TV** (séries) → pasta `/data/media/tv`
   - Em "Idioma preferido de metadados": **Português (Brasil)**.
4. Finalize o assistente.

## PASSO 2 — Jellyseerr (≈2 min)  → http://localhost:5055
1. Em "Sign in", escolha **Jellyfin**.
2. **Jellyfin URL:** `http://jellyfin:8096` — entre com o usuário/senha do Passo 1.
3. *Settings → Services → Radarr → Add Radarr Server*:
   - Hostname/URL: `http://radarr:7878`
   - API Key: `***REMOVED***`
   - Root Folder: `/data/media/movies`
   - Quality Profile padrão: **Original + Legenda** (ou Dublado PT-BR)
   - Salve (Test deve ficar verde).
4. *Settings → Services → Sonarr → Add Sonarr Server*:
   - URL: `http://sonarr:8989`
   - API Key: `***REMOVED***`
   - Root Folder: `/data/media/tv`
   - Quality Profile padrão à sua escolha.

> 💡 Dica: para poder escolher **Dublado x Original** em cada pedido, você pode
> cadastrar o Radarr/Sonarr duas vezes (um "perfil" por servidor) ou trocar o
> Quality Profile na hora de aprovar o pedido.

## PASSO 3 — Homarr / Dashboard (≈5 min)  → http://localhost:7575
1. **Crie sua conta admin** (usuário + senha).
2. Entre no **modo de edição** (ícone de lápis) → **Add → App** para cada serviço,
   usando as URLs da tabela "Endereços de acesso" (use as do Tailscale se for
   acessar de fora).
3. (Opcional) Em cada tile, adicione a **integração** com a API Key para ver
   status (fila de download, etc.).
4. Defina o Homarr como página inicial do seu navegador, se quiser.

---

# ➕ OPCIONAIS (melhoram o resultado, mas não são obrigatórios)

## A) Legendas: conta OpenSubtitles.com (recomendado) → Bazarr
- Crie conta grátis em https://www.opensubtitles.com
- Bazarr → *Settings → Providers → OpenSubtitles.com* → preencha usuário/senha → Save.
- Rende muito mais legendas PT-BR do que só os provedores sem conta.

## B) Indexadores brasileiros privados → Prowlarr
- Os melhores trackers BR (BrasilTracker, BJ-Share, Amigos Share, etc.) são
  **privados** e exigem **conta/convite seu**.
- Prowlarr → *Indexers → Add Indexer* → procure o tracker → informe suas credenciais.

## 🍥 B2) Anime → Prowlarr + Sonarr
- ✅ **Já configurado:** indexadores **Nyaa.si**, **Tokyo Toshokan** e
  **SubsPlease** no Prowlarr, sincronizados para o Sonarr.
- ✅ **Root folder `/data/media/anime`** criado no Sonarr; os animes já existentes
  foram movidos para lá (separados das séries normais).
- ✅ **Release Profile "Bloquear audio dublado (manter original)"** ativo no
  Sonarr: ignora releases de **áudio** dublado (FRENCH/VF/GERMAN/ITA/SPANISH e o
  grupo Tsundere-Raws). Mantém VOSTFR/SUBFRENCH (áudio japonês original + legenda).
- ⏳ **Falta (manual):** criar a biblioteca **Anime** no Jellyfin apontando para
  `/data/media/anime` (tipo Shows). Ver README seção 4.5.
- Opcional: **Anidex** (estava em 502 na hora — re-adicione quando o site voltar).
  O **AnimeTosho.org** público não está nas definições do Prowlarr (só o
  `animetosho-xyz`, que exige API key/conta).
- **Sonarr** → *Settings → Media Management → Root Folders → Add* →
  `/data/media/anime`. Ao adicionar um anime, marque **Series Type: Anime**.
- **Jellyfin** → *Add Media Library* tipo **Shows** com nome "Anime" apontando
  para `/data/media/anime` (metadados via AniDB/TheTVDB).
- Passo a passo completo: ver **README.md → seção 4.3.1 🍥 Anime**.

## C) Trocar a senha do qBittorrent (recomendado)
- qBittorrent → *Tools → Options → Web UI* → defina uma senha sua.
- ⚠️ Se trocar, atualize também em **Radarr e Sonarr** → *Settings → Download
  Clients → qBittorrent* (senha nova).

## D) Desbloquear o 1337x (opcional)
- O domínio `1337x.to` não resolve no seu PC (provável bloqueio do provedor).
- Para tentar: Docker Desktop → *Settings → Docker Engine* → adicione
  `"dns": ["1.1.1.1", "8.8.8.8"]` ao JSON → Apply & Restart. Depois re-teste o
  indexador no Prowlarr. (O The Pirate Bay já funciona sem isso.)

---

# 🧪 Como testar o fluxo completo
1. No **Jellyseerr** (ou direto no Radarr), peça um filme escolhendo o perfil
   **Dublado PT-BR**.
2. Veja o download aparecer no **qBittorrent** (`:8080`).
3. Ao concluir, o Radarr importa para `D:\Media\data\media\movies` (hardlink).
4. O **Bazarr** baixa a legenda PT-BR automaticamente.
5. O filme aparece no **Jellyfin** (`:8096`) pronto para assistir.

# 🔁 Comandos úteis (PowerShell, na pasta do projeto)
```powershell
docker compose ps                 # status de tudo
docker compose restart <serviço>  # reinicia um serviço
docker compose logs -f <serviço>  # ver logs
docker compose down               # parar tudo (dados preservados)
docker compose up -d              # subir tudo
```
