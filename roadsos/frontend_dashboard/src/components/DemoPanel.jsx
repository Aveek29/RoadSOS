import React, { useState } from 'react';
import { api } from '../services/api';

const DEMO_SCENARIOS = [
  {
    key: 'minor',
    label: 'Minor Accident',
    desc: 'Low speed collision, minor injuries',
    icon: '🟢',
    cls: 'btn-demo-minor',
  },
  {
    key: 'major',
    label: 'Major Accident',
    desc: 'High speed crash, serious injuries',
    icon: '🟠',
    cls: 'btn-demo-major',
  },
  {
    key: 'critical',
    label: 'Critical Emergency',
    desc: 'Severe crash, victim unresponsive',
    icon: '🚨',
    cls: 'btn-demo-critical',
  },
];

const DemoPanel = () => {
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState(null);

  const simulate = async (key) => {
    setLoading(true);
    setStatus(null);
    try {
      const res = await api.simulateIncident(key);
      setStatus({
        ok: res.success,
        msg: res.success
          ? `${res.severity} incident created in ${res.city}`
          : res.error,
        id: res.incidentId,
      });
    } catch {
      setStatus({ ok: false, msg: 'Failed to reach backend.' });
    } finally {
      setLoading(false);
    }
  };

  const clearAll = async () => {
    setLoading(true);
    setStatus(null);
    try {
      const res = await api.clearDemoIncidents();
      setStatus({ ok: res.success, msg: res.success ? `Cleared ${res.deleted} demo incidents` : res.error });
    } catch {
      setStatus({ ok: false, msg: 'Clear failed.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="demo-panel">
      <div className="demo-panel-header">
        <h2 className="demo-title">🎮 Demo Simulator</h2>
        <p className="demo-subtitle">
          Inject realistic incidents into the live system — triggers the full
          detection → alert → dispatch pipeline.
        </p>
      </div>

      <div className="demo-buttons">
        {DEMO_SCENARIOS.map(s => (
          <button
            key={s.key}
            className={`btn-demo ${s.cls}`}
            onClick={() => simulate(s.key)}
            disabled={loading}
            id={`btn-demo-${s.key}`}
          >
            <span className="btn-demo-icon">{s.icon}</span>
            <span className="btn-demo-text">
              <span className="btn-demo-label">{s.label}</span>
              <span className="btn-demo-desc">{s.desc}</span>
            </span>
          </button>
        ))}
      </div>

      <div className="demo-divider">utilities</div>

      <button
        className="btn-demo-clear"
        onClick={clearAll}
        disabled={loading}
        id="btn-demo-clear"
      >
        🧹 Clear All Demo Incidents
      </button>

      {loading && (
        <div className="demo-loading">
          <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} />
          Processing...
        </div>
      )}

      {status && (
        <div className={`demo-status ${status.ok ? 'demo-status-ok' : 'demo-status-err'}`}>
          <span>{status.ok ? '✅' : '❌'} {status.msg}</span>
          {status.id && <code>ID: {status.id}</code>}
        </div>
      )}
    </div>
  );
};

export default DemoPanel;
