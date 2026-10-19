import React, { useState } from 'react';
import { Shield, Navigation, BellRing, CheckCircle, Trash2 } from 'lucide-react';
import { api } from '../services/api';
import SeverityPredictionPanel from './SeverityPredictionPanel';

const SeverityConfig = {
  CRITICAL: { badgeClass: 'critical', label: 'High Priority' },
  HIGH:     { badgeClass: 'high',     label: 'High Priority' },
  MEDIUM:   { badgeClass: 'medium',   label: 'Medium Priority' },
  LOW:      { badgeClass: 'low',      label: 'Low Priority' },
};

// Helper to determine nearest station based on city name or coordinates
const getNearestStation = (locationName = '') => {
  const loc = locationName.toLowerCase();
  if (loc.includes('koyambedu')) {
    return { name: 'Koyambedu Police Station', distance: '1.2 km away', phone: '044 2345 6789' };
  } else if (loc.includes('tambaram') || loc.includes('gst')) {
    return { name: 'Tambaram Police Station', distance: '0.8 km away', phone: '044 2239 8765' };
  } else if (loc.includes('sholinganallur') || loc.includes('omr')) {
    return { name: 'Sholinganallur Police Station', distance: '1.5 km away', phone: '044 2450 1234' };
  } else if (loc.includes('teynampet') || loc.includes('anna salai')) {
    return { name: 'Teynampet Police Station', distance: '1.1 km away', phone: '044 2434 5678' };
  } else if (loc.includes('poonamallee')) {
    return { name: 'Poonamallee Police Station', distance: '1.4 km away', phone: '044 2627 2345' };
  }
  return { name: 'Chennai Central Police Station', distance: '1.8 km away', phone: '044 2345 5678' };
};

const SimulatorView = () => {
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
      setStatus({ 
        ok: res.success, 
        msg: res.success ? `Cleared ${res.deleted} demo incidents` : res.error 
      });
    } catch {
      setStatus({ ok: false, msg: 'Clear failed.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ animation: 'fadeIn 0.25s ease' }}>
      <div className="simulator-panel-header">
        <h2 className="simulator-panel-title">🎮 Demo Simulator</h2>
        <p className="simulator-panel-desc">
          Select an option below to simulate a real-time accident. This triggers the on-device sensor fusion logic, broadcasts geohashed notifications, and dispatches responders.
        </p>
      </div>

      <div className="simulator-grid">
        <button className="simulator-card" onClick={() => simulate('minor')} disabled={loading}>
          <span className="simulator-card-icon">🟢</span>
          <span className="simulator-card-label">Minor Accident</span>
          <span className="simulator-card-desc">Low G-force bump, minor injuries.</span>
        </button>
        <button className="simulator-card" onClick={() => simulate('major')} disabled={loading}>
          <span className="simulator-card-icon">🟠</span>
          <span className="simulator-card-label">Major Accident</span>
          <span className="simulator-card-desc">Medium G-force crash, serious injuries.</span>
        </button>
        <button className="simulator-card" onClick={() => simulate('critical')} disabled={loading}>
          <span className="simulator-card-icon">🚨</span>
          <span className="simulator-card-label">Critical Emergency</span>
          <span className="simulator-card-desc">High impact crash, unconscious victim.</span>
        </button>
      </div>

      <button className="btn-simulator-clear" onClick={clearAll} disabled={loading}>
        <Trash2 size={14} style={{ marginRight: '6px', display: 'inline-block', verticalAlign: 'middle' }} />
        Clear Demo Incidents
      </button>

      {loading && (
        <div className="simulator-loading">
          <div className="spinner" />
          Processing simulator request...
        </div>
      )}

      {status && (
        <div className={`simulator-status ${status.ok ? 'success' : 'error'}`}>
          {status.ok ? '✅ ' : '❌ '}
          {status.msg}
        </div>
      )}
    </div>
  );
};

const IncidentDetail = ({ selectedIncident, onDispatch, onUpdateStatus }) => {
  const [dispatching, setDispatching] = useState(false);
  const [showConfirmResolve, setShowConfirmResolve] = useState(false);

  if (!selectedIncident) {
    return <SimulatorView />;
  }

  const {
    id,
    status,
    latitude,
    longitude,
    timestamp,
    severity,
    city,
    source,
  } = selectedIncident;

  const isResolved = status === 'RESOLVED';
  const config = SeverityConfig[severity] || SeverityConfig.LOW;
  const station = getNearestStation(city);

  // Format reported time
  const reportedTimeStr = timestamp
    ? new Date(timestamp).toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      })
    : '—';

  const handleDispatchAction = async () => {
    setDispatching(true);
    // Emit dispatch for both ambulance and police to simulate full dispatching
    onDispatch('police', id);
    onDispatch('ambulance', id);
    setTimeout(() => setDispatching(false), 800);
  };

  return (
    <div className="detail-grid" style={{ animation: 'fadeIn 0.2s ease' }}>
      {/* Left Details Table */}
      <div className="detail-info-pane">
        <div className="detail-badge-title">
          <span className={`detail-priority-badge ${config.badgeClass}`}>
            {config.label}
          </span>
        </div>
        <h2 className="detail-title">Accident Reported</h2>
        <p className="detail-address">{city || 'Accident Location'}</p>

        <div className="detail-table">
          <div className="detail-row">
            <span className="detail-label">⏱ Reported Time</span>
            <span className="detail-value">{reportedTimeStr}</span>
          </div>
          <div className="detail-row">
            <span className="detail-label">👤 Reported by</span>
            <span className="detail-value">
              {source === 'demo' ? 'Demo Simulator' : 'RoadSOS App'}
            </span>
          </div>
          <div className="detail-row">
            <span className="detail-label">📍 Coordinates</span>
            <span className="detail-value coordinates">
              {latitude?.toFixed(5)}° N, {longitude?.toFixed(5)}° E
            </span>
          </div>
          {selectedIncident.dispatchedResources?.length > 0 && (
            <div className="detail-row">
              <span className="detail-label">🚓 Dispatches</span>
              <span className="detail-value" style={{ color: 'var(--color-blue)', fontSize: '12px' }}>
                {selectedIncident.dispatchedResources.map(r => r.type).join(', ')}
              </span>
            </div>
          )}
        </div>

        {/* Optional ML severity prediction — advisory only, never blocks dispatch */}
        <SeverityPredictionPanel
          incidentId={id}
          storedPrediction={selectedIncident.severityPrediction}
        />

        {/* Action Buttons */}
        <div className="detail-actions-row">
          {!isResolved && (
            <>
              {showConfirmResolve ? (
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button 
                    className="btn-detail-action secondary" 
                    onClick={() => setShowConfirmResolve(false)}
                    style={{ padding: '8px 12px', fontSize: '12px' }}
                  >
                    Cancel
                  </button>
                  <button 
                    className="btn-detail-action primary" 
                    onClick={() => {
                      onUpdateStatus(id, 'RESOLVED');
                      setShowConfirmResolve(false);
                    }}
                    style={{ backgroundColor: 'var(--color-green)', borderColor: 'var(--color-green)', padding: '8px 12px', fontSize: '12px' }}
                  >
                    Confirm Resolve
                  </button>
                </div>
              ) : (
                <button 
                  className="btn-detail-action secondary" 
                  onClick={() => setShowConfirmResolve(true)}
                >
                  <CheckCircle size={15} />
                  Mark Resolved
                </button>
              )}

              <button 
                className="btn-detail-action primary" 
                onClick={handleDispatchAction}
                disabled={dispatching}
              >
                <BellRing size={15} />
                {dispatching ? 'Dispatching...' : 'Dispatch Unit'}
              </button>
            </>
          )}

          {isResolved && (
            <div className="resolved-alert-badge">
              <CheckCircle size={16} />
              Incident Resolved
            </div>
          )}
        </div>
      </div>

      {/* Right Nearest Police Station Card */}
      <div className="nearest-station-card">
        <div className="station-header">
          <Shield size={14} style={{ color: 'var(--text-secondary)' }} />
          Nearest Police Station
        </div>
        <div className="station-name">{station.name}</div>
        <div className="station-distance">{station.distance}</div>
        <div className="station-phone">
          {/* Phone Icon */}
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ color: 'var(--text-secondary)' }}>
            <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>
          </svg>
          {station.phone}
        </div>
        
        <button className="btn-navigate">
          <Navigation size={13} />
          Navigate
        </button>
      </div>
    </div>
  );
};

export default IncidentDetail;
