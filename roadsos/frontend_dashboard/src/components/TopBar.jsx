import React, { useState, useEffect } from 'react';

const TopBar = ({ backendStatus }) => {
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const chipClass = {
    connected: 'chip-connected',
    disconnected: 'chip-disconnected',
    checking: 'chip-checking',
  }[backendStatus] || 'chip-checking';

  const chipLabel = {
    connected: 'COMMAND CENTER ONLINE',
    disconnected: 'BACKEND OFFLINE',
    checking: 'CONNECTING...',
  }[backendStatus] || 'CONNECTING...';

  return (
    <header className="top-bar">
      <div className="top-bar-logo">
        <div className="top-bar-logo-icon">🚨</div>
        <span className="top-bar-logo-text">
          Road<span>SoS</span>
        </span>
      </div>

      <div className="top-bar-center">
        <span className="top-bar-title">Emergency Response Platform</span>
      </div>

      <div className="top-bar-right">
        <span className="live-clock">
          {time.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false,
          })}
        </span>
        <div className={`connection-chip ${chipClass}`}>
          <span className="connection-chip-dot" />
          {chipLabel}
        </div>
      </div>
    </header>
  );
};

export default TopBar;
