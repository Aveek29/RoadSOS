import React from 'react';
import { Shield, Truck, Users, Activity, ToggleLeft, ToggleRight } from 'lucide-react';

const MOCK_POLICE = [
  { id: 'PATROL-104', type: 'Cruiser', status: 'RESPONDING', assignment: 'Active Incident NH48', contact: '044 2345 1044' },
  { id: 'PATROL-208', type: 'Patrol Cruiser', status: 'IDLE', assignment: 'None (Patrolling)', contact: '044 2345 2088' },
  { id: 'PATROL-301', type: 'Highway Patrol', status: 'RESPONDING', assignment: 'Active Incident GST Rd', contact: '044 2345 3011' },
  { id: 'PATROL-088', type: 'Patrol Cruiser', status: 'IDLE', assignment: 'None (Patrolling)', contact: '044 2345 0888' },
];

const MOCK_AMBULANCE = [
  { id: 'AMB-TRAUMA-03', type: 'Advanced Life Support', status: 'RESPONDING', assignment: 'Active Incident NH48', contact: '044 4567 0333' },
  { id: 'AMB-EMT-12', type: 'Basic EMT Unit', status: 'IDLE', assignment: 'None (Stationed)', contact: '044 4567 1222' },
  { id: 'AMB-TRAUMA-07', type: 'Advanced Life Support', status: 'IDLE', assignment: 'None (Stationed)', contact: '044 4567 0777' },
];

const NearbyUnitsScreen = ({ incidents = [] }) => {
  // Extract live accepted helpers from incidents list
  const activeIncidents = incidents.filter(i => i.status !== 'RESOLVED');
  const liveHelpers = [];
  
  activeIncidents.forEach(inc => {
    if (inc.acceptedHelpers && inc.acceptedHelpers.length > 0) {
      inc.acceptedHelpers.forEach(h => {
        liveHelpers.push({
          uid: h.uid || 'volunteer_node',
          name: h.name || 'Volunteer',
          phone: h.phone || '—',
          status: 'BUSY',
          assignment: `Incident ${inc.id?.substring(0, 6)}...`,
          distance: `${(h.distanceMeters || 300).toFixed(0)}m away`
        });
      });
    }
  });

  // Default volunteer roster
  const defaultVolunteers = [
    { uid: 'helper_101', name: 'Arjun Kumar', phone: '+919876543210', status: 'ONLINE', assignment: 'Ready', distance: '450m away' },
    { uid: 'helper_102', name: 'Priya Sundar', phone: '+919876543211', status: 'ONLINE', assignment: 'Ready', distance: '1.1km away' },
    { uid: 'helper_105', name: 'Rajesh Nair', phone: '+919876543215', status: 'ONLINE', assignment: 'Ready', distance: '1.6km away' },
  ];

  // Combine live and mock volunteers (prevent duplicates by uid)
  const allVolunteers = [...liveHelpers];
  defaultVolunteers.forEach(v => {
    if (!allVolunteers.some(item => item.uid === v.uid)) {
      allVolunteers.push(v);
    }
  });

  return (
    <div className="units-container" style={{ animation: 'fadeIn 0.2s ease' }}>
      <div style={{ marginBottom: '24px' }}>
        <h3 className="alerts-panel-title" style={{ margin: 0 }}>Emergency Fleet & Responders</h3>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' }}>
          Real-time status tracking of dispatched cruisers, medical units, and community helpers.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '24px' }}>
        {/* Police Patrols */}
        <div style={{ border: '1px solid var(--border-color)', borderRadius: '12px', padding: '16px', background: '#FFFFFF' }}>
          <h4 style={{ fontSize: '14px', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', marginBottom: '12px' }}>
            <Shield size={16} style={{ color: 'var(--color-blue)' }} />
            Police Cruisers
          </h4>
          <table className="command-table" style={{ fontSize: '12px' }}>
            <thead>
              <tr>
                <th>Unit ID</th>
                <th>Status</th>
                <th>Assignment</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_POLICE.map(p => (
                <tr key={p.id}>
                  <td style={{ fontWeight: 600 }}>{p.id}</td>
                  <td>
                    <span className={`badge-status ${p.status === 'RESPONDING' ? 'responding' : 'idle'}`}>
                      {p.status}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>{p.assignment}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Ambulances */}
        <div style={{ border: '1px solid var(--border-color)', borderRadius: '12px', padding: '16px', background: '#FFFFFF' }}>
          <h4 style={{ fontSize: '14px', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', marginBottom: '12px' }}>
            <Truck size={16} style={{ color: 'var(--color-red)' }} />
            Medical Trauma Units
          </h4>
          <table className="command-table" style={{ fontSize: '12px' }}>
            <thead>
              <tr>
                <th>Unit ID</th>
                <th>Status</th>
                <th>Assignment</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_AMBULANCE.map(a => (
                <tr key={a.id}>
                  <td style={{ fontWeight: 600 }}>{a.id}</td>
                  <td>
                    <span className={`badge-status ${a.status === 'RESPONDING' ? 'responding' : 'idle'}`}>
                      {a.status}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>{a.assignment}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Volunteer Community Responders */}
      <div style={{ border: '1px solid var(--border-color)', borderRadius: '12px', padding: '16px', background: '#FFFFFF' }}>
        <h4 style={{ fontSize: '14px', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', marginBottom: '12px' }}>
          <Users size={16} style={{ color: 'var(--color-green)' }} />
          Volunteer Helper Network (Chennai GeoGrid)
        </h4>
        <table className="command-table" style={{ fontSize: '12px' }}>
          <thead>
            <tr>
              <th>Volunteer Name</th>
              <th>Status</th>
              <th>Grid Range</th>
              <th>Assignment</th>
              <th>Contact Node</th>
            </tr>
          </thead>
          <tbody>
            {allVolunteers.map(v => (
              <tr key={v.uid}>
                <td style={{ fontWeight: 600 }}>{v.name}</td>
                <td>
                  <span className={`badge-status ${v.status === 'ONLINE' ? 'resolved' : 'responding'}`} style={{ textTransform: 'capitalize' }}>
                    {v.status === 'ONLINE' ? 'Online' : 'Responding'}
                  </span>
                </td>
                <td>{v.distance}</td>
                <td style={{ color: 'var(--text-secondary)' }}>{v.assignment}</td>
                <td style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-muted)' }}>{v.phone}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default NearbyUnitsScreen;
