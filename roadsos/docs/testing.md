# Testing report — RoadSOS + ML integration

Every result below was produced by **actually running the command in this
environment** on 2026-10-15. Nothing is inferred, and nothing that did not run
is listed as passing.

Legend: **PASS** = executed and succeeded · **FAIL** = executed and failed (none) ·
**BLOCKED** = could not be executed for a reason outside this work ·
**NOT RUN** = intentionally not executed.

---

## 1. Backend — pytest

| # | What | Command | Result |
|---|---|---|---|
| B1 | Full backend suite (unit + contract + safety + real model) | `cd backend && python -m pytest` | **PASS — 60 passed** (31.76s on the run that added the `.env`-loader tests) |
| B2 | Real 1.97 GB artifact loads, SHA-256 matches, predicts | included in B1 (`tests/test_model_artifact.py`, marker `real_model`) | **PASS** — output: `[real model] inference latency ~11.9ms (reported 11.27ms); load seconds = 9.819` (37.9 ms / 21.6 s on a later run — first inference after a cold load) |
| B3 | Earlier full-suite runs (before the `.env`-loader tests were added) | `python -m pytest` | **PASS — 56 passed in 33.97s**, `load seconds = 26.651`, `inference latency ~21.2ms` |

Suite contents — **60 tests**, collected with `pytest --collect-only -q`:

| File | Tests | Focus |
|---|---:|---|
| `tests/test_feature_schema.py` | 15 | 14 raw values → exactly 61 columns, `drop_first` baselines, unknown-key rejection, category/range validation |
| `tests/test_prediction_api.py` | 17 | health 200/503, schema contract (incl. `speedLimitAllowed` + `limits`), 200 happy path, malformed JSON / wrong content-type / missing-or-empty body / non-object `features` → 400, invalid category & missing features → 400 with detail strings, incident-id validation, **`test_api_key_enforced_when_configured` / `test_api_key_not_required_when_unset`, `test_rate_limit_returns_429`** |
| `tests/test_model_artifact.py` | 8 | exact size 1,965,071,297 B, SHA-256 `B9E5BE…E98B2`, `n_features_in_=61`, real inference on two dataset rows, real end-to-end API run, **measured** latency is what gets reported |
| `tests/test_safety.py` | 8 | prediction never creates/mutates incidents, "Fatal" never claims confirmation, never cancels anything, health/app survive an unavailable model, **loader reports unavailable for a missing artifact and refuses a checksum mismatch**, oversized payload cannot block |
| `tests/test_predictor.py` | 8 | ordered probability vector, class order `Fatal/Serious/Slight`, one-hot semantics, error paths |
| `tests/test_env_loader.py` | 4 | `.env` values applied, existing env never overwritten, quotes/comments handled, missing file is a no-op |

## 2. Frontend dashboard — eslint / build / jest

| # | What | Command | Result |
|---|---|---|---|
| D1 | Lint | `npx eslint src --ext .js,.jsx` | **PASS — 0 errors**, 8 **pre-existing** `no-unused-vars` warnings (exit 0). No warning is in a file added by this work. |
| D2 | Production build | `npm run build` | **PASS — exit 0**, "The build folder is ready to be deployed." |
| D3 | API-client contract tests (8) | `CI=true npx react-scripts test --watchAll=false` | **PASS — 8/8** (`src/services/api.ml.test.js`): payload shape, URL-encoding of incident ids, `INVALID_FEATURES`/`MODEL_UNAVAILABLE`/429-style error mapping, 503→"model down", network-error→"unreachable", schema fetch + degrade path |
| D4 | Dev server actually boots and serves the app | `npx react-scripts start` → poll `http://127.0.0.1:3000/` | **PASS — HTTP 200 after 8s**, `#root` div present, `/static/js/bundle.js` → 200 (then stopped) |

Fixes made because these tests failed first (documented, not hidden):
* the test file's `jest.mock` originally preceded its imports → `import/first`
  **2 lint errors** → moved imports to the top (jest still hoists `jest.mock`);
  lint is now clean.

## 3. Flutter app — analyze / unit tests / live end-to-end

| # | What | Command | Result |
|---|---|---|---|
| F1 | Static analysis | `flutter analyze --no-pub` | **PASS (0 errors)** — 233 issues = **0 errors**, **9 warnings**, **224 infos**. Exit code is 1 because analyzer exits non-zero on any warning/info; report counts, not exit code. All 9 warnings are pre-existing app code (`home_screen.dart`, `app_shell.dart`, `plus_code_service.dart`, `helper_network/example_network_simulation.dart`) — none in files added by this work. Infos are `withOpacity`/`DropdownButtonFormField.value` deprecations, deliberately used to match the app's existing style and older-SDK compatibility. *(Config change: `app/analysis_options.yaml` now excludes generated dirs — `.dart_tool`, `build`, `android/ios/web/windows/macos/linux`. Verified these contain no hand-written Dart — the only `.dart` files outside `lib/`+`test/` are `.dart_tool` generated registrants — so nothing real is hidden.)* |
| F2 | Unit + widget tests | `flutter test` | **PASS — 7 passed, 5 skipped** (the 5 skips are the opt-in live tests, skipped with an explicit reason, not silently passing) |
| F3 | Live end-to-end (real HTTP → real model) | `flutter test test/live_backend_e2e_test.dart --dart-define=ROADSOS_LIVE_E2E=true` | **PASS — 5/5**: model health `available/loaded`, schema reports 61 features + 3 classes + `speedLimitAllowed`/`hourMin/hourMax/latitudeMin`, prediction returns a contract-valid class with probabilities summing to 1.0, invalid category → `INVALID_FEATURES`, emergency core unaffected |

F2 test list: `AccidentScenario` serialises exactly the 14 backend feature names ·
parses a successful prediction · maps a 400 without throwing · never throws when
unreachable · parses the schema contract · tolerates a schema without
`speedLimitAllowed`/`limits` · `widget_test.dart` app shell renders
NavigationBar destinations (1080×2400 @3x).

## 4. Live HTTP end-to-end (backend running, real model)

Fresh server (`python app.py`) after all fixes:

| # | Request | Result |
|---|---|---|
| L1 | `GET /api/v1/model/health` | **PASS 200** — `available=true state=loaded nFeaturesIn=61 sha256Verified=true loadSeconds=9.73` |
| L2 | `GET /api/v1/predictions/schema` | **PASS 200** — `nFeatures=61`, `speedLimitAllowed=[10,15,20,30,40,50,60,70]`, `limits.hourMax=23`, `limits.latitudeMin=-90.0`, 9 categorical features |
| L3 | `POST /api/v1/predictions/severity` (valid body) | **PASS 200** — `severity=Serious`, `probs={"Fatal":0.02,"Serious":0.49,"Slight":0.49}`, `latencyMs=9.26`, `advisory=true` |
| L4 | `POST` with unknown category + bad hour + bad speed | **PASS 400** `INVALID_FEATURES`, 3 field-scoped details |
| L5 | `POST` with a missing feature | **PASS 400** `INVALID_FEATURES` |
| L6 | `POST` malformed JSON | **PASS 400** |
| L7 | `POST` wrong `Content-Type` | **PASS 400** |
| L8 | 70 rapid predictions (rate limit) | **PASS** — 56×200 then 14×429 with `Retry-After: 3` (60/min window) |
| L9 | `/health` and `/incidents` *while* rate-limited | **PASS 200 / 200** — ML exhaustion never touches the emergency core |
| L10 | `GET /api/v1/model/health` while rate-limited | **PASS 200** — health stays observable |
| L11 | Incident-attached prediction with Firestore offline | **PASS 200** `persisted:false`, socket event emitted (earlier run on this server) |
| L12 | `flutter test … --dart-define=ROADSOS_LIVE_E2E=true` from a real client | **PASS 5/5** (F3) |

Earlier live run of the same matrix additionally recorded `latencyMs` 29.38 → 12.03 → 9.26
across warm-ups and 45×200 + 25×429 with `Retry-After: 2` for the limiter.

## 5. Security checks (see `docs/security.md` for findings)

| # | Check | Result |
|---|---|---|
| S1 | Secret scan of all backend/dashboard/app source (key patterns) | **PASS — no matches** |
| S2 | `git check-ignore` on `models/road_accident_model.pkl`, `backend/.env`, `backend/serviceAccountKey.json` | **PASS — all three IGNORED** |
| S3 | Actual `.env` / `serviceAccountKey.json` / key files in the tree | **PASS — none exist** (only `.env.example`) |
| S4 | Model artifact marked ignored in `git status --ignored` (`!! models/road_accident_model.pkl`) | **PASS** |

## 6. BLOCKED / NOT RUN — stated honestly

| # | Item | Status | Why |
|---|---|---|---|
| X1 | Presentation slide 9 (architecture diagram) content | **BLOCKED** | image-only slide; this model has no image input, so its content could not be read. Recorded in `docs/presentation-requirements.md`; a human must supply it. |
| X2 | Firestore 404 path (`incident not found`) | **BLOCKED** | requires `serviceAccountKey.json`, which is deliberately not present (secret stays out of git). The offline path (200 `persisted:false`) was exercised instead. |
| X3 | Browser click-through of the dashboard panel | **NOT RUN** | no browser automation available. Compensating evidence: D1 (lint), D2 (build compiles the panel), D3 (client contract tests), D4 (dev server boots), L1–L10 (exactly the endpoints the panel calls, live), socket merge covered by code review + the `severity_prediction` server emit observed in L11. |
| X4 | `flutter build apk` / iOS build | **NOT RUN** | no Android SDK in this environment; not required to validate logic. |
| X5 | Publisher-reported accuracy (80.03 % / 85.4 %) | **NOT RUN** | reproducing it needs the publisher's full training pipeline (SMOTE, CV). Quoted only as an unverified publisher claim. |
| X6 | Production WSGI server (gunicorn/uwsgi) run | **NOT RUN** | only the documented `python app.py` path was executed. |

## 7. Pre-existing defects fixed during validation

These were found *by* the tests above (they were failing before any ML work):

| Defect | Symptom | Fix |
|---|---|---|
| `GlassCard` had no `Material` ancestor | `ListTile` ink well assertion crash in debug builds | wrap child in a transparent `Material` (`app/lib/ui/components.dart`) |
| `HomeScreen` RenderFlex overflow | yellow/black overflow stripes on 1080×2400 @3x | `LayoutBuilder > SingleChildScrollView > ConstrainedBox(minHeight)` |
| `app/test/widget_test.dart` stale | expected `'RoadSoS'` / `Icons.emergency` / `'Start Monitoring'`, needs global engines initialised | rewritten to assert the three NavigationBar destinations |
| Schema endpoint omitted `speedLimitAllowed`/`limits` | Flutter silently received `[]`; a stale speed value could cause a 400 | route now publishes them (regression tests: API test, Flutter unit test, live F3/L2) |
| `.env.example` told users to create `.env`, but nothing read it | config edits silently had no effect | dependency-free loader added (`_load_env_file`), tested by `tests/test_env_loader.py` (4 tests) |
| `python app.py` hardcoded `debug=True` on `0.0.0.0:5000` | Werkzeug debugger reachable, reload spawns extra processes | `FLASK_DEBUG` (default 0), `RUN_HOST`/`RUN_PORT`, `use_reloader=False` — see `docs/security.md` F1 |
| `ROADSOS_API_KEY` compared with `!=` | timing-leaky comparison | `hmac.compare_digest` (tests cover 401 + 200 paths) |

## 8. Reproduce every number

```powershell
# Backend (56 tests)
cd E:\AVNISH-PREOJECT\roadsos\backend
E:\AVNISH-PREOJECT\.venv\Scripts\python.exe -m pytest

# Dashboard (lint / build / 8 tests)
cd E:\AVNISH-PREOJECT\roadsos\frontend_dashboard
npx eslint src --ext .js,.jsx
npm run build
$env:CI='true'; npx react-scripts test --watchAll=false

# Flutter (analyzer counts / 7 unit tests / 5 live tests)
$env:Path = "C:\Users\hp\AppData\Local\Temp\opencode\flutter_sdk\flutter\bin;$env:Path"
cd E:\AVNISH-PREOJECT\roadsos\app
flutter analyze --no-pub
flutter test
flutter test test/live_backend_e2e_test.dart --dart-define=ROADSOS_LIVE_E2E=true
```
