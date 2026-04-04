import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../common/api_config.dart';

class CarCareApiService {
  static const List<String> _fallbackBaseUrls = [
    'http://127.0.0.1:8003',
    'http://10.0.2.2:8003',
  ];
  static const Duration _backendTimeout = Duration(seconds: 8);
  static const Duration _liveFallbackTimeout = Duration(seconds: 3);
  static const double _defaultLatitude = 6.9271;
  static const double _defaultLongitude = 79.8612;
  static const String _sourceLabel = 'OpenStreetMap';

  List<String> get _baseUrls {
    final urls = <String>[ApiConfig.carCareBaseUrl, ..._fallbackBaseUrls];
    final unique = <String>[];
    for (final url in urls) {
      if (!unique.contains(url)) {
        unique.add(url);
      }
    }
    return unique;
  }

  Future<List<Map<String, dynamic>>> fetchServices({
    String? search,
    String? category,
    List<String> serviceTypes = const [],
    double? latitude,
    double? longitude,
    double? minRating,
  }) async {
    try {
      final decoded = await _fetchJson(
        '/services',
        search: search,
        category: category,
        serviceTypes: serviceTypes,
        latitude: latitude,
        longitude: longitude,
        minRating: minRating,
      );

      if (decoded is Map<String, dynamic> && decoded['services'] is List) {
        return (decoded['services'] as List)
            .whereType<Map>()
            .map((service) => Map<String, dynamic>.from(service))
            .toList();
      }
    } catch (_) {
      // Fall back to a live public map query when the local backend is unreachable.
    }

    return _fetchLiveFallback(
      search: search,
      category: category,
      serviceTypes: serviceTypes,
      latitude: latitude,
      longitude: longitude,
      minRating: minRating,
      limit: 10,
    );
  }

  Future<List<Map<String, dynamic>>> fetchNearestLocations({
    String? search,
    String? category,
    List<String> serviceTypes = const [],
    double? latitude,
    double? longitude,
    double? minRating,
    int limit = 5,
  }) async {
    var backendLocations = <Map<String, dynamic>>[];

    try {
      final decoded = await _fetchJson(
        '/locations/nearest',
        search: search,
        category: category,
        serviceTypes: serviceTypes,
        latitude: latitude,
        longitude: longitude,
        minRating: minRating,
        limit: limit,
      );

      if (decoded is Map<String, dynamic> && decoded['locations'] is List) {
        backendLocations = (decoded['locations'] as List)
            .whereType<Map>()
            .map((location) => Map<String, dynamic>.from(location))
            .toList();
        if (backendLocations.length >= limit) {
          return backendLocations.take(limit).toList();
        }
      }
    } catch (_) {
      // Fall back to a live public map query when the local backend is unreachable.
    }

    final fallbackLocations = await _fetchLiveFallback(
      search: search,
      category: category,
      serviceTypes: serviceTypes,
      latitude: latitude,
      longitude: longitude,
      minRating: minRating,
      limit: math.max(limit, 10),
    );

    return _mergeLocations(
      primary: backendLocations,
      secondary: fallbackLocations,
      limit: limit,
    );
  }

  Future<dynamic> _fetchJson(
    String path, {
    String? search,
    String? category,
    List<String> serviceTypes = const [],
    double? latitude,
    double? longitude,
    double? minRating,
    int? limit,
  }) async {
    Object? lastError;

    for (final baseUrl in _baseUrls) {
      final uri = _buildBackendUri(
        baseUrl,
        path,
        search: search,
        category: category,
        serviceTypes: serviceTypes,
        latitude: latitude,
        longitude: longitude,
        minRating: minRating,
        limit: limit,
      );

      try {
        final response = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(_backendTimeout);
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
        lastError = 'HTTP ${response.statusCode} from $uri';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(lastError?.toString() ?? 'Car Care API unavailable.');
  }

  Uri _buildBackendUri(
    String baseUrl,
    String path, {
    String? search,
    String? category,
    List<String> serviceTypes = const [],
    double? latitude,
    double? longitude,
    double? minRating,
    int? limit,
  }) {
    final queryParameters = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (category != null && category.isNotEmpty) {
      queryParameters['category'] = category;
    }
    if (serviceTypes.isNotEmpty) {
      queryParameters['service_types'] = serviceTypes.join(',');
    }
    if (latitude != null) {
      queryParameters['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      queryParameters['longitude'] = longitude.toString();
    }
    if (minRating != null) {
      queryParameters['min_rating'] = minRating.toString();
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    return Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLiveFallback({
    String? search,
    String? category,
    List<String> serviceTypes = const [],
    double? latitude,
    double? longitude,
    double? minRating,
    int limit = 5,
  }) async {
    if (minRating != null) {
      return const [];
    }

    final effectiveLatitude = latitude ?? _defaultLatitude;
    final effectiveLongitude = longitude ?? _defaultLongitude;
    final normalizedServiceTypes = _normalizeServiceTypes(serviceTypes);
    final queryTerms = _queryTermsForServiceTypes(category, normalizedServiceTypes);
    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    final effectiveLimit = math.max(limit, 10);

    // Build a viewbox around the user's location (~±0.30 degrees ≈ 33 km)
    const viewboxMargin = 0.30;
    final viewbox =
        '${effectiveLongitude - viewboxMargin},${effectiveLatitude + viewboxMargin},'
        '${effectiveLongitude + viewboxMargin},${effectiveLatitude - viewboxMargin}';

    for (final term in queryTerms) {
      final queryStr = (search != null && search.trim().isNotEmpty)
          ? '${search.trim()} $term'
          : term;

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': queryStr,
        'countrycodes': 'lk',
        'limit': math.max(effectiveLimit * 2, 20).toString(),
        'addressdetails': '1',
        'viewbox': viewbox,
        'bounded': '1',  
      });

      try {
        final response = await http.get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'vehicle-app-car-care/2.0',
        }).timeout(_liveFallbackTimeout);

        if (response.statusCode != 200) {
          continue;
        }

        final decoded = json.decode(response.body);
        if (decoded is! List) {
          continue;
        }

        for (final item in decoded.whereType<Map>()) {
          final raw = Map<String, dynamic>.from(item);
          final id = (raw['osm_id'] ?? '').toString();
          if (id.isEmpty || seenIds.contains(id)) {
            continue;
          }

          final rawLat = (raw['lat'] ?? '').toString();
          final rawLng = (raw['lon'] ?? '').toString();
          final lat = double.tryParse(rawLat);
          final lng = double.tryParse(rawLng);
          if (lat == null || lng == null) {
            continue;
          }

          // Hard distance cap — never show anything more than 30 km away
          final distKm = _haversineKm(effectiveLatitude, effectiveLongitude, lat, lng);
          if (distKm > 30.0) {
            continue;
          }

          final rawName = (raw['name'] ?? '').toString().trim();
          final address = (raw['display_name'] ?? '').toString().trim();
          final name = _buildDisplayName(
            category: category,
            rawName: rawName,
            address: address,
          );
          if (name.isEmpty) {
            continue;
          }

          // Determine the specific shop name to show to the user
          final shopName = (rawName.isNotEmpty && !_isGenericBusinessName(rawName))
              ? rawName
              : null;

          final searchableText = [
            name,
            address,
            (raw['type'] ?? '').toString(),
            (raw['class'] ?? '').toString(),
          ].join(' ');
          final inferredServiceTypes = _inferServiceTypes(
            category,
            searchableText,
            serviceTypes,
          );

          if (normalizedServiceTypes.isNotEmpty) {
            if (inferredServiceTypes.isEmpty ||
                !inferredServiceTypes.any(normalizedServiceTypes.contains)) {
              continue;
            }
          }

          final descriptionParts = [
            (raw['type'] ?? '').toString().replaceAll('_', ' ').trim(),
            (raw['class'] ?? '').toString().replaceAll('_', ' ').trim(),
          ].where((part) => part.isNotEmpty).toList();

          results.add({
            'id': 'nominatim-$id',
            'name': name,
            'shop_name': shopName,
            'address': address,
            'description': descriptionParts
                .map(_toTitleCase)
                .take(2)
                .join(', '),
            'rating': null,
            'distance_km': distKm,
            'latitude': lat,
            'longitude': lng,
            'category': category ?? 'car_wash',
            'service_types': inferredServiceTypes,
            'source': _sourceLabel,
          });
          seenIds.add(id);

          if (results.length >= effectiveLimit * 2) {
            break;
          }
        }
      } catch (_) {
        // Try the next term instead of failing the full request.
      }

      if (results.length >= effectiveLimit * 2) {
        break;
      }
    }

    results.sort((a, b) {
      final distanceA = (a['distance_km'] as num?)?.toDouble() ?? 0;
      final distanceB = (b['distance_km'] as num?)?.toDouble() ?? 0;
      return distanceA.compareTo(distanceB);
    });

    return results.take(effectiveLimit).map(Map<String, dynamic>.from).toList();
  }

  List<Map<String, dynamic>> _mergeLocations({
    required List<Map<String, dynamic>> primary,
    required List<Map<String, dynamic>> secondary,
    required int limit,
  }) {
    final merged = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final location in [...primary, ...secondary]) {
      final key = _locationKey(location);
      if (!seenKeys.add(key)) {
        continue;
      }
      merged.add(Map<String, dynamic>.from(location));
    }

    merged.sort((a, b) {
      final distanceA = (a['distance_km'] as num?)?.toDouble() ?? double.infinity;
      final distanceB = (b['distance_km'] as num?)?.toDouble() ?? double.infinity;
      return distanceA.compareTo(distanceB);
    });

    return merged.take(limit).toList();
  }

  String _locationKey(Map<String, dynamic> location) {
    final id = (location['id'] ?? '').toString();
    if (id.isNotEmpty) {
      return id;
    }

    final name = (location['name'] ?? '').toString().toLowerCase();
    final latitude = ((location['latitude'] as num?)?.toDouble() ?? 0)
        .toStringAsFixed(5);
    final longitude = ((location['longitude'] as num?)?.toDouble() ?? 0)
        .toStringAsFixed(5);
    return '$name|$latitude|$longitude';
  }

  static const Set<String> _genericBusinessNames = {
    'car wash',
    'car spa',
    'auto wash',
    'vehicle wash',
    'car service',
    'car service center',
    'service center',
    'vehicle service',
    'garage',
    'repair shop',
    'tire shop',
  };

  bool _isGenericBusinessName(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) {
      return true;
    }
    return _genericBusinessNames.contains(normalized) ||
        normalized.startsWith('car wash - ') ||
        normalized.startsWith('service center - ');
  }

  String _extractLocalityFromAddress(String address) {
    for (final part in address.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || _isGenericBusinessName(trimmed)) {
        continue;
      }
      if (trimmed.toLowerCase() == 'colombo' ||
          trimmed.toLowerCase() == 'sri lanka') {
        continue;
      }
      return trimmed;
    }
    return '';
  }

  String _buildDisplayName({
    required String? category,
    required String rawName,
    required String address,
  }) {
    if (rawName.isNotEmpty && !_isGenericBusinessName(rawName)) {
      return rawName;
    }

    final locality = _extractLocalityFromAddress(address);
    if (locality.isNotEmpty) {
      final prefix = category == 'service' ? 'Service Center' : 'Car Wash';
      return '$prefix - $locality';
    }

    return rawName;
  }

  List<String> _normalizeServiceTypes(List<String> serviceTypes) {
    final normalized = <String>[];
    for (final serviceType in serviceTypes) {
      final canonical = _normalizeServiceTypeLabel(serviceType);
      if (canonical.isNotEmpty && !normalized.contains(canonical)) {
        normalized.add(canonical);
      }
    }
    return normalized;
  }

  String _normalizeServiceTypeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'basic wash':
        return 'Basic Wash';
      case 'premium wash':
        return 'Premium Wash';
      case 'interior cleaning':
        return 'Interior Cleaning';
      case 'oil change':
        return 'Oil Change';
      case 'engine check':
        return 'Engine Check';
      case 'tire shop':
      case 'tyre shop':
      case 'tire replacement':
      case 'tyre replacement':
        return 'Tire Shop';
      default:
        return value.trim();
    }
  }

  bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }

  List<String> _queryTermsForServiceTypes(
    String? category,
    List<String> serviceTypes,
  ) {
    final normalizedServiceTypes = _normalizeServiceTypes(serviceTypes);

    if (normalizedServiceTypes.isEmpty) {
      if (category == 'service') {
        return const [
          'car repair',
          'car service center',
          'vehicle workshop',
          'engine diagnostics',
          'oil change',
          'tire shop',
        ];
      }
      return const [
        'car wash',
        'car spa',
        'auto detailing',
        'vehicle wash',
      ];
    }

    final terms = <String>[];
    for (final serviceType in normalizedServiceTypes) {
      switch (serviceType) {
        case 'Basic Wash':
          terms.addAll(['car wash', 'auto wash']);
          break;
        case 'Premium Wash':
          terms.addAll(['auto detailing', 'car detailing', 'car spa']);
          break;
        case 'Interior Cleaning':
          terms.addAll([
            'car interior cleaning',
            'interior detailing',
            'car vacuum',
          ]);
          break;
        case 'Oil Change':
          terms.addAll([
            'oil change',
            'engine oil',
            'lubrication service',
            'quick lube',
          ]);
          break;
        case 'Engine Check':
          terms.addAll([
            'engine repair',
            'engine diagnostics',
            'mechanic',
            'car repair',
            'vehicle workshop',
          ]);
          break;
        case 'Tire Shop':
          terms.addAll([
            'tire shop',
            'tyre shop',
            'wheel alignment',
            'wheel balancing',
            'tire replacement',
          ]);
          break;
        default:
          terms.add(serviceType);
          break;
      }
    }

    final uniqueTerms = <String>[];
    for (final term in terms) {
      if (!uniqueTerms.contains(term)) {
        uniqueTerms.add(term);
      }
    }
    return uniqueTerms;
  }

  List<String> _inferServiceTypes(
    String? category,
    String text,
    List<String> selectedTypes,
  ) {
    final normalized = text.toLowerCase();
    final matches = <String>[];
    final normalizedSelectedTypes = _normalizeServiceTypes(selectedTypes);

    if (category == 'service') {
      final oilMatch = _containsAny(normalized, [
        'oil',
        'engine oil',
        'lube',
        'lubrication',
        'oil filter',
        'quick lube',
      ]);
      final engineMatch = _containsAny(normalized, [
        'engine',
        'repair',
        'diagnostic',
        'mechanic',
        'garage',
        'workshop',
        'tune up',
        'tune-up',
        'service center',
        'service centre',
        'car repair',
        'auto repair',
      ]);
      final tireMatch = _containsAny(normalized, [
        'tire',
        'tyre',
        'wheel alignment',
        'wheel balancing',
        'wheel balance',
        'alloy wheel',
        'rim',
        'puncture',
      ]);

      if (oilMatch) {
        matches.add('Oil Change');
      }
      if (engineMatch) {
        matches.add('Engine Check');
      }
      if (tireMatch) {
        matches.add('Tire Shop');
      }

      if (matches.isEmpty &&
          _containsAny(normalized, [
            'service',
            'motor',
            'auto care',
            'service center',
            'service centre',
          ])) {
        matches.add('Engine Check');
      }
    } else {
      final isWashPlace = _containsAny(normalized, [
        'wash',
        'washing',
        'car wash',
        'auto wash',
        'car spa',
      ]);
      final premiumMatch = _containsAny(normalized, [
        'detail',
        'detailing',
        'wax',
        'polish',
        'ceramic',
        'coating',
      ]);
      final interiorMatch = _containsAny(normalized, [
        'interior',
        'vacuum',
        'upholstery',
        'cabin',
        'seat cleaning',
      ]);

      if (isWashPlace) {
        matches.add('Basic Wash');
      }
      if (premiumMatch) {
        matches.add('Premium Wash');
      }
      if (interiorMatch) {
        matches.add('Interior Cleaning');
      }
    }

    final uniqueMatches = <String>[];
    for (final match in matches) {
      if (!uniqueMatches.contains(match)) {
        uniqueMatches.add(match);
      }
    }

    if (category == 'service' && normalizedSelectedTypes.isNotEmpty) {
      return uniqueMatches
          .where(normalizedSelectedTypes.contains)
          .toList(growable: false);
    }

    return uniqueMatches;
  }

  String _toTitleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

