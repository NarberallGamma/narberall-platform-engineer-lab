# sd-compose

GPU compose pattern for AUTOMATIC1111-class WebUI. The full third-party image tree is not vendored here — only the **NVIDIA reservation** and data/output mounts.

Practice: [`../../../practice/home-lab/ai-lab.md`](../../../practice/home-lab/ai-lab.md). LoRA preset: [`../kohya-lora-preset.example.md`](../kohya-lora-preset.example.md).

Replace `image:` with the local build tag. Checkpoints and LoRAs live under `./data` (not committed).

## Keywords

Stable Diffusion, Docker, NVIDIA, CUDA, SDXL
