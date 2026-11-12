# Daaymn demo-profile photos (AI-generated)

69 photos in `ai/`, 23 made-up adults, 3 each: Alex, Ben, Chris, David, Ethan, Sam, Fiona, Grace, Hannah, Isla, Jessica (made 2026-10-10) and Thandi, Marco, Lerato, Kyle, Priya, Sipho, Amy, Johan, Zara, Tom, Naledi, Mia (made 2026-11-12, same recipe). None depicts a real person.

## How
Generated locally on this machine's GPU with free, open models (no paid service, no spend):
- **Image model:** RealVisXL V5.0 (`SG161222/RealVisXL_V5.0`, SDXL fine-tune), run with Hugging Face `diffusers`.
- **Face consistency:** IP-Adapter plus-face SDXL (`h94/IP-Adapter`, `ip-adapter-plus-face_sdxl_vit-h`) holds photos 2 and 3 to the face in photo 1.
- **Finish:** upscaled to 1200×1600 with a low-strength img2img pass; saved as JPEG.
- Script: `/mnt/storage/aiphotos/gen.py` (prompts, seeds and negatives are in it).

## Licence / terms
- RealVisXL V5.0: CreativeML Open RAIL++-M licence. It permits commercial use of the outputs and does not claim rights over them; use restrictions apply (no illegal, harmful, deceptive or impersonating use, no minors, no sexual content). Daaymn's use as demo profile photos of fictional adults in an app and its store listing fits. Licence text: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md (the base-model licence it inherits); model page: https://huggingface.co/SG161222/RealVisXL_V5.0
- h94/IP-Adapter: Apache-2.0 (commercial use allowed).
- Please verify the licence pages above yourself before relying on this note for legal purposes; this file is not legal advice.

## Checked by eye
Same face across each person's 3 photos, all fully clothed, adult-looking, no watermarks or logos, 1200×1600. Photos were re-rolled where lettering showed in the background. Small background details (distant signs, hands) can still look slightly off at full zoom.

## Re-made 2026-10-10 (older faces)
Grace, Hannah, Isla and Jessica (12 files) were re-made because they read 18–20. Same recipe and `gen.py`; their prompts now add adult-face cues (young adult woman in her mid twenties, adult facial structure) and a negative for teen/girl looks, stated ages Grace 27, Hannah 26, Isla 28, Jessica 26, seed 2000. Same names, 1200×1600. Checked by eye: each person's 3 photos are consistent, all fully clothed, faces read mid/late 20s. The first versions are kept in `/mnt/storage/aiphotos/out_young_backup/`.

## Upload
Merging a change under `tool/seed-photos/` to master runs `.github/workflows/upload-demo-photos.yml`, which upserts every file in `ai/` to the public bucket `seed-photos/ai/` and checks each public URL answers 200. `test/demo_photos_test.dart` fails if a photo the web demo uses is missing here.
