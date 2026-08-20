# Diagram: OS workstation

```mermaid
flowchart TB
  subgraph metal [Hardware]
    PC[PC and small-office servers]
    BIOS[UEFI BIOS]
  end
  subgraph nvme_linux [Linux NVMe]
    ESP1[ESP vfat UKI]
    Btrfs[btrfs @ @home @log @pkg]
    Kern[kernel modules sysctl]
  end
  subgraph nvme_win [Windows NVMe]
    ESP2[ESP Windows BCD]
    NTFS[NTFS]
    Reg[registry services drivers]
  end
  PC --> BIOS
  BIOS --> FW[UEFI NVRAM BootOrder]
  ESP1 --> FW
  ESP2 --> FW
  Kern --> Work[LLM SD games software]
  GPU[RTX CUDA] --> Work
  Snap[snap-pair root+home+ESP rsync] --> Btrfs
  Snap --> ESP1
  sbctl[sbctl sign] --> ESP1
```

Practice: [`../../../practice/home-lab/os-workstation.md`](../../../practice/home-lab/os-workstation.md).  
Code: [`../../../practice/home-lab/reference/snap-pair/`](../../../practice/home-lab/reference/snap-pair/).
