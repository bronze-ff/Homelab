#!/usr/bin/env bash
# Backup noturno do home lab (timer homelab-backup, 04:30): configs dos serviços + .env + compose
# num .tar.gz no HD (D:\Homelab\backups), guardando os 7 mais novos. Fica de fora o que se refaz
# sozinho: caches, metadados e imagens do Jellyfin, transcodes, logs, capas e snapshots do Frigate.
# Também copia os backups diários da Casa Local (.data) para o mesmo HD.
# O .env tem senhas: o arquivo fica só no HD local deste PC; não envie para nuvem sem cifrar.
set -euo pipefail
CONFIG="${CONFIG_PATH:-$HOME/homelab-config}"
STACK="${STACK:-$HOME/homelab}"
DEST="${BACKUP_DEST:-/mnt/d/Homelab/backups}"
CASA="${CASA_BACKUPS:-/mnt/c/Users/adm/AppData/Local/CasaLocal/backups}"
KEEP=7
stamp=$(date +%Y%m%d)
mkdir -p "$DEST"
tmp="$DEST/.homelab-$stamp.tar.gz.tmp"
tar --create --gzip --file "$tmp" \
    --warning=no-file-changed --warning=no-file-removed --ignore-failed-read \
    --exclude='jellyfin/cache' --exclude='jellyfin/data/metadata' --exclude='jellyfin/metadata' \
    --exclude='jellyfin/data/subtitles' --exclude='jellyfin/data/trickplay' --exclude='*/transcodes' \
    --exclude='*/log' --exclude='*/logs' --exclude='*.log' --exclude='*/MediaCover' \
    --exclude='frigate-media' --exclude='frigate/model_cache' --exclude='*/Backups' \
    --exclude='configarr/repos' --exclude='*/cache' \
    -C "$CONFIG" . \
    -C "$STACK" .env docker-compose.wsl.yml || [ $? -eq 1 ]   # 1 = arquivo mudou durante a cópia (SQLite vivo)
mv "$tmp" "$DEST/homelab-$stamp.tar.gz"
ls -1 "$DEST"/homelab-*.tar.gz | head -n -"$KEEP" | xargs -r rm -f
if [ -d "$CASA" ]; then
    mkdir -p "$DEST/casa-local"
    cp -u "$CASA"/casa-data-*.zip "$DEST/casa-local/" 2>/dev/null || true
    ls -1 "$DEST"/casa-local/casa-data-*.zip 2>/dev/null | head -n -"$KEEP" | xargs -r rm -f
fi
echo "backup ok: $(du -h "$DEST/homelab-$stamp.tar.gz" | cut -f1)"
