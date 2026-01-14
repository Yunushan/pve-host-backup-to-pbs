#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/pve-host-backup/config.env"
[ -f "$CONFIG" ] || { echo "Config missing"; exit 1; }
source "$CONFIG"

BACKUP_ID="${BACKUP_ID:-$(hostname -s)}"
META="/var/lib/pve-host-backup-meta"
mkdir -p "$META"

pveversion -v > "$META/pveversion.txt" 2>&1 || true
ip a > "$META/ip-a.txt" 2>&1 || true
dpkg --get-selections > "$META/packages.txt" 2>&1 || true

ARGS=()
[[ "$INCLUDE_ETC" == "1" ]] && ARGS+=(etc.pxar:/etc)
[[ "$INCLUDE_ETC_PVE" == "1" ]] && ARGS+=(pve.pxar:/etc/pve)
[[ "$INCLUDE_ROOT" == "1" ]] && ARGS+=(root.pxar:/root)
[[ "$INCLUDE_USR_LOCAL" == "1" ]] && ARGS+=(usr_local.pxar:/usr/local)
[[ "$INCLUDE_META" == "1" ]] && ARGS+=(meta.pxar:$META)

proxmox-backup-client backup \
  "${ARGS[@]}" \
  --backup-type host \
  --backup-id "$BACKUP_ID" \
  --ns "$PBS_NAMESPACE"
