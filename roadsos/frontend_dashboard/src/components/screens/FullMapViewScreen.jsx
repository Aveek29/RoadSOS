import React from 'react';
import MapView from '../MapView';
import { Target, AlertCircle } from 'lucide-react';

const FullMapViewScreen = ({
  incidents = [],
  selectedIncident,
  onSelectIncident,
  isLoading,
  error,
}) => {
  const activeIncidents = incidents.filter((i) => i.status !== 'RESOLVED');

  return (
    <div className="full-map-container" style={{ animation: 'fadeIn 0.25s ease' }}>
      {isLoading && (
        <div className="loading-overlay">
          <div className="spinner" />
          <p>Initializing spatial telemetry feeds...</p>
        </div>
      )}
      {!isLoading && error && (
        <div className="loading-overlay">
          <p>⚠ {error}</p>
        </div>
      )}
      {!isLoading && !error && (
        <>
          <MapView
            incidents={incidents}
            selectedIncident={selectedIncident}
            onSelectIncident={onSelectIncident}
          />

          {/* Floating HUD Radar Overlay Panel */}
          <div className="map-hud-overlay">
            <h4 className="map-hud-title">
              <Target size={14} style={{ marginRight: '6px', color: 'var(--color-red)', verticalAlign: 'middle' }} />
              Active Incident Feed
            </h4>
            
            <div className="map-hud-list">
              {activeIncidents.length === 0 ? (
                <div style={{ padding: '20px 10px', textAlign: 'center', color: 'var(--text-secondary)', fontSize: '11px' }}>
                  <AlertCircle size={20} style={{ color: 'var(--text-muted)', margin: '0 auto 6px auto' }} />
                  Radar Clear — No active warnings
                </div>
              ) : (
                activeIncidents.map((inc) => {
                  const isSelected = selectedIncident?.id === inc.id;
                  const color = 
                    inc.severity === 'CRITICAL' ? '#8B5CF6' :
                    inc.severity === 'HIGH' ? '#EF4444' :
                    inc.severity === 'MEDIUM' ? '#F59E0B' :
                    '#10B981';

                  return (
                    <div
                      key={inc.id}
                      className="map-hud-item"
                      onClick={() => onSelectIncident(inc)}
                      style={{
                        borderLeft: `3px solid ${color}`,
                        backgroundColor: isSelected ? 'var(--color-red-light)' : 'var(--bg-page)',
                        borderColor: isSelected ? 'var(--color-red)' : color
                      }}
                    >
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: '700', fontSize: '11px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {inc.city || 'Accident Reported'}
                        </div>
                        <div style={{ fontSize: '9px', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
                          {inc.latitude?.toFixed(4)}, {inc.longitude?.toFixed(4)}
                        </div>
                      </div>
                      <span style={{ fontSize: '9px', fontWeight: 'bold', color: color, textTransform: 'uppercase' }}>
                        {inc.severity}
                      </span>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default FullMapViewScreen;
