# Architecture

RoadSOS is three cooperating pieces plus one **optional, isolated** ML module.

```
┌───────────────────────────┐        ┌──────────────────────────────────────┐
│  Flutter app (app/)       │        │  React dashboard                     │
│  riders + volunteers      │        │  (frontend_dashboard/)  police       │
│                           │        │                                      │
│  accident_detection/      │        │  App.js  LiveAlerts  IncidentDetail  │
│   sensor fusion engine    │        │  SeverityPredictionPanel (advisory)  │
│  emergency_handling/      │        │  services/api.js  services/socket.js │
│   countdown, SMS, GPS     │        └───────────────┬──────────────────────┘
│  helper_network/          │                        │ REST + Socket.IO
│  services/                │                        │
│   socket_service.dart ────┼────────┐               │
│   severity_prediction_    │        │               │
│     service.dart (opt.) ──┼──┐     │               │
└───────────────────────────┘  │     │               │
                               │     ▼               ▼
                          ┌────┴─────────────────────────────────────────┐
                          │  Flask backend (backend/)                    │
                          │                                              │
                          │  app.py  ── blueprints ── Socket.IO events   │
                          │   health / incident / dispatch / helper /    │
                          │   analytics / demo        ← emergency core    │
                          │   prediction_routes.py    ← advisory ML only  │
                          │                                              │
                          │  services/firestore_service.py → Firestore   │
                          └───────────────┬──────────────────────────────┘
                                          │
                                 ┌────────▼─────────┐
                                 │  ml/ (OPTIONAL)  │
                                 │  model_loader    │
                                 │  feature_schema  │
                                 │  predictor       │
                                 │  ---------------- │
                                 │  Random Forest    │
                                 │  road_accident_   │
                                 │  model.pkl (1.97G)│
                                 └──────────────────┘
```

## 1. Emergency path (must never depend on ML)

1. **Flutter** streams accelerometer + gyroscope (`accident_detection/services/sensor_service.dart`).
2. Three analyzers (`motion_analyzer`, `orientation_analyzer`, `inactivity_detector`) are correlated by `detection_engine.dart` (confidence threshold 0.7, 90 s event window).
3. A crash event opens a **10-second cancellable countdown** (`emergency_handling/countdown_manager.dart`).
4. If not cancelled: `emergency_service.dart` sends SMS (`sms_service.dart`), writes to Firestore (`firestore_service.dart`) and emits `create_incident` over Socket.IO (`services/socket_service.dart`).
5. **Backend** (`app.py`) fans the incident out: `socketio.emit('incident_created')` → dashboard; helper geohash search (`routes/helper_routes.py`); dispatch/status routes.
6. **Dashboard** renders alerts, dispatches units, streams live location.

Nothing in steps 1–6 imports, calls or waits for the ML module.

## 2. Advisory ML path (optional, additive)

```
client (Flutter / dashboard / curl)
   └── POST /api/v1/predictions/severity        { "features": { …14 raw fields… } }
           │
           ├── routes/prediction_routes.py     optional API key + rate limit + JSON guard
           ├── ml/predictor.py                 get_predictor() → cached singleton
           │      ├── ml/model_loader.py        resolves + SHA-256-verifies + joblib.load, cached
           │      ├── ml/feature_schema.py      validate() → encode() to the exact 61-dim vector
           │      └── ml/errors.py              typed errors → HTTP 400 / 503
           └── response: severity + probabilities + model metadata + limitations
```

`POST /api/v1/incidents/<id>/severity-prediction` does the same **plus** attaching the
result to an existing incident:

* writes only the `severityPrediction` sub-object (never status, sensor severity or escalation);
* emits `severity_prediction` over Socket.IO **before** persisting, so real-time consumers
  still receive the estimate if Firestore is offline;
* returns `persisted: false` when Firestore is unavailable (HTTP 200 — the estimate is
  still valid, it just was not stored).

## 3. Failure isolation

| Failure | Effect on emergency path | Effect on ML |
|---|---|---|
| ML dependencies not installed | none | `/api/v1/*` returns 503 `MODEL_UNAVAILABLE` |
| Model file missing / wrong size / bad SHA-256 | none | 503 `MODEL_UNAVAILABLE`; reason in `GET /api/v1/model/health` |
| Model load slow (cold, ~7–27 s measured) | none — startup warm-up is in a `try/except` | first request slow, then cached |
| Firestore offline | existing app already degrades | prediction returned, `persisted: false` |
| ML client (Flutter/dashboard) unreachable backend | none | UI shows "unavailable"; client swallows the error |

The Flutter client enforces this at the type level: `SeverityPredictionService` never throws —
every method returns a `PredictionOutcome` / `ModelHealth` / `null`, so no ML failure can
propagate into a widget that participates in an emergency flow.

## 4. Directory map

```
roadsos/
├─ app/                          Flutter (riders + volunteers)
│  ├─ lib/accident_detection/     sensor fusion engine
│  ├─ lib/emergency_handling/     countdown, SMS, GPS, Firestore, emergency service
│  ├─ lib/helper_network/         geohash volunteer network
│  ├─ lib/services/               socket, tracking, maps, medical, ML client
│  │  └─ severity_prediction_service.dart   ← ML client (advisory)
│  ├─ lib/ui/screens/severity_prediction_screen.dart  ← ML screen (advisory)
│  └─ test/                       Dart unit + widget tests
├─ backend/                       Flask + Socket.IO command centre
│  ├─ app.py                      app factory, CORS, socket events, model warm-up
│  ├─ routes/                     existing emergency blueprints
│  │  └─ prediction_routes.py     ← ML blueprint (advisory)
│  ├─ ml/                         ← ML inference package (optional)
│  │  ├─ config.py                env-driven model config + pinned revision/SHA
│  │  ├─ model_loader.py          verified, cached load
│  │  ├─ feature_schema.py        validation + one-hot encoding
│  │  ├─ predictor.py             predict() + health()
│  │  ├─ rate_limit.py            in-memory per-IP limiter
│  │  └─ artifacts/feature_schema.json   committed contract (61 features)
│  ├─ scripts/                    download_model.py, verify_model.py, build_feature_schema.py
│  ├─ tests/                      pytest suite (unit + API + safety + real model)
│  └─ requirements-ml.txt         optional ML requirements
├─ frontend_dashboard/            React (CRA) police dashboard
│  └─ src/components/SeverityPredictionPanel.jsx   ← ML panel (advisory)
├─ models/                        local model cache (gitignored)
└─ docs/                          this documentation set
```

## 5. Why a package inside the existing backend instead of a new service?

* The existing backend already owns Firestore, Socket.IO and the incident model; a separate
  service would duplicate all three and add a network hop on the advisory path.
* A separate service would be a *new* failure domain that a hackathon reviewer must deploy;
  the module here can be dropped (`requirements-ml.txt` not installed) and the app still runs.
* The trade-off is honest: model load is in-process, so the API process needs ~2 GB of RAM
  head-room for the artifact. Mitigation: keep `MODEL_HEALTHCHECK=0` and/or run the
  predictions in a sidecar process later — the HTTP contract would not change.
