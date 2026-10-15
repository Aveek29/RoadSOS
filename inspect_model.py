import json
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

MODEL_PATH = r"E:\AVNISH-PREOJECT\model_cache\road_accident_model.pkl"
FEATURES_PATH = r"E:\AVNISH-PREOJECT\ml-model\model_features.pkl"
ENCODER_PATH = r"E:\AVNISH-PREOJECT\ml-model\severity_encoder.pkl"

import joblib  # noqa: E402
import numpy as np  # noqa: E402

print("joblib", joblib.__version__)
import sklearn  # noqa: E402
import pandas as pd  # noqa: E402

print("sklearn", sklearn.__version__)
print("pandas", pd.__version__)
print("numpy", np.__version__)

t0 = time.time()
model = joblib.load(MODEL_PATH)
t1 = time.time()
print(f"LOAD_TIME_SECONDS={t1 - t0:.2f}")

print("model_type:", type(model).__module__ + "." + type(model).__name__)
print("n_features_in_:", getattr(model, "n_features_in_", None))
print("n_outputs_:", getattr(model, "n_outputs_", None))
print("n_estimators:", getattr(model, "n_estimators", None))
print("classes_:", getattr(model, "classes_", None))
print("params:", json.dumps({k: str(v) for k, v in model.get_params().items()}, indent=2))

features = list(joblib.load(FEATURES_PATH))
encoder = joblib.load(ENCODER_PATH)
print("n_features_metadata:", len(features))
print("encoder_classes:", list(encoder.classes_))

# Smoke inference on an all-zero vector (clearly-labelled synthetic technical input)
x = np.zeros((1, len(features)), dtype=float)
t0 = time.time()
pred = model.predict(x)
t1 = time.time()
proba = model.predict_proba(x)
t2 = time.time()
print("predict_latency_ms:", round((t1 - t0) * 1000, 2))
print("proba_latency_ms:", round((t2 - t1) * 1000, 2))
print("raw_pred:", pred.tolist())
print("raw_proba:", proba.tolist())
print("decoded:", encoder.inverse_transform(pred).tolist())
print("feature_importances_len:", len(getattr(model, "feature_importances_", [])))
