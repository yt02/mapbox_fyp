import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/directions_model.dart';
import '../models/navigation_instruction.dart';
import '../models/point_of_interest.dart';
import 'dart:math';

class MapboxService {
  final String? accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
  
  MapboxService() {
    if (accessToken != null) {
      print("Mapbox Access Token: ${accessToken!.substring(0, min(10, accessToken!.length))}...");
    } else {
      print("Mapbox Access Token is not set");
    }
  }
  
  // Get directions with multiple waypoints
  Future<Directions?> getDirectionsWithMultipleWaypoints(List<List<double>> coordinates) async {
    if (accessToken == null) {
      print("Mapbox access token is null");
      return null;
    }
    
    if (coordinates.length < 2) {
      print("Need at least 2 coordinates for directions");
      return null;
    }
    
    // Format coordinates for the API
    final String formattedCoords = coordinates.map((coord) => "${coord[0]},${coord[1]}").join(";");
    
    // Build URL with parameters
    final Uri url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$formattedCoords'
      '?alternatives=false'
      '&geometries=geojson'
      '&overview=full'
      '&steps=true'
      '&annotations=distance,duration'
      '&access_token=$accessToken'
    );
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Directions.fromJson(data);
      } else {
        print("Failed to get directions: ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error getting directions: $e");
      return null;
    }
  }
  
  // Extract navigation instructions from directions response
  List<NavigationInstruction> extractInstructions(Directions directions) {
    List<NavigationInstruction> instructions = [];
    
    if (directions.routes.isEmpty) {
      return instructions;
    }
    
    // Get the first route
    final route = directions.routes.first;
    
    // Extract legs and steps
    if (route.legs != null) {
      for (var leg in route.legs) {
        if (leg.steps != null) {
          for (var step in leg.steps) {
            // Extract instruction details
            String instructionText = step.maneuver.instruction;
            String type = step.maneuver.type;
            String modifier = step.maneuver.modifier ?? '';
            int distance = step.distance.round();
            String? name = step.name;
            
            // Extract location of the maneuver
            List<double>? location = step.maneuver.location;
            
            // Create a navigation instruction
            final instruction = NavigationInstruction(
              instruction: instructionText,
              type: type,
              modifier: modifier,
              distance: distance,
              location: location,
              name: name,
            );
            
            instructions.add(instruction);
            print("Added instruction: $instructionText, type: $type, modifier: $modifier");
          }
        }
      }
    }
    
    return instructions;
  }
  
  // Fetch points of interest around a location
  Future<List<PointOfInterest>> getPointsOfInterest(
    double longitude,
    double latitude,
    {
      double radius = 1000, // Search radius in meters
      List<String> categories = const [], // Filter by categories
      int limit = 10, // Maximum number of results
    }
  ) async {
    if (accessToken == null) {
      print("Mapbox access token is null");
      return [];
    }
    
    // Build URL for the Mapbox Places API
    String categoriesParam = '';
    if (categories.isNotEmpty) {
      categoriesParam = '&types=${categories.join(",")}';
    }
    
    final Uri url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      'poi.json'
      '?proximity=$longitude,$latitude'
      '&radius=$radius'
      '$categoriesParam'
      '&limit=$limit'
      '&access_token=$accessToken'
    );
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] == null) {
          return [];
        }
        
        List<PointOfInterest> pois = [];
        
        for (var feature in data['features']) {
          if (feature['geometry'] == null || 
              feature['geometry']['coordinates'] == null || 
              feature['properties'] == null) {
            continue;
          }
          
          List<dynamic> coordinates = feature['geometry']['coordinates'];
          
          // Calculate distance from current location
          double poiLongitude = coordinates[0];
          double poiLatitude = coordinates[1];
          double distance = _calculateDistance(
            latitude, longitude, poiLatitude, poiLongitude);
          
          String category = 'poi';
          if (feature['properties']['category'] != null) {
            category = feature['properties']['category'];
          } else if (feature['place_type'] != null && feature['place_type'].isNotEmpty) {
            category = feature['place_type'][0];
          }
          
          pois.add(
            PointOfInterest(
              id: feature['id'] ?? '',
              name: feature['text'] ?? 'Unknown',
              description: feature['properties']?['description'],
              category: category,
              latitude: poiLatitude,
              longitude: poiLongitude,
              distance: distance,
              address: feature['place_name'],
              icon: _getCategoryIcon(category),
            )
          );
        }
        
        // Sort by distance
        pois.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
        
        return pois;
      } else {
        print("Failed to get POIs: ${response.statusCode}");
        print("Response body: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error getting POIs: $e");
      return [];
    }
  }
  
  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c; // Distance in km
    return distance;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  // Get icon for category
  String? _getCategoryIcon(String category) {
    Map<String, String> categoryIcons = {
      'restaurant': 'restaurant',
      'cafe': 'cafe',
      'food': 'restaurant',
      'hotel': 'hotel',
      'lodging': 'hotel',
      'attraction': 'attractions',
      'landmark': 'attractions',
      'shop': 'shopping',
      'store': 'shopping',
      'gas_station': 'gas_station',
      'fuel': 'gas_station',
      'hospital': 'hospital',
      'pharmacy': 'pharmacy',
      'parking': 'parking',
      'bank': 'bank_atm',
      'atm': 'bank_atm',
      'school': 'school',
      'college': 'school',
      'university': 'school',
      'police': 'police',
      'post': 'post_office',
      'airport': 'airport',
      'bus': 'bus_station',
      'train': 'train_station',
      'subway': 'subway_station',
    };
    
    String lowerCategory = category.toLowerCase();
    
    for (var key in categoryIcons.keys) {
      if (lowerCategory.contains(key)) {
        return categoryIcons[key];
      }
    }
    
    return 'place'; // Default icon
  }
} 