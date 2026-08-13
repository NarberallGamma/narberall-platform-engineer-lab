# Networking (workstation)

**Role:** Make wired + wireless + dual-boot NetworkManager predictable, then put API/CDN traffic on an explicit path (TUN or SOCKS) when the system proxy is not enough.

## What I own

| Layer | Detail |
|-------|--------|
| Primary | 5 GbE (Realtek RTL8126-class, `r8169`) |
| Wireless | Wi-Fi 7 (Qualcomm FastConnect / `ath12k`), Bluetooth |
| Dual boot | Same NIC, different OS stacks: Windows vs Linux firmware + NM profiles |
| Desktop | NetworkManager on KDE; Ethernet preferred when Wi-Fi RSSI on Linux is worse than Windows on the same radio |
| CLI / APIs | TUN or SOCKS for CDNs that ignore the desktop proxy (example: image CDN download = 0 bytes without TUN) |

## Dual-boot Wi-Fi

Linux and Windows do not share NM/WLAN profiles. On Wi-Fi 7 I have measured **strong Windows RSSI and weak Linux RSSI** on the same AP (5 GHz / DFS BSSID). That is a driver/firmware problem, not "the AP is far". Workaround: Ethernet as the workstation default; Wi-Fi kept for mobility tests after `pacman -Syu`.

## Traffic path for tools

CLI and MCP wrappers do **not** inherit KDE system proxy. For outbound APIs + CDN:

1. TUN on the local client, or
2. explicit `socks5h://127.0.0.1:…` in curl/CLI, or
3. a routing rule for the API/CDN hosts

Same pattern I use on VPS work: do not assume "the GUI VPN" is visible to Docker, Ansible, or Python.

Proof of code: [`../../reference/utilities/mcp-replicate/`](../../reference/utilities/mcp-replicate/) (wrapper does not inherit the desktop proxy).

See [`../../diagrams/practice/home-lab/networking.md`](../../diagrams/practice/home-lab/networking.md).

## Keywords

NetworkManager, Ethernet, Wi-Fi 7, dual boot, TUN, SOCKS, DNS, Linux networking
