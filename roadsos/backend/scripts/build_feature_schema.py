"""Generate the authoritative ML feature schema for RoadSOS.

This script derives the *exact* input contract of the published Random Forest
model from the original artifacts produced by its training notebook:

  * ``model_features.pkl``  -> pandas Index of the 61 one-hot-encoded columns
  * ``severity_encoder.pkl`` -> sklearn LabelEncoder for the target classes
  * optional cleaned dataset -> raw categorical domains (so we know which
    category pandas ``get_dummies(drop_first=True)`` dropped as the baseline).

It writes ``backend/ml/artifacts/feature_schema.json`` which the runtime
inference module consumes. The schema is *generated*, never hand-written, so it
cannot silently drift from the published model.

Usage (from the ``backend`` directory):

    python scripts/build_feature_schema.py \
        --features ../../ml-model/model_features.pkl \
        --encoder  ../../ml-model/severity_encoder.pkl \
        --dataset  ../../ml-model/Road_Accident_Data_Cleaned.csv.gz \
        --out ml/artifacts/feature_schema.json
"""
from __future__ import annotations

import argparse
import json
import os

import joblib

# Categorical base columns that the training notebook one-hot encoded.
# (See Road_Accident_Analysis.ipynb cell: categorical_features = [...])
CATEGORICAL_BASE_COLUMNS = [
    "Day_of_Week",
    "Month",
    "Junction_Control",
    "Light_Conditions",
    "Road_Surface_Conditions",
    "Road_Type",
    "Urban_or_Rural_Area",
    "Weather_Conditions",
    "Vehicle_Type",
]

# Numeric / integer columns kept as-is by the training notebook.
NUMERIC_COLUMNS = ["Year", "Latitude", "Longitude", "Speed_limit", "Hour"]

# Identifier metadata for the model this schema describes.
MODEL_META = {
    "name": "road-accident-severity-prediction",
    "author": "hayamwahdan",
    "framework": "scikit-learn RandomForestClassifier",
    "huggingface_repo": "hayamwahdan/road-accident-severity-prediction",
    "huggingface_revision": "c4a7daf40b05e506c3c00aca7c8ab00bc00db53c",
    "artifact_filename": "road_accident_model.pkl",
    "artifact_size_bytes": 1965071297,
    "license": "MIT",
    "n_estimators": 100,
    "reported_accuracy": 0.8003,
}


def _load_feature_order(features_path: str) -> list[str]:
    obj = joblib.load(features_path)
    return [str(x) for x in list(obj)]


def _load_classes(encoder_path: str) -> list[str]:
    enc = joblib.load(encoder_path)
    return [str(x) for x in list(enc.classes_)]


def _load_raw_domains(dataset_path: str) -> dict[str, list[str]]:
    import pandas as pd

    df = pd.read_csv(dataset_path)
    domains: dict[str, list[str]] = {}
    for col in CATEGORICAL_BASE_COLUMNS:
        if col in df.columns:
            domains[col] = sorted(str(v) for v in df[col].dropna().unique())
    return domains


def build_schema(feature_order, classes, raw_domains):
    feature_set = set(feature_order)

    # --- numeric features -------------------------------------------------
    numeric = []
    for col in NUMERIC_COLUMNS:
        if col in feature_set:
            numeric.append({"name": col})

    # --- categorical / one-hot features ----------------------------------
    categorical = []
    for base in CATEGORICAL_BASE_COLUMNS:
        encoded_values = {
            col[len(base) + 1 :]
            for col in feature_order
            if col.startswith(base + "_")
        }
        raw_values = list(raw_domains.get(base, []))
        present = [v for v in raw_values if v in encoded_values]
        missing = [v for v in raw_values if v not in encoded_values]
        # Baseline = the category pandas dropped via drop_first=True.
        # pandas drops the alphabetically-first category, so pick sorted-first
        # of the missing ones; if our dataset captured none, fall back to
        # sorted(raw)[0] when that is absent from the encoded set.
        baseline = None
        if missing:
            baseline = sorted(missing)[0]
        elif raw_values:
            candidate = sorted(raw_values)[0]
            if candidate not in encoded_values:
                baseline = candidate

        onehot = {}
        for val in present:
            onehot[val] = f"{base}_{val}"

        categorical.append(
            {
                "name": base,
                "values": sorted(set(present) | ({baseline} if baseline else set())),
                "baseline": baseline,
                "onehot": onehot,
            }
        )

    # --- validate every feature is accounted for -------------------------
    covered = {f["name"] for f in numeric} | {
        col for grp in categorical for col in grp["onehot"].values()
    }
    missing = [f for f in feature_order if f not in covered]
    extra = [f for f in covered if f not in feature_set]

    class_labels = {str(i): name for i, name in enumerate(classes)}

    schema = {
        "schema_version": "1.0",
        "model": MODEL_META,
        "n_features": len(feature_order),
        "feature_order": feature_order,
        "numeric_features": numeric,
        "categorical_features": categorical,
        "class_order": classes,
        "class_labels": class_labels,
        "validation": {
            "speed_limit_allowed": [10, 15, 20, 30, 40, 50, 60, 70],
            "year_min": 1900,
            "year_max": 2100,
            "hour_min": 0,
            "hour_max": 23,
            "latitude_min": -90.0,
            "latitude_max": 90.0,
            "longitude_min": -180.0,
            "longitude_max": 180.0,
        },
        "_audit": {
            "uncovered_features": missing,
            "unknown_covered_features": extra,
        },
    }
    return schema


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    here = os.path.dirname(os.path.abspath(__file__))
    default_ml = os.path.abspath(os.path.join(here, "..", "..", "..", "ml-model"))
    ap.add_argument("--features", default=os.path.join(default_ml, "model_features.pkl"))
    ap.add_argument("--encoder", default=os.path.join(default_ml, "severity_encoder.pkl"))
    ap.add_argument(
        "--dataset",
        default=os.path.join(default_ml, "Road_Accident_Data_Cleaned.csv.gz"),
    )
    ap.add_argument(
        "--out",
        default=os.path.join(here, "..", "ml", "artifacts", "feature_schema.json"),
    )
    args = ap.parse_args()

    feature_order = _load_feature_order(args.features)
    classes = _load_classes(args.encoder)
    raw_domains = _load_raw_domains(args.dataset) if os.path.exists(args.dataset) else {}

    schema = build_schema(feature_order, classes, raw_domains)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(schema, fh, indent=2, ensure_ascii=False)

    print(f"Wrote {args.out}")
    print(f"  features: {schema['n_features']}")
    print(f"  classes : {schema['class_order']}")
    print(f"  audit   : {schema['_audit']}")


if __name__ == "__main__":
    main()
