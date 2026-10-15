import React, { useState, useEffect, useCallback } from 'react';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import StatsGrid from './components/StatsGrid';

// Import Screens
import LiveAlertsScreen from './components/screens/LiveAlertsScreen';
import AlertHistoryScreen from './components/screens/AlertHistoryScreen';
import FullMapViewScreen from './components/screens/FullMapViewScreen';
import NearbyUnitsScreen from './components/screens/NearbyUnitsScreen';
import StatisticsScreen from './components/screens/StatisticsScreen';
import SettingsScreen from './components/screens/SettingsScreen';

import { api } from './services/api';
import { socketService } from './services/socket';

const App = () => {
  const [incidents, setIncidents] = useState([]);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [backendStatus, setBackendStatus] = useState('checking');
  const [activeTab, setActiveTab] = useState('live-alerts');
  const [toasts, setToasts] = useState([]);

  const fetchData = useCallback(async () => {
    try {
      const data = await api.getIncidents();
      setIncidents(data);
      setError(null);
      setBackendStatus('connected');
    } catch (e) {
      setError('Failed to connect to backend.');
      setBackendStatus('disconnected');
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Browser synthesized tone generator for alarm warning double-beep
  const playWarningBeep = () => {
    try {
      const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      
      // Beep 1
      const osc1 = audioCtx.createOscillator();
      const gain1 = audioCtx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(880, audioCtx.currentTime); // Pitch: A5
      gain1.gain.setValueAtTime(0.12, audioCtx.currentTime);
      gain1.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.15);
      osc1.connect(gain1);
      gain1.connect(audioCtx.destination);
      osc1.start();
      osc1.stop(audioCtx.currentTime + 0.15);

      // Beep 2 (delayed slightly)
      setTimeout(() => {
        const osc2 = audioCtx.createOscillator();
        const gain2 = audioCtx.createGain();
        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(987.77, audioCtx.currentTime); // Pitch: B5
        gain2.gain.setValueAtTime(0.12, audioCtx.currentTime);
        gain2.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.2);
        osc2.connect(gain2);
        gain2.connect(audioCtx.destination);
        osc2.start();
        osc2.stop(audioCtx.currentTime + 0.2);
      }, 120);
    } catch (e) {
      console.warn('Web Audio warning beep failed to trigger:', e);
    }
  };

  const showToast = useCallback((incident) => {
    playWarningBeep();
    const id = Date.now() + Math.random().toString(36).substring(2, 9);
    const timeStr = incident.timestamp
      ? new Date(incident.timestamp).toLocaleTimeString('en-IN', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        })
      : 'Just now';

    const newToast = {
      id,
      title: `🚨 ${incident.severity} Incident Detected`,
      message: incident.city || `Coords: ${incident.latitude?.toFixed(4)}, ${incident.longitude?.toFixed(4)}`,
      time: timeStr,
      incident,
    };

    setToasts((prev) => [newToast, ...prev]);

    // Dismiss toast automatically after 7 seconds
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 7000);
  }, []);

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Real-time subscriptions
  useEffect(() => {
    socketService.connect(
      () => {
        setBackendStatus('connected');
        setError(null);
      },
      () => setBackendStatus('disconnected')
    );

    socketService.subscribeToIncidentCreated((newInc) => {
      setIncidents((prev) => {
        if (prev.some((i) => i.id === newInc.id)) return prev;
        // Trigger visual toast + warning tone beep
        showToast(newInc);
        return [newInc, ...prev];
      });
    });

    socketService.subscribeToIncidentUpdated((updated) => {
      setIncidents((prev) => prev.map((i) => (i.id === updated.id ? { ...i, ...updated } : i)));
      setSelectedIncident((prev) => (prev && prev.id === updated.id ? { ...prev, ...updated } : prev));
    });

    socketService.subscribeToIncidentDeleted(({ id }) => {
      setIncidents((prev) => prev.filter((i) => i.id !== id));
      setSelectedIncident((prev) => (prev && prev.id === id ? null : prev));
    });

    socketService.subscribeToHelperAccepted(({ incidentId, slotsFilled }) => {
      setIncidents((prev) =>
        prev.map((i) => (i.id === incidentId ? { ...i, helperSlots: slotsFilled } : i))
      );
    });

    // Optional ML advisory: merge predicted severity onto the incident (never touches status/dispatch)
    socketService.subscribeToSeverityPrediction((payload) => {
      if (!payload || !payload.incidentId) return;
      setIncidents((prev) =>
        prev.map((i) => (i.id === payload.incidentId ? { ...i, severityPrediction: payload } : i))
      );
      setSelectedIncident((prev) =>
        prev && prev.id === payload.incidentId ? { ...prev, severityPrediction: payload } : prev
      );
    });

    return () => socketService.disconnect();
  }, [showToast]);

  // Auto-select the first active incident if none is currently selected (only for alerts & map screens)
  useEffect(() => {
    if (activeTab === 'live-alerts' || activeTab === 'map') {
      const active = incidents.filter((i) => i.status !== 'RESOLVED');
      if (!selectedIncident && active.length > 0) {
        setSelectedIncident(active[0]);
      }
    }
  }, [incidents, selectedIncident, activeTab]);

  const handleDispatch = (type, incidentId) => {
    socketService.emitDispatchResource(incidentId, type);
  };

  const handleUpdateStatus = (incidentId, status) => {
    socketService.emitUpdateStatus(incidentId, status);
    if (status === 'RESOLVED') {
      setSelectedIncident(null);
    }
  };

  const activeCount = incidents.filter((i) => i.status !== 'RESOLVED').length;

  // Dynamic header titles
  const getHeaderContent = () => {
    switch (activeTab) {
      case 'history':
        return {
          title: 'Incident History Logs',
          subtitle: 'Ledger records of all resolved emergencies',
        };
      case 'map':
        return {
          title: 'Operations Tactical Map',
          subtitle: 'Real-time geohash proximity matching visualizer',
        };
      case 'units':
        return {
          title: 'Fleet & Responders Management',
          subtitle: 'Active status and range coordinates of response teams',
        };
      case 'stats':
        return {
          title: 'Analytics & SLA Auditor',
          subtitle: 'Golden-hour response time indices and dispatcher stats',
        };
      case 'settings':
        return {
          title: 'System Rules & Settings',
          subtitle: 'Configure SLA targets, dispatcher countdowns, and gateway keys',
        };
      case 'live-alerts':
      default:
        return {
          title: 'Live Accident Alerts',
          subtitle: 'Real-time accident reports from RoadSOS users',
        };
    }
  };

  const headerMeta = getHeaderContent();

  // Dynamic screen rendering
  const renderActiveScreen = () => {
    switch (activeTab) {
      case 'history':
        return <AlertHistoryScreen incidents={incidents} />;
      case 'map':
        return (
          <FullMapViewScreen
            incidents={incidents}
            selectedIncident={selectedIncident}
            onSelectIncident={setSelectedIncident}
            isLoading={isLoading}
            error={error}
          />
        );
      case 'units':
        return <NearbyUnitsScreen incidents={incidents} />;
      case 'stats':
        return <StatisticsScreen />;
      case 'settings':
        return <SettingsScreen />;
      case 'live-alerts':
      default:
        return (
          <LiveAlertsScreen
            incidents={incidents}
            selectedIncident={selectedIncident}
            onSelectIncident={setSelectedIncident}
            isLoading={isLoading}
            error={error}
            onDispatch={handleDispatch}
            onUpdateStatus={handleUpdateStatus}
          />
        );
    }
  };

  return (
    <div className="app-container">
      {/* Fixed Left Sidebar */}
      <Sidebar 
        activeTab={activeTab} 
        onTabChange={(tab) => {
          setActiveTab(tab);
          setSelectedIncident(null);
        }} 
      />

      {/* Main Content Area */}
      <main className="main-content">
        {/* Dynamic Header Controls */}
        <Header 
          notificationCount={activeCount} 
          inspectorName="Inspector Arjun" 
          division="Chennai City Police" 
          customTitle={headerMeta.title}
          customSubtitle={headerMeta.subtitle}
        />

        {/* KPI stats section */}
        <StatsGrid activeIncidentsCount={activeCount} />

        {/* Dynamic Screen View */}
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {renderActiveScreen()}
        </div>

        {/* Footer */}
        <footer className="footer" style={{ marginTop: '20px' }}>
          <span>&copy; 2026 RoadSOS - Intelligent Accident Response System</span>
          <span>v1.0.0</span>
        </footer>
      </main>

      {/* Toast Notification Deck Overlay */}
      <div className="toast-container">
        {toasts.map((toast) => (
          <div key={toast.id} className="toast-card">
            <div className="toast-content">
              <div className="toast-title">{toast.title}</div>
              <div className="toast-message">{toast.message}</div>
              <span className="toast-time">{toast.time}</span>
              <div className="toast-actions">
                <button
                  className="btn-toast-inspect"
                  onClick={() => {
                    setSelectedIncident(toast.incident);
                    setActiveTab('live-alerts'); // Switch to main live alerts view
                    setToasts((prev) => prev.filter((t) => t.id !== toast.id)); // Clear toast
                  }}
                >
                  Inspect Incident
                </button>
              </div>
            </div>
            <button
              className="toast-close"
              onClick={() => setToasts((prev) => prev.filter((t) => t.id !== toast.id))}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default App;
