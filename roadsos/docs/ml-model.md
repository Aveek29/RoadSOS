# The ML model and how RoadSOS uses it

> **Scope warning.** This model predicts the severity of an accident **from historical
> structured crash attributes**. It is *not* crash detection, *not* a medical assessment and
> *not* part of any emergency escalation path. The presentation's "AI Severity Pipeline:
> Ultralytics YOLO (pipeline-ready)" item is a different, *unimplemented* capability — see
> `docs/presentation-requirements.md` (deviation D2). Nothing here claims to deliver it.

## 1. Provenance

| Property | Value |
|---|---|
| Source | Hugging Face — [`hayamwahdan/road-accident-severity-prediction`](https://huggingface.co/hayamwahdan/road-accident-severity-prediction) |
| Revision pinned | `c4a7daf40b05e506c3c00aca7c8ab00bc00db53c` |
| Artifact | `road_accident_model.pkl` — **1,965,071,297 bytes** (1.97 GB) |
| Artifact SHA-256 | `B9E5BE7E6A24CEE9746C743F630E41FADE629E5A38A3DC9FE1017508FE7E98B2` |
| Publishes | MIT license |
| Publisher-stated metrics | baseline accuracy 85.4 %, SMOTE-balanced 80.03 %, 5-fold CV 85.4 % — **not verified by us** |

Verification performed **in this environment**:
- downloaded from the pinned revision and size-checked (1,965,071,297 bytes);
- SHA-256 recomputed and matched the value above;
- loaded with `joblib` under scikit-learn **1.6.1** (the version the publisher pinned in
  `ml-model/requirements.txt`, i.e. the training environment);
- introspection of the live object:

```
class              = RandomForestClassifier
n_estimators       = 100
criterion          = gini
max_features       = sqrt
max_depth          = None
min_samples_split  = 2
min_samples_leaf   = 1
random_state       = 42
n_features_in_     = 61
classes_           = [0 1 2]   → ('Fatal', 'Serious', 'Slight')
```

- measured cold load: **13.5 s** (in-app warm-up) / 26.7 s (first load inside `pytest`);
  measured inference: **12–30 ms** per request (warm).

### 61 vs "62 features"
The publisher's README says *"Final Features 62 (after One-Hot Encoding)"*. The actual artifact
reports `n_features_in_ = 61`, and `feature_names_in_` lists exactly **61** columns. The model
is authoritative for the integration, so RoadSOS uses **61**. Our
`backend/ml/artifacts/feature_schema.json` is generated from the publisher's own
`model_features.pkl` + `severity_encoder.pkl` + cleaned dataset, and an automated audit in
`scripts/build_feature_schema.py` asserts that *every* model column is produced by the raw
feature contract (no uncovered column, no unknown category).

## 2. The input contract (14 raw values → 61 encoded columns)

Sent by a client as `{"features": { … }}`:

| Kind | Fields |
|---|---|
| Numeric (5) | `Year`, `Latitude`, `Longitude`, `Speed_limit`, `Hour` |
| Categorical (9) | `Day_of_Week`, `Month`, `Junction_Control`, `Light_Conditions`, `Road_Surface_Conditions`, `Road_Type`, `Urban_or_Rural_Area`, `Weather_Conditions`, `Vehicle_Type` |

`backend/ml/feature_schema.py` validates each value (unknown keys are **rejected**, not ignored)
and then one-hot encodes with the original `drop_first=True` semantics — the dropped
("baseline") category sets no column to 1:

| Feature | Baseline (encoded as all-zeros) |
|---|---|
| `Day_of_Week` | `Friday` |
| `Month` | `Apr` |
| `Junction_Control` | `Authorised person` |
| `Light_Conditions` | `Darkness - lighting unknown` |
| `Road_Surface_Conditions` | `Dry` |
| `Road_Type` | `Dual carriageway` |
| `Urban_or_Rural_Area` | `Rural` |
| `Weather_Conditions` | `Fine + high winds` |
| `Vehicle_Type` | `Agricultural vehicle` |

`Speed_limit` is restricted to the values present in training: `[10, 15, 20, 30, 40, 50, 60, 70]`
(mph — the dataset is British). `Hour` ∈ [0, 23]; `Year` ∈ [1900, 2100]; lat/lon validated to
legal ranges.

## 3. Output

```json
{
  "severity": "Serious",
  "probabilities": { "Fatal": 0.02, "Serious": 0.49, "Slight": 0.49 },
  "classOrder": ["Fatal", "Serious", "Slight"],
  "predictedClassIndex": 1,
  "modelVersion": "c4a7daf40b05e506c3c00aca7c8ab00bc00db53c",
  "latencyMs": 16.6
}
```

Class indices come from the publisher's `severity_encoder.pkl` (0=Fatal, 1=Serious, 2=Slight)
and are never guessed. `probabilities` are the forest's **vote distribution** — *not* calibrated
real-world probabilities, and every API response says so in its `limitations` array.

## 4. Runtime configuration

All optional; the module works with none of them set (`backend/ml/config.py`).

| Variable | Default | Purpose |
|---|---|---|
| `MODEL_PATH` | — | Explicit `.pkl` path (highest priority) |
| `MODEL_CACHE_DIR` | — | Directory searched when `MODEL_PATH` is unset |
| `MODEL_FILENAME` | `road_accident_model.pkl` | Artifact name |
| `MODEL_HF_REPO` | `hayamwahdan/road-accident-severity-prediction` | Source repo |
| `MODEL_HF_REVISION` | `c4a7daf40b05e506c3c00aca7c8ab00bc00db53c` | Pinned revision |
| `MODEL_SHA256` | `B9E5BE…E98B2` | Integrity check (empty string disables) |
| `MODEL_SCHEMA_PATH` | `backend/ml/artifacts/feature_schema.json` | Input contract |
| `MODEL_HEALTHCHECK` | `1` | Warm the model at startup |
| `PREDICTION_RATE_LIMIT_PER_MIN` | `60` | Per-IP limit for prediction calls |
| `ROADSOS_API_KEY` | empty (open) | Optional shared secret for prediction calls |

Search order when no path is given: `MODEL_PATH` → `MODEL_CACHE_DIR[/models]` →
`backend/models/` → `backend/` → **`<repo>/models/`** (this is where `download_model.py` puts it).

## 5. Fetching the model (never committed)

The artifact is 1.97 GB, so it is gitignored (`.gitignore`: `models/`, `*.pkl`).

```bash
cd backend
python scripts/download_model.py            # resumes/reuses an existing file
python scripts/verify_model.py --load       # size + SHA-256 + real joblib load + smoke predict
```

`download_model.py` writes to `<repo>/models/road_accident_model.pkl`, verifies size and
SHA-256, and refuses to keep a corrupt download.

## 6. Honest limitations (also returned by the API)

1. **Statistical estimate, not an outcome.** The model never observed the crash; it only sees
   pre-crash environment/infrastructure/spatio-temporal attributes.
2. **Probabilities are not calibrated.** They are the average of the trees' votes.
3. **Nothing about the driver.** Behaviour (alcohol, distraction, fatigue) and demographics are
   not modelled and cannot be inferred from these inputs.
4. **Regional bias.** The training data is British (fields like `Junction_Control`,
   `Light_Conditions` and mph speed limits are UK DfT categories). Applying it to other
   territories is an extrapolation; the publisher recommends retraining. The Flutter screen and
   dashboard panel therefore label every result as advisory.
5. **Class imbalance.** Fatal incidents are ~1.2 % of the source data; the publisher applied
   SMOTE at training time, which traded overall accuracy (85.4 % → 80.03 %) for better
   high-severity recall. We did **not** re-evaluate these numbers — reproducing them would
   require the full training pipeline.
6. **No fairness or drift evaluation was performed** in this integration.

## 7. What we deliberately did *not* do

- **No fabricated metrics.** No accuracy/F1/ROC number is claimed anywhere in this repo from our
  own testing; only the publisher's numbers, labelled as unverified.
- **No fake predictions.** There is no fallback that invents a class label. If the model cannot
  be loaded, the endpoint returns **503 `MODEL_UNAVAILABLE`** and says so.
- **No alerting on predictions.** The publisher's README suggests alerting when
  `P(Fatal) > 2 %`; we do *not* wire that to any dispatch, notification or countdown. Severity
  estimates only ever add an advisory `severityPrediction` field (and a `severity_prediction`
  socket event) and are never allowed to change an incident's status.
- **No coupling to detection.** The Random Forest does not read sensor data and the sensor
  engine does not read model output. Two independent systems, on purpose.

## 8. Tests that exercise the model

| Test | File | What it proves |
|---|---|---|
| Real artifact loads, SHA-256 matches, 61 features, classes in the documented order | `backend/tests/test_model_artifact.py` (marked `real_model`) | the model really is the pinned artifact and really runs |
| Prediction vector length/one-hot semantics | `backend/tests/test_feature_schema.py`, `test_predictor.py` | contract correctness |
| API behaviour (200/400/503, unknown keys, ranges, rate limit, API key) | `backend/tests/test_prediction_api.py` | endpoint contract |
| Safety invariants (never mutates status, never blocks emergency routes, advisory flags) | `backend/tests/test_safety.py` | isolation from emergency workflows |
| Flutter client parses results, maps errors, never throws | `app/test/severity_prediction_service_test.dart` | client-side isolation |

Exact results: `docs/testing.md`.
