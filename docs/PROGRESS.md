# Parking Beauty — Progress

> Claude reads this file at the start of every session and updates it at the end of every task.
> Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (add a reason)
> Build order (SPEC §14): **Stage 1 basic backend → Stage 2 basic frontend → Stage 3 remaining features.**
> "Basic" = the simplest correct version. No shortcuts on correctness, security or tests.

## Current

- **Stage:** 1 — Basic backend
- **Step:** B1 — ML model spike (runs right after B0.1, per ADR-0002)
- **Next up:** B1.1 Model survey (needs `uv` installed)
- **Blocked on owner:** —

---

## Owner tasks (things Claude can't do)

| When | Task | Cost |
|---|---|---|
| B0 | Create the GitHub repo; install the tools (Homebrew, Go, Python/uv, Docker/OrbStack, Node, jq, firebase-tools) | Free |
| F0 | Install fvm/Flutter, Xcode + CocoaPods, Android Studio + an emulator; create the Firebase **dev** project | Free |
| F1 | (Optional now, required by R2) Apple Developer account for Sign in with Apple on a real device + TestFlight | $99/yr |
| R2 | Google Cloud + billing account (card), Neon, Cloudflare, Upstash, R2 accounts; buy a domain; approve the budget + kill switch apply | ~$12/yr domain |
| R6 | Gemini API key (free tier); accept its data terms | Free |
| R7 | Google Play developer account; register a DMCA agent; publish ToS/Privacy | $25 once + $6 |
| R8 | AdMob account, ad units, blocked categories, `app-ads.txt` | Free |

---

# Stage 1 — Basic backend (local, headless)

Everything is tested through the API with `pbctl`, `pbsim` and `make e2e`. **Postgres only:** no Redis, deck pools, replicas or rate limits yet (those come in R5).

> Order within Stage 1 (ADR-0002): **B0.1 → B1 → B0.2–B0.10 → B2 …**

## B0 — Foundations (part 1)

- [x] **B0.1 Repo scaffold:** directories per SPEC §13, `.gitignore`, `.editorconfig`, `README.md`, `.env.example`, Makefile skeleton. ADR-0001 (serverless-first) and ADR-0002 (three-stage build order).

## B1 — ML model spike (decision gate)

- [ ] **B1.1** Survey **MIT/Apache-licensed** plate + vehicle detectors (e.g. `open-image-models` / `fast-alpr`). Check the licenses of both the weights and the training data. Write the shortlist in `packages/ml-models/MODEL_CARD.md`.
- [ ] **B1.2** Build `/fixtures/images` (~40 images: plates, faces, no car, night, angled, NSFW placeholders). Use only the owner's own photos or CC0/public-domain images, with each source recorded.
- [ ] **B1.3** Export to **ONNX** and **TFLite**; parity script (IoU ≥ 0.9, confidence within ±0.05); measure desktop inference time.
- [ ] **B1.4** ADR-0003: model choice, thresholds, sizes. **If no viable model, stop and ask the owner.**

## B0 — Foundations (part 2)

- [ ] **B0.2 Local stack:** `docker-compose.yml` with Postgres, SeaweedFS, the Pub/Sub emulator, the Firebase Auth emulator, otel-lgtm, `tick-runner`. `make dev` up/down.
- [ ] **B0.3 OpenAPI + codegen:** `openapi.yaml` with `/healthz`, `/readyz`, `/v1/bootstrap`; `oapi-codegen` (Go) + the `dart-dio` generator script (output unused until F0); `make gen`.
- [ ] **B0.4 Go skeleton:** `cmd/api`, `cmd/worker`, `cmd/agent` (stub). Env config, `slog` JSON, OpenTelemetry, graceful shutdown, RFC 9457 errors, request-ID/trace middleware.
- [ ] **B0.5 Database baseline:** goose + sqlc, `Writer()`/`Reader()` (both point to the primary for now), UUIDv7, and migrations for `users`, `outbox`, `processed_events`, `audit_log` (monthly partitions), `aggregation_watermarks`.
- [ ] **B0.6 Events + scheduling:**
  - `EventBus` interface with a Pub/Sub (emulator) implementation and an outbox writer.
  - After-commit publish + `outbox_sweeper`.
  - Worker push endpoint with idempotent consumer helpers.
  - `/jobs/tick` with advisory locks.
- [ ] **B0.7 Feature flags + entitlements (SPEC §1.3):**
  - OpenFeature + flagd in-process, with `config/flags/flags.flagd.json` (all registry flags) and `config/plans.json`.
  - `features` / `entitlements` packages, evaluation-context middleware, `/v1/bootstrap`, flag-schema validation, `pbctl flags` (local).
- [ ] **B0.8 E2E harness:**
  - `/tests/e2e`, the `pbctl` skeleton.
  - `/test/*` routes with a production guard, injectable `Clock`, `test_outbox` + `FakePushSender`, `/test/reset`, `/test/events/drain`, `make e2e`, `make seed`.
  - Tests: E19, E25, E35, E36.
- [ ] **B0.9 Environment config (SPEC §12.7):** `APP_ENV` = `dev`/`ci`/`test`/`prod` with startup validation; `.env.example` → `.env` via `make dev`; `deploy/env/{test,prod}.yaml` placeholders; `flags.base` + `flags.{dev,test,prod}` overrides merged by a script; the Makefile refuses `TARGET=prod` for e2e/seed/load.
- [ ] **B0.10 CI:** GitHub Actions on every PR: lint, unit, integration (testcontainers), `make e2e`, Schemathesis, `make gen` diff check, flag-schema validation.

**Done when:** `make dev` boots; `/healthz` shows a trace in local Grafana; `make e2e` is green in CI.

## B2 — Auth and profiles API

- [ ] **B2.1** `AuthVerifier` (Firebase JWKS, emulator-aware) + auth middleware feeding the flag evaluation context.
- [ ] **B2.2** `users` upsert on first call; handle (`citext` unique); 13+ gate + EULA acceptance.
- [ ] **B2.3** `/me` GET/PATCH/DELETE; `user.deleted` consumer with the deletion cascade.
- [ ] **B2.4** `pbctl login` / `me`. E2E: E1, E16, E18.

## B3 — Upload pipeline API

- [ ] **B3.1** `ml-svc`: FastAPI `/detect`, `/moderate/image`, `/moderate/text`; models baked into the image; `pytest`; OTel. Added to compose.
- [ ] **B3.2** `ObjectStore` (S3 API → SeaweedFS); `POST /v1/uploads` presign with size/type limits; quarantine cleanup task.
- [ ] **B3.3** `posts` table; `POST /v1/posts` with `Idempotency-Key`; `post.created` via the outbox; `GET /v1/posts/{id}`, `DELETE /v1/posts/{id}`.
- [ ] **B3.4** Image pipeline consumer:
  - govips re-encode
  - detect + server blur
  - NSFW moderation
  - pHash duplicate check
  - variants + BlurHash
  - status + `post.published` / `post.rejected` events
- [ ] **B3.5** Both blur modes: `blur_source: device` (re-check) and `server` (full blur + immediate quarantine delete); metrics.
- [ ] **B3.6** `pbsim` CLI (`--no-blur`, `--server-blur`, `--keep-exif`).
- [ ] **B3.7** Golden pipeline test (0 detections above 0.2 on every fixture). E2E: E2–E6, E17, E20, E22, E23.

## B4 — Judge API

- [ ] **B4.1** `votes` (hash-partitioned), `views`, `post_stats`; `aggregate_counters` (watermark) + `reconcile_counters` tick tasks.
- [ ] **B4.2** Vote / undo / batched views endpoints.
- [ ] **B4.3** Simple deck: `GET /v1/deck`, a Postgres query with fresh + random mix; excludes own, voted and recently served (`deck_served` table, 24h). Returns `items[]` (`post`; `ad_slot` defined in the schema, never generated while `ads` is off).
- [ ] **B4.4** `pbctl deck` / `vote`. E2E: E7 (basic mix), E8, E9.

## B5 — Explore API

- [ ] **B5.1** Ranking functions (Wilson lower bound, hot score) with unit tests; `recompute_ranking` tick task.
- [ ] **B5.2** `GET /v1/feed` (sorts, windows, country/city filters, keyset pagination); `GET /v1/locations`. No caching yet.
- [ ] **B5.3** `pbctl feed`. E2E: E10.

## B6 — Comments API

- [ ] **B6.1** Comment endpoints (list, create, reply, edit within 10 min, soft delete), synchronous blocklist.
- [ ] **B6.2** `comment.created` → async moderation via `ml-svc` (pending → published / needs_review / rejected); notification consumer writes to `test_outbox` only.
- [ ] **B6.3** `pbctl comment`. E2E: E11.

**Stage 1 done when:** the whole core loop works with `pbctl` + `pbsim` alone (sign up → post → swipe → explore → comment), and `make e2e` is green in CI.

---

# Stage 2 — Basic frontend (Flutter, against the local stack)

A simple but well-structured app that drives the Stage 1 API. It's built on the modular structure from SPEC §1.2 from day one, so later features slot in. Posting uses the **server-blur path** until R1. **Dev builds only; no external users.**

## F0 — App shell and design system v1

- [ ] **F0.1** Melos monorepo with fvm-pinned Flutter; packages `pb_tokens`, `pb_ui`, `pb_core`, `pb_api` (generated), `features/*` stubs, `apps/mobile`, `apps/widgetbook`; import-boundary lint.
- [ ] **F0.2** `tokens.json` (SPEC §1.1 colours) → generated tokens + `ThemeExtension`; Nunito bundled. Components: `PbScaffold`, `PbCard`, `PbButton`, **`TrafficLightButton`**, `EmptyState`, `ErrorState`, `LoadingSkeleton`, each with a Widgetbook entry + goldens.
- [ ] **F0.3** `pb_core`: `freezed` `AppConfig`, bootstrap → cache → bundled defaults, `FeatureModule`, `FeatureGate`, `featureProvider`, `entitlementsProvider`, `ItemRendererRegistry`, ARB l10n.
- [ ] **F0.4** App shell: `go_router`; config-driven tabs (Judge, Explore, Post, Parkee [flag off], Profile) with placeholder screens; dio with auth/retry/`traceparent` interceptors; refresh on foreground; `.env`-style config pointing at the local API.
- [ ] **F0.5** Firebase dev project: `flutterfire configure`, Crashlytics, Remote Config (maintenance mode, minimum version, API base URL). Runs on both simulators.
- [ ] **F0.6 Build flavors (SPEC §12.7):**
  - `flutter_flavorizr` `dev`/`test`/`prod` (app ID suffix, name, ribbon icons).
  - `config/env/{dev,test,prod}.json` + `--dart-define-from-file`; `dev.local.json` git-ignored.
  - Per-flavor Firebase options (test/prod use placeholders until R2/R7).
  - Startup safety check, env banner + debug menu (compiled out of prod).
  - `make run-dev`/`run-test`/`run-prod`, `make build-test`/`build-prod`; `.vscode/launch.json` configurations.
  - CI check that all env files have the same keys.
  - ✅ PB Dev and a placeholder PB Test install side by side on a simulator.
- [ ] **F0.7** Flutter CI: analyze, unit/widget/golden tests, boundary lint, all three flavors build.

## F1 — Auth and onboarding

- [ ] **F1.1** Sign-in screen (Apple, Google; email/password against the emulator in dev).
- [ ] **F1.2** Onboarding: handle, age (13+), EULA acceptance.
- [ ] **F1.3** Profile screen: handle, my posts, sign out, delete account (with confirmation).

## F2 — Judge screen

- [ ] **F2.1** `pb_ui`: `SwipeDeck`, `PostCard` (full), `StatChip` (Widgetbook + goldens).
- [ ] **F2.2** Judge feature: deck from `/v1/deck`, swipe + traffic-light buttons (glow while dragging, tint, haptics), optimistic votes with simple retry, undo, prefetch at 5 cards left, image preloading.
- [ ] **F2.3** Anonymous browsing with a sign-in prompt after 5 swipes; view events batched every 10s. Check 60fps on a mid-range Android.

## F3 — Explore and post detail

- [ ] **F3.1** Explore: sort and filter controls (from `/v1/locations`), compact `PostCard`, infinite scroll.
- [ ] **F3.2** Post detail: full image, stats, my vote, link to comments.

## F4 — Post flow (basic, server blur)

- [ ] **F4.1** Camera/picker, resize to 2048px + EXIF strip (in an isolate), optional location → precision-4 geohash, caption with wording hint.
- [ ] **F4.2** Upload: presign → PUT with retry → `POST /v1/posts` (`blur_source: server`) → status polling → success/rejection screens. Show a visible "dev build: server blur" banner until R1.

## F5 — Comments UI

- [ ] **F5.1** `CommentTile`; list, reply, edit (10-min window), delete; "pending" state for your own comments.

## F6 — App smoke tests

- [ ] **F6.1** One Patrol/Maestro flow against the local stack: sign in → swipe → explore → post → comment.
- [ ] **F6.2** Golden tests for the Judge screen and traffic-light states; check that a flag turned off hides its tab.

**Stage 2 done when:** the smoke flow passes on the iOS simulator and the Android emulator.

---

# Stage 3 — Remaining features (in this order)

## R1 — On-device blur (required before any external testers)

- [ ] **R1.1** TFLite detector + ML Kit faces in an isolate; lazy model loading; timing metrics.
- [ ] **R1.2** Review screen: auto boxes (plate boxes can't be removed), add/resize boxes, pixelation, no-car / blurry / dark warnings.
- [ ] **R1.3** `blur_source: device` by default; server-blur fallback only on slow or unsupported devices (first-use benchmark); remove the dev banner.
- [ ] **R1.4** Model parity test in CI; the E2/E3 golden checks pass for app-blurred uploads.

## R2 — Cloud test environment (owner approval needed)

- [ ] **R2.1** (Owner) accounts + billing. Claude writes `docs/limits.md` (current free-tier limits).
- [ ] **R2.2 FIRST:** OpenTofu: **$10 budget, alerts at 50/90/100%, billing kill switch.** Verify that a test alert arrives.
- [ ] **R2.3** OpenTofu:
  - Artifact Registry
  - Cloud Run (`api`, `worker`, `ml-svc`, `agent`) with max-instance caps
  - Pub/Sub topics, subscriptions and dead-letter topics
  - the Scheduler tick
  - Secret Manager, service accounts, IAM/OIDC
- [ ] **R2.4** Neon + branching; R2 buckets + lifecycle rules; Cloudflare DNS/proxy/WAF; flags bucket + polling; Firebase `parking-beauty-test` project.
- [ ] **R2.5** GitHub Actions deploy to `test` on merge to `main` (Workload Identity Federation, no keys); nightly E2E on a fresh Neon branch.
- [ ] **R2.6** `test` flavor wired to the test environment (`config/env/test.json`, Firebase test project); `make run-test` works on a real phone, installed side by side with the dev build.

## R3 — Safety and admin

- [ ] **R3.1** Reports + moderator actions + audit log; alert at ≥ 3 reports.
- [ ] **R3.2** Blocks, filtered everywhere.
- [ ] **R3.3** Public removal requests + Turnstile.
- [ ] **R3.4** Admin endpoints; Appsmith app (exported JSON in the repo).
- [ ] **R3.5** App: report/block UI; ToS/EULA/Privacy screens.
- [ ] **R3.6** E2E: E12, E13, E14. All Apple 1.2 requirements can be demonstrated.

## R4 — Push notifications

- [ ] **R4.1** FCM device-token registration; real `PushSender`; notification consumers with batching.
- [ ] **R4.2** `config_changed` data message → the app refreshes bootstrap; post status via push instead of polling.

## R5 — Scale, caching and DB protection (SPEC §4.2)

- [ ] **R5.1 Redis cache layer:** Upstash (Valkey locally) behind the existing `Cache` interface. Feed pages, post cards, served sets, entitlements; `singleflight`, jittered TTLs, stale-while-revalidate, serve-stale-on-error, negative caching, versioned keys.
- [ ] **R5.2 Invalidation:** event-driven cache invalidation (`post.removed`/`published`, `user.deleted`, `block.created`, entitlement changes); `my_vote` merged with one batched query.
- [ ] **R5.3 Edge + conditional requests:** Cloudflare cache rules (immutable images, anonymous feed/locations/bootstrap with `stale-while-revalidate`); `ETag`/`304` on bootstrap and feed; client backoff with jitter + `Retry-After`.
- [ ] **R5.4 Deck pools** (`refresh_deck_pools`) + the full 50/30/20 mix.
- [ ] **R5.5 DB protection:**
  - pool-size × max-instances check in OpenTofu
  - statement/lock/idle timeouts
  - separate read/write/job pools
  - read-replica routing + read-your-writes
  - `EXPLAIN` query-budget checks in CI
  - `views` daily partitions + rollup/drop
- [ ] **R5.6 Buffered writes:** `vote_write_buffer` flag (Redis stream → batched upsert), buffered views (HLL + stream), automatic fallback to direct writes.
- [ ] **R5.7 Load shedding:** rate limits (`redis_rate` + Postgres fallback), Cloudflare rate rules, adaptive degraded modes (cache-only reads, auto-buffered votes, pause non-essential jobs) with hysteresis, `read_only_mode` flag, upload backpressure.
- [ ] **R5.8 Push at scale:** FCM topic for `config_changed`, batched sends, per-user throttles, invalid-token cleanup.
- [ ] **R5.9 App:** offline vote queue (`drift`); ETag-aware bootstrap/feed client.
- [ ] **R5.10 Tests and proof:**
  - Compose runs 2× api/worker + toxiproxy.
  - E2E: E7 (full mix), E15, E21, E24, E38–E42.
  - Cache hit-ratio metrics + alerts.
  - k6 steady/spike/soak profiles on the test environment (temporary budget increase approved by the owner) meet the SPEC §4.2.9 targets.

## R6 — Parkee (behind the `parkee` flag)

- [ ] **R6.1** `agent` service: SSE, `agent_config` + admin endpoint, `/v1/agent/config`, conversation storage + 30-day purge.
- [ ] **R6.2** `LlmProvider`: Gemini + `FakeLlmProvider`.
- [ ] **R6.3** Tools: `search_feed`, `get_post`, `get_comment_summary`, `get_my_stats`, `get_my_post_status`, `draft_caption`.
- [ ] **R6.4** Confirmation flow (`create_report` → confirm/cancel/expire).
- [ ] **R6.5** Photo rating (on-device blur → server re-check → LLM; nothing saved as a post).
- [ ] **R6.6** Safety: moderation on input and output, delimited untrusted data, per-plan quotas, global budget + "nap" state.
- [ ] **R6.7** Parkee UI: `ChatBubble`, `SuggestionChip`, `ConfirmActionCard`, rating card, streaming.
- [ ] **R6.8** Agent evals (~50 golden conversations; fake LLM in CI, real one nightly). E2E: E27–E32.

## R7 — Launch hardening

- [ ] **R7.1** k6 load test (200 RPS deck/feed) **within the budget cap**.
- [ ] **R7.2** Dashboards + alerts (dead letters, outbox age, error rate, budget).
- [ ] **R7.3** Analytics events + funnels (swipes/session, viewer → poster, D1/D7).
- [ ] **R7.4** Prod environment: `infra/tofu/envs/prod` (own budget + kill switch), Firebase/Neon/R2 prod, `prod` flavor wired up, **release-tag deploy with a required reviewer**, test → prod image promotion (no rebuild). Verify the prod build refuses non-prod hosts.
- [ ] **R7.5** Firebase App Check on upload/vote/comment.
- [ ] **R7.6** Store assets, privacy labels / Data Safety form, ToS/Privacy on Cloudflare Pages, TestFlight + Play internal testing.
- [ ] **R7.7** Game day on the test environment.

## R8 — Ads (after launch, once retention is healthy)

- [ ] **R8.1** Server-side ad slots (flags + `ad_free` entitlement + frequency flags).
- [ ] **R8.2** Ads module: AdMob initialised **only** when enabled; native `AdCard`; preload; `no_fill`; Skip-only deck behaviour.
- [ ] **R8.3** UMP consent + ATT prompt.
- [ ] **R8.4** House ads + admin + `POST /v1/events/ads`.
- [ ] **R8.5** E2E: E26, E33, E34. Then a 50/50 rollout; keep ads only if D7 retention drops ≤ 5%.

## Later (not scheduled)

- [ ] Subscriptions: RevenueCat, webhook, `subscriptions` + grants, paywall UI, E37.
- [ ] "Was my car featured?" (SPEC §11): **blocked on legal review.**
- [ ] Dark mode; more languages.

---

## Features

One entry per completed feature/task, newest first: what it is, what it does, and the branch it started on.

| Feature | What it does | Branch |
|---|---|---|
| **B0.1 Repo scaffold** | Creates the SPEC §13 folder layout, `.gitignore` (keeps secrets, build output and model files out of Git), `.editorconfig`, `README.md`, `.env.example` (placeholder config, copied to `.env` from B0.2) and a `Makefile` whose `make help` lists every command (each one a stub naming the step that builds it). Adds ADR-0001 (serverless-first) and ADR-0002 (build order, B1 spike moved up). | `b0.1-repo-scaffold` |

## Decisions log

| ADR | Title | Date |
|---|---|---|
| 0001 | Serverless-first (Cloud Run + Neon + Pub/Sub) | 2026-11-01 |
| 0002 | Three-stage build: basic backend → basic frontend → remaining features; B1 spike runs right after B0.1 | 2026-11-01 |

## Open questions for the owner

- (Claude adds questions here when blocked; the owner answers inline.)

## Session notes

<!-- One dated line per session, newest first. Example:
- 2026-11-02 — B0.2 done. Pub/Sub emulator needs PUBSUB_EMULATOR_HOST; added to .env.example.
-->
- 2026-11-01 — B0.1 done: SPEC §13 directories (.gitkeep), .gitignore, .editorconfig, README, .env.example, Makefile stubs (each exits 1 and names its step), ADR-0000/0001/0002. Owner chose to run B1 next (ADR-0002). Not yet installed on owner's Mac: Go, uv, firebase-tools; Docker daemon not running. Repo LICENSE is MIT; owner to confirm that's intended.
