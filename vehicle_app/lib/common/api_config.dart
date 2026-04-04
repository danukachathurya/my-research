import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _fallbackAssessUrl = 'http://10.0.2.2:8000/assess';
  static const String _fallbackTroubleshootingUrl = 'http://127.0.0.1:8001';
  static const String _fallbackRoadResqUrl = 'http://10.0.2.2:8002';
  static const String _fallbackCarCareUrl = 'http://127.0.0.1:8003';

  static Uri get assessUri =>
      _parseOrFallback(dotenv.env['API_URL'], _fallbackAssessUrl);

  static String get assessUrl => assessUri.toString();

  static Uri get baseUri {
    final segments = List<String>.from(assessUri.pathSegments);
    if (segments.isNotEmpty && segments.last == 'assess') {
      segments.removeLast();
    }
    return assessUri.replace(pathSegments: segments);
  }

  static String get baseUrl => baseUri.toString();

  static Uri get troubleshootingUri => _parseOrFallback(
      dotenv.env['TROUBLESHOOTING_API_URL'], _fallbackTroubleshootingUrl);

  static String get troubleshootingBaseUrl => troubleshootingUri.toString();

  static Uri get roadResqUri =>
      _parseOrFallback(dotenv.env['ROADRESQ_API_URL'], _fallbackRoadResqUrl);

  static String get roadResqBaseUrl => roadResqUri.toString();

  static Uri get carCareUri =>
      _parseOrFallback(dotenv.env['CAR_CARE_API_URL'], _fallbackCarCareUrl);

  static String get carCareBaseUrl => carCareUri.toString();

  static Uri resolve(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(
      pathSegments: [...baseUri.pathSegments, cleanPath],
    );
  }

  static Uri _parseOrFallback(String? raw, String fallback) {
    final parsed = _normalize(raw);
    if (parsed != null) {
      return parsed;
    }
    return Uri.parse(fallback);
  }

  static Uri? _normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = Uri.decodeFull(value).trim();
    value = value.replaceFirst(RegExp(r'^/+'), '');
    if (!value.contains('://')) {
      value = 'http://$value';
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null || parsed.host.isEmpty) {
      return null;
    }

    return parsed.replace(
      pathSegments: parsed.pathSegments.where((s) => s.isNotEmpty).toList(),
    );
  }
}
