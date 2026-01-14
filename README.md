# pve-host-backup-to-pbs

Open-source toolkit to back up **Proxmox VE host nodes** (not just VMs/CTs)
to **Proxmox Backup Server (PBS)** using `proxmox-backup-client`.

## What this does
- Backs up Proxmox VE *node configuration* and metadata
- Uses PBS-native, deduplicated, incremental backups
- Keeps secrets **out of Git** (systemd encrypted credentials)
- Installs as a systemd service + timer (daily, staggered)

## What this does NOT do
- This does NOT replace VM/CT backups
- This does NOT back up VM disks (handled by PVE → PBS integration)

## Default backed-up paths
- /etc
- /etc/pve
- /root
- /usr/local
- generated metadata (network, pveversion, packages)

## Quick install
```bash
git clone https://github.com/YOURNAME/pve-host-backup-to-pbs.git
cd pve-host-backup-to-pbs
sudo ./scripts/install.sh
```

## Security notes
- Use PBS API tokens, not passwords
- Tokens are stored via systemd encrypted credentials
- Never commit real repository strings or tokens

## License
MIT
