# SSH tunnel (Docker)

Six `ssh -N -L` processes plus nginx **stream** round-robin on 10808. Same 10-minute rolling restart as the Android app (one tunnel at a time). Config via env or `ssh-tunnel.conf.example` — `HOST=jump.example.com`, never a real IP in git.

Practice: [`../../../android-ssh.md`](../../../android-ssh.md).

```bash
docker build -t ssh-tunnel:local .
docker run --rm -p 10808:10808 \
  -v /path/to/key:/config/key:ro \
  -v ./ssh-tunnel.conf:/config/ssh-tunnel.conf:ro \
  ssh-tunnel:local
```

CRLF is stripped from the mounted conf (Windows dual-boot leftover). The key is copied to `/tmp` and `chmod 600` because bind mounts often arrive as 0777.

## Keywords

Docker, OpenSSH, nginx stream, port forwarding
