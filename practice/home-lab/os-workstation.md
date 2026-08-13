# Multi-OS workstation

**Role:** I treat the home PC as a platform: install, rollback, GPU, boot, and disks are coded habits, not one-off tweaks. The same machine is **tuned per workload** (LLM, Stable Diffusion, games, office/engineering software). Diagnosis goes to **hardware and firmware**, not only to a shell on an already-booted OS.

## Hardware class (generic)

| Piece | Class |
|-------|--------|
| CPU | AMD Ryzen 9 9950X3D (16C/32T) |
| RAM | 64 GB |
| GPU | NVIDIA RTX 4080 16 GB (open kernel modules + CUDA 13) |
| Linux disk | NVMe, btrfs |
| Windows disk | Separate NVMe (Windows 11) |
| Extra storage | HDD archive / media (ntfs3 when mounted) |
| NIC | 5 GbE Realtek + Wi-Fi 7 (Qualcomm) |

Two full operating systems, two ESPs. Windows stays for a small set of vendor-only tools (anti-cheat, Office/Visio-class, sim hardware). Daily Platform / AI work is **native Arch** (KDE Plasma, Wayland). WSL2 was the previous substrate; the same Docker/Ansible/CUDA patterns moved over.

## Dual boot

| Topic | What I run |
|-------|------------|
| Layout | Separate NVMe per OS; Linux ESP and Windows ESP are not merged |
| Linux boot | UKI on the Linux ESP; firmware Boot Manager still reaches Windows |
| Windows pitfall | Do not copy `EFI/Microsoft` onto the Linux ESP (no BCD there; Windows will not start) |
| Secure Boot | `sbctl` for signing UKI / boot artifacts; PK/KEK/db live in **NVRAM** (not in snapper) |
| Rollback vs firmware | Snapshot restore brings back signed files on `/boot`; NVRAM enrollment is a separate backup (`sbctl export`, `efi-readvar`) |

I debug dual-boot as a platform problem: two ESPs, NVRAM `Boot####` entries, os-prober vs dedicated Windows Boot Manager, UKI vs GRUB. Experiments on the bootloader go behind a paired snapshot plus ESP rsync.

## Btrfs + snapshots

| Subvolume | Mount | In snapper |
|-----------|--------|------------|
| `@` | `/` | **root** |
| `@home` | `/home` | **home** |
| `@log` | `/var/log` | no (logs survive a root rollback) |
| `@pkg` | `/var/cache/pacman/pkg` | no |

`/boot` is vfat (ESP): **not** in btrfs snapshots. `snap-pair` therefore also rsyncs the ESP so a rollback is kernel + UKI + configs, not only `@`/`@home`.

Automation:

- **timeline** (hourly) on root + home
- **snap-pac** pre/post every pacman/yay
- **snap-pair** (manual) with shared `pair=` userdata: root + home + `/boot` in one named restore point
- **snap-restore --pair** for a coordinated rollback

This is the same idea as cloud: backup before mutate, restore as a unit, logs kept out of the snapshot so forensics survive.

Proof of code: [`../../reference/utilities/snap-pair/`](../../reference/utilities/snap-pair/).

## GPU / CUDA

| Layer | Stack |
|-------|--------|
| Driver | `nvidia-open` (Ada) + `nvidia-utils`, Wayland `nvidia_drm` modeset |
| Toolkit | CUDA 13 (`nvcc`), OpenCL, `nvtop` |
| 32-bit | `lib32-nvidia-utils` for Proton |
| CPU microcode | `amd-ucode` in the boot image |

Post-install is rolling: `linux`, firmware, NVIDIA, CUDA via the distro, not vendor EXE installers.

## Workload-oriented OS (not one generic install)

The same hardware is studied and tuned for **different jobs**. A “works for SSH” install is not enough.

| Workload | What I actually tune |
|----------|----------------------|
| Local LLM | VRAM vs context, quantization, offload, CPU affinity, swap vs OOM, cgroup/memory limits, serving (Ollama / llama.cpp-class) |
| Stable Diffusion / LoRA | Driver + Docker GPU, batch vs VRAM, compose, datasets on disk — see [ai-lab.md](ai-lab.md) |
| Games / Proton | 32-bit NVIDIA, compositor, scheduler, GameMode-class knobs, dual-boot when a vendor stack is Windows-only |
| Office / engineering software | Native Linux when it is honest; Windows when the vendor requires it (Office/Visio-class, anti-cheat, sim hardware) |

This is the same habit as production capacity planning: measure the bottleneck (CPU, RAM, GPU, disk, thermal, firmware), then change the layer that actually owns it.

## Hardware, BIOS, and assembly

I work with **metal**, not only with images of metal.

- Built PCs by hand (CPU, RAM, GPU, storage, cooling, cabling) and brought them up through UEFI
- Assembled **simple office servers** (small-office towers / light racks: disks, NIC, OS, backup) — not a datacenter integrator claim
- **BIOS / UEFI** is a normal surface: boot order, RAM (EXPO/XMP and timings), CPU limits, Resizable BAR, IOMMU, Secure Boot keys, fan/thermal, PCIe
- Hardware diagnosis: SMART, memtest-class RAM, thermals, PSU, PCIe/GPU, disks that lie until `dmesg` or a bench says otherwise
- **Turnkey PC:** from empty box to a stable, measured profile for the job (office, games, LLM, SD) — not “it POSTed”

If the box will not POST, the problem is not “restart systemd”.

## Overclock, undervolt, sensors (any PC, turnkey)

Firmware and silicon are tuned with **measurements**, not folklore. Goal is a stable profile for the workload (quiet office, games, LLM/SD), then leave it documented.

| Layer | What I actually do |
|-------|---------------------|
| RAM | EXPO/XMP or manual: frequency, timings, voltage; stability with memtest-class runs before calling it done |
| CPU | Boost / PBO-class limits, Curve Optimizer-class undervolt, PPT/TDC/EDC where the silicon exposes them; thermals vs clocks |
| GPU | Core/mem clock, power limit, **undervolt** curve; CUDA and games both used as the load, not only a synthetic screen |
| Cooling | Fan curves, pump, case airflow; noise vs temperature vs sustained clocks |

**Utilities** (Windows and/or Linux, whichever owns the box): HWiNFO / equivalent sensors, vendor BIOS AMD CBS / Intel-class menus, Afterburner-class GPU tools, `nvidia-smi` / `nvtop`, `sensors` / `s-tui`, stress-ng / OCCT-class / memtest. Read power, clocks, thermals, throttling, and errors — then change one knob.

This is the same loop as production: baseline → change → measure → keep or roll back. A turnkey PC is BIOS + silicon + OS + the profile for the job, not a driver installer and a wallpaper.

## OS internals when the fault lives there

I go as deep as the incident needs — Linux **kernel** and Windows **registry** included.

| Surface | Typical work |
|---------|----------------|
| Linux kernel | `dmesg` / journal, modules, sysctl, cgroups, traces; kernel cmdline and module params; rebuild or pin a kernel when the regression is there |
| Windows | Registry, services, driver stacks, Event Viewer; Fast Startup / mount issues; vendor tools that only exist on NT |
| Split | Decide whether the fault is firmware, hardware, kernel/driver, or userspace — then stay on that layer |

Breadth is the point for a hiring read: the work is **not** limited to cloud consoles and a terminal session on a VM. Bare-metal office boxes and a dual-boot workstation use the same diagnostic loop as a crashed production node.

## Disks and media

- Linux root on btrfs with COW snapshots
- Windows C:/D: mounted **on demand** (`ntfs3`); Fast Startup off when mounts misbehave
- Archive HDDs for media; KDE/mpv NVDEC for 4K HEVC (faster than the Windows path on the same GPU)

See [`../../diagrams/practice/home-lab/os-workstation.md`](../../diagrams/practice/home-lab/os-workstation.md).

## Keywords

Arch Linux, systemd, btrfs, snapper, UKI, Secure Boot, sbctl, dual boot, NVIDIA, CUDA, Wayland, NVMe, BIOS/UEFI, hardware diagnostics, kernel, Windows registry, workload tuning (LLM, SD, games), overclock, undervolt, HWiNFO, EXPO/XMP
