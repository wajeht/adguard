# adguard

AdGuard Home + Unbound on Raspberry Pi 5.

```
Clients → AdGuard (ad blocking) → Unbound (DoT) → Cloudflare
```

## setup

```bash
scp .env pi@192.168.4.181:~/adguard/
./install.sh install
```

Then open `http://SERVER_IP:3000`, set upstream DNS to `unbound`.

## commands

```bash
./install.sh install           # full setup
./install.sh status            # containers + NFS
./install.sh nfs mount         # mount NFS
./install.sh nfs unmount       # unmount NFS
./install.sh borgmatic-init    # init borg repo
./install.sh borgmatic-backup  # manual backup
```

## troubleshooting

port 53 conflict — disable systemd-resolved:
```bash
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```
