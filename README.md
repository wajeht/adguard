# adguard

AdGuard Home + Unbound on Raspberry Pi 5.

```
Clients → AdGuard (ad blocking) → Unbound (DoT) → Cloudflare
```

## setup

```bash
scp .env pi@192.168.4.181:~/adguard/
./setup.sh install
```

Then open `http://SERVER_IP:3000`, set upstream DNS to `unbound`.

## commands

```bash
./setup.sh install           # full setup
./setup.sh status            # containers + NFS
./setup.sh nfs mount         # mount NFS
./setup.sh nfs unmount       # unmount NFS
./setup.sh borgmatic-init    # init borg repo
./setup.sh borgmatic-backup  # manual backup
```

## troubleshooting

port 53 conflict — disable systemd-resolved:
```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```
