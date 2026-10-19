import logging
from services.firestore_service import FirestoreService
from services.memory_store import MemoryStore

logger = logging.getLogger('RoadSoS.Incident')

# Valid status transitions: current_status -> set of allowed next statuses
VALID_TRANSITIONS = {
    'ACTIVE': {'RESPONDING', 'RESOLVED', 'CRITICAL'},
    'RESPONDING': {'RESOLVED'},
    'CRITICAL': {'RESPONDING', 'RESOLVED'},
    'RESOLVED': set(),  # Terminal — no further transitions allowed
}


class IncidentService:
    def __init__(self):
        self.firestore = FirestoreService()
        self.collection = 'incidents'

    def get_incidents(self, status_filter=None, limit=50):
        logger.info("Fetching incidents (filter=%s, limit=%d)", status_filter, limit)
        incidents = []

        if not self.firestore.is_connected:
            # Offline mode: serve from the in-memory store so the full
            # command-centre flow keeps working without Firestore.
            incidents = MemoryStore().list_incidents(status_filter, limit)
            logger.info("Firestore not connected - served %d incidents from memory", len(incidents))
            return incidents

        query = self.firestore.get_collection(self.collection)

        # Filter + Pagination
        if status_filter:
            query = query.where('status', '==', status_filter)
        else:
            query = query.where('status', '!=', 'RESOLVED')

        # Sort by timestamp descending (most recent first)
        query = query.order_by('timestamp', direction='DESCENDING')
        docs = query.limit(limit).stream()

        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            if 'timestamp' in data and data['timestamp']:
                data['timestamp'] = str(data['timestamp'])
            if 'updatedAt' in data and data['updatedAt']:
                data['updatedAt'] = str(data['updatedAt'])
            incidents.append(data)

        logger.info("Fetched %d incidents", len(incidents))
        return incidents

    def get_incident(self, incident_id):
        if not self.firestore.is_connected:
            return MemoryStore().get_incident(incident_id)

        doc = self.firestore.get_document(self.collection, incident_id)
        if doc.exists:
            data = doc.to_dict()
            data['id'] = doc.id
            if 'timestamp' in data and data['timestamp']:
                data['timestamp'] = str(data['timestamp'])
            if 'updatedAt' in data and data['updatedAt']:
                data['updatedAt'] = str(data['updatedAt'])
            return data
        return None

    def update_fields(self, incident_id, updates):
        """Persists field updates for an incident (dispatch, tracking, ...).

        Writes to Firestore when connected, otherwise to the in-memory store.
        Raises ValueError when the incident is unknown offline.
        """
        if not self.firestore.is_connected:
            if not MemoryStore().update_incident(incident_id, updates):
                raise ValueError(f"Incident '{incident_id}' not found")
            return
        self.firestore.update_document(self.collection, incident_id, updates)

    def update_status(self, incident_id, new_status):
        valid_statuses = list(VALID_TRANSITIONS.keys())
        if new_status not in valid_statuses:
            raise ValueError(f"Invalid status '{new_status}'. Must be one of: {valid_statuses}")

        # Validate transition from current status
        incident = self.get_incident(incident_id)
        if not incident:
            raise ValueError(f"Incident '{incident_id}' not found")

        current_status = incident.get('status', 'ACTIVE')
        allowed = VALID_TRANSITIONS.get(current_status, set())

        if new_status not in allowed:
            raise ValueError(
                f"Invalid transition: {current_status} → {new_status}. "
                f"Allowed transitions: {allowed or 'none (terminal state)'}"
            )

        self.update_fields(incident_id, {'status': new_status})
        logger.info("Status updated: %s → %s (%s)", incident_id, new_status, current_status)
