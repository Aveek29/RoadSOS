# RUN.md — RoadSOS step-by-step run guide

> Anyone can run this project in ~5 minutes by following the steps in order.
> Works on Windows (PowerShell). Linux/macOS notes are at the bottom.

**Guide status**

| Field | Value |
|---|---|
| Last verified | **2026-10-20 (UTC)** |
| Verified on | Windows 10/11 · Python 3.13 · Node.js 18+ · Flutter (temp SDK) |
| Verified live | backend `:5000` (model loaded, SHA-256 OK) + dashboard `:3000` (`webpack compiled successfully`) |
| Commit verified | `c39b427` (branch `main`) → <https://github.com/Aveek29/RoadSOS> |
| ML latency observed | 9–47 ms per prediction · model cold-load 7–55 s (hardware dependent) |

> If a step behaves differently later, check the commit you cloned (`git log -1`) against the
> verified commit above before assuming the guide is wrong.

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

## Optional — Flutter mobile app (step by step)

> **Yes, the phone app works too.** It needs Flutter + Android SDK (or a physical Android phone).
> The backend must keep running (Step 4) while you use the app.

### Step A — Install Flutter (one time)

1. Download the Flutter SDK: <https://docs.flutter.dev/get-started/install>
2. Add `flutter\bin` to your `PATH`, then verify:
   ```powershell
   flutter --version
   flutter doctor        # fix anything marked with ✗ (Android toolchain)
   ```
3. For an emulator: open **Android Studio → Device Manager → Create Device**, or use a real phone with USB debugging on.

### Step B — Get the app dependencies (one time)

```powershell
cd RoadSOS\roadsos\app
flutter pub get
```

### Step C — Run it against the backend

**Choose ONE case below based on where the app runs:**

| Case | Command | Notes |
|---|---|---|
| **C1. Android emulator** | `flutter run` | Backend URL `10.0.2.2:5000` is the default — nothing extra needed |
| **C2. Physical phone (same Wi-Fi)** | `flutter run --dart-define=ROADSOS_BACKEND_URL=http://<PC-LAN-IP>:5000` | Get `<PC-LAN-IP>` from `ipconfig` — the IPv4 address of your Wi-Fi adapter, e.g. `192.168.1.42` |
| **C3. iOS device** | Needs a **Mac + Xcode**; then the same commands | Not possible from Windows |
| **C4. Build a shareable APK** | `flutter build apk --release` | Needs Android SDK; output: `build\app\outputs\flutter-apk\app-release.apk` |

**C2 in full (physical phone):**
```powershell
ipconfig                                  # note your Wi-Fi IPv4, e.g. 192.168.1.42
# allow backend through the firewall (one time, admin PowerShell):
New-NetFirewallRule -DisplayName "RoadSOS backend 5000" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
cd RoadSOS\roadsos\app
flutter run --dart-define=ROADSOS_BACKEND_URL=http://192.168.1.42:5000
```

> ⚠️ The phone and the PC **must be on the same Wi-Fi**, and the backend must be started normally
> (Step 4 binds `0.0.0.0:5000`). If the app shows no data, re-check the IP and the firewall rule.

### Step D — Use it

**Profile → Severity Prediction → enter values → Predict** → you get the same
severity badge + probability bars as the dashboard.

> ⚠️ **Not verified by us:** building a release APK (`flutter build apk`) was **NOT RUN** in our
> environment — no Android SDK was available. Running via `flutter run` from a dev machine is verified.
> Full status: [`roadsos/docs/testing.md`](roadsos/docs/testing.md)

### Step E — Stop the app

Press `q` in the `flutter run` terminal (the backend keeps running).

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

---

*Guide last verified 2026-10-20 (UTC) against commit `c39b427`. Commands, ports and expected
outputs above match a real end-to-end run: model loaded with SHA-256 verified, dashboard compiled,
and a live prediction returned from the backend.*
