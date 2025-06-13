import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../config/app_config.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  bool _debugMode = true; // Set to true to enable detailed logging
  
  // Fetch weather data for the given coordinates
  Future<Weather?> getWeatherForLocation(double latitude, double longitude) async {
    try {
      final apiKey = AppConfig.openWeatherApiKey;
      
      if (_debugMode) {
        print('WeatherService: API Key available: ${apiKey != null && apiKey.isNotEmpty}');
      }
      
      if (apiKey == null || apiKey.isEmpty) {
        print('WeatherService: No API key found');
        return null;
      }
      
      final url = '$_baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey';
      if (_debugMode) {
        print('WeatherService: Fetching weather data from: $url');
        print('WeatherService: Request coordinates: $latitude, $longitude');
      } else {
        print('WeatherService: Fetching weather data...');
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (_debugMode) {
        print('WeatherService: Response status code: ${response.statusCode}');
        print('WeatherService: Response headers: ${response.headers}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (_debugMode) {
          print('WeatherService: Response data: ${response.body}');
        }
        
        final weather = Weather.fromJson(data);
        
        if (_debugMode) {
          print('WeatherService: Successfully parsed weather data:');
          print('  - Location: ${weather.name}, ${weather.sys.country}');
          print('  - Temperature: ${weather.getFormattedTemperature()}');
          print('  - Weather: ${weather.getWeatherMain()} (${weather.getWeatherDescription()})');
        }
        
        return weather;
      } else {
        print('WeatherService: Failed to load weather data. Status code: ${response.statusCode}');
        print('WeatherService: Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('WeatherService: Error fetching weather data: $e');
      return null;
    }
  }
  
  // Enable or disable debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    print('WeatherService: Debug mode ${enabled ? 'enabled' : 'disabled'}');
  }
  
  // Check if the API key is configured
  bool isApiKeyConfigured() {
    final apiKey = AppConfig.openWeatherApiKey;
    final isConfigured = apiKey != null && apiKey.isNotEmpty;
    
    if (_debugMode) {
      print('WeatherService: API key configured: $isConfigured');
      if (!isConfigured) {
        print('WeatherService: Please add OPENWEATHER_API_KEY to your .env file');
      }
    }
    
    return isConfigured;
  }
  
  // Get weather icon based on condition
  IconData getWeatherIcon(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return Icons.cloud;
      default:
        return Icons.wb_sunny;
    }
  }
} 