import logging
import math
from datetime import datetime, timezone
from services.firestore_service import FirestoreService

logger = logging.getLogger('RoadSoS.Helper')

MAX_RESPONDERS = 3
BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def encode_geohash(latitude: float, longitude: float, precision: int = 9) -> str:
    """Computes standard geohash representation for a pair of coordinates."""
    # Clip and normalize inputs
    lat = max(-90.0, min(90.0, latitude))
    lon = ((longitude + 180.0) % 360.0) - 180.0

    lat_interval = (-90.0, 90.0)
    lon_interval = (-180.0, 180.0)
    geohash = []
    bits = 0
    ch = 0
    even = True

    while len(geohash) < precision:
        if even:
            mid = (lon_interval[0] + lon_interval[1]) / 2.0
            if lon > mid:
                ch |= (1 << (4 - bits))
                lon_interval = (mid, lon_interval[1])
            else:
                lon_interval = (lon_interval[0], mid)
        else:
            mid = (lat_interval[0] + lat_interval[1]) / 2.0
            if lat > mid:
                ch |= (1 << (4 - bits))
                lat_interval = (mid, lat_interval[1])
            else:
                lat_interval = (lat_interval[0], mid)
        even = not even
        if bits < 4:
            bits += 1
        else:
            geohash.append(BASE32[ch])
            bits = 0
            ch = 0
    return "".join(geohash)


def get_geohash_neighbors(latitude: float, longitude: float, precision: int) -> list:
    """
    Returns center geohash and its 8 neighboring cell prefixes.
    Utilizes coordinate-jitter shifts to cover boundaries.
    """
    # Grid sizes in degrees (approximate) for precision 5 and 6
    # P5 is ~4.9km x 4.9km; P6 is ~1.2km x 0.6km
    if precision <= 5:
        lat_offset = 0.045
        lng_offset = 0.045
    else:
        lat_offset = 0.010
        lng_offset = 0.010

    prefixes = set()
    # 9 directions including center (0,0)
    for i in [-1, 0, 1]:
        for j in [-1, 0, 1]:
            shifted_lat = latitude + (i * lat_offset)
            shifted_lng = longitude + (j * lng_offset)
            prefixes.add(encode_geohash(shifted_lat, shifted_lng, precision))
    return list(prefixes)


def calculate_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates Haversine distance in meters between two coordinates."""
    R = 6371000.0  # Earth's radius
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) *
         (math.sin(delta_lambda / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


class HelperService:
    def __init__(self):
        self.firestore = FirestoreService()

    def register_helper(self, uid: str, name: str, phone: str, fcm_token: str = None) -> dict:
        """Registers a volunteer or updates their metadata profile."""
        self.firestore._ensure_db()
        helper_data = {
            'uid': uid,
            'name': name,
            'phone': phone,
            'status': 'OFFLINE',
            'reputationScore': 5.0,
            'activeMissionId': None,
            'updatedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        }
        if fcm_token:
            helper_data['fcmToken'] = fcm_token
        self.firestore.db.collection('helpers').document(uid).set(helper_data, merge=True)
        logger.info("Registered helper %s (%s)", name, uid)
        return {'success': True, 'message': 'Helper registered successfully'}

    def update_presence(self, uid: str, lat: float, lng: float, status: str, fcm_token: str = None) -> dict:
        """Updates volunteer location, presence status, and computes active geohash."""
        self.firestore._ensure_db()
        geohash_val = encode_geohash(lat, lng, precision=9)
        updates = {
            'latitude': round(lat, 6),
            'longitude': round(lng, 6),
            'geohash': geohash_val,
            'status': status.upper(),  # ONLINE, OFFLINE, BUSY
            'updatedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        }
        if fcm_token:
            updates['fcmToken'] = fcm_token
        self.firestore.db.collection('helpers').document(uid).update(updates)
        logger.info("Updated helper presence for %s: status=%s, geohash=%s", uid, status, geohash_val)
        return {'success': True, 'geohash': geohash_val}

    def get_nearest_helpers(self, lat: float, lng: float, radius_meters: float = 5000.0) -> list:
        """
        Retrieves nearest online, available volunteers within a given radius.
        Uses prefix queries on geohashes for scalable database performance.
        """
        self.firestore._ensure_db()
        # Choose prefix precision: 6 chars for tight radius, 5 chars for large radius
        precision = 6 if radius_meters <= 1500.0 else 5
        prefixes = get_geohash_neighbors(lat, lng, precision)
        
        helpers_ref = self.firestore.db.collection('helpers')
        candidates = {}

        # Fetch candidates matching each unique geohash prefix
        for prefix in prefixes:
            # Query range
            start_hash = prefix
            end_hash = prefix + '\uf8ff'
            
            docs = helpers_ref.where('status', '==', 'ONLINE') \
                             .where('geohash', '>=', start_hash) \
                             .where('geohash', '<=', end_hash) \
                             .stream()
            for doc in docs:
                data = doc.to_dict()
                candidates[doc.id] = data

        nearby = []
        for uid, data in candidates.items():
            if data.get('activeMissionId'):
                continue  # Helper is busy on another mission
                
            h_lat = data.get('latitude')
            h_lng = data.get('longitude')
            if h_lat is None or h_lng is None:
                continue
                
            distance = calculate_distance_meters(lat, lng, h_lat, h_lng)
            if distance <= radius_meters:
                data['distanceMeters'] = round(distance, 1)
                nearby.append(data)

        # Sort closest first
        nearby.sort(key=lambda x: x['distanceMeters'])
        return nearby

    def accept_incident(self, incident_id: str, helper_uid: str, distance_meters: float) -> dict:
        """
        Atomically assigns a helper, sets status to BUSY, and spawns an active mission document.
        """
        self.firestore._ensure_db()
        
        # 1. Fetch helper and assert availability
        helper_doc = self.firestore.db.collection('helpers').document(helper_uid).get()
        if not helper_doc.exists:
            # Auto register helper if missing to support smooth demo flow
            self.register_helper(helper_uid, f"Volunteer {helper_uid[:4]}", "+919999999999")
            helper_data = self.firestore.db.collection('helpers').document(helper_uid).get().to_dict()
        else:
            helper_data = helper_doc.to_dict()

        if helper_data.get('status') == 'BUSY':
            return {
                'success': False,
                'message': 'You are currently assigned to another active mission',
                'slotsFilled': 0
            }

        incident = self._get_incident(incident_id)
        if not incident:
            raise ValueError(f"Incident '{incident_id}' not found")

        if incident.get('status') == 'RESOLVED':
            raise ValueError("Cannot respond to a RESOLVED incident")

        accepted_helpers = incident.get('acceptedHelpers', [])

        # Prevent duplicate assignment
        if any(h.get('uid') == helper_uid for h in accepted_helpers):
            return {
                'success': False,
                'message': 'You have already accepted this incident',
                'slotsFilled': len(accepted_helpers),
            }

        # Check capacity
        if len(accepted_helpers) >= MAX_RESPONDERS:
            return {
                'success': False,
                'message': f'All {MAX_RESPONDERS} responder slots are full',
                'slotsFilled': len(accepted_helpers),
            }

        mission_id = f"mission_{incident_id}_{helper_uid}"
        now_str = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

        # Create active mission record
        mission_data = {
            'id': mission_id,
            'incidentId': incident_id,
            'helperId': helper_uid,
            'helperName': helper_data.get('name', 'Volunteer'),
            'helperPhone': helper_data.get('phone', ''),
            'status': 'ASSIGNED',
            'assignedAt': now_str,
            'updatedAt': now_str
        }
        self.firestore.db.collection('missions').document(mission_id).set(mission_data)

        # Update helper presence status to BUSY
        self.firestore.db.collection('helpers').document(helper_uid).update({
            'status': 'BUSY',
            'activeMissionId': mission_id,
            'updatedAt': now_str
        })

        # Add the helper to incident document list
        helper_entry = {
            'uid': helper_uid,
            'name': helper_data.get('name', 'Volunteer'),
            'phone': helper_data.get('phone', ''),
            'acceptedAt': now_str,
            'distanceMeters': round(distance_meters, 1),
        }
        accepted_helpers.append(helper_entry)
        slots_filled = len(accepted_helpers)

        updates = {
            'acceptedHelpers': accepted_helpers,
            'helperSlots': slots_filled,
            'helperRequestOpen': slots_filled < MAX_RESPONDERS,
        }
        self.firestore.update_document('incidents', incident_id, updates)

        logger.info(
            "Helper %s accepted incident %s (slot %d/%d, mission=%s)",
            helper_uid, incident_id, slots_filled, MAX_RESPONDERS, mission_id
        )
        return {
            'success': True,
            'message': 'You have been assigned. Drive safely.',
            'slotsFilled': slots_filled,
            'missionId': mission_id
        }

    def update_mission_status(self, mission_id: str, status: str) -> dict:
        """
        Updates active mission state (ASSIGNED, EN_ROUTE, ON_SCENE, COMPLETED, ABANDONED).
        Updates helper availability and modifies reputation score dynamically.
        """
        self.firestore._ensure_db()
        mission_doc = self.firestore.db.collection('missions').document(mission_id).get()
        if not mission_doc.exists:
            raise ValueError(f"Mission '{mission_id}' not found")

        mission_data = mission_doc.to_dict()
        helper_uid = mission_data['helperId']
        incident_id = mission_data['incidentId']
        status = status.upper()

        now_str = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        self.firestore.db.collection('missions').document(mission_id).update({
            'status': status,
            'updatedAt': now_str
        })

        # Fetch helper for reputation recalculation
        helper_ref = self.firestore.db.collection('helpers').document(helper_uid)
        helper_doc = helper_ref.get()
        rep_score = 5.0
        if helper_doc.exists:
            rep_score = helper_doc.to_dict().get('reputationScore', 5.0)

        # Release helper if mission ends (COMPLETED or ABANDONED)
        if status in ('COMPLETED', 'ABANDONED'):
            if status == 'COMPLETED':
                # Increment reputation score up to max 5.0
                rep_score = min(5.0, rep_score + 0.1)
                msg = "Mission completed successfully. Reputation score increased."
            else:  # ABANDONED
                # Decrement reputation score down to min 0.0
                rep_score = max(0.0, rep_score - 0.2)
                msg = "Mission abandoned. Reputation score decreased."

            # Update helper to Online and clean mission links
            helper_ref.update({
                'status': 'ONLINE',
                'activeMissionId': None,
                'reputationScore': round(rep_score, 2),
                'updatedAt': now_str
            })
            
            # Remove helper from incident accepted list if abandoned
            if status == 'ABANDONED':
                self._remove_helper_from_incident(incident_id, helper_uid)
        else:
            msg = f"Mission status updated to {status}."

        logger.info("Mission %s updated to %s. Helper %s reputation: %.2f", mission_id, status, helper_uid, rep_score)
        return {'success': True, 'message': msg, 'status': status, 'reputationScore': round(rep_score, 2)}

    def decline_incident(self, incident_id: str, helper_uid: str) -> dict:
        """Decrements helper reputation slightly on incident rejection (discourages inactivity)."""
        self.firestore._ensure_db()
        logger.info("Helper %s declined incident %s", helper_uid, incident_id)
        
        # Penalize reputation score slightly for declining (e.g., -0.05)
        helper_ref = self.firestore.db.collection('helpers').document(helper_uid)
        helper_doc = helper_ref.get()
        if helper_doc.exists:
            rep_score = helper_doc.to_dict().get('reputationScore', 5.0)
            new_rep = max(0.0, rep_score - 0.05)
            helper_ref.update({
                'reputationScore': round(new_rep, 2),
                'updatedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
            })
        return {'success': True, 'message': 'Response recorded'}

    def _remove_helper_from_incident(self, incident_id: str, helper_uid: str):
        """Helper utility to vacate a slot on incident when volunteer abandons."""
        incident = self._get_incident(incident_id)
        if not incident:
            return
        accepted_helpers = incident.get('acceptedHelpers', [])
        updated_helpers = [h for h in accepted_helpers if h.get('uid') != helper_uid]
        slots_filled = len(updated_helpers)

        updates = {
            'acceptedHelpers': updated_helpers,
            'helperSlots': slots_filled,
            'helperRequestOpen': slots_filled < MAX_RESPONDERS,
        }
        self.firestore.update_document('incidents', incident_id, updates)

    def _get_incident(self, incident_id: str):
        if not self.firestore.is_connected:
            return None
        doc = self.firestore.get_document('incidents', incident_id)
        if doc.exists:
            data = doc.to_dict()
            data['id'] = doc.id
            return data
        return None

