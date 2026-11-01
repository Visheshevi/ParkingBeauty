# ADR-0002: Three-stage build order, with the ML spike first

- **Status:** accepted
- **Date:** 2026-11-01

## Context

SPEC §14 builds the product in three stages so each one ends with something working end to end:

1. **Basic backend** (B0–B6): every core feature works and is tested through the API alone, on the local stack.
2. **Basic frontend** (F0–F6): a simple Flutter app on the modular structure, driving the Stage 1 API (server-blur path for posts).
3. **Remaining features** (R1–R8): on-device blur, cloud, safety, push, scale layer, Parkee, launch, ads.

Within Stage 1, the spec puts the ML model spike (B1) after all ten B0 foundation tasks. B1 is the project's biggest risk: it must find a plate/face/vehicle detector whose weights **and** training data are MIT/Apache-licensed and that exports to both TFLite (phone) and ONNX (server). If none exists, the privacy design and the upload pipeline change, which would affect B0 work too.

## Decision

- Keep the three-stage build order from SPEC §14 unchanged.
- **Reorder within Stage 1:** after **B0.1** (repo scaffold), run **B1.1–B1.4** (the model spike and ADR-0003), then continue with **B0.2–B0.10**, then B2 onward.
- B1 needs only Python + uv and the repo layout, not the docker stack or Go skeleton, so nothing it needs is skipped.

## Consequences

- We learn within days, not weeks, whether a viable model exists. If not, we stop and ask the owner before investing in the pipeline.
- `docs/PROGRESS.md` lists B1 directly after B0.1. SPEC §14 still shows the original order; this ADR takes precedence for that ordering only.
- B1's fixture images and model files are ready before B3 (upload pipeline) needs them, same as before.
