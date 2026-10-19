# RoadSOS — Test command reference

A copy-paste guide to **start, exercise and verify every layer** of RoadSOS:
the Flutter mobile app, the Flask + Socket.IO backend, the ML severity model
and the React command-centre dashboard.

Every command below was run on this machine. Where a result is expected, the
"expect" column tells you what success looks like.

---

## 0. Prerequisites (one time)

| Tool | Where | Check |
|---|---|---|
| Python venv | `E:\AVNISH-PREOJECT\.venv` (3.13) | `E:\AVNISH-PREOJECT\.venv\Scripts\python.exe --version` |
| Flutter SDK | add to PATH per session (see below) | `flutter --version` |
| Node + npm | `roadsos\frontend_dashboard` | `node --version` |

Flutter PATH refresh for a new PowerShell window:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
```

> Use **one** PowerShell window per long-running server. Do not chain commands
> with `&`; use `;`. `$pid` is read-only — use `$proc`.

---

## 1. Start the backend (do this first)

The ML model is ~2 GB and takes ~15 s to load, so wait for `GET /health` to answer.

```powershell
cd E:\AVNISH-PREOJECT\roadsos\backend
$env:PYTHONUNBUFFERED='1'
E:\AVNISH-PREOJECT\.venv\Scripts\python.exe app.py
```

Healthy output ends with:

```
[INFO] RoadSoS: Severity model ready (load=13.5s, sha256_verified=True).
[INFO] RoadSoS: Flask Command Center started with SocketIO.
 * Running on http://0.0.0.0:5000
```

Quick liveness check from another window:

```powershell
Invoke-WebRequest http://127.0.0.1:5000/health -UseBasicParsing | Select-Object -ExpandProperty Content
# expect: {"firebase":"disconnected","status":"OK"}   (firebase "disconnected" is normal — see §7)
```

Stop the backend / free the port:

```powershell
Get-Process python -ErrorAction SilentlyContinue | Stop-Process -Force
```

> **Two backends on one port is the #1 source of "my fix didn't take".** If a
> result looks stale, kill every python process and start exactly one backend.

---

## 2. One-shot automated verification (all layers)

Run in this order. All of these must be green for a "finalised" state.

| # | Command (from the layer folder) | What it proves | Expect |
|---|---|---|---|
| 1 | backend: `...\.venv\Scripts\python.exe -m pytest tests -q` | unit + contract + safety + real-model tests | **60 passed** |
| 2 | backend: `...\python.exe scripts\connectivity_test.py` | every HTTP route + the Socket.IO round trip against a live server | **14/14** |
| 3 | backend: `...\python.exe <temp>\deep_verify_test.py` | full SOS → dispatch → tracking → resolve lifecycle, ML boundary, volunteer flow, abuse resistance | **30/30** |
| 4 | backend: `...\python.exe <temp>\sos_ack_test.py` | SOS ACK contract (`success` + `incidentId`) shared by app & dashboard | **6/6** |
| 5 | app: `flutter analyze` | static analysis | **0 errors** (warnings/infos are pre-existing) |
| 6 | app: `flutter test --dart-define=ROADSOS_LIVE_E2E=true --dart-define=ROADSOS_BACKEND_URL=http://127.0.0.1:5000` | unit + widget + live ML + live duplex socket | **19 passed** |
| 7 | dashboard: `npx eslint src --ext .js,.jsx` | lint | **0 errors** (8 pre-existing warnings) |
| 8 | dashboard: `$env:CI='true'; npx react-scripts test --watchAll=false` | API-client contract tests | **8 passed** |
| 9 | dashboard: `npm run build` | production bundle compiles | `build\` created |

`deep_verify_test.py` and `sos_ack_test.py` live in the session temp folder
(`C:\Users\hp\AppData\Local\Temp\opencode\`). Steps 2–4 and 6 need the backend
from §1 running; step 1 does not.

---

## 3. Backend route reference — what each one is for

Base URL `http://127.0.0.1:5000`. All routes return JSON.

### Incidents (the emergency core)

| Method & path | Purpose | Example |
|---|---|---|
| `GET /incidents` | **Dashboard live feed.** Active incidents only (`RESOLVED` hidden). | `curl http://127.0.0.1:5000/incidents` |
| `GET /incidents?status=RESOLVED` | **History screen.** Completed incidents. | `curl "http://127.0.0.1:5000/incidents?status=RESOLVED"` |
| `GET /incidents?limit=10` | Cap the response (1–200). | `curl "http://127.0.0.1:5000/incidents?limit=10"` |
| `GET /incident/<id>` | Single incident; used to confirm a status change landed. | `curl http://127.0.0.1:5000/incident/sock_abc123` |
| `POST /update-status` | Move an incident to `ACTIVE` / `RESPONDING` / `RESOLVED`. Resolving stops tracking + broadcasts `incident_updated`. | body `{"incidentId":"...","status":"RESOLVED"}` |
| `POST /incident/<id>/location` | **HTTP GPS ping** from the app (socket `update_location` is the low-latency path). Updates `victimLat/Lng`. | body `{"latitude":13.09,"longitude":80.28}` |
| `POST /incident/<id>/stop-tracking` | Set `trackingActive=false` (privacy: stop streaming the victim's position). | `curl -X POST .../stop-tracking` |

PowerShell body example:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:5000/update-status `
  -ContentType 'application/json' -Body '{"incidentId":"sock_abc123","status":"RESOLVED"}'
```

### Dispatch

| Method & path | Purpose | Example |
|---|---|---|
| `POST /dispatch` | Send an ambulance / police / helper to an incident. Rejects a duplicate of the same type within 60 s, invalid types, and dispatch to a `RESOLVED` incident. | body `{"incidentId":"...","type":"ambulance"}` |

### Volunteers (helpers)

| Method & path | Purpose | Example |
|---|---|---|
| `POST /helper/register` | Create/update a volunteer profile. | body `{"uid":"h1","name":"Ravi","phone":"+91...","fcmToken":"..."}` |
| `POST /helper/presence` | Online/offline + GPS; computes a geohash used by `nearest`. | body `{"uid":"h1","latitude":13.0,"longitude":80.2,"status":"ONLINE"}` |
| `GET /helper/nearest?lat=..&lng=..&radius=5000` | Rescue-2 style nearest-available-volunteer lookup. | `curl "http://127.0.0.1:5000/helper/nearest?lat=13.0&lng=80.2"` |
| `POST /helper/respond` | Accept/decline. Accept assigns a mission + broadcasts `helper_accepted`; a second accept is rejected with "already accepted". | body `{"incidentId":"...","helperUid":"h1","accepted":true,"distanceMeters":120}` |
| `POST /helper/mission/update` | Volunteer progress `EN_ROUTE`/`ON_SCENE`/`COMPLETED`/`ABANDONED`; boosts reputation on completion; broadcasts `mission_updated`. | body `{"missionId":"mission_...","status":"COMPLETED"}` |

### ML severity model

| Method & path | Purpose | Example |
|---|---|---|
| `GET /api/v1/model/health` | Is the 61-feature model loaded, SHA-256 verified, and how fast? | `curl http://127.0.0.1:5000/api/v1/model/health` |
| `GET /api/v1/predictions/schema` | The contract the app builds its form from (5 numeric + 9 categorical, allowed values, ranges). | `curl http://127.0.0.1:5000/api/v1/predictions/schema` |
| `POST /api/v1/predictions/severity` | Predict `Fatal`/`Serious`/`Slight` from 14 raw values. 400 `INVALID_FEATURES` on bad input. Rate limited (60/min). | body `{"features":{...14 fields...}}` |
| `POST /api/v1/incidents/<id>/severity-prediction` | Predict for an existing incident and attach it as an advisory (never mutates status). | body `{"features":{...}}` |

### Operations / demo

| Method & path | Purpose | Example |
|---|---|---|
| `GET /health` | Process + Firebase status. | `curl http://127.0.0.1:5000/health` |
| `GET /analytics` | Counters for the dashboard stat cards (active, resolved today, critical, helpers). | `curl http://127.0.0.1:5000/analytics` |
| `POST /demo/simulate` | Create a realistic random Chennai incident (`minor`/`major`/`critical`) and broadcast it — drives the dashboard demo. | body `{"severityType":"critical"}` |
| `POST /demo/clear` | Delete all `isDemo` incidents (reset between rehearsals). | `curl -X POST http://127.0.0.1:5000/demo/clear` |

---

## 4. Socket.IO reference — the real-time layer

Endpoint: `http://127.0.0.1:5000`. The **backend never polls**; the app and
dashboard hold a duplex connection.

### Events the client sends (upstream)

| Event | Payload | Who sends | Effect |
|---|---|---|---|
| `create_incident` | `{latitude, longitude, confidence, severity, severityScore, plusCode}` | Flutter SOS | Creates the incident, **ACKs `{success, incidentId}`** (the app stores this id), broadcasts `incident_created` |
| `update_location` | `{incidentId, latitude, longitude}` | Flutter live tracking | Persists victim position, broadcasts `location_updated` |
| `dispatch_resource` | `{incidentId, type}` | Dashboard | Same as `POST /dispatch` |
| `update_status` | `{incidentId, status}` | Dashboard | Same as `POST /update-status` |
| `helper_respond` | `{incidentId, helperUid, accepted, distanceMeters}` | Flutter volunteer | Accept/decline |
| `stop_tracking` | `{incidentId}` | Flutter | Stop GPS streaming |

### Events the client receives (downstream)

| Event | Emitted when | Consumed by |
|---|---|---|
| `incident_created` | SOS, `/demo/simulate` | App incident feed, dashboard alerts (+ warning beep) |
| `incident_updated` | status / dispatch / tracking change | App + dashboard |
| `incident_deleted` | removal | App + dashboard |
| `helper_accepted` | volunteer accepts | Dashboard `helperSlots` |
| `mission_updated` | mission status changes | Dashboard |
| `severity_prediction` | ML advisory attached | App + dashboard (advisory only) |
| `location_updated` | `update_location` socket or HTTP ping | Dashboard map marker |

The Flutter client subscribes to all seven events and exposes them through
`SocketService.onEvent(name)` / `SocketService.serverEvents`.

> **Native transport note.** On Android/iOS the Dart client connects over
> **websocket only**; `socket_io_client` does not implement polling on
> `dart:io`. Web builds keep polling as a fallback. This is set in
> `app/lib/services/socket_service.dart`.

---

## 5. Verify each requested capability

### 5.1 Real-time alerts (backend → dashboard/app), end to end

```powershell
# Terminal A: watch the backend.  Terminal B:
$body = '{"severityType":"critical"}'
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:5000/demo/simulate -ContentType 'application/json' -Body $body
```

Terminal A logs `Demo incident created: demo_xxx` and (when the dashboard or
app is connected) the client receives `incident_created` immediately. The app
also has a live socket test that asserts exactly this:

```
flutter test test/live_socket_e2e_test.dart --dart-define=ROADSOS_LIVE_E2E=true --dart-define=ROADSOS_BACKEND_URL=http://127.0.0.1:5000
```

### 5.2 Mobile signal → app (duplex socket)

The same test file proves the app connects *and* receives server pushes, plus
`statusStream` connection state. It uses the same `SocketService` the SOS flow
uses, so a green run means the app's socket path is wired.

### 5.3 Real-time accident detection (sensors → SOS)

On-device chain: accelerometer/gyroscope → `MotionAnalyzer` + `OrientationAnalyzer`
+ `InactivityDetector` → `DetectionEngine` confidence ≥ 0.7 →
`EngineEvent.accidentDetected` → `EmergencyService.performSOS()`.

Verified without a phone via synthetic sensor samples:

```
cd E:\AVNISH-PREOJECT\roadsos\app
flutter test test/detection_engine_test.dart
```

Covers: impact + sustained rotation crosses 0.7 and fires · a single low spike does
**not** false-trigger · `reset()` re-arms · the home screen's "Test SOS (Demo)"
button path.

A physical device is still needed for the real sensor + SMS send (see §8).

---

## 6. Start each part for a live demo

```powershell
# 1. Backend  (window 1)
cd E:\AVNISH-PREOJECT\roadsos\backend
E:\AVNISH-PREOJECT\.venv\Scripts\python.exe app.py

# 2. Dashboard (window 2)  -> http://127.0.0.1:3000
cd E:\AVNISH-PREOJECT\roadsos\frontend_dashboard
$env:REACT_APP_API_URL='http://127.0.0.1:5000'
npm start

# 3. Flutter app (window 3) — Android emulator reaches the host as 10.0.2.2
cd E:\AVNISH-PREOJECT\roadsos\app
flutter run --dart-define=ROADSOS_BACKEND_URL=http://10.0.2.2:5000
```

For a device on the same Wi-Fi use the host LAN IP (`http://192.168.x.x:5000`).
The one URL knob is `ROADSOS_BACKEND_URL` (dart-define) on the app and
`REACT_APP_API_URL` on the dashboard.

Demo script: dashboard **Live Alerts** → open the app → **Test SOS (Demo)**, or
`POST /demo/simulate`. Watch the alert card, toast + beep, the map marker, then
dispatch an ambulance and resolve. The **History** tab shows the resolved record.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `{"firebase":"disconnected"}` | Expected offline. `serviceAccountKey.json` is intentionally absent; the in-memory store is the fallback and everything except cross-restart persistence works. Drop the key in `backend/` to enable Firestore + FCM. |
| Fixes seem to have no effect | A stale backend is still holding :5000. Run `Get-Process python \| Stop-Process -Force` and start one. |
| App shows "demo history" note | Backend empty/unreachable from the app. Check `ROADSOS_BACKEND_URL` (emulator = `10.0.2.2`). |
| Dashboard "Failed to connect" | Backend not up, or `REACT_APP_API_URL` wrong. CORS allows any origin by default. |
| `flutter test` live tests skipped | Pass `--dart-define=ROADSOS_LIVE_E2E=true`. |
| Rate limited (429) on predictions | 60/min window on the ML route; wait and retry. |

---

## 8. Known gaps (honest limits)

| Item | Why not automated here |
|---|---|
| `flutter build apk` / iOS build | no Android SDK / Xcode in this environment |
| Physical-device crash detection + SMS send | needs a real phone/emulator with sensors and a SIM |
| Firestore persistence + FCM push | needs `serviceAccountKey.json` / `google-services.json` |
| Browser click-through automation | no browser automation available; covered by lint + build + client contract tests + live routes |

See `docs/testing.md` for the dated test report and `docs/security.md` for the
accepted security gaps.
