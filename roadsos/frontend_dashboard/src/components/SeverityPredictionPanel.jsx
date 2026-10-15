import React, { useEffect, useState, useCallback } from 'react';
import { Brain, AlertTriangle, Loader2, Activity } from 'lucide-react';
import { api } from '../services/api';

/**
 * Advisory accident-severity analysis (ML).
 *
 * IMPORTANT — this panel is *not* crash detection. It shows a statistical
 * severity estimate produced by the published Random Forest model from
 * structured accident attributes (weather, light, road, speed, location, time).
 * It never changes an incident's status and must never be treated as a
 * confirmed outcome or a medical assessment.
 */

const DEFAULT_FORM = {
  Year: 2021,
  Latitude: 13.0827,
  Longitude: 80.2707,
  Speed_limit: 30,
  Hour: 15,
  Day_of_Week: 'Monday',
  Month: 'Jan',
  Junction_Control: 'Give way or uncontrolled',
  Light_Conditions: 'Daylight',
  Road_Surface_Conditions: 'Dry',
  Road_Type: 'Single carriageway',
  Urban_or_Rural_Area: 'Urban',
  Weather_Conditions: 'Fine no high winds',
  Vehicle_Type: 'Car',
};

const SEVERITY_TONE = { Fatal: 'critical', Serious: 'high', Slight: 'low' };

const SeverityPredictionPanel = ({ incidentId, storedPrediction }) => {
  const [schema, setSchema] = useState(null);
  const [modelAvailable, setModelAvailable] = useState(null);
  const [form, setForm] = useState(DEFAULT_FORM);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [details, setDetails] = useState(null);
  const [schemaError, setSchemaError] = useState(false);

  useEffect(() => {
    let mounted = true;
    api.getPredictionSchema().then((res) => {
      if (mounted && res?.success) setSchema(res);
      else if (mounted) setSchemaError(true);
    });
    api.modelHealth().then((res) => {
      if (mounted) setModelAvailable(!!res?.model?.available);
    });
    return () => { mounted = false; };
  }, []);

  const setField = (key, value, numeric) => {
    setForm((prev) => ({ ...prev, [key]: numeric ? value : value }));
    setResult(null);
    setError(null);
    setDetails(null);
  };

  const runAnalysis = useCallback(async () => {
    setLoading(true);
    setError(null);
    setDetails(null);
    setResult(null);

    // Coerce numeric fields to numbers before sending.
    const payload = { ...form };
    ['Year', 'Latitude', 'Longitude', 'Speed_limit', 'Hour'].forEach((k) => {
      payload[k] = Number(payload[k]);
    });

    const res = incidentId
      ? await api.predictSeverityForIncident(incidentId, payload)
      : await api.predictSeverity(payload);

    if (res?.success) {
      setResult(res);
      if (typeof res.model === 'object' && 'available' in res.model) {
        setModelAvailable(!!res.model.available);
      }
    } else {
      setError(res?.error || 'Prediction request failed');
      setDetails(res?.details || null);
      if (res?.code === 'MODEL_UNAVAILABLE') setModelAvailable(false);
    }
    setLoading(false);
  }, [form, incidentId]);

  // ---- not ready states --------------------------------------------------
  // A prediction already persisted on the incident (Firestore doc or the
  // `severity_prediction` socket payload) — shown until a fresh run replaces it.
  const stored = storedPrediction?.prediction || storedPrediction;

  if (schemaError) {
    return (
      <div className="ml-unavailable">
        <AlertTriangle size={16} />
        Severity analysis unavailable — backend schema could not be loaded.
        Emergency workflows are unaffected.
      </div>
    );
  }

  const numField = (label, key, extra = {}) => (
    <label className="ml-field" key={key}>
      <span>{label}</span>
      <input
        type="number"
        value={form[key]}
        onChange={(e) => setField(key, e.target.value)}
        {...extra}
      />
    </label>
  );

  // The server publishes the exact legal domain for every numeric field; bind
  // inputs to it so a typo cannot turn into a 400 after the click.
  const limits = schema?.limits || {};
  const limitedField = (label, key, { min, max, step, units = '' }) =>
    numField(label, key, {
      ...(min != null ? { min } : {}),
      ...(max != null ? { max } : {}),
      ...(step ? { step } : {}),
      placeholder: units,
    });

  // Speed limits are a closed set from training data — a select beats a number
  // box that could be rejected with `Speed_limit: must be one of [...]`.
  const speedOptions = schema?.speedLimitAllowed;
  const speedField =
    Array.isArray(speedOptions) && speedOptions.length > 0 ? (
      <label className="ml-field" key="Speed_limit">
        <span>Speed limit (mph)</span>
        <select
          value={form.Speed_limit}
          onChange={(e) => setField('Speed_limit', e.target.value)}
        >
          {speedOptions.map((v) => (
            <option key={v} value={v}>{v}</option>
          ))}
        </select>
      </label>
    ) : (
      numField('Speed limit (mph)', 'Speed_limit')
    );

  const selectField = (label, key) => {
    const spec = schema?.input?.categoricalFeatures?.[key];
    if (!spec) return null;
    return (
      <label className="ml-field" key={key}>
        <span>{label}</span>
        <select value={form[key]} onChange={(e) => setField(key, e.target.value)}>
          {spec.values.map((v) => (
            <option key={v} value={v}>{v}</option>
          ))}
        </select>
      </label>
    );
  };

  return (
    <div className="ml-panel">
      <div className="ml-panel-header">
        <div className="ml-title">
          <Brain size={16} />
          Accident Severity Analysis
          <span className="ml-advisory-chip">advisory · ML estimate</span>
        </div>
        <div className={`ml-model-status ${modelAvailable ? 'on' : 'off'}`}>
          <Activity size={13} />
          {modelAvailable === null ? 'checking model…' : modelAvailable ? 'model online' : 'model unavailable'}
        </div>
      </div>

      <p className="ml-panel-desc">
        Predicts historical accident severity (<strong>Slight / Serious / Fatal</strong>) from
        environmental, infrastructure, road, speed and time attributes using the published
        Random Forest model. This is <strong>not</strong> live crash detection and does not
        change an incident's status.
      </p>

      {schema && (
        <div className="ml-form">
          <div className="ml-form-grid">
            {limitedField('Year', 'Year', { min: limits.yearMin ?? 1900, max: limits.yearMax ?? 2100 })}
            {limitedField('Hour (0–23)', 'Hour', { min: limits.hourMin ?? 0, max: limits.hourMax ?? 23 })}
            {speedField}
            {limitedField('Latitude', 'Latitude', {
              min: limits.latitudeMin ?? -90,
              max: limits.latitudeMax ?? 90,
              step: 'any',
            })}
            {limitedField('Longitude', 'Longitude', {
              min: limits.longitudeMin ?? -180,
              max: limits.longitudeMax ?? 180,
              step: 'any',
            })}
            {selectField('Day of week', 'Day_of_Week')}
            {selectField('Month', 'Month')}
            {selectField('Weather', 'Weather_Conditions')}
            {selectField('Light conditions', 'Light_Conditions')}
            {selectField('Road surface', 'Road_Surface_Conditions')}
            {selectField('Road type', 'Road_Type')}
            {selectField('Junction control', 'Junction_Control')}
            {selectField('Urban / rural', 'Urban_or_Rural_Area')}
            {selectField('Vehicle type', 'Vehicle_Type')}
          </div>

          <button className="btn-ml-run" onClick={runAnalysis} disabled={loading}>
            {loading ? <Loader2 size={14} className="spin" /> : <Brain size={14} />}
            {loading ? 'Analysing…' : 'Run severity analysis'}
          </button>
        </div>
      )}

      {loading && (
        <div className="ml-loading"><div className="spinner" />Running inference…</div>
      )}

      {error && (
        <div className="ml-error">
          <AlertTriangle size={14} /> {error}
          {Array.isArray(details) && details.length > 0 && (
            <ul className="ml-error-details">
              {details.slice(0, 6).map((d, i) => <li key={i}>{d}</li>)}
            </ul>
          )}
        </div>
      )}

      {result && (
        <div className="ml-result">
          <div className={`ml-result-head tone-${SEVERITY_TONE[result.prediction.severity] || 'low'}`}>
            <span className="ml-result-label">Predicted severity</span>
            <span className="ml-result-value">{result.prediction.severity}</span>
          </div>

          <div className="ml-probs">
            {(result.prediction.classOrder || ['Fatal', 'Serious', 'Slight']).map((cls) => {
              const pct = (result.prediction.probabilities[cls] || 0) * 100;
              return (
                <div className="ml-prob-row" key={cls}>
                  <span className="ml-prob-name">{cls}</span>
                  <div className="ml-prob-bar">
                    <div className={`ml-prob-fill tone-${SEVERITY_TONE[cls]}`} style={{ width: `${pct.toFixed(1)}%` }} />
                  </div>
                  <span className="ml-prob-val">{pct.toFixed(1)}%</span>
                </div>
              );
            })}
          </div>

          <div className="ml-meta">
            <span>Model: {result.model?.name || 'road-accident-severity-prediction'}</span>
            <span>Rev: {(result.model?.revision || '').slice(0, 10)}</span>
            <span>{result.timestamp}</span>
            {result.latencyMs != null && <span>{result.latencyMs} ms</span>}
          </div>

          <div className="ml-disclaimer">
            Statistical estimate only — not a confirmed outcome, medical assessment or
            dispatch instruction. {result.persisted === false && 'Not persisted (Firestore offline).'}
          </div>
        </div>
      )}

      {!result && stored && stored.severity && (
        <div className="ml-result">
          <div className={`ml-result-head tone-${SEVERITY_TONE[stored.severity] || 'low'}`}>
            <span className="ml-result-label">Saved estimate</span>
            <span className="ml-result-value">{stored.severity}</span>
          </div>
          <div className="ml-meta">
            {stored.predictedAt && <span>{stored.predictedAt}</span>}
            {stored.modelVersion && <span>Rev: {String(stored.modelVersion).slice(0, 10)}</span>}
            <span>advisory · from incident record</span>
          </div>
          <div className="ml-disclaimer">
            Stored advisory estimate from a previous run — not a confirmed outcome or
            medical assessment.
          </div>
        </div>
      )}
    </div>
  );
};

export default SeverityPredictionPanel;
