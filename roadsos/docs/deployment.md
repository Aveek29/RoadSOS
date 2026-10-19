# Deployment & run book

Verified in this environment (Windows, Python 3.13, Node, Flutter 3.47.7).
Steps that were **not** executed (production WSGI, Android APK build) are marked
so — see `docs/testing.md` §6.

---

## 0. Prerequisites

| Component | Needed for | Version used here |
|---|---|---|
| Python | backend | **3.13** (3.9+ likely fine; pins in `requirements-ml.txt` are for 3.13) |
| Node.js + npm | dashboard | Node 20 / npm 10 (CRA 5) |
| Flutter SDK | mobile app | 3.47.7 (any 3.x with null safety) |
| ~2.1 GB free disk | model artifact | 1,965,071,297 B model + venv |
| Git | clone only | — |

The model is **optional**: every emergency feature works with it absent.

## 1. Backend

```powershell
cd roadsos
python -m venv .venv                      # or use an existing venv
.\.venv\Scripts\activate                 # macOS/Linux: source .venv/bin/activate
cd backend
pip install -r requirements.txt -r requirements-ml.txt
```

**Download the model (~1.97 GB, never committed):**

```powershell
python scripts/download_model.py          # resumes, verifies size + SHA-256
python scripts/verify_model.py --load     # optional: real joblib load + smoke predict
```

The file must land at `roadsos/models/road_accident_model.pkl` (gitignored).
Without it the server still starts — only `/api/v1/…` returns `503
MODEL_UNAVAILABLE`.

**Configure (optional — copy and edit):**

```powershell
copy .env.example .env
```

| Variable | When to set it |
|---|---|
| `ALLOWED_ORIGINS` | **Always in production.** Comma-separated dashboard origins, e.g. `https://dashboard.example.com`. Unset ⇒ any origin + a startup warning. |
| `ROADSOS_API_KEY` | To require `X-API-Key`/`Bearer` on prediction calls (dev: leave empty) |
| `PREDICTION_RATE_LIMIT_PER_MIN` | Per-IP prediction limit (default 60) |
| `MODEL_PATH` / `MODEL_CACHE_DIR` | If the artifact lives outside `roadsos/models/` |
| `MODEL_HEALTHCHECK=0` | Skip startup warm-up (saves ~10 s, first request pays) |

**Run:**

```powershell
python app.py                              # http://127.0.0.1:5000
```

First readiness check (expect `available: true`, `sha256Verified: true`):

```powershell
curl -s http://127.0.0.1:5000/api/v1/model/health
```

Measured load times on this machine: **9.7–13.5 s warm** (startup warm-up),
**~27 s cold** (first load inside `pytest` on a cold OS cache). Inference is
**9–30 ms** warm.

## 2. Dashboard

```powershell
cd roadsos/frontend_dashboard
npm install                                # package-lock.json is committed
npm start                                  # dev server → http://localhost:3000 (boots in ~8 s)
# production build:
npm run build                              # → build/  (exit 0)
```

API base URL defaults to `http://127.0.0.1:5000`; point elsewhere with:

```powershell
$env:REACT_APP_API_URL = "https://api.example.com"
npm run build            # (or npm start)
```

Because the dashboard is a different origin, the backend's `ALLOWED_ORIGINS`
must include `http://localhost:3000` (or the origin you use).

## 3. Flutter app

```powershell
$env:Path = "<flutter-sdk>\bin;$env:Path"   # if the SDK is not on PATH
cd roadsos/app
flutter pub get
flutter test                                 # 7 unit/widget tests (5 live tests skip)
```

**Where the backend lives — resolved centrally by `AppConfig`:**
`app/lib/config/app_config.dart` is the **single source of truth** for the
backend address. Every networked service (Socket.IO, the prediction HTTP
client, the helper geohash index) resolves it from there, so you set the
address **once** — it can no longer drift between files. Priority:

1. `--dart-define=ROADSOS_BACKEND_URL=…` (explicit override)
2. Platform default (no flag needed):

| Device | Resolved automatically to |
|---|---|
| Android emulator | `http://10.0.2.2:5000` (default) |
| iOS simulator / desktop / web | `http://127.0.0.1:5000` |
| Physical device | `http://<your-LAN-IP>:5000` (must pass the flag) |

```powershell
# physical device / LAN demo
flutter run --dart-define=ROADSOS_BACKEND_URL=http://<PC-LAN-IP>:5000
```

**Connection resilience (`SocketService`):** transports `polling` → upgrade to
`websocket` (survives emulators/LANs where websocket-only fails), automatic
reconnection with backoff, and a bounded outbox that **queues SOS events
emitted while offline and flushes them on reconnect** so a `create_incident`
is never silently dropped. `statusStream` exposes connectivity to the UI.

Live end-to-end test (backend must be running):

```powershell
flutter test test/live_backend_e2e_test.dart --dart-define=ROADSOS_LIVE_E2E=true
```

## 4. Smoke test after any change

```powershell
# backend
cd roadsos/backend; python -m pytest        # expect: 60 passed
# dashboard
cd ..\frontend_dashboard
npx eslint src --ext .js,.jsx               # expect: 0 errors
npm run build                               # expect: exit 0
$env:CI='true'; npx react-scripts test --watchAll=false   # expect: 8 passed
# flutter (12 = 7 unit/widget + 5 live E2E, backend running)
cd ..\app
flutter analyze --no-pub                    # expect: 0 errors (warnings/infos exit 1)
flutter test --dart-define=ROADSOS_LIVE_E2E=true   # expect: 12 passed
```

**Cross-stack connectivity suite (Flutter → backend → ML, 13 checks):**

```powershell
# backend must be running (python app.py) — HTTP + Socket.IO end-to-end
cd roadsos\backend; python <repo>\connectivity_test.py   # expect: 13/13 passed
```

Proves: health, model availability + SHA-256, schema, two predictions whose
probabilities **shift** (live model, not canned), 400 validation, incidents,
demo simulate, analytics, socket connect, `create_incident → incident_created`
echo, and the `helper_respond` **ack**.

Full expected results and how they were produced: `docs/testing.md`.

## 5. Operating notes

* **Failure isolation.** If the artifact is missing, corrupt, or the wrong
  size/hash, `/api/v1/*` returns `503 MODEL_UNAVAILABLE`; `/health`,
  `/incidents`, `/dispatch`, socket events and the countdown/emergency flows are
  untouched (verified: they stay `200` even while predictions are being
  rate-limited).
* **Rate limiting is in-memory and per process.** Running more than one worker
  multiplies the effective per-IP limit and the counter is not shared. Keep a
  single process (the documented path) unless you move the limiter to shared
  storage.
* **Model loading is a warm-up, not a request cost.** Startup blocks ~10–20 s
  (warm cache) while the 1.97 GB pickle loads; requests afterwards cost
  ~10–30 ms.
* **Task Manager may show two `python.exe` for one server.** This venv's
  `python.exe` is a launcher that re-executes the base interpreter — a control
  script doubles identically. Check the startup log line instead:
  `Serving on http://0.0.0.0:5000 (FLASK_DEBUG=0, reloader=off)`.
* **Never commit:** `models/*.pkl`, `.env`, `serviceAccountKey.json`,
  `*.p12` — all are gitignored (verified with `git check-ignore`).
* **Pinned supply chain.** The artifact always comes from HF revision
  `c4a7daf40b05e506c3c00aca7c8ab00bc00db53c` and is SHA-256 checked before use;
  `scikit-learn` is pinned to the publisher's **1.6.1** training version.
* **Presentation mode:** `POST /demo/simulate` seeds demo incidents,
  `POST /demo/clear` removes them (pre-existing routes, unchanged).

## 6. Not executed here (do before real production)

* Running behind gunicorn/uwsgi or a reverse proxy — **not tested**; only
  `python app.py` was.
* `flutter build apk` / iOS archive — **not tested** (no Android SDK/Xcode here).
* Firestore-backed 404 path — **blocked** without `serviceAccountKey.json`;
  the offline path (`persisted: false`) is what was verified.
* TLS, secrets manager, and shared-rate-limit storage — out of scope of this
  repo's current state; see `docs/security.md`.
