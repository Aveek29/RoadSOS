import React from 'react';
import { ShieldAlert, Clock, Map, Car, BarChart3, Settings } from 'lucide-react';

const MENU_ITEMS = [
  { id: 'live-alerts', label: 'Live Alerts', icon: ShieldAlert },
  { id: 'history', label: 'Alert History', icon: Clock },
  { id: 'map', label: 'Map View', icon: Map },
  { id: 'units', label: 'Nearby Units', icon: Car },
  { id: 'stats', label: 'Statistics', icon: BarChart3 },
  { id: 'settings', label: 'Settings', icon: Settings },
];

const Sidebar = ({ activeTab = 'live-alerts', onTabChange }) => {
  return (
    <aside className="sidebar">
      <div>
        <div className="sidebar-logo">
          <div className="sidebar-logo-icon">
            <span>SOS</span>
          </div>
          <div>
            <h2 className="sidebar-logo-text">
              Road<span>SOS</span>
            </h2>
            <span className="sidebar-logo-sub">POLICE DASHBOARD</span>
          </div>
        </div>

        <ul className="sidebar-menu">
          {MENU_ITEMS.map((item) => {
            const Icon = item.icon;
            return (
              <li key={item.id}>
                <button
                  className={`sidebar-item ${activeTab === item.id ? 'active' : ''}`}
                  onClick={() => onTabChange && onTabChange(item.id)}
                  style={{
                    width: '100%',
                    background: 'none',
                    border: 'none',
                    textAlign: 'left',
                    fontFamily: 'inherit',
                  }}
                >
                  <Icon size={18} />
                  {item.label}
                </button>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="sidebar-status">
        <div className="sidebar-status-title">System Status</div>
        <div className="sidebar-status-value">
          <span className="sidebar-status-dot"></span>
          Online
        </div>
        <div className="sidebar-status-desc">All systems operational</div>
      </div>
    </aside>
  );
};

export default Sidebar;
