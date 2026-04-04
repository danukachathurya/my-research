class GarageRecommendation {
  final String name;
  final String address;
  final double rating;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final double? distance;
  final double? mlScore;
  final double? finalScore;

  GarageRecommendation({
    required this.name,
    required this.address,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.distance,
    this.mlScore,
    this.finalScore,
  });

  factory GarageRecommendation.fromJson(Map<String, dynamic> json) {
    return GarageRecommendation(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      phoneNumber: json['phone_number'],
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      mlScore: json['ml_score'] != null ? (json['ml_score'] as num).toDouble() : null,
      finalScore: json['final_score'] != null ? (json['final_score'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'phone_number': phoneNumber,
      'distance': distance,
      'ml_score': mlScore,
      'final_score': finalScore,
    };
  }

  // Helper to format distance for display
  String get formattedDistance {
    if (distance == null) return 'N/A';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distance!.toStringAsFixed(1)} km';
    }
  }

  // Helper to get rating stars
  String get ratingStars {
    return '⭐' * rating.round();
  }
}
