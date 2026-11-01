# CLAUDE.md — Parking Beauty

Parking Beauty is a mobile app (Flutter, iOS + Android) where people upload photos of parked cars, blurred on the phone, and others swipe to judge them as good or bad parking. It also has an Explore feed, comments, an AI assistant (Parkee) and, later, ads. The backend is serverless Go on Google Cloud Run, plus a Python ML service.

## Source of truth

- **`docs/SPEC.md`** is the full product and technical spec. Read the sections relevant to your current task before writing code. When the spec and this file disagree, the spec wins.
- **`docs/PROGRESS.md`** holds the current stage and step, the task checklist, "Next up", and session notes. **Read it at the start of every session.**

## Build order (SPEC §14, ADR-0002)

1. **Stage 1, basic backend (B0–B6):** every core feature works and is tested through the API alone. Local stack, Postgres only.
2. **Stage 2, basic frontend (F0–F6):** a simple Flutter app on the modular structure, driving the Stage 1 API. Posts use the server-blur path.
3. **Stage 3, remaining features (R1–R8):** on-device blur, cloud, safety, push, scale layer, Parkee, launch, ads.

"Basic" means the simplest **correct** version. Don't skip tests, security or the module/flag structure to go faster. Don't build Stage 3 features early. Keep the interfaces that let them slot in later (e.g. the `Cache` interface with a no-op/Postgres implementation in Stage 1).
- **`docs/adr/`** holds architecture decision records. Any deviation from the spec needs a new ADR (short: context, decision, consequences).

## Working agreement

1. **One task at a time.** Work only on the current task in `docs/PROGRESS.md`. Don't start the next task or step without the owner's go-ahead.
2. **Plan before coding** at the start of each step (B0, B1, F0, …) and for any task touching more than ~5 files: list the steps, the files and your open questions, then wait for approval.
3. **Ask, don't guess,** when a decision is the owner's: accounts, costs, product behaviour, anything listed in §16 of the spec. For small technical ambiguities, pick the simplest option, write an ADR, and continue.
4. **Tests come with the code.** A task is done only when its tests pass locally (`make test`, plus `make e2e` when the backend changed).
5. **Commit after each task.** Use Conventional Commits (`feat(judge): …`, `fix(api): …`), on a branch named `<task-id>-<slug>` (e.g. `b0.2-local-stack`).
6. **End of task / session:** tick the box in `docs/PROGRESS.md`, update "Next up", and add a dated line to "Session notes" (what was done, any gotchas).

## About the owner

- Background: C++/Java, warehouse automation, now manages a data science team. **New to Flutter/Dart.**
- When you introduce a Flutter or Dart pattern for the first time (Riverpod providers, `freezed`, isolates, `go_router`, widgets rebuilding), add a short code comment and a 2–3 line explanation in your summary.
- Prefers direct, concise summaries: what changed, how it was verified, and what's next.

## Commands (created in step B0; keep this list current)

```
make dev        # start the local stack (docker compose) + api/worker with live reload
make test       # all unit + integration tests (Go, Python, Flutter)
make e2e        # headless end-to-end suite against the local stack
make gen        # regenerate code from OpenAPI, sqlc, freezed/json_serializable, tokens
make migrate    # apply goose migrations to the local DB
make lint       # go vet + staticcheck, ruff, flutter analyze, import-boundary check
make seed       # deterministic fixture data (TARGET=dev|test, never prod)
make run-dev    # PB Dev app against the local stack     (VS Code: "PB Dev")
make run-test   # PB Test app against the test env       (VS Code: "PB Test")
make run-prod   # prod app, release mode; read-only checks (VS Code: "Parking Beauty (prod, release)")
make build-test / build-prod   # installable builds; build-prod is normally CI only
fvm flutter ... # always use fvm (the project pins its Flutter version)
melos run ...   # Dart monorepo scripts
```

## Repo map (see §13 of the spec for the full layout)

```
apps/mobile, apps/widgetbook      Flutter app shell, component catalog
packages/flutter/*                pb_tokens, pb_ui, pb_core, pb_api, features/*
services/api                      Go: cmd/api, cmd/worker, cmd/agent, internal/*
services/ml-svc                   Python FastAPI + ONNX Runtime
packages/api-spec                 openapi.yaml (source of truth for the API)
packages/ml-models                TFLite + ONNX models, MODEL_CARD.md
db/migrations, db/queries         goose migrations, sqlc queries
config/flags, config/plans.json   feature flags (flagd) and plan entitlements
tests/e2e, tests/agent-evals      headless E2E suite, Parkee evals
tools/pbctl, tools/pbsim          CLI client, simulated phone uploader
infra/tofu                        OpenTofu (cloud infrastructure)
```

## Conventions (condensed from §15 of the spec)

- **API:** change `openapi.yaml` first, then run `make gen`. Never hand-edit generated Go or Dart code.
- **Database:** every change is a **new** goose migration. Never edit a migration that's already applied. SQL lives in `db/queries` (sqlc). No string-built SQL.
- **Vendors:** every external vendor sits behind an interface, with a fake or emulator for tests.
- **IDs:** UUIDv7, generated in the app. All times in UTC.
- **Logging:** every handler and consumer is idempotent and logs `trace_id`. Structured JSON logs only.
- **Feature flags (§1.3):** every user-facing feature has a flag. Use only `features.*` / `entitlements.*` (Go) and `FeatureGate` / providers (Dart). No ad-hoc booleans, env-var switches or `isPremium` checks.
- **Flutter:**
  - Feature packages never import each other.
  - UI comes only from `pb_ui` components. If one is missing, add it to `pb_ui` with a Widgetbook entry and a golden test.
  - No hard-coded strings (use ARB), colours or sizes (use tokens), or switches (use `AppConfig` / flags).
  - Heavy work runs in isolates.
- **Headless first:** every feature must be fully testable through the API (§12.5). No business logic that lives only in the app.
- **Dependencies:** add one only with a one-line justification in the commit or PR. Prefer the stack in §3 of the spec.

## Hard rules: never do these

- Never sign up for, enable or configure a **paid** service or tier, add a payment method, or raise a cost limit or budget (§3.1). Ask the owner.
- Never run anything against **prod** (E2E, seeding, load tests, migrations, scripts), or `tofu apply` / `gcloud` commands that change cloud resources, without explicit owner approval in this session. Default target is always `dev`.
- Never hard-code an environment's URL, project ID or key in code. It belongs in `config/env/*.json` (app) or `deploy/env/*.yaml` / Secret Manager (backend), with the same keys in all environments (SPEC §12.7).
- Never read, print or commit secrets (`.env*`, service-account keys, tokens). Use `.env.example` with placeholders.
- Never use AGPL code or models (e.g. Ultralytics YOLO weights). Record every model's license in `MODEL_CARD.md`.
- Never add an auth bypass. Tests use real tokens from the Firebase Auth emulator.
- Never send personal data (emails, raw photos, plate text) to an external LLM.
- Never weaken a test to make it pass. Fix the code, or explain why the test is wrong and ask.
- Never edit `docs/SPEC.md` without the owner asking. Propose changes in your summary instead.
- Always create a new branch for a feature. Never develop anything on main. 

## Definition of done (every task)

- [ ] The code follows the conventions above, and `make lint` is clean
- [ ] Unit/integration tests are added and passing (`make test`)
- [ ] The relevant E2E scenarios from §12.5 are added/passing (`make e2e`) if the backend changed
- [ ] OpenAPI and generated code are in sync (`make gen` produces no diff)
- [ ] New features have a flag entry in `config/flags` and the §1.3 registry row
- [ ] `docs/PROGRESS.md` is updated (checkbox, Next up, session note)
- [ ] Committed on the task branch with a Conventional Commit message
