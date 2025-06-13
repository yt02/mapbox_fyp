class PointOfInterest {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double latitude;
  final double longitude;
  final double? distance; // Distance from user's current location in km
  final String? address;
  final String? icon; // Icon name or URL

  PointOfInterest({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.address,
    this.icon,
  });

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      distance: json['distance'],
      address: json['address'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'address': address,
      'icon': icon,
    };
  }
} 