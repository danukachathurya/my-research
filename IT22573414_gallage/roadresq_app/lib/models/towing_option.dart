class TowingOption {
  final String towingId;
  final String name;
  final String phone;
  final String city;
  final double distanceKm;
  final double baseFeeKlr;
  final double ratePerKmLkr;
  final double estimatedCostLkr;
  final int avgEtaMinutes;
  final double rating;
  final int numReviews;
  final bool available24h;
  final bool flatbedAvailable;
  final List<String> vehicleTypes;

  const TowingOption({
    required this.towingId,
    required this.name,
    required this.phone,
    required this.city,
    required this.distanceKm,
    required this.baseFeeKlr,
    required this.ratePerKmLkr,
    required this.estimatedCostLkr,
    required this.avgEtaMinutes,
    required this.rating,
    required this.numReviews,
    required this.available24h,
    required this.flatbedAvailable,
    required this.vehicleTypes,
  });

  factory TowingOption.fromJson(Map<String, dynamic> json) {
    return TowingOption(
      towingId: json['towing_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      baseFeeKlr: (json['base_fee_lkr'] as num?)?.toDouble() ?? 0.0,
      ratePerKmLkr: (json['rate_per_km_lkr'] as num?)?.toDouble() ?? 0.0,
      estimatedCostLkr: (json['estimated_cost_lkr'] as num?)?.toDouble() ?? 0.0,
      avgEtaMinutes: (json['avg_eta_minutes'] as num?)?.toInt() ?? 30,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      numReviews: (json['num_reviews'] as num?)?.toInt() ?? 0,
      available24h: json['available_24h'] as bool? ?? false,
      flatbedAvailable: json['flatbed_available'] as bool? ?? false,
      vehicleTypes: (json['vehicle_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'towing_id': towingId,
        'name': name,
        'phone': phone,
        'city': city,
        'distance_km': distanceKm,
        'base_fee_lkr': baseFeeKlr,
        'rate_per_km_lkr': ratePerKmLkr,
        'estimated_cost_lkr': estimatedCostLkr,
        'avg_eta_minutes': avgEtaMinutes,
        'rating': rating,
        'num_reviews': numReviews,
        'available_24h': available24h,
        'flatbed_available': flatbedAvailable,
        'vehicle_types': vehicleTypes,
      };

  /// Formatted cost string e.g. "LKR 2,884"
  String get formattedCost {
    final cost = estimatedCostLkr.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'LKR $cost';
  }

  /// Formatted distance e.g. "3.2 km"
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  /// Rating as star string e.g. "⭐ 4.2"
  String get ratingStars => '⭐ ${rating.toStringAsFixed(1)}';
}
