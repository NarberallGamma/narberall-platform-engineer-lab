# SSH tunnel (Android)

Foreground Service that keeps **several SSH local forwards** alive on mobile NAT. Not a system VPN — a separate proxy client points at `127.0.0.1`.

Package in this tree: `com.example.sshtunnel` (renamed from the private app id).

Practice: [`../../../android-ssh.md`](../../../android-ssh.md). Jump-side socat: [`../../../../../iac/ansible/reference/ansible-edge/`](../../../../../iac/ansible/reference/ansible-edge/). Desktop twin: [`../ssh-tunnel-docker/`](../ssh-tunnel-docker/).

## Behavior

| Feature | Default |
|---------|---------|
| Forwards | 10809–10814, one SSH session each |
| Balancer | 10808 round-robin |
| Keepalive | `ServerAliveInterval` ~30s |
| Rotation | every 10 minutes, **one** tunnel recycled |
| Config | host, port, user, paste private key, ping + SSH test |

`gradle-wrapper.jar` is not vendored. Generate the wrapper locally, then `./gradlew assembleDebug`.

## Lab limitation

`HostKeyVerifier` currently accepts any host key (first-run convenience on a known jump). Production hardening would pin the key.

## Keywords

Android, Gradle, Foreground Service, SSHJ, port forwarding, NAT
