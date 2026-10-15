import React from 'react';

const SEVERITY_META = {
  CRITICAL: { emoji: '🚨', label: 'CRITICAL' },
  HIGH:     { emoji: '🔴', label: 'HIGH' },
  MEDIUM:   { emoji: '🟠', label: 'MEDIUM' },
  LOW:      { emoji: '🟢', label: 'LOW' },
};

const SeverityBadge = ({ severity, score }) => {
  const meta = SEVERITY_META[severity] || SEVERITY_META.LOW;
  return (
    <span className={`severity-badge sev-badge-${severity || 'LOW'}`}>
      {meta.emoji} {meta.label}
      {score != null && (
        <span className="severity-score">{(score * 100).toFixed(0)}%</span>
      )}
    </span>
  );
};

export default SeverityBadge;
