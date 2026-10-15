import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

enum IncidentStatus { active, responding, resolved, critical }

class IncidentManager {
  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  Future<String> createIncident(double lat, double lng) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][IncidentManager] Firebase not initialized. Skipping createIncident.');
      return 'mock_incident_id';
    }
    final docRef = await firestore.collection('incidents').add({
      'lat': lat,
      'lng': lng,
      'status': IncidentStatus.active.name,
      'responders': [],
      'timestamp': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateStatus(String incidentId, IncidentStatus status) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][IncidentManager] Firebase not initialized. Skipping updateStatus.');
      return;
    }
    await firestore.collection('incidents').doc(incidentId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> getResponderCount(String incidentId) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][IncidentManager] Firebase not initialized. Skipping getResponderCount.');
      return 0;
    }
    try {
      final doc =
          await firestore.collection('incidents').doc(incidentId).get();
      if (!doc.exists) return 0;
      List<dynamic> responders = doc.data()?['responders'] ?? [];
      return responders.length;
    } catch (e) {
      print('[Error][IncidentManager] getResponderCount failed: $e');
      return 0;
    }
  }

  Future<bool> addResponder(
      String incidentId, String helperUid, int maxResponders) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][IncidentManager] Firebase not initialized. Skipping addResponder.');
      return false;
    }
    final docRef = firestore.collection('incidents').doc(incidentId);

    try {
      // Transaction ensures maxResponders logic safely handles rapid concurrent accepts
      return await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        List<dynamic> responders = snapshot.data()?['responders'] ?? [];

        if (responders.length >= maxResponders) {
          return false; // Reached assignment quota
        }

        if (responders.contains(helperUid)) {
          return true; // Accidental duplicate button press
        }

        responders.add(helperUid);

        // Auto-escalate status when responders join
        final newStatus = responders.length >= maxResponders
            ? IncidentStatus.responding.name
            : IncidentStatus.responding.name;

        transaction.update(docRef, {
          'responders': responders,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('[Error][Firestore] Transaction failed: $e');
      return false;
    }
  }

  /// Escalates an incident to CRITICAL status (e.g., when no responders
  /// arrive within a time limit). Called externally by a timeout mechanism.
  Future<void> escalateToCritical(String incidentId) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][IncidentManager] Firebase not initialized. Skipping escalateToCritical.');
      return;
    }
    try {
      final doc =
          await firestore.collection('incidents').doc(incidentId).get();
      if (!doc.exists) return;

      final status = doc.data()?['status'] ?? '';
      // Only escalate if the incident is still active (no responders yet)
      if (status == IncidentStatus.active.name) {
        await updateStatus(incidentId, IncidentStatus.critical);
        print('[Incident] Escalated $incidentId to CRITICAL — no responders');
      }
    } catch (e) {
      print('[Error][IncidentManager] Escalation failed: $e');
    }
  }
}
