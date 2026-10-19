"""Bounded, thread-safe in-memory store for incidents, helpers and missions.

This is the offline database: when Firestore is not configured/connected the
whole command-centre flow (SOS create -> dispatch -> live tracking -> status
transitions -> resolve, plus the volunteer network) operates on this store so
the product works end-to-end in demo mode. When Firestore is connected it
remains the single source of truth and this store is not used.

Everything is process-local and bounded, so memory stays flat no matter how
long the server runs.
"""
import logging
import threading
from collections import OrderedDict

logger = logging.getLogger('RoadSoS.MemoryStore')

# Bounds keep memory flat under sustained load (oldest entries are evicted).
MAX_INCIDENTS = 500
MAX_HELPERS = 1000
MAX_MISSIONS = 1000


class MemoryStore:
    """Process-wide singleton holding offline incidents/helpers/missions."""

    _instance = None
    _instance_lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._instance_lock:
                if cls._instance is None:
                    inst = super().__new__(cls)
                    inst._incidents = OrderedDict()
                    inst._helpers = OrderedDict()
                    inst._missions = OrderedDict()
                    inst._lock = threading.Lock()
                    cls._instance = inst
        return cls._instance

    # -- generic bounded helpers -------------------------------------------
    @staticmethod
    def _bounded_put(store: "OrderedDict", key, data, limit: int):
        store[key] = data
        while len(store) > limit:
            store.popitem(last=False)

    # -- incidents ----------------------------------------------------------
    def put_incident(self, incident_id, data):
        with self._lock:
            self._bounded_put(self._incidents, incident_id, data, MAX_INCIDENTS)
        return incident_id

    def get_incident(self, incident_id):
        with self._lock:
            data = self._incidents.get(incident_id)
            return dict(data) if data is not None else None

    def update_incident(self, incident_id, fields) -> bool:
        with self._lock:
            data = self._incidents.get(incident_id)
            if data is None:
                return False
            data.update(fields)
            return True

    def list_incidents(self, status_filter=None, limit=50):
        with self._lock:
            items = [dict(v) | {'id': k} for k, v in self._incidents.items()]
        # Newest first (timestamp is an ISO string, sorts correctly).
        items.sort(key=lambda d: str(d.get('timestamp', '')), reverse=True)
        if status_filter:
            items = [d for d in items if d.get('status') == status_filter]
        else:
            items = [d for d in items if d.get('status') != 'RESOLVED']
        return items[:limit]

    def all_incidents(self):
        with self._lock:
            return [dict(v) | {'id': k} for k, v in self._incidents.items()]

    def clear_demo_incidents(self):
        """Removes demo incidents, returning the removed ids for broadcasting."""
        with self._lock:
            ids = [k for k, v in self._incidents.items() if v.get('isDemo')]
            for k in ids:
                del self._incidents[k]
        return ids

    # -- helpers (volunteers) ----------------------------------------------
    def put_helper(self, uid, data):
        with self._lock:
            self._bounded_put(self._helpers, uid, data, MAX_HELPERS)
        return uid

    def get_helper(self, uid):
        with self._lock:
            data = self._helpers.get(uid)
            return dict(data) if data is not None else None

    def update_helper(self, uid, fields) -> bool:
        with self._lock:
            data = self._helpers.get(uid)
            if data is None:
                return False
            data.update(fields)
            return True

    def all_helpers(self):
        with self._lock:
            return [dict(v) for v in self._helpers.values()]

    # -- missions -----------------------------------------------------------
    def put_mission(self, mission_id, data):
        with self._lock:
            self._bounded_put(self._missions, mission_id, data, MAX_MISSIONS)
        return mission_id

    def get_mission(self, mission_id):
        with self._lock:
            data = self._missions.get(mission_id)
            return dict(data) if data is not None else None

    def update_mission(self, mission_id, fields) -> bool:
        with self._lock:
            data = self._missions.get(mission_id)
            if data is None:
                return False
            data.update(fields)
            return True
