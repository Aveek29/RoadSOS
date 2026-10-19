import logging
from datetime import datetime, timezone
from flask import Blueprint, jsonify
from services.firestore_service import FirestoreService

logger = logging.getLogger('RoadSoS.Analytics')

analytics_bp = Blueprint('analytics_bp', __name__)
_fs = FirestoreService()


@analytics_bp.route('/analytics', methods=['GET'])
def get_analytics():
    """
    Returns aggregated metrics for the dashboard analytics bar.

    Response:
        {
            "activeIncidents": 3,
            "resolvedToday": 7,
            "criticalIncidents": 1,
            "availableHelpers": 12,
            "avgResponseTimeMins": 4.2
        }
    """
    logger.info("GET /analytics")
    try:
        if not _fs.is_connected:
            # Offline mode: aggregate from the memory store so the dashboard
            # analytics bar reflects the real state of live demo/incident data.
            from services.memory_store import MemoryStore
            store = MemoryStore()
            all_incidents = store.all_incidents()

            active = [i for i in all_incidents if i.get('status') != 'RESOLVED']
            resolved = [i for i in all_incidents if i.get('status') == 'RESOLVED']

            today_start = datetime.now(timezone.utc).replace(
                hour=0, minute=0, second=0, microsecond=0
            )
            resolved_today = 0
            response_times = []
            for data in resolved:
                updated = data.get('updatedAt', data.get('timestamp', ''))
                try:
                    updated_dt = datetime.fromisoformat(str(updated).replace('Z', '+00:00'))
                    if updated_dt.tzinfo is None:
                        updated_dt = updated_dt.replace(tzinfo=timezone.utc)
                    if updated_dt >= today_start:
                        resolved_today += 1
                except (ValueError, TypeError):
                    pass

                created = data.get('timestamp')
                dispatched = data.get('dispatchedResources', [])
                if created and dispatched:
                    try:
                        first_dispatch = datetime.fromisoformat(
                            dispatched[0].get('dispatchedAt', '').replace('Z', '+00:00')
                        )
                        created_dt = datetime.fromisoformat(
                            str(created).replace('Z', '+00:00')
                        )
                        delta = (first_dispatch - created_dt).total_seconds() / 60.0
                        if 0 < delta < 120:
                            response_times.append(delta)
                    except (ValueError, TypeError):
                        pass

            avg_response = round(
                sum(response_times) / len(response_times), 1
            ) if response_times else 0.0
            available_helpers = sum(
                1 for h in store.all_helpers() if h.get('status') == 'ONLINE'
            )

            return jsonify({
                'activeIncidents': len(active),
                'resolvedToday': resolved_today,
                'criticalIncidents': sum(1 for i in active if i.get('severity') == 'CRITICAL'),
                'availableHelpers': available_helpers,
                'avgResponseTimeMins': avg_response,
            }), 200

        db = _fs.db
        incidents_ref = db.collection('incidents')

        # Active incidents (not resolved)
        active_docs = list(
            incidents_ref.where('status', '!=', 'RESOLVED').stream()
        )
        active_count = len(active_docs)

        # Critical incidents
        critical_count = sum(
            1 for d in active_docs
            if d.to_dict().get('severity') == 'CRITICAL'
        )

        # Resolved today
        today_start = datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        resolved_docs = list(
            incidents_ref
            .where('status', '==', 'RESOLVED')
            .where('updatedAt', '>=', today_start)
            .stream()
        )
        resolved_today = len(resolved_docs)

        # Average response time (minutes): time from timestamp to first dispatch
        response_times = []
        for doc in resolved_docs:
            data = doc.to_dict()
            created = data.get('timestamp')
            dispatched = data.get('dispatchedResources', [])
            if created and dispatched:
                try:
                    first_dispatch_str = dispatched[0].get('dispatchedAt', '')
                    first_dispatch = datetime.fromisoformat(
                        first_dispatch_str.replace('Z', '+00:00')
                    )
                    delta = (first_dispatch - created).total_seconds() / 60.0
                    if 0 < delta < 120:  # sanity check: within 2 hours
                        response_times.append(delta)
                except Exception:
                    pass

        avg_response = round(
            sum(response_times) / len(response_times), 1
        ) if response_times else 0.0

        return jsonify({
            'activeIncidents': active_count,
            'resolvedToday': resolved_today,
            'criticalIncidents': critical_count,
            'availableHelpers': 0,   # Requires a separate helpers registry in future
            'avgResponseTimeMins': avg_response,
        }), 200

    except Exception as e:
        logger.exception("GET /analytics failed")
        return jsonify({'error': str(e)}), 500
