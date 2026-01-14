#!/usr/bin/env bash
set -e

echo "[+] Installing Proxmox host backup to PBS"

apt update
apt install -y proxmox-backup-client

mkdir -p /etc/pve-host-backup
chmod 700 /etc/pve-host-backup

cp examples/config.env.example /etc/pve-host-backup/config.env || true

install -m 700 scripts/pve-host-backup.sh /usr/local/sbin/pve-host-backup.sh
install -m 644 systemd/pve-host-backup.service /etc/systemd/system/
install -m 644 systemd/pve-host-backup.timer /etc/systemd/system/

echo "[!] Enter PBS token secret (will be encrypted)"
systemd-ask-password -n | systemd-creds encrypt       --name=proxmox-backup-client.password -       /etc/pve-host-backup/pbs-token.cred

chmod 600 /etc/pve-host-backup/pbs-token.cred

systemctl daemon-reload
systemctl enable --now pve-host-backup.timer

echo "[✓] Installation complete"
