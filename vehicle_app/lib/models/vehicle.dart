class Vehicle {
  final String name;
  final String model;
  final String manufacturer;

  Vehicle({
    required this.name,
    required this.model,
    required this.manufacturer,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      name: json['name'] ?? '',
      model: json['model'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'model': model,
      'manufacturer': manufacturer,
    };
  }
}
