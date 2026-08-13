# Android SSH client + Docker balancer

**Role:** I wrote the **failover client** for the edge platform: SSH port-forwards that stay up on mobile NAT, plus a Docker equivalent for the desktop.

Not a system VPN. Local listeners only; a separate proxy client (NekoBox-class) points at `127.0.0.1`.

## Problem

A **single** long-lived SSH `-L` degrades: download collapses after hours while upload stays high (TCP window / half-closed sockets on one multiplexed channel). Mobile NAT also drops quiet sessions.

## Android app (from scratch)

Foreground Service (notification so the OS does not kill tunnels):

| Feature | Behavior |
|---------|----------|
| Config UI | host, port, user, paste private key, ping + SSH test |
| Forwards | several local ports (default 10809–10814) → `remote_host:remote_port` on the jump (usually `127.0.0.1` + socat port) |
| Sessions | **one SSH session per tunnel** (not one mux for all) |
| Keepalive | `ServerAliveInterval=30` |
| Balancer | extra listen port (default 10808) round-robins across tunnels |
| Rotation | every 10 minutes **one** tunnel is torn down and re-raised; the other five stay up |
| Client | NekoBox-class app uses `127.0.0.1:10808` |

Build: Android Studio / Gradle `assembleDebug`.

## Docker twin (desktop)

One container: six `ssh -N -L` processes + nginx **stream** balancer. Host publishes a single port. Same 10-minute rolling restart (1→2→…→6). Config via env or `ssh-tunnel.conf.example` (key mounted read-only).

This is the same reliability pattern as the Ansible `ssh_tunnel` role on the jump (restricted users, `permitopen`, socat). Client and server were designed together.

Proof of code: [`../../reference/apps/ssh-tunnel-android/`](../../reference/apps/ssh-tunnel-android/), [`../../reference/apps/ssh-tunnel-docker/`](../../reference/apps/ssh-tunnel-docker/). Jump socat: [`../../reference/ansible-edge/`](../../reference/ansible-edge/).

## Diagram

See [`../../diagrams/practice/home-lab/android-ssh.md`](../../diagrams/practice/home-lab/android-ssh.md).

## Keywords

Android, Gradle, Foreground Service, SSH, port forwarding, Docker, nginx stream, NAT, failover
