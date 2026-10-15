import React from 'react';
import AlertsList from '../AlertsList';
import MapView from '../MapView';
import IncidentDetail from '../IncidentDetail';

const LiveAlertsScreen = ({
  incidents,
  selectedIncident,
  onSelectIncident,
  isLoading,
  error,
  onDispatch,
  onUpdateStatus,
}) => {
  return (
    <div className="content-grid" style={{ animation: 'fadeIn 0.2s ease' }}>
      {/* Active Alerts List */}
      <AlertsList 
        incidents={incidents} 
        selectedIncident={selectedIncident} 
        onSelectIncident={onSelectIncident} 
      />

      {/* Map & Detail pane */}
      <div className="right-column">
        <div className="map-panel">
          {isLoading && (
            <div className="loading-overlay">
              <div className="spinner" />
              <p>Loading interactive mapping network...</p>
            </div>
          )}
          {!isLoading && error && (
            <div className="loading-overlay">
              <p>⚠ {error}</p>
            </div>
          )}
          {!isLoading && !error && (
            <MapView 
              incidents={incidents} 
              selectedIncident={selectedIncident} 
              onSelectIncident={onSelectIncident} 
            />
          )}
        </div>

        <div className="detail-panel">
          <IncidentDetail 
            selectedIncident={selectedIncident} 
            onDispatch={onDispatch} 
            onUpdateStatus={onUpdateStatus} 
          />
        </div>
      </div>
    </div>
  );
};

export default LiveAlertsScreen;
