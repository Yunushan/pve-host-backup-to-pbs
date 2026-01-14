#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/pve-host-backup/config.env"
[ -f "$CONFIG" ] || { echo "Config missing"; exit 1; }
source "$CONFIG"

BACKUP_ID="${BACKUP_ID:-$(hostname -s)}"
ETC_PATH="${ETC_PATH:-/etc}"
ETC_PVE_PATH="${ETC_PVE_PATH:-/etc/pve}"
ROOT_PATH="${ROOT_PATH:-/root}"
USR_LOCAL_PATH="${USR_LOCAL_PATH:-/usr/local}"
META_DIR="${META_DIR:-/var/lib/pve-host-backup-meta}"

mkdir -p "$META_DIR"

pveversion -v > "$META_DIR/pveversion.txt" 2>&1 || true
ip a > "$META_DIR/ip-a.txt" 2>&1 || true
dpkg --get-selections > "$META_DIR/packages.txt" 2>&1 || true

ARGS=()
[[ "$INCLUDE_ETC" == "1" ]] && ARGS+=(etc.pxar:"$ETC_PATH")
[[ "$INCLUDE_ETC_PVE" == "1" ]] && ARGS+=(pve.pxar:"$ETC_PVE_PATH")
[[ "$INCLUDE_ROOT" == "1" ]] && ARGS+=(root.pxar:"$ROOT_PATH")
[[ "$INCLUDE_USR_LOCAL" == "1" ]] && ARGS+=(usr_local.pxar:"$USR_LOCAL_PATH")
[[ "$INCLUDE_META" == "1" ]] && ARGS+=(meta.pxar:"$META_DIR")

proxmox-backup-client backup \
  "${ARGS[@]}" \
  --backup-type host \
  --backup-id "$BACKUP_ID" \
  --ns "$PBS_NAMESPACE"
