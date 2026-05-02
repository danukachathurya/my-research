import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'api_config.dart';

class InsuranceClaimService {
  String get _assessUrl => ApiConfig.assessUrl;

  Uri _notifyUri(String claimId) {
    final uri = Uri.parse(_assessUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri.replace(
      pathSegments: [...baseSegments, 'claims', claimId, 'notify'],
    );
  }

  Uri _insurersUri() {
    final uri = Uri.parse(_assessUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri.replace(pathSegments: [...baseSegments, 'insurers']);
  }

  Uri _claimUri(String claimId) {
    final uri = Uri.parse(_assessUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri.replace(pathSegments: [...baseSegments, 'claims', claimId]);
  }

  String insurerDisplayName(Map<String, dynamic> insurer) {
    return (insurer['name'] ??
            insurer['company_name'] ??
            insurer['display_name'] ??
            insurer['companyName'] ??
            insurer['id'] ??
            '')
        .toString()
        .trim();
  }

  String? findInsurerIdByCompanyName(
    String? companyName,
    List<Map<String, dynamic>> insurers,
  ) {
    final needle = companyName?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) {
      return null;
    }

    for (final insurer in insurers) {
      if (insurerDisplayName(insurer).toLowerCase() == needle) {
        final id = insurer['id']?.toString().trim();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchInsurers() async {
    final response = await http.get(_insurersUri());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load insurers: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid insurers response format');
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['id'] != null && item['id'].toString().isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> fetchClaim(String claimId) async {
    final response = await http.get(_claimUri(claimId));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load claim: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid claim response format');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> fetchInsurersFromFirestore() async {
    final docs = await FirebaseFirestore.instance
        .collection('insurer_partners')
        .get();

    return docs.docs
        .map((doc) {
          final data = doc.data();
          final id = (data['insurerId'] ?? doc.id).toString().trim();
          final name = (data['companyName'] ?? '').toString().trim();
          if (id.isEmpty || name.isEmpty) {
            return null;
          }
          return <String, dynamic>{'id': id, 'name': name};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadInsurers() async {
    List<Map<String, dynamic>> insurers = [];
    try {
      insurers = await fetchInsurers();
    } catch (_) {
      // Fallback to Firestore below.
    }

    if (insurers.isNotEmpty) {
      return insurers;
    }

    try {
      return await fetchInsurersFromFirestore();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<String?> resolveCurrentUserInsurerId(
    List<Map<String, dynamic>> insurers,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = profile.data() ?? <String, dynamic>{};
      final assigned = data['assignedInsurerId']?.toString().trim();
      if (assigned != null && assigned.isNotEmpty) {
        return assigned;
      }

      final company = data['insurerCompanyName']?.toString().trim();
      return findInsurerIdByCompanyName(company, insurers);
    } catch (_) {
      return null;
    }
  }

  Future<void> notifyInsurer({
    required String claimId,
    required String insurerId,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? damageImage,
  }) async {
    final body = <String, dynamic>{'insurer_id': insurerId};
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }
    if (damageImage != null && damageImage.isNotEmpty) {
      body['damage_image'] = damageImage;
    }

    final response = await http.post(
      _notifyUri(claimId),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    var message = 'Notify failed: ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        message = '$message - ${decoded['detail']}';
      }
    } catch (_) {
      if (response.body.trim().isNotEmpty) {
        message = '$message - ${response.body.trim()}';
      }
    }
    throw Exception(message);
  }

  Future<Map<String, dynamic>?> buildDamageImagePayload(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }

      var normalized = img.bakeOrientation(decoded);
      const maxDimension = 960;
      if (normalized.width > maxDimension || normalized.height > maxDimension) {
        if (normalized.width >= normalized.height) {
          normalized = img.copyResize(
            normalized,
            width: maxDimension,
            interpolation: img.Interpolation.average,
          );
        } else {
          normalized = img.copyResize(
            normalized,
            height: maxDimension,
            interpolation: img.Interpolation.average,
          );
        }
      }

      var quality = 72;
      List<int> encoded = img.encodeJpg(normalized, quality: quality);
      while (encoded.length > 180000 && quality > 48) {
        quality -= 12;
        encoded = img.encodeJpg(normalized, quality: quality);
      }

      final filename = imageFile.uri.pathSegments.isNotEmpty
          ? imageFile.uri.pathSegments.last
          : 'damage_image.jpg';

      return <String, dynamic>{
        'filename': filename,
        'content_type': 'image/jpeg',
        'data_base64': base64Encode(encoded),
        'width': normalized.width,
        'height': normalized.height,
      };
    } catch (_) {
      return null;
    }
  }
}
