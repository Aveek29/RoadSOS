import React, { useState, useEffect } from 'react';
import { Clock, CheckCircle, Search, Info, MapPin, Inbox } from 'lucide-react';

const SeverityBadge = ({ severity }) => {
  const label = severity === 'CRITICAL' || severity === 'HIGH' ? 'High' : severity === 'MEDIUM' ? 'Medium' : 'Low';
  const cls = severity === 'CRITICAL' ? 'critical' : severity === 'HIGH' ? 'high' : severity === 'MEDIUM' ? 'medium' : 'low';
  return (
    <span className={`alert-card-priority-badge ${cls}`} style={{ display: 'inline-block' }}>
      {label}
    </span>
  );
};

const getRelativeTimeString = (isoString) => {
  try {
    const diff = Date.now() - new Date(isoString).getTime();
    const mins = Math.floor(diff / 60000);
    const hours = Math.floor(mins / 60);
    const days = Math.floor(hours / 24);

    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    if (hours < 24) return `${hours}h ago`;
    return `${days}d ago`;
  } catch (e) {
    return '';
  }
};

const getTimelineData = (incident) => {
  if (incident.timeline && incident.timeline.length > 0) {
    return incident.timeline;
  }

  // Fallback dynamic timeline for real incidents
  const timeline = [];
  const reportedTime = new Date(incident.timestamp || Date.now());

  // 1. Report
  timeline.push({
    status: 'reported',
    label: 'Incident Reported',
    time: incident.timestamp || new Date().toISOString(),
    desc: `Emergency reported via ${incident.source === 'demo' ? 'Command Simulator' : 'RoadSOS Mobile Client'}.`
  });

  // 2. Dispatch (if any resources are dispatched)
  if (incident.dispatchedResources && incident.dispatchedResources.length > 0) {
    const minDispatchTime = new Date(Math.min(...incident.dispatchedResources.map(r => new Date(r.dispatchedAt || reportedTime.getTime() + 120000))));
    timeline.push({
      status: 'dispatched',
      label: 'Emergency Dispatch Initiated',
      time: minDispatchTime.toISOString(),
      desc: `Dispatched resources: ${incident.dispatchedResources.map(r => r.type === 'police' ? '🚓 Police' : '🚑 Ambulance').join(', ')}.`
    });

    // 3. Arrival (simulated relative to dispatch)
    const arrivalTime = new Date(minDispatchTime.getTime() + 480000); // 8 mins later
    timeline.push({
      status: 'arrived',
      label: 'First Responder Arrival',
      time: arrivalTime.toISOString(),
      desc: 'First responding unit arrived on-scene to secure the sector.'
    });
  }

  // 4. Resolved
  timeline.push({
    status: 'resolved',
    label: 'Incident Marked Resolved',
    time: new Date(reportedTime.getTime() + 1800000).toISOString(), // ~30m later
    desc: 'Incident cleared, lanes reopened, logged by Chennai Dispatch Center.'
  });

  return timeline;
};

const AlertHistoryScreen = ({ incidents = [] }) => {
  const resolvedIncidents = incidents.filter((i) => i.status === 'RESOLVED');
  const [mockIncidents, setMockIncidents] = useState([]);
  const [selectedHistory, setSelectedHistory] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Combine real resolved incidents and mock incidents
  const allResolved = [...resolvedIncidents, ...mockIncidents];

  const filteredHistory = allResolved.filter((inc) => {
    const term = searchQuery.toLowerCase();
    const cityMatch = inc.city ? inc.city.toLowerCase().includes(term) : false;
    const idMatch = inc.id ? inc.id.toLowerCase().includes(term) : false;
    const sevMatch = inc.severity ? inc.severity.toLowerCase().includes(term) : false;
    return cityMatch || idMatch || sevMatch;
  });

  // Auto-select first incident in list if none is selected, or if selected one is not in the filtered history
  useEffect(() => {
    if (filteredHistory.length > 0) {
      const isStillPresent = selectedHistory && filteredHistory.some(i => i.id === selectedHistory.id);
      if (!selectedHistory || !isStillPresent) {
        setSelectedHistory(filteredHistory[0]);
      }
    } else {
      setSelectedHistory(null);
    }
  }, [filteredHistory, selectedHistory]);

  const injectMockRecords = () => {
    const now = Date.now();
    const formattedMockData = [
      {
        id: 'INC-2026-8801',
        status: 'RESOLVED',
        timestamp: new Date(now - 3600000 * 1.5).toISOString(), // 1.5 hours ago
        city: 'Koyambedu Junction, Chennai',
        severity: 'CRITICAL',
        latitude: 13.0694,
        longitude: 80.1948,
        confidence: 0.94,
        source: 'demo',
        description: 'Critical collision between a loaded truck and two-wheeler. Rider sustained severe head trauma; automated helmet sensor-fusion triggered emergency SOS.',
        dispatchedResources: [
          { type: 'police', name: 'Traffic Patrol 4B', dispatchedAt: new Date(now - 3600000 * 1.48).toISOString(), arrivedAt: new Date(now - 3600000 * 1.4).toISOString() },
          { type: 'ambulance', name: 'ALS Medic 12', dispatchedAt: new Date(now - 3600000 * 1.46).toISOString(), arrivedAt: new Date(now - 3600000 * 1.35).toISOString() }
        ],
        timeline: [
          { status: 'reported', label: 'Collision Event Triggered', time: new Date(now - 3600000 * 1.5).toISOString(), desc: 'On-device sensor fusion detected 14G impact. Automatic broadcast sent.' },
          { status: 'dispatched', label: 'Emergency Responders Dispatched', time: new Date(now - 3600000 * 1.47).toISOString(), desc: 'Traffic Patrol 4B & ALS Medic 12 dispatched by Chennai Command Center.' },
          { status: 'arrived', label: 'Emergency Responders Arrived', time: new Date(now - 3600000 * 1.4).toISOString(), desc: 'Ambulance team stabilized rider; police cordoned off lane to manage heavy traffic.' },
          { status: 'cleared', label: 'Scene Cleared & Secured', time: new Date(now - 3600000 * 1.1).toISOString(), desc: 'Debris removed by municipal workers. Victim transported to Chennai Metro Hospital.' },
          { status: 'resolved', label: 'Incident Closed (Resolved)', time: new Date(now - 3600000 * 1.0).toISOString(), desc: 'Flow restored. Log verified and closed by Inspector Arjun.' }
        ]
      },
      {
        id: 'INC-2026-8802',
        status: 'RESOLVED',
        timestamp: new Date(now - 3600000 * 4.2).toISOString(), // 4.2 hours ago
        city: 'Tambaram GST Road (near MEPZ Flyover), Chennai',
        severity: 'HIGH',
        latitude: 12.9229,
        longitude: 80.1218,
        confidence: 0.88,
        source: 'app',
        description: 'Multi-car fender bender blocking the center lane of GST road. Significant delays reported, airbags did not deploy, minor passenger shock.',
        dispatchedResources: [
          { type: 'police', name: 'GST Patrol Car 8', dispatchedAt: new Date(now - 3600000 * 4.1).toISOString(), arrivedAt: new Date(now - 3600000 * 3.9).toISOString() }
        ],
        timeline: [
          { status: 'reported', label: 'Citizen Incident Report', time: new Date(now - 3600000 * 4.2).toISOString(), desc: 'Multiple reports received via RoadSOS app from commuters.' },
          { status: 'dispatched', label: 'Police Dispatch', time: new Date(now - 3600000 * 4.1).toISOString(), desc: 'GST Patrol Car 8 dispatched for route management.' },
          { status: 'arrived', label: 'Patrol Arrived at Site', time: new Date(now - 3600000 * 3.9).toISOString(), desc: 'Officers diverted traffic to side lanes and called private towing services.' },
          { status: 'cleared', label: 'Vehicles Towed', time: new Date(now - 3600000 * 3.2).toISOString(), desc: 'Both cars moved to MEPZ service lane. Road fully reopened.' },
          { status: 'resolved', label: 'Incident Closed', time: new Date(now - 3600000 * 3.0).toISOString(), desc: 'Insurance claims processed, incident finalized by GST Patrol.' }
        ]
      },
      {
        id: 'INC-2026-8803',
        status: 'RESOLVED',
        timestamp: new Date(now - 3600000 * 8.0).toISOString(), // 8 hours ago
        city: 'Sholinganallur OMR Junction, Chennai',
        severity: 'MEDIUM',
        latitude: 12.9012,
        longitude: 80.2269,
        confidence: 0.82,
        source: 'app',
        description: 'Auto-rickshaw overturned due to slippery surface caused by light morning showers. Volunteers arrived on scene to assist passengers.',
        dispatchedResources: [
          { type: 'ambulance', name: 'OMR Trauma Ambulance', dispatchedAt: new Date(now - 3600000 * 7.95).toISOString(), arrivedAt: new Date(now - 3600000 * 7.8).toISOString() }
        ],
        timeline: [
          { status: 'reported', label: 'Volunteer Report Received', time: new Date(now - 3600000 * 8.0).toISOString(), desc: 'Incident reported with photos via RoadSOS Volunteer dashboard.' },
          { status: 'dispatched', label: 'Medical Response Dispatched', time: new Date(now - 3600000 * 7.95).toISOString(), desc: 'Trauma Care Unit 14 directed to the junction.' },
          { status: 'arrived', label: 'Ambulance Arrived', time: new Date(now - 3600000 * 7.8).toISOString(), desc: 'Treated two passengers for minor abrasions. No hospital transport required.' },
          { status: 'cleared', label: 'Obstruction Removed', time: new Date(now - 3600000 * 7.5).toISOString(), desc: 'Auto-rickshaw uprighted and pushed to the side. Traffic flowing smoothly.' },
          { status: 'resolved', label: 'Incident Resolved', time: new Date(now - 3600000 * 7.4).toISOString(), desc: 'Cleared from central database tracking logs.' }
        ]
      },
      {
        id: 'INC-2026-8804',
        status: 'RESOLVED',
        timestamp: new Date(now - 86400000 * 1.2).toISOString(), // ~30 hours ago (yesterday)
        city: 'Kathipara Flyover, Guindy, Chennai',
        severity: 'CRITICAL',
        latitude: 13.0067,
        longitude: 80.2018,
        confidence: 0.97,
        source: 'demo',
        description: 'High-speed sedan crashed into concrete divider on the Kathipara ramp. Airbag deployment telemetry detected by vehicle gateway integration.',
        dispatchedResources: [
          { type: 'police', name: 'Guindy Highway Patrol', dispatchedAt: new Date(now - 86400000 * 1.2 + 120000).toISOString(), arrivedAt: new Date(now - 86400000 * 1.2 + 600000).toISOString() },
          { type: 'ambulance', name: 'Guindy Trauma Unit', dispatchedAt: new Date(now - 86400000 * 1.2 + 180000).toISOString(), arrivedAt: new Date(now - 86400000 * 1.2 + 720000).toISOString() }
        ],
        timeline: [
          { status: 'reported', label: 'Airbag Telemetry Received', time: new Date(now - 86400000 * 1.2).toISOString(), desc: 'Automatic SOS broadcast sent from integrated vehicular system. High confidence.' },
          { status: 'dispatched', label: 'Emergency Responders Dispatched', time: new Date(now - 86400000 * 1.2 + 180000).toISOString(), desc: 'Guindy Highway Patrol and Trauma Care unit dispatched simultaneously.' },
          { status: 'arrived', label: 'Emergency Responders Arrived', time: new Date(now - 86400000 * 1.2 + 720000).toISOString(), desc: 'Driver extricated with minor fractures. First aid administered.' },
          { status: 'cleared', label: 'Wreckage Cleared', time: new Date(now - 86400000 * 1.2 + 3600000).toISOString(), desc: 'Sedan towed to local station. Concrete divider inspected and secured.' },
          { status: 'resolved', label: 'Incident Resolved', time: new Date(now - 86400000 * 1.2 + 4500000).toISOString(), desc: 'Cleared from Kathipara main deck, incident logged as completed.' }
        ]
      },
      {
        id: 'INC-2026-8805',
        status: 'RESOLVED',
        timestamp: new Date(now - 86400000 * 1.8).toISOString(), // ~43 hours ago (yesterday)
        city: 'Usman Road, T-Nagar, Chennai',
        severity: 'LOW',
        latitude: 13.0324,
        longitude: 80.2337,
        confidence: 0.76,
        source: 'app',
        description: 'Minor bumper scraping in highly congested market area. No injuries reported, minor paint damage.',
        dispatchedResources: [],
        timeline: [
          { status: 'reported', label: 'Manual Incident Report', time: new Date(now - 86400000 * 1.8).toISOString(), desc: 'Report submitted by passenger via RoadSOS application.' },
          { status: 'dispatched', label: 'No Dispatch Required', time: new Date(now - 86400000 * 1.8 + 60000).toISOString(), desc: 'SLA logic determined lowest threat level. Traffic camera monitored.' },
          { status: 'arrived', label: 'Parties Mutual Agreement', time: new Date(now - 86400000 * 1.8 + 1200000).toISOString(), desc: 'Both parties agreed to swap contact details and clear the lane without formal mediation.' },
          { status: 'resolved', label: 'Incident Closed', time: new Date(now - 86400000 * 1.8 + 1800000).toISOString(), desc: 'Marked as resolved after confirmation of cleared blockages.' }
        ]
      }
    ];
    setMockIncidents(formattedMockData);
    setSelectedHistory(formattedMockData[0]);
  };

  return (
    <div className="content-grid" style={{ animation: 'fadeIn 0.2s ease', gridTemplateColumns: '1fr 360px' }}>
      {/* Left Column: Historical Table */}
      <div className="history-container">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <h3 className="alerts-panel-title" style={{ margin: 0 }}>Incident Ledger</h3>
          
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            {allResolved.length > 0 && (
              mockIncidents.length > 0 ? (
                <button className="btn-inject-utility" onClick={() => { setMockIncidents([]); setSelectedHistory(null); }} style={{ color: 'var(--color-red)' }}>
                  Clear Mock Data
                </button>
              ) : (
                <button className="btn-inject-utility" onClick={injectMockRecords}>
                  Inject Mock Data
                </button>
              )
            )}
            
            <div className="btn-filter" style={{ padding: '6px 12px', minWidth: '220px' }}>
              <Search size={14} style={{ color: 'var(--text-secondary)' }} />
              <input
                type="text"
                placeholder="Search by ID, location, priority..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{
                  border: 'none',
                  background: 'none',
                  outline: 'none',
                  fontSize: '12px',
                  width: '100%',
                  color: 'var(--text-primary)',
                }}
              />
            </div>
          </div>
        </div>

        <div className="table-responsive">
          {allResolved.length === 0 ? (
            <div className="empty-state-card">
              <div className="empty-state-icon-container">
                <Inbox size={32} />
              </div>
              <h4 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '8px' }}>
                No History Logs Detected
              </h4>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', maxWidth: '360px', margin: '0 auto', lineHeight: 1.5 }}>
                There are currently no resolved emergency incidents recorded in the central database ledger.
              </p>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '8px', maxWidth: '360px', lineHeight: 1.4 }}>
                To test the dispatch panel, resolve an active alert in the Live Alerts console, or inject mock Chennai historical data below.
              </p>
              <button className="btn-inject-records" onClick={injectMockRecords}>
                <span>⚡ Inject Mock Chennai Records</span>
              </button>
            </div>
          ) : filteredHistory.length === 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-secondary)', padding: '40px' }}>
              <Clock size={36} style={{ color: 'var(--text-muted)', marginBottom: '12px' }} />
              <strong>No history matches</strong>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                Try adjusting your search filter or clear the query.
              </span>
            </div>
          ) : (
            <table className="command-table">
              <thead>
                <tr>
                  <th>Incident ID</th>
                  <th>Resolved Time</th>
                  <th>Location</th>
                  <th>Severity</th>
                  <th>Dispatched Resources</th>
                </tr>
              </thead>
              <tbody>
                {filteredHistory.map((inc) => {
                  const isSelected = selectedHistory?.id === inc.id;
                  const dateStr = inc.timestamp
                    ? new Date(inc.timestamp).toLocaleString('en-IN', {
                        day: '2-digit',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit',
                      })
                    : '—';

                  return (
                    <tr
                      key={inc.id}
                      onClick={() => setSelectedHistory(inc)}
                      className={isSelected ? 'table-row-selected' : ''}
                      style={{ cursor: 'pointer' }}
                    >
                      <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                        {inc.id}
                      </td>
                      <td>
                        <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{dateStr}</div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{getRelativeTimeString(inc.timestamp)}</div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <MapPin size={12} style={{ color: 'var(--text-muted)' }} />
                          <span>{inc.city || 'Unknown Location'}</span>
                        </div>
                      </td>
                      <td>
                        <SeverityBadge severity={inc.severity} />
                      </td>
                      <td style={{ verticalAlign: 'middle' }}>
                        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                          {inc.dispatchedResources && inc.dispatchedResources.length > 0 ? (
                            inc.dispatchedResources.map((res, idx) => (
                              <span 
                                key={idx} 
                                style={{ 
                                  display: 'inline-flex', 
                                  alignItems: 'center', 
                                  gap: '4px', 
                                  fontSize: '11px', 
                                  background: res.type === 'police' ? 'var(--color-blue-light)' : 'var(--color-red-light)', 
                                  color: res.type === 'police' ? 'var(--color-blue)' : 'var(--color-red)', 
                                  border: `1px solid ${res.type === 'police' ? 'var(--color-blue-border)' : 'var(--color-red-border)'}`,
                                  padding: '2px 8px', 
                                  borderRadius: '4px',
                                  fontWeight: 500
                                }}
                              >
                                {res.type === 'police' ? '🚓' : '🚑'} {res.name || (res.type === 'police' ? 'Police' : 'Ambulance')}
                              </span>
                            ))
                          ) : (
                            <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontStyle: 'italic' }}>None</span>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Right Column: Inspect History Details Card */}
      <div className="detail-panel">
        {selectedHistory ? (
          <div style={{ display: 'flex', flexDirection: 'column', height: '100%', animation: 'fadeIn 0.15s ease' }}>
            <div className="simulator-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '16px', marginBottom: '16px' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                  <span className="badge-status resolved">
                    <CheckCircle size={10} style={{ marginRight: '4px' }} />
                    Resolved
                  </span>
                  <span style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)' }}>
                    {selectedHistory.id}
                  </span>
                </div>
                <h4 className="detail-title" style={{ fontSize: '18px', fontWeight: 800 }}>Incident Ledger Log</h4>
              </div>
            </div>

            <div style={{ flex: 1, overflowY: 'auto', paddingRight: '4px' }}>
              {/* Description overview panel */}
              {selectedHistory.description && (
                <div style={{ background: '#F8FAFC', borderLeft: '3px solid var(--color-blue)', padding: '12px 14px', borderRadius: '4px', fontSize: '12px', color: 'var(--text-secondary)', lineHeight: 1.4, marginBottom: '20px' }}>
                  <strong style={{ display: 'block', color: 'var(--text-primary)', marginBottom: '4px', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.4px' }}>Incident Overview</strong>
                  {selectedHistory.description}
                </div>
              )}

              {/* Parametric Data table */}
              <h5 style={{ fontSize: '11px', fontWeight: 'bold', textTransform: 'uppercase', color: 'var(--text-secondary)', letterSpacing: '0.5px', marginBottom: '10px' }}>
                Telemetry & Parameters
              </h5>
              <div className="detail-table" style={{ marginBottom: '24px', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '12px' }}>
                <div className="detail-row" style={{ padding: '6px 0', borderBottom: '1px solid #F1F5F9' }}>
                  <span className="detail-label" style={{ fontSize: '12px', width: '110px' }}>📍 Area</span>
                  <span className="detail-value" style={{ fontSize: '12px' }}>{selectedHistory.city || 'Unknown'}</span>
                </div>
                <div className="detail-row" style={{ padding: '6px 0', borderBottom: '1px solid #F1F5F9' }}>
                  <span className="detail-label" style={{ fontSize: '12px', width: '110px' }}>⏱ Timestamp</span>
                  <span className="detail-value" style={{ fontSize: '12px' }}>
                    {new Date(selectedHistory.timestamp).toLocaleString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                      second: '2-digit',
                      hour12: true
                    })}
                  </span>
                </div>
                <div className="detail-row" style={{ padding: '6px 0', borderBottom: '1px solid #F1F5F9' }}>
                  <span className="detail-label" style={{ fontSize: '12px', width: '110px' }}>🚨 Severity</span>
                  <span className="detail-value" style={{ fontSize: '12px' }}>
                    <SeverityBadge severity={selectedHistory.severity} />
                  </span>
                </div>
                <div className="detail-row" style={{ padding: '6px 0', borderBottom: '1px solid #F1F5F9' }}>
                  <span className="detail-label" style={{ fontSize: '12px', width: '110px' }}>🧭 Coordinates</span>
                  <span className="detail-value coordinates" style={{ fontSize: '12px' }}>
                    {selectedHistory.latitude?.toFixed(6)}, {selectedHistory.longitude?.toFixed(6)}
                  </span>
                </div>
                <div className="detail-row" style={{ padding: '6px 0' }}>
                  <span className="detail-label" style={{ fontSize: '12px', width: '110px' }}>🎯 Confidence</span>
                  <span className="detail-value" style={{ fontSize: '12px' }}>{(selectedHistory.confidence * 100).toFixed(0)}%</span>
                </div>
              </div>

              {/* Dynamic Dispatch Timeline */}
              <h5 style={{ fontSize: '11px', fontWeight: 'bold', textTransform: 'uppercase', color: 'var(--text-secondary)', letterSpacing: '0.5px', marginBottom: '10px' }}>
                Dispatch Timeline Track
              </h5>
              <div style={{ position: 'relative', background: '#FFFFFF', border: '1px solid var(--border-color)', borderRadius: '8px', padding: '16px' }}>
                <div className="timeline-container">
                  <div className="timeline-line"></div>
                  {getTimelineData(selectedHistory).map((node, i) => {
                    let nodeClass = 'completed';
                    if (node.status === 'reported') nodeClass = selectedHistory.severity === 'CRITICAL' ? 'critical' : selectedHistory.severity === 'HIGH' ? 'high' : 'active';
                    
                    return (
                      <div key={i} className={`timeline-node ${nodeClass}`}>
                        <div className="timeline-dot">
                          <div className="timeline-dot-inner"></div>
                        </div>
                        <div className="timeline-header">
                          <span className="timeline-title">{node.label}</span>
                          <span className="timeline-time">
                            {new Date(node.time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                          </span>
                        </div>
                        <div className="timeline-body">{node.desc}</div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-muted)', textAlign: 'center' }}>
            <Info size={32} style={{ color: 'var(--text-muted)', marginBottom: '8px' }} />
            <strong style={{ color: 'var(--text-primary)', fontSize: '14px' }}>Select an Incident</strong>
            <span style={{ fontSize: '12px', marginTop: '4px' }}>
              Click on any row in the incident ledger to inspect the details, coordinates, and dispatch logs.
            </span>
          </div>
        )}
      </div>
    </div>
  );
};

export default AlertHistoryScreen;
