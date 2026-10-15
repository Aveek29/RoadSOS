import logging
from firebase_admin import firestore

logger = logging.getLogger('RoadSoS.Firestore')


class FirestoreService:
    def __init__(self):
        try:
            self.db = firestore.client()
        except ValueError:
            self.db = None
            logger.warning("Firestore client not initialized.")

    def _ensure_db(self):
        """Raises a clear error when Firestore is not connected."""
        if self.db is None:
            try:
                self.db = firestore.client()
            except Exception:
                raise ConnectionError(
                    "Firestore is not initialized. "
                    "Ensure serviceAccountKey.json is configured."
                )

    def get_collection(self, collection_name):
        self._ensure_db()
        return self.db.collection(collection_name)

    def get_document(self, collection_name, doc_id):
        self._ensure_db()
        return self.db.collection(collection_name).document(doc_id).get()

    def update_document(self, collection_name, doc_id, data):
        self._ensure_db()
        data['updatedAt'] = firestore.SERVER_TIMESTAMP
        self.db.collection(collection_name).document(doc_id).update(data)

    def add_document(self, collection_name, data):
        """Creates a new document in the specified collection."""
        self._ensure_db()
        _, doc_ref = self.db.collection(collection_name).add(data)
        return doc_ref.id

    @property
    def is_connected(self):
        if self.db is None:
            try:
                self.db = firestore.client()
            except Exception:
                pass
        return self.db is not None
