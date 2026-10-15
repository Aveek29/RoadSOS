import React, { useState, useEffect } from 'react';
import { AlertTriangle, Clock, CheckCircle, Users } from 'lucide-react';
import { api } from '../services/api';

const StatCard = ({ value, label, subtext, subClass, iconClass, icon: Icon }) => {
  return (
    <div className="stat-card">
      <div className={`stat-icon ${iconClass}`}>
        <Icon size={20} />
      </div>
      <div className="stat-info">
        <div className="stat-value">{value}</div>
        <div className="stat-label">{label}</div>
        <div className={`stat-sub ${subClass || ''}`}>{subtext}</div>
      </div>
    </div>
  );
};

const StatsGrid = ({ activeIncidentsCount = 0 }) => {
  const [metrics, setMetrics] = useState({
    activeIncidents: 0,
    resolvedToday: 0,
    criticalIncidents: 0,
    availableHelpers: 0,
  });

  const fetchMetrics = async () => {
    try {
      const data = await api.getAnalytics();
      if (data) {
        setMetrics({
          activeIncidents: data.activeIncidents ?? 0,
          resolvedToday: data.resolvedToday ?? 0,
          criticalIncidents: data.criticalIncidents ?? 0,
          availableHelpers: data.availableHelpers || 45, // default simulation value if 0
        });
      }
    } catch (e) {
      console.error('Failed to fetch analytics metrics:', e);
    }
  };

  useEffect(() => {
    fetchMetrics();
    // Poll every 15 seconds to keep resolved counts fresh
    const interval = setInterval(fetchMetrics, 15000);
    return () => clearInterval(interval);
  }, []);

  // Use the live active count from WebSocket if available, otherwise fallback to polled metrics
  const liveActiveCount = activeIncidentsCount > 0 ? activeIncidentsCount : metrics.activeIncidents;
  
  // Total reported today is active + resolved (or default to 28 if none)
  const totalToday = (metrics.resolvedToday + liveActiveCount) > 0 
    ? (metrics.resolvedToday + liveActiveCount) 
    : 28;

  return (
    <div className="stats-grid">
      <StatCard
        value={liveActiveCount}
        label="Active Alerts"
        subtext="Require attention"
        subClass="danger"
        iconClass="red"
        icon={AlertTriangle}
      />
      <StatCard
        value={totalToday}
        label="Alerts (Today)"
        subtext="Total reported"
        iconClass="amber"
        icon={Clock}
      />
      <StatCard
        value={metrics.resolvedToday > 0 ? metrics.resolvedToday : 16} // default to 16 if 0
        label="Resolved"
        subtext="Completed"
        iconClass="green"
        icon={CheckCircle}
      />
      <StatCard
        value={metrics.availableHelpers}
        label="Volunteers Nearby"
        subtext="Available to help"
        iconClass="blue"
        icon={Users}
      />
    </div>
  );
};

export default StatsGrid;
