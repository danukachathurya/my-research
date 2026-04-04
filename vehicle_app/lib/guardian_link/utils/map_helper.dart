import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class MapHelper {
  /// Opens the device's default maps application with the given coordinates
  /// On Android: Opens Google Maps
  /// On iOS: Opens Apple Maps
  /// On other platforms: Opens Google Maps in browser
  static Future<void> openMapsNavigation(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    Uri uri;

    if (Platform.isAndroid) {
      // Google Maps for Android
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    } else if (Platform.isIOS) {
      // Apple Maps for iOS
      uri = Uri.parse('https://maps.apple.com/?q=$latitude,$longitude');
    } else {
      // Fallback to Google Maps web for other platforms
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps application');
    }
  }

  /// Opens Google Maps with directions from current location to the given coordinates
  static Future<void> openMapsDirections(
    double latitude,
    double longitude, {
    String? destinationLabel,
  }) async {
    Uri uri;

    if (Platform.isAndroid) {
      // Google Maps directions for Android
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    } else if (Platform.isIOS) {
      // Apple Maps directions for iOS
      uri = Uri.parse(
        'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d',
      );
    } else {
      // Fallback to Google Maps web
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps application');
    }
  }

  /// Opens maps with a specific location marker (view only, no navigation)
  static Future<void> openMapsLocation(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    Uri uri;

    if (Platform.isAndroid || Platform.isIOS) {
      // Use geo: URI scheme for better app integration
      uri = Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude${label != null ? '($label)' : ''}',
      );

      // Fallback to web URLs if geo: scheme doesn't work
      if (!await canLaunchUrl(uri)) {
        if (Platform.isAndroid) {
          uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
          );
        } else {
          uri = Uri.parse('https://maps.apple.com/?q=$latitude,$longitude');
        }
      }
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps application');
    }
  }
}
