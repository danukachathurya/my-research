Map<String, dynamic> jsonAsMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> jsonAsStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

Map<String, double> jsonAsDoubleMap(dynamic value) {
  final map = jsonAsMap(value);
  return map.map(
    (key, item) => MapEntry(
      key,
      item is num ? item.toDouble() : double.tryParse(item.toString()) ?? 0.0,
    ),
  );
}

double jsonToDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int jsonToInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? jsonNullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}
