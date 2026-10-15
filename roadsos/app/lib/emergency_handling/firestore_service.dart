import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreService {
  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Maximum number of retry attempts for transient failures
  final int maxRetries;

  FirestoreService({this.maxRetries = 2});

  /// Stores incident metadata in Firebase and returns the document ID.
  /// Retries on transient failures with exponential backoff.
  Future<String?> storeIncident({
    required double latitude,
    required double longitude,
    double? confidenceScore,
    String? severity,
    double? severityScore,
    String? plusCode,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][Firestore] Firebase not initialized. Skipping Firestore write.');
      return null;
    }
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final docRef = await firestore.collection('incidents').add({
          'latitude': latitude,
          'longitude': longitude,
          'victimLat': latitude,
          'victimLng': longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'ACTIVE',
          'source': 'mobile',
          'trackingActive': true,
          'acceptedHelpers': [],
          'helperSlots': 0,
          'helperRequestOpen': true,
          'dispatchedResources': [],
          if (confidenceScore != null) 'confidence': confidenceScore,
          if (severity != null) 'severity': severity,
          if (severityScore != null) 'severityScore': severityScore,
          if (plusCode != null) 'plusCode': plusCode,
        });
        print('[Firestore] Incident stored (ID: ${docRef.id})');
        return docRef.id;
      } catch (e) {
        print(
            '[Error][Firestore] Write attempt ${attempt + 1}/${maxRetries + 1} failed: $e');
        if (attempt < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s...
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    print('[Error][Firestore] All write attempts exhausted');
    return null;
  }

  /// Updates the victim's live GPS coordinates on the incident document.
  Future<void> updateVictimLocation({
    required String incidentId,
    required double latitude,
    required double longitude,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('[Warning][Firestore] Firebase not initialized. Skipping updateVictimLocation.');
      return;
    }
    try {
      await firestore.collection('incidents').doc(incidentId).update({
        'victimLat': latitude,
        'victimLng': longitude,
        'trackingActive': true,
      });
    } catch (e) {
      print('[Error][Firestore] updateVictimLocation failed: $e');
    }
  }
}
