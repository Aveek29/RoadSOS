import React, { useState } from 'react';
import { Settings, Shield, Bell, Key, CheckCircle, Database } from 'lucide-react';

const SettingsRow = ({ label, desc, children }) => (
  <div className="settings-row">
    <div className="settings-row-info">
      <span className="settings-row-label">{label}</span>
      <span className="settings-row-desc">{desc}</span>
    </div>
    {children}
  </div>
);

const ToggleSwitch = ({ checked, onChange }) => (
  <label className="switch">
    <input type="checkbox" checked={checked} onChange={onChange} />
    <span className="slider"></span>
  </label>
);

const SettingsScreen = () => {
  const [soundAlert, setSoundAlert] = useState(true);
  const [autoSms, setAutoSms] = useState(true);
  const [autoPopup, setAutoPopup] = useState(true);
  const [radius, setRadius] = useState('2km');
  const [timeout, setTimeoutVal] = useState('60s');
  const [maxSlots, setMaxSlots] = useState('3');

  return (
    <div className="settings-container" style={{ animation: 'fadeIn 0.2s ease' }}>
      {/* Column 1: Configuration forms */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {/* Notification preferences */}
        <div className="settings-card">
          <h4 className="settings-title">
            <Bell size={16} style={{ color: 'var(--color-red)' }} />
            Notification Toggles
          </h4>
          <div className="settings-group">
            <SettingsRow label="Audible Alert Siren" desc="Play sound when a new incident is received">
              <ToggleSwitch checked={soundAlert} onChange={(e) => setSoundAlert(e.target.checked)} />
            </SettingsRow>
            <SettingsRow label="Immediate Dispatch Overlay" desc="Auto-focus and pop-up details on critical alerts">
              <ToggleSwitch checked={autoPopup} onChange={(e) => setAutoPopup(e.target.checked)} />
            </SettingsRow>
            <SettingsRow label="Broadcast SMS Warnings" desc="Send auto-alerts to first responder dispatch desks">
              <ToggleSwitch checked={autoSms} onChange={(e) => setAutoSms(e.target.checked)} />
            </SettingsRow>
          </div>
        </div>

        {/* Dispatch variables */}
        <div className="settings-card">
          <h4 className="settings-title">
            <Shield size={16} style={{ color: 'var(--color-blue)' }} />
            Response & Dispatch Settings
          </h4>
          <div className="settings-group">
            <SettingsRow label="Volunteer Geohash Proximity" desc="Max search radius for nearby helper matching">
              <select className="input-select" value={radius} onChange={(e) => setRadius(e.target.value)}>
                <option value="1km">1.2 km (Geohash 6)</option>
                <option value="2km">2.5 km (Default)</option>
                <option value="5km">4.9 km (Geohash 5)</option>
                <option value="10km">10.0 km (Large Grid)</option>
              </select>
            </SettingsRow>
            <SettingsRow label="Volunteer Slots Limit" desc="Maximum volunteer slot reservations per accident">
              <select className="input-select" value={maxSlots} onChange={(e) => setMaxSlots(e.target.value)}>
                <option value="2">2 volunteers max</option>
                <option value="3">3 volunteers (Recommended)</option>
                <option value="5">5 volunteers max</option>
              </select>
            </SettingsRow>
            <SettingsRow label="Auto-dispatch Escalation Timeout" desc="Escalate to ambulance if volunteer slots are empty">
              <select className="input-select" value={timeout} onChange={(e) => setTimeoutVal(e.target.value)}>
                <option value="30s">30 seconds</option>
                <option value="60s">60 seconds</option>
                <option value="120s">2 minutes</option>
                <option value="300s">5 minutes</option>
              </select>
            </SettingsRow>
          </div>
        </div>
      </div>

      {/* Column 2: System Status logs & integrations */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <div className="settings-card">
          <h4 className="settings-title">
            <Database size={16} style={{ color: 'var(--color-green)' }} />
            API Gateway Integrations
          </h4>
          <div className="settings-group">
            <div style={{ padding: '10px 14px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '8px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>Firebase Admin SDK Connection</strong>
                <span style={{ color: 'var(--color-green)', fontWeight: 'bold' }}>CONNECTED</span>
              </div>
              <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                Listening on <code>incidents</code> collection snapshots via admin event-listeners.
              </span>
            </div>

            <div style={{ padding: '10px 14px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '8px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>Twilio SMS Gateway</strong>
                <span style={{ color: 'var(--color-green)', fontWeight: 'bold' }}>OPERATIONAL</span>
              </div>
              <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                Twilio balance: <code>$14.80</code>. SMS dispatcher queues running healthy.
              </span>
            </div>

            <div style={{ padding: '10px 14px', background: '#F8FAFC', borderRadius: '8px', border: '1px solid var(--border-color)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '8px' }}>
                <strong style={{ color: 'var(--text-primary)' }}>Chennai Geohash Index Grid</strong>
                <span style={{ color: 'var(--color-green)', fontWeight: 'bold' }}>SYNCHRONIZED</span>
              </div>
              <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                Cascade 9-grid neighbor generator responding in under <code>8.5ms</code>.
              </span>
            </div>
          </div>
        </div>

        {/* Security / keys check */}
        <div className="settings-card">
          <h4 className="settings-title">
            <Key size={16} style={{ color: 'var(--color-purple)' }} />
            Security & Calibration
          </h4>
          <div className="settings-group" style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
            <p>
              This console is calibrated for <strong>Chennai City Police Emergency Dispatch Desks</strong>. All logins and dispatch events are logged for SLA auditing.
            </p>
            <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
              <button className="btn-detail-action secondary" style={{ flex: 1, padding: '8px 12px', fontSize: '12px' }}>
                Download Incident Logs
              </button>
              <button className="btn-detail-action primary" style={{ flex: 1, padding: '8px 12px', fontSize: '12px', background: 'var(--color-purple)' }}>
                Re-Calibrate Grid Baselines
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SettingsScreen;
