import React, { useState, useEffect } from 'react';
import { api } from '../services/api';

const MetricCard = ({ label, value, icon, colorClass }) => (
  <div className={`metric-card ${colorClass}`}>
    <div className="metric-icon">{icon}</div>
    <div className="metric-value">{value ?? '—'}</div>
    <div className="metric-label">{label}</div>
  </div>
);

const AnalyticsBar = () => {
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchMetrics = async () => {
    try {
      const data = await api.getAnalytics();
      setMetrics(data);
    } catch {
      // non-critical, fail silently
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
    const id = setInterval(fetchMetrics, 30000);
    return () => clearInterval(id);
  }, []);

  if (loading) {
    return (
      <div className="analytics-bar analytics-loading">
        <div className="spinner" style={{ width: 14, height: 14, borderWidth: 2 }} />
        Loading metrics...
      </div>
    );
  }

  return (
    <div className="analytics-bar">
      <MetricCard
        label="Active Incidents"
        value={metrics?.activeIncidents}
        icon="🔴"
        colorClass="metric-danger"
      />
      <MetricCard
        label="Critical"
        value={metrics?.criticalIncidents}
        icon="🚨"
        colorClass="metric-critical"
      />
      <MetricCard
        label="Resolved Today"
        value={metrics?.resolvedToday}
        icon="✅"
        colorClass="metric-success"
      />
      <MetricCard
        label="Avg Response"
        value={
          metrics?.avgResponseTimeMins
            ? `${metrics.avgResponseTimeMins}m`
            : '—'
        }
        icon="⏱"
        colorClass="metric-info"
      />
      <MetricCard
        label="Helpers"
        value={metrics?.availableHelpers}
        icon="👥"
        colorClass="metric-helper"
      />
    </div>
  );
};

export default AnalyticsBar;
