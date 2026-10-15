import 'package:url_launcher/url_launcher.dart';

class SMSService {
  /// Sends emergency SMS to a list of contacts using the sms: URI scheme.
  /// Optionally includes accident confidence score in the message body.
  Future<void> sendEmergencySMS({
    required List<String> contacts,
    required double latitude,
    required double longitude,
    double? confidenceScore,
    int maxRetries = 2,
  }) async {
    final confidenceStr = confidenceScore != null
        ? '\nConfidence: ${(confidenceScore * 100).toInt()}%'
        : '';

    String message =
        '🚨 Accident detected!$confidenceStr\nLocation: https://maps.google.com/?q=$latitude,$longitude';

    for (String contact in contacts) {
      bool sent = await _attemptSendWithRetry(contact, message, maxRetries);
      if (sent) {
        print('[SMS] SMS intent launched for $contact');
      } else {
        print(
            '[Error][SMS] Failed to launch SMS intent for $contact after $maxRetries retries');
      }
    }
  }

  Future<bool> _attemptSendWithRetry(
      String contact, String message, int maxRetries) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final encodedMsg = Uri.encodeComponent(message);
        final uri = Uri.parse('sms:$contact?body=$encodedMsg');

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return true;
        } else {
          print('[Error][SMS] Cannot launch SMS URI for $contact');
          return false;
        }
      } catch (e) {
        print('[Error][SMS] Attempt ${attempt + 1} failed for $contact: $e');
        if (attempt == maxRetries) return false;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }
}
