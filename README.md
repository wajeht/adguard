# AdGuard Home + Unbound DNS

Network-wide ad blocking with encrypted DNS forwarding.

```
Clients → AdGuard (ad blocking) → Unbound (caching + DoT) → Cloudflare
```

## Features

- **Ad blocking** via AdGuard blocklists
- **DNS caching** via Unbound
- **Encrypted DNS** via DNS-over-TLS to Cloudflare
- **Privacy** from ISP (they only see encrypted traffic)
- **Automated backups** via borgmatic + borg (NFS to Synology NAS)

## Prerequisites

- Docker & Docker Compose
- Raspberry Pi 5 (or any ARM64/x86_64 server) with static LAN IP
- NFS share for backups (optional)

## Install

```bash
# Copy .env with BORG_PASSPHRASE to the server
scp .env pi@192.168.4.181:~/adguard/

# Full setup (NFS mount, create dirs, compose up, borgmatic init)
./install.sh install
```

### Ports Used

| Port | Service |
|------|---------|
| 53   | DNS |
| 3000 | AdGuard initial setup UI |
| 80   | AdGuard web UI (after setup) |
| 443  | AdGuard HTTPS |

If port 53 conflicts with systemd-resolved, see Troubleshooting.

## AdGuard Setup

1. Open `http://YOUR_SERVER_IP:3000`
2. Complete the setup wizard (create admin user)
3. Go to Settings → DNS settings
4. Set **Upstream DNS servers** to:
   ```
   unbound
   ```
5. Click **Test upstreams** then **Apply**

After setup, web UI is at `http://YOUR_SERVER_IP` (port 80).

## Router Configuration

Set your router's DNS server to your server's LAN IP. All devices on your network will then use AdGuard.

### UniFi Router

1. Go to **UniFi Network Console** → **Settings** → **Networks**
2. Select your **Default** network
3. Uncheck **Auto DNS Server**
4. Enter your server's LAN IP
5. Click **Apply Changes**

Devices will get the new DNS on next DHCP lease renewal.

## Recommended Blocklists

Go to **Filters** → **DNS blocklists** → **Add blocklist**

| Name | URL |
|------|-----|
| OISD Big | `https://big.oisd.nl/domainswild` |
| AdGuard DNS filter | (built-in, just enable) |
| Smart TV | `https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV-AGH.txt` |

**Note:** OISD Big alone is comprehensive. More lists = more potential false positives.

## Commands

| Command | Description |
|---------|-------------|
| `./install.sh install` | Full setup: NFS, dirs, compose up, borgmatic init |
| `./install.sh setup` | Create data/backup directories |
| `./install.sh nfs mount` | Mount NFS backup share |
| `./install.sh nfs unmount` | Unmount NFS backup share |
| `./install.sh nfs status` | Show NFS mount status |
| `./install.sh borgmatic-init` | Initialize borg repo |
| `./install.sh borgmatic-backup` | Run backup now |
| `./install.sh status` | Show containers and mounts |

## Unbound: Recursive vs Forwarding Mode

### Recursive Mode (default unbound behavior)
```
Unbound → Root servers → TLD servers → Authoritative servers
```
- Queries DNS root servers directly
- Most private (no third-party DNS provider)
- **Problem:** Some ISPs block/throttle root server queries, causing random SERVFAIL errors

### Forwarding Mode (our config)
```
Unbound → Cloudflare (encrypted DNS-over-TLS)
```
- Forwards queries to Cloudflare over encrypted connection
- More reliable on most home networks
- Still private (ISP sees encrypted traffic, not your queries)
- Still get caching benefits

**If you see random SERVFAIL errors**, your network likely blocks direct root server access. Use forwarding mode (already configured in `unbound/custom.conf`).

## Troubleshooting

### Port 53 already in use

Likely `systemd-resolved` is using it. Options:

1. Bind DNS to specific IP in docker-compose.yml:
   ```yaml
   ports:
     - "YOUR_SERVER_IP:53:53/tcp"
     - "YOUR_SERVER_IP:53:53/udp"
   ```

2. Disable systemd-resolved stub:
   ```bash
   sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
   sudo systemctl restart systemd-resolved
   ```

### Unbound SERVFAIL on some domains

If some domains resolve but others return SERVFAIL, your ISP likely blocks direct root server queries. The default config uses forwarding mode to Cloudflare which fixes this.

To switch to recursive mode (if your network supports it), edit `unbound/custom.conf` and remove the `forward-zone` section.

### Unbound not starting

Check logs:
```bash
sudo docker logs unbound
```

### AdGuard data directory permission errors

If you see errors like `no such file or directory` when adding blocklists:

```bash
sudo docker stop adguard
sudo rm -rf ~/adguard/data
sudo mkdir -p ~/adguard/data/work ~/adguard/data/conf
sudo chmod -R 777 ~/adguard/data
sudo docker start adguard
```

Then go through setup wizard again at `http://YOUR_SERVER_IP:3000`.

### ARM64 (Raspberry Pi) Notes

Uses `klutchell/unbound` image (ARM-compatible) instead of `mvance/unbound`.

Custom config files go in `unbound/` directory and are mounted to `/etc/unbound/custom.conf.d/`.
