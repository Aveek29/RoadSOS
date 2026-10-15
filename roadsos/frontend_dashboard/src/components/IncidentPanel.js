import React, { useState } from 'react';
import SeverityBadge from './SeverityBadge';
import DemoPanel from './DemoPanel';

const ConfidenceBar = ({ value }) => {
  const pct = Math.round((value || 0) * 100);
  const color =
    value >= 0.8 ? 'var(--col-red)' :
    value >= 0.6 ? 'var(--col-amber)' :
    'var(--col-teal)';
  return (
    <div className="confidence-row">
      <div className="confidence-bar-track">
        <div
          className="confidence-bar-fill"
          style={{ width: `${pct}%`, background: color }}
        />
      </div>
      <span className="confidence-value" style={{ color }}>{pct}%</span>
    </div>
  );
};

const IncidentPanel = ({ selectedIncident, onDispatch, onUpdateStatus }) => {
  const [showConfirm, setShowConfirm] = useState(false);

  if (!selectedIncident) return <DemoPanel />;

  const {
    id, status, latitude, longitude, timestamp,
    severity, severityScore, plusCode, city,
    confidence, trackingActive, isDemo,
    acceptedHelpers = [], helperSlots = 0,
    dispatchedResources = [],
  } = selectedIncident;

  const isResolved = status === 'RESOLVED';

  return (
    <div className="panel-active" style={{ animation: 'slide-in-right 0.25s ease' }}>

      {/* ── Hero Section ── */}
      <div className="panel-hero">
        <div className="panel-header-row">
          <span className="panel-title">Incident Detail</span>
          <div className="panel-badges">
            {severity && <SeverityBadge severity={severity} score={severityScore} />}
            {isDemo && <span className="badge-demo">DEMO</span>}
          </div>
        </div>

        <div className="panel-meta">
          <div className="panel-meta-row">
            <span className="panel-meta-label">Status</span>
            <span className={`status-badge status-${status?.toLowerCase()}`}>
              {status}
            </span>
            {trackingActive && !isResolved && (
              <span className="live-tracking-pill">📡 Live</span>
            )}
          </div>

          <div className="panel-meta-row">
            <span className="panel-meta-label">ID</span>
            <span className="panel-meta-value">{id}</span>
          </div>

          <div className="panel-meta-row">
            <span className="panel-meta-label">Location</span>
            <span className="panel-meta-value">
              {latitude?.toFixed(5)}, {longitude?.toFixed(5)}
              {city && <span style={{ color: 'var(--text-secondary)' }}> · {city}</span>}
            </span>
          </div>

          {plusCode && (
            <div className="panel-meta-row">
              <span className="panel-meta-label">Plus Code</span>
              <code className="plus-code">{plusCode}</code>
            </div>
          )}

          <div className="panel-meta-row">
            <span className="panel-meta-label">Time</span>
            <span className="panel-meta-value">{timestamp || '—'}</span>
          </div>
        </div>
      </div>

      {/* ── Confidence ── */}
      {confidence != null && (
        <div className="panel-section-block">
          <div className="panel-section-heading">🎯 Detection Confidence</div>
          <ConfidenceBar value={confidence} />
        </div>
      )}

      {/* ── Helpers ── */}
      <div className="panel-section-block">
        <div className="panel-section-heading">👥 Volunteer Responders</div>
        <div className="helper-slots-row">
          <span className="helper-slots-label">Slots filled</span>
          <span className="helper-slots-count">{helperSlots} / 3</span>
          <div className="helper-slot-bar">
            {[0, 1, 2].map(i => (
              <div
                key={i}
                className={`slot-pip ${i < helperSlots ? 'slot-filled' : 'slot-empty'}`}
              />
            ))}
          </div>
        </div>
        {acceptedHelpers.length > 0 && (
          <div className="accepted-helpers-list">
            {acceptedHelpers.map((h, i) => (
              <div key={i} className="helper-entry">
                <span className="helper-uid">🏃 {h.uid}</span>
                {h.distanceMeters != null && (
                  <span className="helper-distance">
                    {h.distanceMeters.toFixed(0)}m
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ── Dispatch Timeline ── */}
      <div className="panel-section-block">
        <div className="panel-section-heading">
          🚨 Dispatch Log
          <span style={{ marginLeft: 'auto', color: 'var(--text-secondary)', fontWeight: 500 }}>
            {dispatchedResources.length} units
          </span>
        </div>
        {dispatchedResources.length > 0 ? (
          <div className="dispatch-timeline">
            {dispatchedResources.map((r, i) => (
              <div key={i} className="timeline-entry">
                <span className="timeline-icon">
                  {r.type === 'ambulance' ? '🚑' : r.type === 'police' ? '🚓' : '👥'}
                </span>
                <span className="timeline-text">
                  {r.type?.charAt(0).toUpperCase() + r.type?.slice(1)}
                </span>
                <span className="timeline-time">
                  {r.dispatchedAt ? new Date(r.dispatchedAt).toLocaleTimeString() : '—'}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <p style={{ fontSize: 12, color: 'var(--text-muted)', fontStyle: 'italic' }}>
            No units dispatched yet
          </p>
        )}
      </div>

      {/* ── Dispatch Actions ── */}
      <div className="action-buttons">
        <button
          id="btn-dispatch-ambulance"
          className="btn-dispatch btn-ambulance"
          onClick={() => onDispatch('ambulance', id)}
          disabled={isResolved}
        >
          🚑 Dispatch Ambulance
        </button>
        <button
          id="btn-dispatch-police"
          className="btn-dispatch btn-police"
          onClick={() => onDispatch('police', id)}
          disabled={isResolved}
        >
          🚓 Dispatch Police
        </button>
        <button
          id="btn-dispatch-helper"
          className="btn-dispatch btn-helper"
          onClick={() => onDispatch('helper', id)}
          disabled={isResolved}
        >
          👥 Notify Volunteers
        </button>

        <hr />

        {!isResolved && !showConfirm && (
          <button
            id="btn-resolve"
            className="btn-resolve"
            onClick={() => setShowConfirm(true)}
          >
            ✅ Mark as Resolved
          </button>
        )}

        {showConfirm && (
          <div className="confirm-dialog">
            <p>⚠ Confirm — mark this incident resolved?</p>
            <div className="confirm-dialog-actions">
              <button
                className="btn-resolve"
                style={{ flex: 1 }}
                onClick={() => {
                  onUpdateStatus(id, 'RESOLVED');
                  setShowConfirm(false);
                }}
              >
                ✅ Confirm
              </button>
              <button
                className="btn-cancel"
                style={{ flex: 1 }}
                onClick={() => setShowConfirm(false)}
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {isResolved && (
          <div className="resolved-badge">
            ✅ Incident Resolved
          </div>
        )}
      </div>
    </div>
  );
};

export default IncidentPanel;
