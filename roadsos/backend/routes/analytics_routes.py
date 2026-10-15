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
            return jsonify({
                'activeIncidents': 0,
                'resolvedToday': 0,
                'criticalIncidents': 0,
                'availableHelpers': 0,
                'avgResponseTimeMins': 0,
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
