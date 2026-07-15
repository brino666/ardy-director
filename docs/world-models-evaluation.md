# World models: evaluated and parked (2026-07-15)

Context for anyone tempted to build the interactive prompting engine (#1) on a
world model instead of the ARDY -> Unreal path. We looked. Here is what we found,
so you do not have to repeat it.

## The question

Google charges $250/month for AI Ultra, which includes Project Genie (Genie 3),
a real-time world model that turns a prompt into a navigable 3D world. Worth it?
Anything open we can self-host instead?

## What a world model actually is

A world model does **not** produce 3D geometry. It generates the **next video
frame** conditioned on your control inputs. You get the convincing illusion of a
3D world, but there is no mesh, no scene graph, nothing to export, light, or
keep. When the session ends the world is gone. This is the opposite of what the
ARDY -> Unreal pipeline gives us (real, persistent, renderable geometry).

Genie 3, World Labs' Marble, and OpenAI's Sora are all closed (API / subscription
only). Open alternatives: NVIDIA Cosmos-Predict (needs H100/H200), Oasis 500M
(Decart/Etched, Minecraft-domain), LingBot-World, GenieRedux.

## Spike: Oasis 500M on a V100 (Tesla V100-SXM2-32GB, sm_70)

We stood up the open Oasis 500M (etched-ai/open-oasis, weights via an ungated
mirror since Etched's repo is gated). It runs. Findings:

- **It works self-hosted.** Generated a 32-frame Minecraft clip at 640x360. The
  terrain, trees, sky, and even the HUD are all hallucinated by the 500M net.
- **Domain is Minecraft only** (that is all the open 500M was trained on).

### Resolution sweep (the surprising part)

We expected smaller frames to run faster (fewer latent tokens). They did not:

| Resolution | DDIM steps | gen FPS |
|-----------|-----------|---------|
| 640x360   | 10        | 0.57    |
| 320x180   | 10        | 0.51    |
| 200x120   | 10        | 0.50    |
| 120x80    | 10        | 0.49    |
| 200x120   | 4         | 0.60    |

**Resolution does not move the needle, and tiny frames are slightly slower.**
Dropping DDIM steps from 10 to 4 barely helped either. So the bottleneck is
**not** spatial attention / token count. It is fixed per-frame cost: the ViT-VAE
decode per frame, the autoregressive loop, and kernel-launch overhead that
dominates when the GPU is under-utilized at small token counts. That fewer
diffusion steps barely helped points at the VAE decode as a large fixed chunk.

Quality also degrades below ~320x180: the picture holds at 320p, falls apart at
200x120 and smaller.

### What would be needed for playable (>=5 FPS) real-time

- flash-attention: the realtime-oasis fork requires `flash_attn`, which does not
  build on Volta (needs sm_80+ / Ampere+). Blocked on our current GPUs.
- torch.compile, fp16/quantization, a lighter VAE, or Ampere+/H100 hardware.

## Verdict

**Parked.** On our hardware Oasis is a ~0.5 FPS, 360p, Minecraft-only research
toy. Do not pay $250/month for Genie either: it produces no reusable assets.
For directable, renderable, keepable 3D, the ARDY -> Unreal pipeline (#2) is the
right bet. Revisit world models if we get Ampere+/H100-class hardware.
