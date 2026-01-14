# pve-host-backup-to-pbs

Backs up **Proxmox VE host nodes** (not VMs/CTs) to **Proxmox Backup Server**
using `proxmox-backup-client`. It is intentionally small: one script, one config
file, and a systemd service + timer.

## What this does
- Backs up host configuration and metadata (not VM/CT disks)
- Uses PBS-native, deduplicated, incremental backups
- Keeps secrets out of Git (systemd encrypted credentials)
- Installs as a systemd service + timer (daily, staggered)

## What this does NOT do
- It does not replace VM/CT backups
- It does not back up VM disks (handled by PVE + PBS integration)

## Requirements
- A Proxmox VE host (root access required)
- Network access to your PBS instance
- A PBS API token (recommended) and datastore
- `proxmox-backup-client` (installed by the installer)
- systemd with credential support (default on PVE)

## Quick install
```bash
git clone https://github.com/YOURNAME/pve-host-backup-to-pbs.git
cd pve-host-backup-to-pbs
sudo ./scripts/install.sh
```

The installer does the following:
- Installs `proxmox-backup-client` via `apt`
- Creates `/etc/pve-host-backup` (mode 700)
- Copies `examples/config.env.example` to `/etc/pve-host-backup/config.env` (will not overwrite)
- Installs the backup script to `/usr/local/sbin/pve-host-backup.sh`
- Installs `systemd/pve-host-backup.service` and `systemd/pve-host-backup.timer`
- Prompts once for your PBS token secret and encrypts it into `/etc/pve-host-backup/pbs-token.cred`
- Enables and starts the timer

## File layout
- `scripts/pve-host-backup.sh` -> installed to `/usr/local/sbin/pve-host-backup.sh`
- `examples/config.env.example` -> copied to `/etc/pve-host-backup/config.env`
- `systemd/pve-host-backup.service` -> `/etc/systemd/system/pve-host-backup.service`
- `systemd/pve-host-backup.timer` -> `/etc/systemd/system/pve-host-backup.timer`
- Encrypted credential -> `/etc/pve-host-backup/pbs-token.cred`
- Metadata dir -> `/var/lib/pve-host-backup-meta` (default, override with `META_DIR`)

## Configuration (very detailed)
Configuration lives at `/etc/pve-host-backup/config.env` and is sourced by the
backup script at runtime. Edit this file after installation.

Example:
```bash
PBS_REPOSITORY="user@pbs!token@pbs.example.com:datastore"
PBS_FINGERPRINT="AA:BB:CC:DD:EE:FF"

BACKUP_ID=""
PBS_NAMESPACE="pve-hosts"

INCLUDE_ETC=1
INCLUDE_ETC_PVE=1
INCLUDE_ROOT=1
INCLUDE_USR_LOCAL=1
INCLUDE_META=1

ETC_PATH="/etc"
ETC_PVE_PATH="/etc/pve"
ROOT_PATH="/root"
USR_LOCAL_PATH="/usr/local"
META_DIR="/var/lib/pve-host-backup-meta"
```

Details by variable:
- `PBS_REPOSITORY` (required)
  Repository string passed to `proxmox-backup-client`. Format:
  `user@pbs!token@pbs.example.com:datastore`
- `PBS_FINGERPRINT` (required)
  TLS fingerprint from your PBS UI (or `proxmox-backup-client fingerprint`).
- `BACKUP_ID` (optional)
  Backup ID for the host. If empty, defaults to `hostname -s`.
- `PBS_NAMESPACE` (recommended)
  PBS namespace for grouping host backups. Default in the example is `pve-hosts`.
- `INCLUDE_ETC`
  If `1`, includes `/etc` as `etc.pxar`.
- `INCLUDE_ETC_PVE`
  If `1`, includes `/etc/pve` as `pve.pxar`.
- `INCLUDE_ROOT`
  If `1`, includes `/root` as `root.pxar`.
- `INCLUDE_USR_LOCAL`
  If `1`, includes `/usr/local` as `usr_local.pxar`.
- `INCLUDE_META`
  If `1`, includes generated metadata as `meta.pxar`.
- `ETC_PATH`
  Path used for `etc.pxar` (default `/etc`).
- `ETC_PVE_PATH`
  Path used for `pve.pxar` (default `/etc/pve`).
- `ROOT_PATH`
  Path used for `root.pxar` (default `/root`).
- `USR_LOCAL_PATH`
  Path used for `usr_local.pxar` (default `/usr/local`).
- `META_DIR`
  Directory used for generated metadata (default `/var/lib/pve-host-backup-meta`).

Important notes:
- `proxmox-backup-client` expects `PBS_REPOSITORY` and `PBS_FINGERPRINT` in the
  environment. If you see "repository not specified" or TLS errors, export these
  variables in the config file or pass them explicitly in the script.
- `ENABLE_ROOTFS`, `EXCLUDES`, `ON_CALENDAR`, and `RANDOM_DELAY_SEC` exist in the
  example config but are not used by the current script or timer. They are
  placeholders for future enhancements or local customization.

## How backups are built
On each run, `pve-host-backup.sh`:
1. Loads `/etc/pve-host-backup/config.env`
2. Picks a `BACKUP_ID` (hostname by default)
3. Writes metadata to `META_DIR` (default `/var/lib/pve-host-backup-meta`):
   - `pveversion -v`
   - `ip a`
   - `dpkg --get-selections`
4. Builds a `proxmox-backup-client backup` command with one or more `pxar` archives
5. Runs the backup with:
   - `--backup-type host`
   - `--backup-id <BACKUP_ID>`
   - `--ns <PBS_NAMESPACE>`

Paths come from the `*_PATH` variables (defaults shown here):
- `etc.pxar:/etc`
- `pve.pxar:/etc/pve`
- `root.pxar:/root`
- `usr_local.pxar:/usr/local`
- `meta.pxar:/var/lib/pve-host-backup-meta`

## systemd service + timer
`systemd/pve-host-backup.service` is a oneshot unit that runs the script and
loads the encrypted credential:

- Credential name: `proxmox-backup-client.password`
- Credential file: `/etc/pve-host-backup/pbs-token.cred`

`systemd/pve-host-backup.timer` runs daily at 02:00 with a 2-hour random delay
to stagger backups across hosts:

```ini
OnCalendar=*-*-* 02:00:00
RandomizedDelaySec=7200
Persistent=true
```

To change the schedule:
```bash
sudo systemctl edit --full pve-host-backup.timer
sudo systemctl daemon-reload
sudo systemctl restart pve-host-backup.timer
```

## Running manually
Prefer running the systemd service so the credential is loaded:
```bash
sudo systemctl start pve-host-backup.service
sudo journalctl -u pve-host-backup.service -n 100 --no-pager
```

If you run the script directly, you must provide a password or token secret via
environment (for example `PBS_PASSWORD`) because the systemd credential will not
be available outside the service.

## Verifying backups
- In the PBS UI, look for snapshots under namespace `pve-hosts` (or your custom namespace)
- Or via CLI:
  ```bash
  proxmox-backup-client snapshots --ns pve-hosts
  ```

## Restore (high level)
You can restore individual archives with `proxmox-backup-client restore`. Example:
```bash
proxmox-backup-client restore host/<BACKUP_ID>/<TIMESTAMP> etc.pxar /tmp/restore/etc --ns pve-hosts
```

Restore carefully on a running node. For `/etc/pve`, only restore when you
understand cluster implications.

## Troubleshooting
- `Config missing`
  Ensure `/etc/pve-host-backup/config.env` exists and is readable by root.
- `repository not specified` or TLS errors
  Ensure `PBS_REPOSITORY` and `PBS_FINGERPRINT` are set and exported.
- Authentication failed
  Re-run credential setup:
  `systemd-ask-password -n | systemd-creds encrypt --name=proxmox-backup-client.password - /etc/pve-host-backup/pbs-token.cred`
- Timer not running
  Check status: `systemctl status pve-host-backup.timer` and `systemctl list-timers --all | rg pve-host-backup`
- No snapshots created
  Check logs: `journalctl -u pve-host-backup.service -n 200 --no-pager`

## Security notes
- Use PBS API tokens, not passwords
- Token secret is encrypted with systemd credentials and stored on disk
- Keep `/etc/pve-host-backup/config.env` and `/etc/pve-host-backup/pbs-token.cred` root-only
- Never commit real repository strings or tokens

## License
MIT (see `LICENSE`)
