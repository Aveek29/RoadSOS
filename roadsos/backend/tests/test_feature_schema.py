"""Unit tests for feature-schema loading, validation and one-hot encoding."""
from __future__ import annotations

import pytest

from ml.errors import FeatureValidationError
from ml.feature_schema import FeatureSchema


def test_schema_loads_and_matches_published_model(schema):
    assert schema.n_features == 61
    assert len(schema.feature_order) == 61
    assert schema.class_order == ["Fatal", "Serious", "Slight"]
    assert schema.class_labels[0] == "Fatal"
    assert schema.class_labels[1] == "Serious"
    assert schema.class_labels[2] == "Slight"


def test_numeric_and_categorical_counts(schema):
    assert schema.numeric_features == [
        "Year",
        "Latitude",
        "Longitude",
        "Speed_limit",
        "Hour",
    ]
    assert len(schema.categorical) == 9  # 5 numeric + 9 categorical = 14 inputs
    assert len(schema.raw_feature_names) == 14


def test_encode_produces_exactly_one_onehot_per_group(schema, valid_features):
    vec = schema.encode(schema.validate(valid_features))
    assert len(vec) == 61

    active = {schema.feature_order[i] for i, v in enumerate(vec) if v == 1.0}
    # One active column per non-baseline category supplied.
    assert "Day_of_Week_Monday" in active
    assert "Month_Mar" in active
    assert "Weather_Conditions_Fine no high winds" in active
    assert "Vehicle_Type_Car" in active
    assert "Urban_or_Rural_Area_Urban" in active
    assert "Road_Type_Single carriageway" in active
    assert "Light_Conditions_Daylight" in active
    assert "Junction_Control_Auto traffic signal" in active
    # Road surface "Dry" is the drop_first baseline -> every road-surface col is 0
    for name in schema.feature_order:
        if name.startswith("Road_Surface_Conditions_"):
            assert name not in active
    assert len(active) == 8


def test_baseline_category_encodes_to_all_zero_group(schema, valid_features):
    # Day_of_Week baseline is Friday.
    vec = schema.encode(schema.validate(dict(valid_features, Day_of_Week="Friday")))
    day_cols = [n for n in schema.feature_order if n.startswith("Day_of_Week_")]
    assert day_cols
    for name in day_cols:
        assert vec[schema.feature_order.index(name)] == 0.0


def test_encode_keeps_exact_published_order(schema, valid_features):
    vec = schema.encode(schema.validate(valid_features))
    # Numeric values land at their documented positions.
    assert vec[schema.feature_order.index("Year")] == 2021.0
    assert vec[schema.feature_order.index("Speed_limit")] == 30.0
    assert vec[schema.feature_order.index("Hour")] == 15.0


def test_missing_numeric_feature_rejected(schema, valid_features):
    bad = dict(valid_features)
    bad.pop("Hour")
    with pytest.raises(FeatureValidationError) as exc:
        schema.validate(bad)
    assert any("Hour" in d for d in exc.value.details)


def test_missing_categorical_feature_rejected(schema, valid_features):
    bad = dict(valid_features)
    bad.pop("Weather_Conditions")
    with pytest.raises(FeatureValidationError) as exc:
        schema.validate(bad)
    assert any("Weather_Conditions" in d for d in exc.value.details)


def test_invalid_categorical_value_rejected(schema, valid_features):
    bad = dict(valid_features, Weather_Conditions="Hurricane")
    with pytest.raises(FeatureValidationError) as exc:
        schema.validate(bad)
    assert any("Weather_Conditions" in d for d in exc.value.details)


def test_unknown_feature_rejected(schema, valid_features):
    bad = dict(valid_features, bogus_feature=1)
    with pytest.raises(FeatureValidationError) as exc:
        schema.validate(bad)
    assert any("bogus_feature" in d for d in exc.value.details)


def test_wrong_numeric_type_rejected(schema, valid_features):
    bad = dict(valid_features, Hour="not-a-number")
    with pytest.raises(FeatureValidationError) as exc:
        schema.validate(bad)
    assert any("Hour" in d for d in exc.value.details)


def test_boolean_rejected_for_numeric(schema, valid_features):
    bad = dict(valid_features, Speed_limit=True)
    with pytest.raises(FeatureValidationError):
        schema.validate(bad)


def test_numeric_string_is_coerced(schema, valid_features):
    ok = dict(valid_features, Hour="15")
    assert schema.validate(ok)["Hour"] == 15.0


def test_range_checks_hour_lat_speed(schema, valid_features):
    with pytest.raises(FeatureValidationError):
        schema.validate(dict(valid_features, Hour=25))
    with pytest.raises(FeatureValidationError):
        schema.validate(dict(valid_features, Latitude=100.0))
    with pytest.raises(FeatureValidationError):
        schema.validate(dict(valid_features, Speed_limit=999))


def test_non_dict_features_rejected(schema):
    with pytest.raises(FeatureValidationError):
        schema.validate(["not", "a", "dict"])


def test_all_categorical_domains_present(schema):
    allowed = schema.allowed_values()
    # every encoded (non-baseline) value must be in the allowed domain
    for group, spec in schema.categorical.items():
        for val in spec["onehot"]:
            assert val in allowed[group]
        # baseline is present in values but has no one-hot column
        if spec["baseline"]:
            assert spec["baseline"] in allowed[group]
            assert spec["baseline"] not in spec["onehot"]
