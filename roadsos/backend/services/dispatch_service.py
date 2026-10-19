import logging
from services.incident_service import IncidentService
from datetime import datetime, timezone

logger = logging.getLogger('RoadSoS.Dispatch')


class DispatchService:
    def __init__(self):
        self.incident_service = IncidentService()

    def dispatch_responder(self, incident_id, dispatch_type):
        valid_types = ['ambulance', 'police', 'helper']
        if dispatch_type not in valid_types:
            raise ValueError(f"Invalid dispatch type '{dispatch_type}'. Must be one of: {valid_types}")

        incident = self.incident_service.get_incident(incident_id)
        if not incident:
            raise ValueError(f"Incident '{incident_id}' not found")

        # Prevent dispatching to resolved incidents
        if incident.get('status') == 'RESOLVED':
            raise ValueError("Cannot dispatch to a RESOLVED incident")

        # Duplicate dispatch guard: check if the same type was dispatched
        # within the last 60 seconds
        dispatched_resources = incident.get('dispatchedResources', [])
        now = datetime.now(timezone.utc)

        for existing in dispatched_resources:
            if existing.get('type') == dispatch_type:
                dispatched_at_str = existing.get('dispatchedAt', '')
                try:
                    dispatched_at = datetime.fromisoformat(
                        dispatched_at_str.replace('Z', '+00:00')
                    )
                except (ValueError, TypeError):
                    # Unparseable timestamp: allow the dispatch rather than
                    # blocking responders. (Note: the duplicate rejection must
                    # live outside this try, or it would be swallowed here.)
                    continue
                elapsed = (now - dispatched_at).total_seconds()
                if elapsed < 60:
                    raise ValueError(
                        f"A {dispatch_type} was already dispatched "
                        f"{int(elapsed)}s ago. "
                        f"Wait before dispatching again."
                    )

        # Prepare update payload
        updates = {
            'status': 'RESPONDING'
        }

        dispatch_log = {
            'type': dispatch_type,
            'dispatchedAt': now.isoformat().replace('+00:00', 'Z'),
        }

        dispatched_resources.append(dispatch_log)
        updates['dispatchedResources'] = dispatched_resources

        self.incident_service.update_fields(incident_id, updates)

        logger.info("%s dispatched to incident %s", dispatch_type.capitalize(), incident_id)
        return True
