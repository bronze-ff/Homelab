#!/usr/bin/env bash
# Instala os timers do home lab no systemd do WSL (precisa de sudo).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$here"/backup-homelab.sh "$here"/limpeza-semanal.sh
sudo install -m 644 "$here"/systemd/homelab-*.service "$here"/systemd/homelab-*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer homelab-limpeza.timer
systemctl list-timers 'homelab-*' --no-pager
