# Example API Calls for Command Center Backend

These requests demonstrate how to interact with the Flask APIs representing our robust backend endpoints natively overriding Firebase state remotely. 

### 1. Health Status
Check if the backend systems are online.

```bash
curl -X GET http://127.0.0.1:5000/health
```

### 2. Fetch Active Incidents
Allows the frontend dashboard to pull an array of all active crashes missing `RESOLVED` mapping. You can pass the `limit` query flag.

```bash
curl -X GET "http://127.0.0.1:5000/incidents?limit=20"
```

### 3. Fetch Single Target Incident 
Populate specific telemetry for a singular known event. Replace `YOUR_INCIDENT_ID`.

```bash
curl -X GET http://127.0.0.1:5000/incident/YOUR_INCIDENT_ID
```

### 4. Dispatch First Responders (Ambulance/Police/Helper)
Appends a mapped resource timestamp entry underneath the target incident document implicitly updating incident statuses inside Firestore.

```bash
curl -X POST http://127.0.0.1:5000/dispatch \
-H "Content-Type: application/json" \
-d '{"incidentId": "YOUR_INCIDENT_ID", "type": "ambulance"}'
```

### 5. Manually Escalate/De-Escalate Incident Status
Trigger status transformations from command mapping logic limits `[ACTIVE, RESPONDING, RESOLVED]`.

```bash
curl -X POST http://127.0.0.1:5000/update-status \
-H "Content-Type: application/json" \
-d '{"incidentId": "YOUR_INCIDENT_ID", "status": "RESOLVED"}'
```
