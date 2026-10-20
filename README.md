# 🚨 RoadSOS — Intelligent Accident Response System

> End-to-end accident response platform with a **real ML accident-severity advisory**: a published Random Forest model wired through the Flask backend into the React command-centre dashboard and the Flutter rider app — with safety, security, and tests to back it up.

**Live locally:** backend `:5000` · dashboard `:3000` · Flutter app (optional)

---

> 📖 **New here (or running the project for someone else)? Follow [`RUN.md`](RUN.md) — a numbered step-by-step guide from clone to testing, plus troubleshooting.**

## ⚡ Quick start (local, ~5 minutes)

### Prerequisites

| Python 3.11–3.13 | Node.js 18+ | ~2.5 GB free disk* | Flutter SDK *(optional)* |
|---|---|---|---|
| `python --version` | `node --version` | *model = 1.9 GB* | `flutter --version` |

### 1️⃣ Backend — terminal 1

```powershell
git clone https://github.com/Aveek29/RoadSOS.git
cd RoadSOS\roadsos\backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt -r requirements-ml.txt
python scripts\download_model.py     # one-time: downloads + SHA-256 verifies the 1.9 GB model
python app.py
```

Wait for both lines (~7–25 s model load):

```
Severity model ready (load=6.84s, sha256_verified=True).
Serving on http://0.0.0.0:5000  (FLASK_DEBUG=0, reloader=off)
```

### 2️⃣ Dashboard — terminal 2

```powershell
cd RoadSOS\roadsos\frontend_dashboard
npm install
npm start          # → http://localhost:3000
```

### 3️⃣ Test the ML in 30 seconds

1. Open `http://localhost:5000/api/v1/model/health` → must show `"available": true`, `"sha256Verified": true`
2. Open **http://localhost:3000** → **🎮 Demo Simulator → 🟠 Major Accident** (creates a test incident)
3. In the incident's detail card → scroll to **"AI Severity Prediction"** → click **Run severity analysis**
4. ✅ You get **Slight / Serious / Fatal** + 3 probability bars + your inputs echoed + model revision + latency
5. Change inputs (hour, wet road, speed…) → run again → **percentages shift** — proof of a live model

> Stop everything with `Ctrl+C` in each terminal.

<details>
<summary><b>Test the API directly (PowerShell)</b></summary>

```powershell
$f = @{ Year=2021; Latitude=13.0827; Longitude=80.2707; Speed_limit=30; Hour=15; Day_of_Week="Monday"; Month="Jan"; Junction_Control="Give way or uncontrolled"; Light_Conditions="Daylight"; Road_Surface_Conditions="Dry"; Road_Type="Single carriageway"; Urban_or_Rural_Area="Urban"; Weather_Conditions="Fine no high winds"; Vehicle_Type="Car" }
$r = Invoke-RestMethod -Method Post -Uri http://localhost:5000/api/v1/predictions/severity -ContentType "application/json" -Body (@{features=$f} | ConvertTo-Json)
"$($r.prediction.severity) | $($r.prediction.probabilities | ConvertTo-Json -Compress) | $($r.prediction.latencyMs) ms"
```

</details>

### 4️⃣ Flutter app (optional)

```powershell
cd RoadSOS\roadsos\app
flutter pub get
flutter run        # Android emulator → backend address 10.0.2.2:5000 preconfigured
```

Profile → **Severity Prediction** → enter values → predict.
Physical device: `flutter run --dart-define=ROADSOS_BACKEND_URL=http://<your-PC-IP>:5000`

### 5️⃣ Full test suites (optional — all previously executed green)

```powershell
# Backend: 60 passed (~1 min, loads the real model)
cd roadsos\backend && .venv\Scripts\activate && python -m pytest

# Dashboard: 0 lint errors · build OK · 8/8 Jest
cd roadsos\frontend_dashboard
npx eslint src --ext .js,.jsx
npm run build
$env:CI='true'; npx react-scripts test --watchAll=false

# Flutter: 0 errors · 7 passed + 5 skipped
cd roadsos\app && flutter analyze --no-pub && flutter test
```

---

## 🎯 What we built (presentation summary)

### Starting point → our additions

| Starting point (existing project) | What **we** added |
|---|---|
| Crash detection, SOS countdown, geofenced helper alerts, command-centre dashboard | **Real ML severity advisory, end-to-end** |
| Simple rule-based severity (`LOW/MEDIUM/HIGH/CRITICAL`) | **Published Random Forest** → `Slight / Serious / Fatal` + calibrated vote probabilities |
| No ML in the pipeline | **Pinned, verified model artifact** (SHA-256), REST API, dashboard panel, Flutter screen |

### ML integration deliverables

| # | Deliverable | Where |
|---|---|---|
| 1 | **ML module** — config, loader, predictor, 61-feature schema, rate limiter, typed errors | `roadsos/backend/ml/` |
| 2 | **REST API** — health, schema, prediction endpoints; 503 `MODEL_UNAVAILABLE` when model is down | `roadsos/backend/routes/prediction_routes.py` |
| 3 | **Dashboard panel** — schema-driven form, probability bars, offline/error states | `frontend_dashboard/src/components/SeverityPredictionPanel.jsx` |
| 4 | **Flutter screen** — 14-input form with client-side validation, speed dropdown from schema | `app/lib/ui/screens/severity_prediction_screen.dart` |
| 5 | **Safety-first design** — prediction is *advisory only*; it never blocks or delays emergency flows (countdown, dispatch, SMS) | enforced by tests `test_safety.py` |
| 6 | **Reproducibility** — HF revision pinned + SHA-256 verified on every startup; env-driven config | `ml/config.py`, `scripts/download_model.py` |
| 7 | **85 automated tests** across 3 stacks (details below) | `backend/tests/`, `app/test/`, `src/services/*.test.js` |
| 8 | **8 documents** — architecture, API, ML model, testing, security, deployment, presentation traceability | `roadsos/docs/` |
| 9 | **Security audit** — 12 findings, secret-scan, production checklist | `roadsos/docs/security.md` |

### Numbers to show your teacher

| Metric | Value |
|---|---|
| Model | `hayamwahdan/road-accident-severity-prediction`, Random Forest, **100 trees**, pinned rev `c4a7daf40b` |
| Artifact | 1,965,071,297 bytes, **SHA-256 verified at startup** (never committed to git) |
| Features | **14 raw inputs → exactly 61 one-hot columns** (verified `n_features_in_=61`) |
| Classes | Fatal / Serious / Slight |
| Inference latency | **9–47 ms** (measured) |
| Model cold-load | ~7–25 s, once per start, non-blocking |
| Tests executed | **60 backend + 8 Jest + 7 Flutter + 5 live E2E = 80 passing** (5 Flutter live tests skip without a running backend by design) |
| Repo | 287 files, ~47,600 lines, secrets & 1.9 GB artifact excluded by `.gitignore` |

### 5-minute demo script

1. **Show it's a real model** — open `/api/v1/model/health` → `sha256Verified: true`, revision `c4a7daf40b`
2. **Show the feature** — dashboard → Demo Simulator → incident → *AI Severity Prediction* → Run analysis → probability bars appear in ~17 ms
3. **Show it's live, not canned** — change lat/long or make it night + wet → probabilities change
4. **Show safety** — stop the backend → predicting shows *"model unavailable"* gracefully; SOS countdown/dispatch still work
5. **Show rigor** — run `python -m pytest` live → `60 passed`
6. **Show honesty** — point at `docs/presentation-requirements.md` (slide-by-slide traceability) and the deviations list

### Honesty notes (documented, not hidden)

- Dashboard was **CRA**, not Vite as the slide assumed (deviation D1) — kept CRA rather than rewrite.
- Slide's "YOLO pipeline-ready" claim had no code in the repo — the RF module is a **strictly separate** advisory path (D2); it does not touch crash detection.
- SMS goes through the `sms:` URI (D3/D4); Firestore needs a local `serviceAccountKey.json` (not in git) — offline mode is exercised and labelled `persisted: false`.
- Publisher-reported accuracy (80.03%) **NOT RUN** — retraining their pipeline is out of scope; we report it as *their* number only.
- Full list: [`roadsos/docs/presentation-requirements.md`](roadsos/docs/presentation-requirements.md)

---

## ✅ Test results (all executed locally)

| Suite | Command | Result |
|---|---|---|
| Backend (60 tests, real model) | `python -m pytest` | ✅ **60 passed** |
| Dashboard lint | `npx eslint src --ext .js,.jsx` | ✅ 0 errors |
| Dashboard build | `npm run build` | ✅ exit 0 |
| Dashboard unit (8) | `react-scripts test --watchAll=false` | ✅ **8/8** |
| Flutter analyze | `flutter analyze --no-pub` | ✅ 0 errors |
| Flutter unit (12) | `flutter test` | ✅ **7 passed, 5 skipped**† |
| Flutter live E2E (5) | `flutter test … --dart-define=ROADSOS_LIVE_E2E=true` | ✅ **5/5** |
| Live HTTP matrix | health · schema · predict · 400s · rate-limit 429 | ✅ all as specified |
| Browser click-through | dashboard panel via UI | ✅ verified (this README's Quick Start) |
| Publisher's model accuracy | retrain & score | ⛔ NOT RUN (their pipeline) |

† Live tests skip deliberately when no backend is running — never fake a pass.
Details: [`roadsos/docs/testing.md`](roadsos/docs/testing.md)

---

## 🔌 API in 30 seconds

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Service liveness |
| GET | `/api/v1/model/health` | Model state, SHA-256, revision, latency |
| GET | `/api/v1/predictions/schema` | 61 features, allowed values, min/max limits |
| POST | `/api/v1/predictions/severity` | **14 inputs → severity + 3 probabilities + metadata** |
| GET/POST | `/incidents`, `/dispatch`, `/api/v1/incidents/…` | Legacy command-centre (unchanged) |

Full reference: [`roadsos/docs/api.md`](roadsos/docs/api.md) · sample bodies: `roadsos/backend/example_api_requests.md`

---

## 🛡️ Safety & security (short version)

- **Advisory, never authoritative** — ML output is labelled a statistical estimate; it cannot block or delay SOS countdown, dispatch, or SMS (enforced by tests).
- **Fail-open for safety, fail-closed for ML** — model down ⇒ prediction endpoints return 503 while every emergency endpoint keeps working.
- **Secrets out of git** — `.env`, `serviceAccountKey.json`, and the 1.9 GB model are ignored; verified with `git check-ignore`.
- **Rate limited** (60 req/min/IP → 429 + `Retry-After`), 1 MB request cap, constant-time API-key compare, `FLASK_DEBUG` defaults to 0.
- 12 findings + production checklist: [`roadsos/docs/security.md`](roadsos/docs/security.md)

---

## 📂 Repository structure

```
RoadSOS/
├── README.md                  ← you are here (quick start + presentation)
├── roadsos/                   ← the platform
│   ├── backend/               ← Flask API + ml/ module + 60 pytest tests
│   │   ├── ml/                ← config, loader, predictor, 61-feature schema
│   │   ├── routes/            ← prediction + legacy command-centre routes
│   │   └── tests/             ← 60 tests
│   ├── frontend_dashboard/    ← React command centre + SeverityPredictionPanel
│   ├── app/                   ← Flutter rider app + severity prediction screen
│   ├── docs/                  ← 7 docs (architecture, api, ml, testing, security…)
│   └── assets/                ← UI screenshots
├── ml-model/                  ← publisher's notebook + dataset (reference only)
├── Project.pptx               ← original presentation (requirements source)
└── slides_extracted/          ← extracted slide images
```

## 📚 Documentation

| Doc | Contents |
|---|---|
| [`architecture.md`](roadsos/docs/architecture.md) | How the pieces fit |
| [`api.md`](roadsos/docs/api.md) | Every endpoint + examples |
| [`ml-model.md`](roadsos/docs/ml-model.md) | Model provenance, 61-feature contract, baselines |
| [`testing.md`](roadsos/docs/testing.md) | Full PASS/FAIL/BLOCKED/NOT RUN report |
| [`security.md`](roadsos/docs/security.md) | Findings F1–F12 + production checklist |
| [`deployment.md`](roadsos/docs/deployment.md) | Run book, env vars, LAN demo |
| [`presentation-requirements.md`](roadsos/docs/presentation-requirements.md) | Slide-by-slide traceability + deviations |
| [`roadsos/README.md`](roadsos/README.md) | Deep-dive project README |

## 🩹 Troubleshooting

| Symptom | Fix |
|---|---|
| Predict → 503 `MODEL_UNAVAILABLE` | Wait for `Severity model ready` in backend log, or run `scripts\download_model.py` first |
| Port 5000/3000 busy | Close the other server or `RUN_PORT=5001 python app.py` |
| Dashboard can't reach API | Backend must be running; override with `REACT_APP_API_URL` |
| 429 Too Many Requests | 60 predictions/min limit — wait a minute |
| Phone can't load data | Use `--dart-define=ROADSOS_BACKEND_URL=http://<PC-LAN-IP>:5000` |
