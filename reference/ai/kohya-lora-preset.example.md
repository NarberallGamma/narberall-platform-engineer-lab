# Kohya LoRA preset (generic)

Practical starting point for a **small character or style set** (tens of images) on a 16 GB GPU. Dataset names and checkpoint filenames stay local.

Practice: [`../../practice/home-lab/ai-lab.md`](../../practice/home-lab/ai-lab.md). Compose: [`sd-compose/`](sd-compose/).

## Paths (inside the training container)

- **Pretrained model:** path to an SD1.5 or SDXL `.safetensors` checkpoint
- **Image folder:** captioned dataset (`image.png` + `image.txt`)
- **Output / logging:** `/app/output/lora` and `/app/output/logs`
- **Caption extension:** `.txt`

## SD1.5 profile

| Knob | Value |
|------|--------|
| LoRA type | Standard |
| Save / mixed precision | fp16 |
| Train batch size | 1 |
| Gradient accumulate | 1 (2 if VRAM is tight) |
| Epoch | 10 (character: often 8–12) |
| Save every N epochs | 1 |
| Max train steps | 0 (let epochs finish) |
| Optimizer | AdamW8bit |
| LR scheduler | cosine |
| UNet LR | 0.0001 |
| Text encoder LR | 0.00005 |
| LR warmup | 10% |
| Max grad norm | 1 |
| Max resolution | 512,512 |
| Enable buckets | ON (256–1024, step 64, no upscale) |
| Network Rank / Alpha | 16 / 16 |
| Cache latents | ON |
| Gradient checkpointing | ON if VRAM is tight |
| xformers | ON |
| Shuffle caption | ON |
| Keep n tokens | 1 |
| Clip skip | 2 for anime SD1.5; 1 if quality drops |

## SDXL profile (instead of SD1.5)

- SDXL ON
- Max resolution 1024,1024
- Clip skip 1
- Text encoder LR 0 or 0.00001
- Rank/Alpha 16/16 or 32/16

## Ops notes

- Pick the **best sample epoch**, not the last file. Keep every-epoch saves.
- Character LoRA: if samples still improve, add +3…+5 epochs; if style overfits, stop earlier.
- Export: `.safetensors` + training json. Do not commit datasets or personal captions.

## Keywords

Kohya, LoRA, SD1.5, SDXL, AdamW8bit, CUDA
