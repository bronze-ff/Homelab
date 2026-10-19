#!/usr/bin/env bash
# Limpeza semanal (timer homelab-limpeza, domingo 05:15): imagens Docker que nenhum container usa há
# mais de 7 dias (sobram a cada atualização do Diun/compose pull), cache de build e journal antigo.
# Não toca em containers, volumes nem configs.
set -uo pipefail
before=$(df --output=avail -BM / | tail -1 | tr -dc 0-9)
docker image prune --all --force --filter "until=168h" >/dev/null
docker builder prune --force --filter "until=168h" >/dev/null 2>&1 || true
journalctl --vacuum-time=14d >/dev/null 2>&1 || true
after=$(df --output=avail -BM / | tail -1 | tr -dc 0-9)
echo "limpeza ok: $(( after - before )) MB liberados"
