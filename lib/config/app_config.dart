import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String? mapboxAccessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
  static String? mapboxStyleUrl = 'mapbox://styles/mapbox/navigation-day-v1';
  static String? mapboxStyleUrlNight = 'mapbox://styles/mapbox/navigation-night-v1';
  
  // Google Places
  static String? googleApiKey = dotenv.env['GOOGLE_API_KEY'];
  
  // OpenWeatherMap
  static String? openWeatherApiKey = dotenv.env['OPENWEATHER_API_KEY'];
  
  // Navigation
  static double recenterZoomLevel = 16.0;
  static double navigationZoomLevel = 18.0;
  static double arrivingDistance = 50.0; // in meters
  
  // Default map camera position (Kuala Lumpur, Malaysia)
  static const double defaultLatitude = 3.1390;
  static const double defaultLongitude = 101.6869;
} 