# Parking Beauty

A mobile app (iOS + Android) where people post photos of parked cars and others swipe to judge them: right for good parking, left for bad. Plates and faces are blurred before anything is shared. It also has an Explore feed, comments and, later, an AI assistant (Parkee).

> Status: early development (Stage 1, basic backend). See [docs/PROGRESS.md](docs/PROGRESS.md).

## Stack at a glance

| Part | Tech |
|---|---|
| App | Flutter (Dart 3), Riverpod, go_router, Melos monorepo |
| API + workers | Go (`chi`, `oapi-codegen`, `pgx` + `sqlc`, `goose`) on Google Cloud Run |
| ML service | Python 3.12, FastAPI, ONNX Runtime |
| Data | Postgres (Neon in the cloud), Cloudflare R2 for images, Pub/Sub for events |
| Auth / push | Firebase Authentication, Firebase Cloud Messaging |
| Flags | OpenFeature + flagd |

The full design is in [docs/SPEC.md](docs/SPEC.md). Key decisions are in [docs/adr/](docs/adr/).

## Prerequisites

Homebrew, Go, Python + [uv](https://docs.astral.sh/uv/), Docker (Docker Desktop or OrbStack), Node, jq and `firebase-tools`. The Flutter toolchain (fvm, Xcode, Android Studio) is needed from Stage 2.

## Getting started

```sh
make help   # list all commands
```

Most commands are still being built; `make help` shows them all, and each one says which step adds it.

## Repo layout

```
apps/            Flutter app shell + Widgetbook component catalog
packages/        Flutter packages, OpenAPI spec, ML models
services/        Go API/worker/agent, Python ML service
db/              goose migrations, sqlc queries
config/          feature flags, plans
deploy/, infra/  per-environment config, OpenTofu
tests/, tools/   E2E + load tests, CLI tools (pbctl, pbsim)
fixtures/        test images
docs/            spec, progress, ADRs
```

## License

See [LICENSE](LICENSE).
