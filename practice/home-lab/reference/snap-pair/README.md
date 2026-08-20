# snap-pair

Paired **root + home** snapper snapshots plus an ESP (`/boot`) rsync, because vfat is not in btrfs. Same `pair=` userdata on both configs so restore is one unit.

On a real host the binaries live under `/usr/local/bin` and the log under `/var/log/snap-pair.log`. This directory is the **example** tree: `common.sh` next to the scripts (or `SNAP_PAIR_LIB`).

Practice: [`../../os-workstation.md`](../../os-workstation.md).

```bash
sudo ./snap-pair.example.sh "before-kernel"
sudo ./snap-boot-backup.example.sh list
```

`/boot` is not in snapper. Rollback without the ESP copy returns `@`/`@home` but not the UKI.

## Keywords

btrfs, snapper, ESP, rsync, systemd
