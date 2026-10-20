# RUN.md — RoadSOS step-by-step run guide

> Anyone can run this project in ~5 minutes by following the steps in order.
> Works on Windows (PowerShell). Linux/macOS notes are at the bottom.

---

## Before you start — check these

| Requirement | Check command | Expected |
|---|---|---|
| Python 3.11–3.13 | `python --version` | `Python 3.1x.x` |
| Node.js 18+ | `node --version` | `v18` or higher |
| npm | `npm --version` | any |
| Free disk space | — | **~2.5 GB** (the ML model is 1.9 GB) |

Optional: Flutter SDK (only if you want the mobile app).

> **Folder note:** all commands below run from the folder where you cloned the repo
> (shown here as `RoadSOS`). Replace it with your actual path.

---

## Step 1 — Get the project

```powershell
git clone https://github.com/Aveek29/RoadSOS.git
cd RoadSOS
```

---

## Step 2 — Set up the backend (one time only, ~3 min)

```powershell
cd roadsos\backend

# create + activate a virtual environment
python -m venv .venv
.venv\Scripts\activate

# install Python dependencies (base + ML stack)
pip install -r requirements.txt -r requirements-ml.txt

# download the real trained model (1.9 GB, one time; verifies SHA-256)
python scripts\download_model.py
```

Expected at the end of `download_model.py`:
```
OK: <path>\road_accident_model.pkl
```

> If the download is interrupted, just run the same command again — it resumes/reuses the cache.

---

## Step 3 — Set up the dashboard (one time only, ~2 min)

Open a **second** PowerShell window:

```powershell
cd RoadSOS\roadsos\frontend_dashboard
npm install
```

---

## Step 4 — Start the backend  ← terminal 1

```powershell
cd RoadSOS\roadsos\backend
.venv\Scripts\activate
python app.py
```

**Wait for these two lines** (model cold-load takes ~7–55 s the first time):

```
Severity model ready (load=6.84s, sha256_verified=True).
Serving on http://0.0.0.0:5000  (FLASK_DEBUG=0, reloader=off)
```

✅ **Verify:** open <http://localhost:5000/api/v1/model/health>
You must see `"available": true` and `"sha256Verified": true`.

> Leave this window running. Never close it while testing.

---

## Step 5 — Start the dashboard  ← terminal 2

```powershell
cd RoadSOS\roadsos\frontend_dashboard
npm start
```

**Wait for:** `webpack compiled successfully`, then it opens <http://localhost:3000>
(if the browser doesn't open, type the URL yourself).

---

## Step 6 — Test it 🎯

1. Open **<http://localhost:3000>**
2. Scroll down to **🎮 Demo Simulator**
3. Click **🟠 Major Accident** → a test incident is created
4. The incident detail card opens → scroll to **"AI Severity Prediction"**
5. Click **Run severity analysis**
6. ✅ You should see:
   - a severity badge: **Slight / Serious / Fatal**
   - three probability bars summing to 100%
   - your inputs echoed back
   - model revision `c4a7daf40b` and a latency in milliseconds

**Prove it's a live model:** change *Hour* to `2`, *Road surface* to `Wet or damp`,
*Light conditions* to `Darkness - lighting unknown` → run again → **numbers change**.

---

## Step 7 — Stop everything

Press `Ctrl+C` in **both** terminal windows (backend first, then dashboard).

---

## Optional — Flutter mobile app

```powershell
cd RoadSOS\roadsos\app
flutter pub get
flutter run
```

Then: **Profile → Severity Prediction → enter values → Predict**.

- Android emulator: backend address `10.0.2.2:5000` is already the default.
- Physical phone (same Wi-Fi): use your PC's LAN IP —
  ```powershell
  flutter run --dart-define=ROADSOS_BACKEND_URL=http://192.168.1.42:5000
  ```
  (find your IP with `ipconfig`)

---

## Optional — Run the test suites

```powershell
# backend — expect 60 passed (~1 min, loads the real model)
cd roadsos\backend
.venv\Scripts\activate
python -m pytest

# dashboard — expect 0 lint errors, successful build, 8/8 unit tests
cd roadsos\frontend_dashboard
npx eslint src --ext .js,.jsx
npm run build
$env:CI='true'; npx react-scripts test --watchAll=false

# flutter — expect 0 analyze errors, 7 passed + 5 skipped
cd roadsos\app
flutter analyze --no-pub
flutter test
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Panel says **model offline** | Backend still cold-loading, or not started | Wait for `Severity model ready`, then retry |
| `503 MODEL_UNAVAILABLE` | Model file missing | Run `python scripts\download_model.py` |
| `Port 5000 is in use` | Another server running | Close it, or `$env:RUN_PORT=5001; python app.py` |
| `Port 3000 is in use` | Another dev server | Close it, or answer `Y` to use another port |
| Dashboard can't reach API | Backend not running | Start terminal 1 first |
| `429 Too Many Requests` | 60 predictions/min limit | Wait a minute and retry |
| Phone app shows no data | Wrong backend URL | Use `--dart-define=ROADSOS_BACKEND_URL=http://<PC-IP>:5000` |
| `.venv\Scripts\activate` blocked | PowerShell script policy | Run `Set-ExecutionPolicy -Scope Process Bypass` once, then retry |

---

## Linux / macOS quick equivalent

```bash
git clone https://github.com/Aveek29/RoadSOS.git && cd RoadSOS/roadsos/backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-ml.txt
python scripts/download_model.py
python app.py            # terminal 1

cd ../frontend_dashboard   # terminal 2
npm install && npm start
```

---

## Summary — the 2 commands you'll use daily

```powershell
# terminal 1
cd roadsos\backend; .venv\Scripts\activate; python app.py

# terminal 2
cd roadsos\frontend_dashboard; npm start
```

Then open **<http://localhost:3000>**.
