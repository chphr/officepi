# Pi Homelab

Docker Compose stack running on a Raspberry Pi:

| Service       | Purpose                          | Exposure                          |
|---------------|-----------------------------------|-------------------------------------|
| AdGuard Home  | Network-wide DNS / ad blocking    | LAN only (port 53, 80/3000)         |
| Gophish       | Phishing simulation / sec training| Admin UI: localhost/VPN only. Landing page optionally tunneled |
| Foundry VTT   | Virtual tabletop                  | Public, via Cloudflare Tunnel       |
| cloudflared   | Cloudflare Tunnel ingress         | Outbound only, no open ports        |

All services run on a single custom bridge network (`homelab`) so they
can reach each other by container name if needed, while each exposes
only the ports it actually needs to the host.

## Architecture notes

- **No port forwarding.** The only thing that talks to the public
  internet is `cloudflared`. Public routes (e.g. `table.example.com` →
  `foundryvtt:30000`) are configured in the Cloudflare Zero Trust
  dashboard under **Networks → Tunnels**, not in this repo.
- **Gophish admin stays local.** The admin panel (3333) is bound to
  `127.0.0.1` on the host and is deliberately left out of the tunnel.
  Reach it via SSH tunnel, Tailscale, or WireGuard — never expose a
  phishing-simulation admin panel publicly.
- **Data vs. config.** This repo holds only configuration
  (`docker-compose.yml`, `.env.example`, static config files). Actual
  service data lives in Docker named volumes and is backed up
  separately — see below. That data is never committed to git.

## Before you start (Raspberry Pi OS specifics)

1. **Install Docker + Compose plugin:**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   sudo apt install docker-compose-plugin
   ```
   Log out/in for the group change to apply.

2. **Free up port 53 for AdGuard Home.** Raspberry Pi OS runs
   `systemd-resolved`, which binds port 53 by default and will
   collide with AdGuard.
   ```bash
   sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
   sudo rm -f /etc/resolv.conf
   sudo sh -c 'echo "nameserver 127.0.0.1" > /etc/resolv.conf'
   sudo systemctl restart systemd-resolved
   ```

3. **Create your tunnel** in the Cloudflare Zero Trust dashboard
   (Networks → Tunnels → Create a tunnel → Docker), copy the token
   it gives you into `.env` as `CLOUDFLARE_TUNNEL_TOKEN`, and add
   public hostname routes pointing at the container:port you want
   reachable (e.g. `foundryvtt:30000`).

## Setup

```bash
git clone <this-repo-url>
cd pi-homelab
cp .env.example .env
nano .env   # fill in real values — this file is gitignored
docker compose up -d
```

First-run steps per service:
- **AdGuard Home**: visit `http://<pi-ip>:3000` to complete the setup
  wizard, then it moves to port 80.
- **Gophish**: default admin login is printed in the container logs
  on first start (`docker compose logs gophish`) — change it
  immediately.
- **Foundry VTT**: visit `http://<pi-ip>:30000`, it will use the
  credentials from `.env` to activate your license automatically.

## Updating

```bash
docker compose pull
docker compose up -d
```

## Backups

Config (this repo) is versioned in git. Service **data** is backed up
separately with:

```bash
./scripts/backup.sh
```

This tars each named volume to `~/pi-homelab-backups/<timestamp>/`.
Point `BACKUP_DIR` at an external drive, or uncomment the `rclone`
line in the script to push offsite. Suggested: run it via cron weekly:

```bash
crontab -e
# add:
0 3 * * 0 /home/pi/pi-homelab/scripts/backup.sh >> /home/pi/backup.log 2>&1
```

## Restoring on a new Pi

```bash
git clone <this-repo-url>
cd pi-homelab
cp .env.example .env   # fill in values
docker compose up -d   # creates empty volumes
docker compose down    # stop so volumes aren't in use

# for each volume, restore from a backup tarball:
docker run --rm -v adguard_work:/data -v ~/pi-homelab-backups/<timestamp>:/backup alpine \
  tar xzf /backup/adguard_work.tar.gz -C /data
# repeat for adguard_conf, gophish_data, foundry_data

docker compose up -d
```

## Repo layout

```
pi-homelab/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── services/
│   └── gophish/config.json   # static config, no secrets
└── scripts/
    └── backup.sh
```
