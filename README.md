# AdGuard Home + Unbound DNS

Network-wide ad blocking with encrypted DNS forwarding on Raspberry Pi 5.

```
Clients → AdGuard (ad blocking) → Unbound (caching + DoT) → Cloudflare
```

## Install

```bash
scp .env pi@192.168.4.181:~/adguard/   # copy borg passphrase
./install.sh install                     # NFS, dirs, compose up, borgmatic init
```

## Commands

```bash
./install.sh install           # full setup
./install.sh status            # containers + NFS mounts
./install.sh nfs mount         # mount NFS backup share
./install.sh nfs unmount       # unmount NFS backup share
./install.sh borgmatic-init    # init borg repo
./install.sh borgmatic-backup  # run backup now
```

## AdGuard Setup

1. Open `http://SERVER_IP:3000`, complete setup wizard
2. Settings → DNS → Upstream DNS: `unbound`
3. Set router DNS to server's LAN IP

## Ports

| Port | Service |
|------|---------|
| 53 | DNS |
| 80 | Web UI |
| 443 | HTTPS |
| 3000 | Initial setup UI |

## Troubleshooting

**Port 53 conflict** — disable systemd-resolved stub:
```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

**SERVFAIL on some domains** — ISP blocks root server queries. Forwarding mode to Cloudflare (default config) fixes this.

**Unbound not starting** — `sudo docker logs unbound`
