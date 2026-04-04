class SparePartBid {
  final String vendorId;
  final String vendorName;
  final String phone;
  final String city;
  final double priceLkr;
  final int leadTimeDays;
  final int warrantyMonths;
  final double rating;

  const SparePartBid({
    required this.vendorId,
    required this.vendorName,
    required this.phone,
    required this.city,
    required this.priceLkr,
    required this.leadTimeDays,
    required this.warrantyMonths,
    required this.rating,
  });

  factory SparePartBid.fromJson(Map<String, dynamic> json) {
    return SparePartBid(
      vendorId: json['vendor_id'] as String? ?? '',
      vendorName: json['vendor_name'] as String? ?? 'Unknown Vendor',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      priceLkr: (json['price_lkr'] as num?)?.toDouble() ?? 0.0,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 1,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'phone': phone,
        'city': city,
        'price_lkr': priceLkr,
        'lead_time_days': leadTimeDays,
        'warranty_months': warrantyMonths,
        'rating': rating,
      };

  /// Formatted price e.g. "LKR 84,500"
  String get formattedPrice {
    final p = priceLkr.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'LKR $p';
  }
}

class PartWithBids {
  final String partName;
  final List<SparePartBid> bids;
  final double lowestBidLkr;
  final double highestBidLkr;

  const PartWithBids({
    required this.partName,
    required this.bids,
    required this.lowestBidLkr,
    required this.highestBidLkr,
  });

  factory PartWithBids.fromJson(Map<String, dynamic> json) {
    return PartWithBids(
      partName: json['part_name'] as String? ?? 'Unknown Part',
      bids: (json['bids'] as List<dynamic>?)
              ?.map((b) => SparePartBid.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      lowestBidLkr: (json['lowest_bid_lkr'] as num?)?.toDouble() ?? 0.0,
      highestBidLkr: (json['highest_bid_lkr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'part_name': partName,
        'bids': bids.map((b) => b.toJson()).toList(),
        'lowest_bid_lkr': lowestBidLkr,
        'highest_bid_lkr': highestBidLkr,
      };

  /// Formatted price range e.g. "LKR 84,500 – LKR 97,700"
  String get formattedPriceRange {
    String fmt(double v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'LKR ${fmt(lowestBidLkr)} – LKR ${fmt(highestBidLkr)}';
  }
}

class SparePartsBidsResult {
  final String damageType;
  final String vehicleInfo;
  final List<PartWithBids> partsNeeded;
  final double totalMinCostLkr;
  final double totalMaxCostLkr;

  const SparePartsBidsResult({
    required this.damageType,
    required this.vehicleInfo,
    required this.partsNeeded,
    required this.totalMinCostLkr,
    required this.totalMaxCostLkr,
  });

  factory SparePartsBidsResult.fromJson(Map<String, dynamic> json) {
    return SparePartsBidsResult(
      damageType: json['damage_type'] as String? ?? '',
      vehicleInfo: json['vehicle_info'] as String? ?? '',
      partsNeeded: (json['parts_needed'] as List<dynamic>?)
              ?.map((p) => PartWithBids.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      totalMinCostLkr: (json['total_min_cost_lkr'] as num?)?.toDouble() ?? 0.0,
      totalMaxCostLkr: (json['total_max_cost_lkr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'damage_type': damageType,
        'vehicle_info': vehicleInfo,
        'parts_needed': partsNeeded.map((p) => p.toJson()).toList(),
        'total_min_cost_lkr': totalMinCostLkr,
        'total_max_cost_lkr': totalMaxCostLkr,
      };

  /// Formatted total range e.g. "LKR 84,500 – LKR 102,300"
  String get formattedTotalRange {
    String fmt(double v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'LKR ${fmt(totalMinCostLkr)} – LKR ${fmt(totalMaxCostLkr)}';
  }
}
