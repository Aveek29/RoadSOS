import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MapNavigationService {
  /// Launches navigation to the destination coordinates.
  /// Tries Google Maps native scheme first on Android, Google Maps/Apple Maps on iOS,
  /// and falls back to a driving directions web URL.
  static Future<void> launchNavigation({
    required double latitude,
    required double longitude,
  }) async {
    final String googleMapsUrl = 'google.navigation:q=$latitude,$longitude&mode=d';
    final String appleMapsUrl = 'maps://?daddr=$latitude,$longitude';
    final String webFallbackUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';

    debugPrint('[MapNavigation] Launching route to: $latitude, $longitude');

    try {
      if (Platform.isAndroid) {
        final Uri googleUri = Uri.parse(googleMapsUrl);
        if (await canLaunchUrl(googleUri)) {
          await launchUrl(googleUri, mode: LaunchMode.externalNonBrowserApplication);
          return;
        }
      } else if (Platform.isIOS) {
        // Try Google Maps iOS scheme first
        final Uri googleUri = Uri.parse('comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving');
        if (await canLaunchUrl(googleUri)) {
          await launchUrl(googleUri, mode: LaunchMode.externalNonBrowserApplication);
          return;
        }

        // Fallback to Apple Maps native scheme
        final Uri appleUri = Uri.parse(appleMapsUrl);
        if (await canLaunchUrl(appleUri)) {
          await launchUrl(appleUri, mode: LaunchMode.externalNonBrowserApplication);
          return;
        }
      }

      // Final fallback to browser Web directions
      final Uri webUri = Uri.parse(webFallbackUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not resolve web directions link.';
      }
    } catch (e) {
      debugPrint('[MapNavigation] Deep link failed: $e. Falling back to platform browser.');
      final Uri fallbackUri = Uri.parse(webFallbackUrl);
      try {
        await launchUrl(fallbackUri, mode: LaunchMode.platformDefault);
      } catch (innerError) {
        debugPrint('[MapNavigation] Critical browser failure: $innerError');
        rethrow;
      }
    }
  }
}
