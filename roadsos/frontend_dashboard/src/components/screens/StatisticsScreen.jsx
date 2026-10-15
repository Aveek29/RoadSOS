import React from 'react';
import { TrendingUp, Award, Zap, Hourglass } from 'lucide-react';

const WEEKLY_DATA = [
  { day: 'Mon', count: 18, height: '65%' },
  { day: 'Tue', count: 24, height: '85%' },
  { day: 'Wed', count: 14, height: '50%' },
  { day: 'Thu', count: 29, height: '100%' },
  { day: 'Fri', count: 22, height: '78%' },
  { day: 'Sat', count: 16, height: '56%' },
  { day: 'Sun', count: 11, height: '38%' },
];

const SummaryCard = ({ label, value, subtext, icon: Icon, colorClass }) => (
  <div className="stat-card" style={{ padding: '16px' }}>
    <div className={`stat-icon ${colorClass}`} style={{ width: '38px', height: '38px', fontSize: '16px' }}>
      <Icon size={16} />
    </div>
    <div className="stat-info">
      <div className="stat-value" style={{ fontSize: '20px' }}>{value}</div>
      <div className="stat-label" style={{ fontSize: '12px' }}>{label}</div>
      <div className="stat-sub">{subtext}</div>
    </div>
  </div>
);

const StatisticsScreen = () => {
  return (
    <div style={{ animation: 'fadeIn 0.2s ease', display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* 3 Summary metric cards */}
      <div className="stats-summary-grid">
        <SummaryCard
          label="Dispatcher Efficiency"
          value="98.4%"
          subtext="Within dynamic SLA targets"
          icon={Zap}
          colorClass="green"
        />
        <SummaryCard
          label="Average Dispatch Delay"
          value="1.2 mins"
          subtext="Golden-hour response delay"
          icon={Hourglass}
          colorClass="amber"
        />
        <SummaryCard
          label="Helper Ratios"
          value="3.4 per alert"
          subtext="Crowdvolunteer dispatch density"
          icon={TrendingUp}
          colorClass="blue"
        />
      </div>

      {/* Main Charts area */}
      <div className="charts-grid">
        {/* Weekly alert volume bar chart */}
        <div className="chart-card">
          <h4 className="chart-title">Alerts Volume (Last 7 Days)</h4>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: '220px', padding: '0 20px', borderBottom: '1px solid var(--border-color)', margin: 'auto 0' }}>
            {WEEKLY_DATA.map((item, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1, gap: '8px' }}>
                <span style={{ fontSize: '11px', fontWeight: 'bold', color: 'var(--text-secondary)' }}>
                  {item.count}
                </span>
                <div style={{
                  backgroundColor: i === 3 ? 'var(--color-red)' : 'var(--color-blue)',
                  width: '24px',
                  height: `calc(160px * ${item.count / 29})`,
                  borderRadius: '4px 4px 0 0',
                  boxShadow: i === 3 ? '0 4px 10px rgba(239, 68, 68, 0.2)' : 'none',
                  transition: 'all 0.3s ease'
                }} />
                <span style={{ fontSize: '11px', fontWeight: '600', color: 'var(--text-secondary)' }}>
                  {item.day}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Severity distribution donut chart */}
        <div className="chart-card" style={{ alignItems: 'center' }}>
          <h4 className="chart-title" style={{ alignSelf: 'flex-start' }}>Severity Distribution</h4>

          <div className="chart-visual-wrapper">
            {/* SVG Donut */}
            <svg width="160" height="160" viewBox="0 0 36 36" style={{ transform: 'rotate(-90deg)' }}>
              {/* Outer ring */}
              <circle cx="18" cy="18" r="15.915" fill="none" stroke="#E2E8F0" strokeWidth="3" />
              {/* Low slice - Green - 15% */}
              <circle cx="18" cy="18" r="15.915" fill="none" stroke="#10B981" strokeWidth="3" strokeDasharray="15 85" strokeDashoffset="100" />
              {/* Medium slice - Amber - 45% */}
              <circle cx="18" cy="18" r="15.915" fill="none" stroke="#F59E0B" strokeWidth="3" strokeDasharray="45 55" strokeDashoffset="85" />
              {/* High slice - Red - 30% */}
              <circle cx="18" cy="18" r="15.915" fill="none" stroke="#EF4444" strokeWidth="3" strokeDasharray="30 70" strokeDashoffset="40" />
              {/* Critical slice - Purple - 10% */}
              <circle cx="18" cy="18" r="15.915" fill="none" stroke="#8B5CF6" strokeWidth="3" strokeDasharray="10 90" strokeDashoffset="10" />
            </svg>

            {/* Center label */}
            <div style={{ position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <span style={{ fontSize: '24px', fontWeight: '800', fontFamily: 'var(--font-head)' }}>124</span>
              <span style={{ fontSize: '10px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Total alerts</span>
            </div>
          </div>

          {/* Legend */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px 24px', width: '100%', marginTop: 'auto' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px' }}>
              <span style={{ width: '10px', height: '10px', borderRadius: '2px', backgroundColor: '#8B5CF6' }}></span>
              <strong>Critical</strong>
              <span style={{ color: 'var(--text-secondary)', marginLeft: 'auto' }}>10%</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px' }}>
              <span style={{ width: '10px', height: '10px', borderRadius: '2px', backgroundColor: '#EF4444' }}></span>
              <strong>High</strong>
              <span style={{ color: 'var(--text-secondary)', marginLeft: 'auto' }}>30%</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px' }}>
              <span style={{ width: '10px', height: '10px', borderRadius: '2px', backgroundColor: '#F59E0B' }}></span>
              <strong>Medium</strong>
              <span style={{ color: 'var(--text-secondary)', marginLeft: 'auto' }}>45%</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px' }}>
              <span style={{ width: '10px', height: '10px', borderRadius: '2px', backgroundColor: '#10B981' }}></span>
              <strong>Low</strong>
              <span style={{ color: 'var(--text-secondary)', marginLeft: 'auto' }}>15%</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default StatisticsScreen;
