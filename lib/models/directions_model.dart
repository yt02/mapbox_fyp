class Directions {
  final List<Route> routes;
  final List<Waypoint> waypoints;
  final String code;
  final String uuid;

  Directions({
    required this.routes,
    required this.waypoints,
    required this.code,
    required this.uuid,
  });

  factory Directions.fromJson(Map<String, dynamic> json) {
    print("Debug - Parsing Directions from JSON");
    print("Debug - Response code: ${json['code']}");
    print("Debug - Routes count: ${(json['routes'] as List? ?? []).length}");
    print("Debug - Waypoints count: ${(json['waypoints'] as List? ?? []).length}");
    
    try {
      return Directions(
        routes: (json['routes'] as List? ?? []).map((e) => Route.fromJson(e)).toList(),
        waypoints: (json['waypoints'] as List? ?? []).map((e) => Waypoint.fromJson(e)).toList(),
        code: json['code'] ?? '',
        uuid: json['uuid'] ?? '',
      );
    } catch (e) {
      print("Debug - Error parsing Directions: $e");
      rethrow;
    }
  }
}

class Route {
  final String weight_name;
  final double weight;
  final double duration;
  final double distance;
  final List<Leg> legs;
  final dynamic geometry; // Can be GeoJSON object or polyline string

  Route({
    required this.weight_name,
    required this.weight,
    required this.duration,
    required this.distance,
    required this.legs,
    required this.geometry,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    print("Debug - Parsing Route from JSON");
    print("Debug - Duration: ${json['duration']}");
    print("Debug - Distance: ${json['distance']}");
    
    try {
      // Handle geometry which can be different formats
      var geometryValue = json['geometry'];
      
      if (geometryValue != null) {
        if (geometryValue is Map) {
          print("Debug - Geometry is GeoJSON Map format");
          // It's already a GeoJSON object, keep it as is
        } else if (geometryValue is String) {
          print("Debug - Geometry is String (polyline)");
          // It's a polyline string, keep it as is
        } else {
          print("Debug - Geometry is an unexpected type: ${geometryValue.runtimeType}");
        }
      } else {
        print("Debug - Geometry is null");
        geometryValue = null;
      }
      
      return Route(
        weight_name: json['weight_name'] ?? '',
        weight: (json['weight'] ?? 0).toDouble(),
        duration: (json['duration'] ?? 0).toDouble(),
        distance: (json['distance'] ?? 0).toDouble(),
        legs: (json['legs'] as List? ?? []).map((e) => Leg.fromJson(e)).toList(),
        geometry: geometryValue,
      );
    } catch (e) {
      print("Debug - Error parsing Route: $e");
      rethrow;
    }
  }
}

class Leg {
  final List<Step> steps;
  final double duration;
  final double distance;
  final String summary;

  Leg({
    required this.steps,
    required this.duration,
    required this.distance,
    required this.summary,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      steps: (json['steps'] as List? ?? []).map((e) => Step.fromJson(e)).toList(),
      duration: (json['duration'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      summary: json['summary'] ?? '',
    );
  }
}

class Step {
  final Maneuver maneuver;
  final String name;
  final double duration;
  final double distance;
  final String driving_side;
  final String mode;
  final dynamic geometry; // Can be GeoJSON object or polyline string

  Step({
    required this.maneuver,
    required this.name,
    required this.duration,
    required this.distance,
    required this.driving_side,
    required this.mode,
    required this.geometry,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      maneuver: Maneuver.fromJson(json['maneuver'] ?? {}),
      name: json['name'] ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      driving_side: json['driving_side'] ?? '',
      mode: json['mode'] ?? '',
      geometry: json['geometry'], // Can be GeoJSON or polyline
    );
  }
}

class Maneuver {
  final String type;
  final String instruction;
  final int bearing_after;
  final int bearing_before;
  final List<double> location;
  final String? modifier;

  Maneuver({
    required this.type,
    required this.instruction,
    required this.bearing_after,
    required this.bearing_before,
    required this.location,
    this.modifier,
  });

  factory Maneuver.fromJson(Map<String, dynamic> json) {
    return Maneuver(
      type: json['type'] ?? '',
      instruction: json['instruction'] ?? '',
      bearing_after: json['bearing_after'] ?? 0,
      bearing_before: json['bearing_before'] ?? 0,
      location: json['location'] != null 
        ? List<double>.from(json['location']) 
        : [0.0, 0.0],
      modifier: json['modifier'],
    );
  }
}

class Waypoint {
  final String name;
  final List<double> location;

  Waypoint({
    required this.name,
    required this.location,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      name: json['name'] ?? '',
      location: json['location'] != null 
        ? List<double>.from(json['location']) 
        : [0.0, 0.0],
    );
  }
} 