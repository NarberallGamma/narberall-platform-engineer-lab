# libvirt guest builder

**Business first:** guest images are built from a **toolbox container** with qemu/libvirt, not from a laptop that happens to have `virt-install`. Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I used Ubuntu bionic, deadsnakes Python 3.8, the libvirt/qemu stack, and an idle `tail -f /dev/null` CMD so the box stays up as a workdir. Timezone in this copy is `Etc/UTC`. Workdir is `/guest-builder`.

```text
libvirt-guest/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| qemu-kvm + libvirt-bin + python3-libvirt | Guest-builder package set, not a slim runtime |
| `COPY . /guest-builder` | Original tool body lived next to this file |
| Idle CMD | Toolbox, not a one-shot build entrypoint |

Guest scripts and preseed files that the original `COPY .` expected are **not** in git. The published file is the package list and workdir. `docker build` succeeds; there is no guest recipe inside the image.

```bash
docker build -t example.registry/libvirt-guest:local -f Dockerfile .
docker run --rm -it --privileged example.registry/libvirt-guest:local bash
```

`--privileged` / device mounts are a host choice for real libvirt use and are not encoded here.

**Keywords:** libvirt, qemu, guest builder, Ubuntu bionic
