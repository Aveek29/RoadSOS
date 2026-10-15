import React from 'react';
import { Filter, Calendar, Bell, ChevronDown } from 'lucide-react';

const Header = ({ notificationCount = 3, inspectorName = 'Inspector Arjun', division = 'Chennai City Police', customTitle, customSubtitle }) => {
  return (
    <header className="header-section">
      <div className="header-title-group">
        <h1>{customTitle || 'Live Accident Alerts'}</h1>
        <p>{customSubtitle || 'Real-time accident reports from RoadSOS users'}</p>
      </div>

      <div className="header-actions">
        {/* Status Filter */}
        <button className="btn-filter">
          <Filter size={15} />
          All Status
          <ChevronDown size={14} />
        </button>

        {/* Time range Filter */}
        <button className="btn-filter">
          <Calendar size={15} />
          Last 24 Hours
          <ChevronDown size={14} />
        </button>

        {/* Notification Bell */}
        <button className="bell-icon-btn">
          <Bell size={18} />
          {notificationCount > 0 && (
            <span className="bell-badge">{notificationCount}</span>
          )}
        </button>

        {/* Profile Card */}
        <div className="profile-group">
          <div className="profile-avatar">
            {/* Simple SVG avatar inside circle */}
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M20 21C20 19.6044 20 18.9067 19.7275 18.372C19.4878 17.9018 19.0982 17.5122 18.628 17.2725C18.0933 17 17.3956 17 16 17H8C6.60444 17 5.90668 17 5.37201 17.2725C4.90181 17.5122 4.51218 17.9018 4.27248 18.372C4 18.9067 4 19.6044 4 21" stroke="#475569" strokeWidth="2" strokeLinecap="round"/>
              <circle cx="12" cy="9" r="4" stroke="#475569" strokeWidth="2"/>
            </svg>
          </div>
          <div className="profile-info">
            <span className="profile-name">{inspectorName}</span>
            <span className="profile-role">{division}</span>
          </div>
          <ChevronDown size={14} style={{ color: 'var(--text-secondary)' }} />
        </div>
      </div>
    </header>
  );
};

export default Header;
