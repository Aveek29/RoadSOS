import React from 'react';
import { ChevronRight } from 'lucide-react';

const SeverityConfig = {
  CRITICAL: { dotClass: 'purple', badgeClass: 'critical', label: 'High Priority' },
  HIGH:     { dotClass: 'red',    badgeClass: 'high',     label: 'High Priority' },
  MEDIUM:   { dotClass: 'amber',  badgeClass: 'medium',   label: 'Medium Priority' },
  LOW:      { dotClass: 'green',  badgeClass: 'low',      label: 'Low Priority' },
};

const AlertCard = ({ incident, isSelected, onClick }) => {
  const sev = incident.severity || 'LOW';
  const config = SeverityConfig[sev] || SeverityConfig.LOW;
  
  // Format timestamp (e.g. 10:24 AM)
  const timeStr = incident.timestamp
    ? new Date(incident.timestamp).toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      })
    : '—';

  return (
    <div
      className={`alert-card sev-${sev} ${isSelected ? 'selected' : ''}`}
      onClick={() => onClick && onClick(incident)}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          onClick && onClick(incident);
        }
      }}
    >
      <div className="alert-card-header">
        <div className="alert-card-status-title">
          <span className={`alert-card-dot ${config.dotClass}`} />
          Accident Reported
        </div>
        <span className="alert-card-time">{timeStr}</span>
      </div>
      
      <div className="alert-card-body">
        {incident.city || `Location (${incident.latitude?.toFixed(4)}, ${incident.longitude?.toFixed(4)})`}
        {incident.plusCode && <span style={{ display: 'block', color: 'var(--text-muted)', fontSize: '10px', marginTop: '2px' }}>{incident.plusCode}</span>}
      </div>

      <div className="alert-card-badge-row">
        <span className={`alert-card-priority-badge ${config.badgeClass}`}>
          {config.label}
        </span>
      </div>
    </div>
  );
};

const AlertsList = ({ incidents = [], selectedIncident, onSelectIncident }) => {
  const activeIncidents = incidents.filter((i) => i.status !== 'RESOLVED');

  return (
    <div className="alerts-panel">
      <h3 className="alerts-panel-title">Active Alerts</h3>
      
      <div className="alerts-list">
        {activeIncidents.length === 0 ? (
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            flex: 1,
            color: 'var(--text-secondary)',
            fontSize: '13px',
            textAlign: 'center',
            padding: '20px'
          }}>
            <span style={{ fontSize: '28px', marginBottom: '8px' }}>✅</span>
            <strong>All Clear</strong>
            <span style={{ color: 'var(--text-muted)', fontSize: '11px', marginTop: '4px' }}>
              No active accidents reported.
            </span>
          </div>
        ) : (
          activeIncidents.map((inc) => (
            <AlertCard
              key={inc.id}
              incident={inc}
              isSelected={selectedIncident?.id === inc.id}
              onClick={onSelectIncident}
            />
          ))
        )}
      </div>

      <button className="view-all-alerts-btn">
        View All Alerts
        <ChevronRight size={16} />
      </button>
    </div>
  );
};

export default AlertsList;
