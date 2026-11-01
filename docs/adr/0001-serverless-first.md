# ADR-0001: Serverless-first (Cloud Run + Neon + Pub/Sub)

- **Status:** accepted
- **Date:** 2026-11-01

## Context

Parking Beauty is built by one owner with a hard cost ceiling (SPEC §3.1: $10/month budget with a billing kill switch). Traffic will be near zero for a long time and spiky later. There's no one to run servers or clusters.

## Decision

- Run every backend service as a stateless container on **Google Cloud Run** (`us-central1`), scaling to zero, with max-instance caps.
- Use **Neon** serverless Postgres as the only database, **Google Pub/Sub** (fed by a transactional outbox) for events, and one **Cloud Scheduler** job hitting `worker /jobs/tick` for scheduled work.
- Use **Cloudflare R2** for images (free egress) and Cloudflare's free plan as CDN/WAF.
- Every vendor sits behind a small interface (`EventBus`, `ObjectStore`, `AuthVerifier`, …), with a fake or emulator for tests.

## Consequences

- Near-zero cost at MVP scale, and no servers to patch or babysit.
- Cold starts on the first request after idle (Go keeps them under ~1s). Setting `api` min-instances to 1 is an owner decision (SPEC §16.6).
- Local development needs emulators (Pub/Sub, Firebase Auth) and S3-compatible storage (SeaweedFS) in docker-compose.
- **Portability fallback:** everything is plain OCI containers + Postgres + S3 API + Redis protocol, configured by environment variables. Moving to a self-hosted Kubernetes cluster would need only a different `EventBus` implementation (e.g. NATS) and deploy manifests, not changes to business logic.
