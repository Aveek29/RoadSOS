# API reference

Base URL: `http://<host>:5000` (Flask + Socket.IO). All REST payloads are JSON.

* **Emergency endpoints** (`/health`, `/incidents`, `/dispatch`, …) are the pre-existing
  command-centre API. They are **never** gated by the ML module.
* **Advisory ML endpoints** (`/api/v1/…`) are additive, optional and read-only with respect to
  incident state.

---

## 1. Emergency / command-centre endpoints (pre-existing)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness + Firestore connectivity |
| GET | `/incidents` | List incidents |
| GET | `/incident/<id>` | One incident |
| POST | `/update-status` | Change incident status (`ACTIVE`/`RESOLVED`) |
| POST | `/dispatch` | Dispatch a responder unit |
| POST | `/incident/<id>/location` | Stream a location update |
| POST | `/incident/<id>/stop-tracking` | End live tracking |
| POST | `/helper/register`, `/helper/presence`, `/helper/nearest`, `/helper/respond`, `/helper/mission/update` | Geohash volunteer network |
| GET | `/analytics` | Dashboard statistics |
| POST | `/demo/simulate`, `/demo/clear` | Demo data generator (for presentations) |

Socket.IO events: `connect`, `disconnect`, `create_incident`, `update_location`,
`dispatch_resource`, `update_status`, `helper_respond`, `stop_tracking` (client→server);
`incident_created`, `incident_updated`, `incident_deleted`, `helper_accepted`,
**`severity_prediction`** (server→client).

---

## 2. `GET /api/v1/model/health`

Reports whether the pinned model is usable. **200** when ready, **503** when the artifact is
missing/unloadable (so probes can gate on it).

```bash
curl -s http://127.0.0.1:5000/api/v1/model/health
```

Real response from this environment:

```json
{
  "success": true,
  "model": {
    "available": true,
    "state": "loaded",
    "reason": null,
    "nFeaturesIn": 61,
    "nFeaturesSchema": 61,
    "classOrder": ["Fatal", "Serious", "Slight"],
    "schemaVersion": "1.0",
    "sha256Verified": true,
    "artifactSizeBytes": 1965071297,
    "loadSeconds": 13.471,
    "model": {
      "name": "road-accident-severity-prediction",
      "framework": "scikit-learn RandomForestClassifier",
      "repo": "hayamwahdan/road-accident-severity-prediction",
      "revision": "c4a7daf40b05e506c3c00aca7c8ab00bc00db53c",
      "artifact_filename": "road_accident_model.pkl",
      "expected_size_bytes": 1965071297,
      "license": "MIT"
    }
  }
}
```

## 3. `GET /api/v1/predictions/schema`

The machine-readable input contract (the dashboard and the Flutter screen build their inputs
from this — categories are never hard-coded in a client).

```json
{
  "success": true,
  "schemaVersion": "1.0",
  "input": {
    "numericFeatures": ["Year", "Latitude", "Longitude", "Speed_limit", "Hour"],
    "categoricalFeatures": {
      "Day_of_Week": { "values": ["Friday", "Monday", "…"], "baseline": "Friday" },
      "Month": { "values": ["Jan", "Feb", "…"], "baseline": "Apr" }
    }
  },
  "output": { "classOrder": ["Fatal", "Serious", "Slight"], "classLabels": {...}, "nFeatures": 61 },
  "speedLimitAllowed": [10, 15, 20, 30, 40, 50, 60, 70],
  "limits": {
    "yearMin": 1900, "yearMax": 2100,
    "hourMin": 0, "hourMax": 23,
    "latitudeMin": -90.0, "latitudeMax": 90.0,
    "longitudeMin": -180.0, "longitudeMax": 180.0
  },
  "limitations": ["Model-derived severity is a statistical estimate, …"]
}
```

## 4. `POST /api/v1/predictions/severity`

Request:

```json
{
  "features": {
    "Year": 2021, "Latitude": 51.5074, "Longitude": -0.1278,
    "Speed_limit": 30, "Hour": 15,
    "Day_of_Week": "Monday", "Month": "Jan",
    "Junction_Control": "Give way or uncontrolled",
    "Light_Conditions": "Daylight",
    "Road_Surface_Conditions": "Dry",
    "Road_Type": "Single carriageway",
    "Urban_or_Rural_Area": "Urban",
    "Weather_Conditions": "Fine no high winds",
    "Vehicle_Type": "Car"
  }
}
```

Real 200 response from this environment:

```json
{
  "success": true,
  "prediction": {
    "severity": "Serious",
    "probabilities": { "Fatal": 0.02, "Serious": 0.49, "Slight": 0.49 },
    "classOrder": ["Fatal", "Serious", "Slight"],
    "predictedClassIndex": 1,
    "modelVersion": "c4a7daf40b05e506c3c00aca7c8ab00bc00db53c",
    "latencyMs": 16.6
  },
  "model": { "name": "road-accident-severity-prediction", "revision": "c4a7daf40b…", "license": "MIT" },
  "predictionId": "3a7632c88f4b401da64980813ea9ebc2",
  "timestamp": "2026-10-15T15:32:29.982228Z",
  "advisory": true,
  "limitations": ["…4 items…"]
}
```

Error responses (all verified live):

| Status | `code` | When | Body |
|---|---|---|---|
| 400 | `INVALID_FEATURES` | unknown category, out-of-range value, missing/unknown feature | `{"success":false,"error":"Invalid prediction request","code":"INVALID_FEATURES","details":["Day_of_Week: 'Funday' is not an allowed category","Hour: must be between 0 and 23","Speed_limit: must be one of [10, 15, 20, 30, 40, 50, 60, 70]"]}` |
| 400 | `INVALID_JSON` | not JSON, malformed body, missing `features`, wrong `Content-Type` | `{"success":false,"error":"Request Content-Type must be application/json","code":"INVALID_JSON"}` |
| 401 | `UNAUTHORIZED` | `ROADSOS_API_KEY` set and key missing/wrong | `{"success":false,"error":"Missing or invalid API key","code":"UNAUTHORIZED"}` |
| 429 | `RATE_LIMITED` | > `PREDICTION_RATE_LIMIT_PER_MIN` in 60 s from one IP | `{"success":false,"error":"Prediction rate limit exceeded","code":"RATE_LIMITED","retryAfterSeconds":2}` + `Retry-After` header |
| 503 | `MODEL_UNAVAILABLE` | artifact missing/corrupt/unloadable | `{"success":false,"error":"Accident-severity model is currently unavailable. Emergency incident handling is unaffected.","code":"MODEL_UNAVAILABLE"}` |
| 500 | `PREDICTION_FAILED` | unexpected inference error | logged server-side |

## 5. `POST /api/v1/incidents/<incident_id>/severity-prediction`

Same request body. Adds the estimate to an incident.

```json
{
  "success": true,
  "incidentId": "abc123",
  "predictionId": "e964fb19cbb84be59a7fef844b277cfc",
  "prediction": { "severity": "Serious", "probabilities": {...}, "classOrder": [...], "latencyMs": 19.43, "modelVersion": "c4a7daf40b…" },
  "persisted": false,
  "advisory": true,
  "timestamp": "2026-10-15T15:32:30.057699Z",
  "limitations": ["…"]
}
```

Behaviour:

* writes **only** `incidents/<id>.severityPrediction = {predictionId, severity, probabilities,
  classOrder, modelVersion, model, predictedAt, advisory:true, source:"ml"}` —
  `status`, sensor severity, `dispatchedResources` and escalation fields are untouched;
* emits the `severity_prediction` socket event **before** trying to persist, so a Firestore
  outage cannot lose the estimate;
* returns `persisted: false` (HTTP 200) when Firestore is unavailable — observed in this
  environment, where no service-account key is configured;
* returns **404** `Incident not found` only when Firestore *is* connected and the document does
  not exist.

## 6. Authentication

Optional, and only for `/api/v1/predictions/*`:

```bash
export ROADSOS_API_KEY=super-secret
curl -H "X-API-Key: super-secret" ...      # or:  -H "Authorization: Bearer super-secret"
```

Unset ⇒ open (local development). The legacy command-centre endpoints keep their existing
(no-auth) behaviour — documented as a security finding rather than silently changed.

## 7. Limits and CORS

* Request bodies: `MAX_CONTENT_LENGTH` (default 1 MB).
* Prediction rate: `PREDICTION_RATE_LIMIT_PER_MIN` (default 60/min/IP, in-memory — per process).
* CORS: `ALLOWED_ORIGINS` (comma-separated). Unset ⇒ `*` **with a startup warning**.

## 8. Client quick reference

| Client | Where |
|---|---|
| Dashboard | `frontend_dashboard/src/services/api.js` → `modelHealth()`, `getPredictionSchema()`, `predictSeverity(features)`, `predictSeverityForIncident(id, features)` |
| Dashboard UI | `frontend_dashboard/src/components/SeverityPredictionPanel.jsx` (inside `IncidentDetail`) |
| Dashboard socket | `frontend_dashboard/src/services/socket.js` → `subscribeToSeverityPrediction(cb)` |
| Flutter app | `app/lib/services/severity_prediction_service.dart` (`checkModelHealth`, `fetchSchema`, `predictSeverity`, `predictForIncident`) |
| Flutter UI | `app/lib/ui/screens/severity_prediction_screen.dart` (Profile → *Analytics (optional)* → *Severity Predictor*) |

`docs/testing.md` records which of these paths were actually executed.
