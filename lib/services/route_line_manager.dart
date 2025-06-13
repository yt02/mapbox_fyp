import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert';
import '../models/directions_model.dart' as app_models;

class RouteLineManager {
  MapboxMap? mapboxMap;
  
  // Source and layer IDs
  static const String _routeLineSourceId = 'mapbox-route-line-source';
  static const String _routeLineLayerId = 'mapbox-route-line-layer';
  static const String _routeOutlineLayerId = 'mapbox-route-outline-layer';
  static const String _routePulseLayerId = 'mapbox-route-pulse-layer';
  static const String _routeOriginSourceId = 'mapbox-route-origin-source';
  static const String _routeOriginLayerId = 'mapbox-route-origin-layer';
  static const String _routeDestinationSourceId = 'mapbox-route-destination-source';
  static const String _routeDestinationLayerId = 'mapbox-route-destination-layer';
  
  // Line width settings
  static const double _defaultLineWidth = 5.0;
  static const double _navigationLineWidth = 9.0;
  static const double _defaultOutlineWidth = 7.0;
  static const double _navigationOutlineWidth = 12.0;
  static const double _pulseLineWidth = 14.0;
  
  // Line color settings
  final int _defaultLineColor = Colors.blue.value;
  final int _navigationLineColor = Colors.blue.shade600.value;
  final int _outlineColor = Colors.white.withOpacity(0.7).value;
  final int _pulseColor = Colors.blue.shade300.withOpacity(0.4).value;
  
  // Animation timer
  Timer? _pulseAnimationTimer;
  bool _isPulseVisible = false;
  bool _isNavigationMode = false;

  // Initialize the route line manager with the map instance
  void initialize(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    print("Debug - RouteLineManager initialized");
  }

  // Draw a route on the map
  Future<void> drawRoute(app_models.Directions directions, {bool isNavigationMode = false}) async {
    print("Debug - RouteLineManager.drawRoute called");
    
    if (mapboxMap == null) {
      print("Debug - MapboxMap is null, cannot draw route");
      return;
    }
    
    if (directions.routes.isEmpty) {
      print("Debug - No routes available to draw");
      return;
    }
    
    final style = mapboxMap!.style;
    final route = directions.routes.first;
    
    print("Debug - Route to draw: distance=${route.distance}m, duration=${route.duration}s");
    print("Debug - Route geometry type: ${route.geometry.runtimeType}");
    
    // Clear any existing route
    await clearRoute();
    
    // Create a GeoJSON source for the route
    try {
      await _addRouteSource(style, route);
    } catch (e) {
      print("Debug - Error adding route source: $e");
      return;
    }
    
    // Add a line layer to visualize the route
    try {
      await _addRouteLineLayer(style, isNavigationMode: isNavigationMode);
    } catch (e) {
      print("Debug - Error adding route line layer: $e");
      return;
    }
    
    // Add origin and destination markers
    try {
      await _addRouteEndpoints(style, directions);
    } catch (e) {
      print("Debug - Error adding route endpoints: $e");
      return;
    }
    
    // Fit the camera to show the entire route
    try {
      await _fitRouteInView(directions);
    } catch (e) {
      print("Debug - Error fitting route in view: $e");
      return;
    }
    
    print("Debug - Route drawing completed successfully");
  }

  // Update the route line style for navigation mode
  Future<void> updateRouteForNavigation() async {
    if (mapboxMap == null) return;
    
    _isNavigationMode = true;
    final style = mapboxMap!.style;
    
    try {
      // Check if the layers exist
      bool mainLayerExists = false;
      bool outlineLayerExists = false;
      
      try {
        await style.getStyleLayerProperty(_routeLineLayerId, "type");
        mainLayerExists = true;
      } catch (_) {
        mainLayerExists = false;
      }
      
      try {
        await style.getStyleLayerProperty(_routeOutlineLayerId, "type");
        outlineLayerExists = true;
      } catch (_) {
        outlineLayerExists = false;
      }
      
      // Update main line layer
      if (mainLayerExists) {
        // Update line width
        await style.setStyleLayerProperty(
          _routeLineLayerId,
          "line-width",
          _navigationLineWidth.toString()
        );
        
        // Update line color
        await style.setStyleLayerProperty(
          _routeLineLayerId,
          "line-color",
          _navigationLineColor.toString()
        );
      }
      
      // Update outline layer
      if (outlineLayerExists) {
        // Update outline width
        await style.setStyleLayerProperty(
          _routeOutlineLayerId,
          "line-width",
          _navigationOutlineWidth.toString()
        );
      }
      
      // Add pulsing effect layer if it doesn't exist
      await _addPulseEffectLayer();
      
      // Start pulse animation
      _startPulseAnimation();
      
      print("Debug - Route line updated for navigation mode");
    } catch (e) {
      print("Debug - Error updating route line for navigation: $e");
    }
  }

  // Reset the route line style to default
  Future<void> resetRouteStyle() async {
    if (mapboxMap == null) return;
    
    _isNavigationMode = false;
    final style = mapboxMap!.style;
    
    try {
      // Check if the layers exist
      bool mainLayerExists = false;
      bool outlineLayerExists = false;
      
      try {
        await style.getStyleLayerProperty(_routeLineLayerId, "type");
        mainLayerExists = true;
      } catch (_) {
        mainLayerExists = false;
      }
      
      try {
        await style.getStyleLayerProperty(_routeOutlineLayerId, "type");
        outlineLayerExists = true;
      } catch (_) {
        outlineLayerExists = false;
      }
      
      // Update main line layer
      if (mainLayerExists) {
        // Reset line width
        await style.setStyleLayerProperty(
          _routeLineLayerId,
          "line-width",
          _defaultLineWidth.toString()
        );
        
        // Reset line color
        await style.setStyleLayerProperty(
          _routeLineLayerId,
          "line-color",
          _defaultLineColor.toString()
        );
      }
      
      // Update outline layer
      if (outlineLayerExists) {
        // Reset outline width
        await style.setStyleLayerProperty(
          _routeOutlineLayerId,
          "line-width",
          _defaultOutlineWidth.toString()
        );
      }
      
      // Remove pulse effect layer
      _stopPulseAnimation();
      await _removePulseEffectLayer();
      
      print("Debug - Route line reset to default style");
    } catch (e) {
      print("Debug - Error resetting route line style: $e");
    }
  }

  // Clear the route and markers from the map
  Future<void> clearRoute() async {
    print("Debug - RouteLineManager.clearRoute called");
    if (mapboxMap == null) return;
    
    // Stop any animations
    _stopPulseAnimation();
    
    final style = mapboxMap!.style;
    
    // Helper function to safely remove a layer
    Future<void> safelyRemoveLayer(String layerId) async {
      try {
        // Check if the layer exists before trying to remove it
        bool exists = false;
        try {
          await style.getStyleLayerProperty(layerId, "type");
          exists = true;
        } catch (_) {
          exists = false;
        }
        
        if (exists) {
          await style.removeStyleLayer(layerId);
          print("Debug - Layer $layerId removed");
        }
      } catch (e) {
        print('Error checking/removing layer $layerId: $e');
      }
    }
    
    // Helper function to safely remove a source
    Future<void> safelyRemoveSource(String sourceId) async {
      try {
        // Check if the source exists before trying to remove it
        bool exists = false;
        try {
          await style.getStyleSourceProperty(sourceId, "type");
          exists = true;
        } catch (_) {
          exists = false;
        }
        
        if (exists) {
          await style.removeStyleSource(sourceId);
          print("Debug - Source $sourceId removed");
        }
      } catch (e) {
        print('Error checking/removing source $sourceId: $e');
      }
    }
    
    // Remove route line layers
    await safelyRemoveLayer(_routeLineLayerId);
    await safelyRemoveLayer(_routeOutlineLayerId);
    await safelyRemoveLayer(_routePulseLayerId);
    await safelyRemoveSource(_routeLineSourceId);
    
    // Remove origin marker
    await safelyRemoveLayer(_routeOriginLayerId);
    await safelyRemoveSource(_routeOriginSourceId);
    
    // Remove destination marker
    await safelyRemoveLayer(_routeDestinationLayerId);
    await safelyRemoveSource(_routeDestinationSourceId);
  }

  // Add the route line source to the map
  Future<void> _addRouteSource(StyleManager style, app_models.Route route) async {
    print("Debug - Adding route source");
    
    // Get the geometry from the route
    List<List<double>> coordinates = [];
    
    print("Debug - Route geometry type: ${route.geometry.runtimeType}");
    
    // Handle different geometry formats
    if (route.geometry is Map) {
      // This is a GeoJSON object
      print("Debug - Processing GeoJSON geometry");
      if (route.geometry['type'] == 'LineString' && route.geometry['coordinates'] != null) {
        // Extract coordinates from GeoJSON LineString
        var coords = route.geometry['coordinates'];
        if (coords is List) {
          coordinates = List<List<double>>.from(coords.map((coord) {
            if (coord is List) {
              return List<double>.from(coord);
            }
            return <double>[];
          }));
          print("Debug - Extracted ${coordinates.length} coordinates from GeoJSON");
        }
      } else {
        print("Debug - Unsupported GeoJSON geometry type: ${route.geometry['type']}");
      }
    } else if (route.geometry is String) {
      print("Debug - Decoding polyline string geometry");
      // If geometry is a polyline string, decode it
      if (route.geometry.isNotEmpty) {
        coordinates = decodePolyline(route.geometry);
        print("Debug - Decoded ${coordinates.length} coordinates from polyline");
      } else {
        print("Debug - Empty polyline string");
      }
    } else {
      print("Debug - Unsupported geometry type: ${route.geometry.runtimeType}");
    }
    
    if (coordinates.isEmpty) {
      print('Debug - No valid coordinates in route geometry');
      return;
    }
    
    print("Debug - First coordinate: ${coordinates.first}");
    print("Debug - Last coordinate: ${coordinates.last}");
    
    // Create a LineString feature from the coordinates
    final Map<String, dynamic> routeFeature = {
      'type': 'Feature',
      'properties': {},
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates
      }
    };
    
    print("Debug - GeoJSON feature created");
    
    // Convert to JSON string
    final String featureJson = jsonEncode(routeFeature);
    print("Debug - GeoJSON: ${featureJson.substring(0, min(100, featureJson.length))}...");
    
    // Create a GeoJSON source with the route feature
    final geojsonSource = GeoJsonSource(
      id: _routeLineSourceId,
      data: featureJson,
    );
    
    await style.addSource(geojsonSource);
    print("Debug - Route source added to map");
  }

  // Add the route line layer to the map
  Future<void> _addRouteLineLayer(StyleManager style, {bool isNavigationMode = false}) async {
    _isNavigationMode = isNavigationMode;
    
    // First add the outline layer
    final outlineLayer = LineLayer(
      id: _routeOutlineLayerId,
      sourceId: _routeLineSourceId,
      lineColor: _outlineColor,
      lineWidth: isNavigationMode ? _navigationOutlineWidth : _defaultOutlineWidth,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
      lineBlur: 1.0, // Add slight blur for a softer edge
    );
    
    await style.addLayer(outlineLayer);
    
    // Add pulse effect layer if in navigation mode
    if (isNavigationMode) {
      await _addPulseEffectLayer();
    }
    
    // Then add the main line layer on top
    final lineLayer = LineLayer(
      id: _routeLineLayerId,
      sourceId: _routeLineSourceId,
      lineColor: isNavigationMode ? _navigationLineColor : _defaultLineColor,
      lineWidth: isNavigationMode ? _navigationLineWidth : _defaultLineWidth,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    );
    
    await style.addLayer(lineLayer);
    
    // Start pulse animation if in navigation mode
    if (isNavigationMode) {
      _startPulseAnimation();
    }
  }

  // Add origin and destination markers
  Future<void> _addRouteEndpoints(StyleManager style, app_models.Directions directions) async {
    if (directions.waypoints.length < 2) return;
    
    final origin = directions.waypoints.first;
    final destination = directions.waypoints.last;
    
    // Origin marker
    final originFeature = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': origin.location
      }
    };
    
    final originSource = GeoJsonSource(
      id: _routeOriginSourceId,
      data: jsonEncode(originFeature),
    );
    
    await style.addSource(originSource);
    
    final originLayer = CircleLayer(
      id: _routeOriginLayerId,
      sourceId: _routeOriginSourceId,
      circleRadius: 8.0,
      circleColor: Colors.green.value,
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.value,
    );
    
    await style.addLayer(originLayer);
    
    // Destination marker
    final destinationFeature = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': destination.location
      }
    };
    
    final destinationSource = GeoJsonSource(
      id: _routeDestinationSourceId,
      data: jsonEncode(destinationFeature),
    );
    
    await style.addSource(destinationSource);
    
    final destinationLayer = CircleLayer(
      id: _routeDestinationLayerId,
      sourceId: _routeDestinationSourceId,
      circleRadius: 8.0,
      circleColor: Colors.red.value,
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.value,
    );
    
    await style.addLayer(destinationLayer);
  }

  // Fit the camera to show the entire route
  Future<void> _fitRouteInView(app_models.Directions directions) async {
    if (mapboxMap == null || directions.waypoints.length < 2) return;
    
    // Get the route coordinates
    List<Point> points = directions.waypoints.map((waypoint) {
      return Point(
        coordinates: Position(
          waypoint.location[0],
          waypoint.location[1],
        ),
      );
    }).toList();
    
    // Create edge insets for padding
    MbxEdgeInsets padding = MbxEdgeInsets(top: 100, left: 100, bottom: 100, right: 100);
    
    // Calculate the camera options to fit all points and await the result
    mapboxMap!.cameraForCoordinates(
      points,
      padding,
      null,
      null
    ).then((cameraOptions) {
      // Animate the camera to fit the route
      mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1000, startDelay: 0),
      );
    });
  }
  
  // Decode a polyline string into a list of coordinates
  List<List<double>> decodePolyline(String encoded) {
    print("Debug - Decoding polyline: ${encoded.substring(0, min(20, encoded.length))}...");
    
    List<List<double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        double latV = lat / 1E5;
        double lngV = lng / 1E5;
        
        poly.add([lngV, latV]);
      }
      
      print("Debug - Decoded ${poly.length} coordinates");
      if (poly.isNotEmpty) {
        print("Debug - First decoded point: ${poly.first}");
        print("Debug - Last decoded point: ${poly.last}");
      }
      
      return poly;
    } catch (e) {
      print("Debug - Error decoding polyline: $e");
      return [];
    }
  }
  
  int min(int a, int b) {
    return a < b ? a : b;
  }

  // Add a pulsing effect layer for the route
  Future<void> _addPulseEffectLayer() async {
    if (mapboxMap == null) return;
    
    final style = mapboxMap!.style;
    
    // Check if the layer already exists
    try {
      await style.getStyleLayerProperty(_routePulseLayerId, "type");
      return; // Layer already exists
    } catch (_) {
      // Layer doesn't exist, proceed with adding it
    }
    
    try {
      // Add the pulse layer between the outline and main route line
      final pulseLayer = LineLayer(
        id: _routePulseLayerId,
        sourceId: _routeLineSourceId,
        lineColor: _pulseColor,
        lineWidth: _pulseLineWidth,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineOpacity: 0.0, // Start invisible
      );
      
      // Add the pulse layer (it will be between outline and main line)
      await style.addLayer(pulseLayer);
      
      print("Debug - Pulse effect layer added");
    } catch (e) {
      print("Debug - Error adding pulse effect layer: $e");
    }
  }
  
  // Remove the pulse effect layer
  Future<void> _removePulseEffectLayer() async {
    if (mapboxMap == null) return;
    
    final style = mapboxMap!.style;
    
    try {
      // Check if the layer exists
      try {
        await style.getStyleLayerProperty(_routePulseLayerId, "type");
      } catch (_) {
        return; // Layer doesn't exist
      }
      
      // Remove the layer
      await style.removeStyleLayer(_routePulseLayerId);
      
      print("Debug - Pulse effect layer removed");
    } catch (e) {
      print("Debug - Error removing pulse effect layer: $e");
    }
  }
  
  // Start the pulse animation
  void _startPulseAnimation() {
    // Cancel any existing animation
    _stopPulseAnimation();
    
    // Start a new animation timer
    _pulseAnimationTimer = Timer.periodic(Duration(milliseconds: 1500), (_) {
      _animatePulse();
    });
    
    // Immediately show the first pulse
    _animatePulse();
  }
  
  // Stop the pulse animation
  void _stopPulseAnimation() {
    _pulseAnimationTimer?.cancel();
    _pulseAnimationTimer = null;
  }
  
  // Animate the pulse effect
  Future<void> _animatePulse() async {
    if (mapboxMap == null || !_isNavigationMode) return;
    
    final style = mapboxMap!.style;
    
    try {
      // Toggle pulse visibility
      _isPulseVisible = !_isPulseVisible;
      
      // Update pulse opacity
      await style.setStyleLayerProperty(
        _routePulseLayerId,
        "line-opacity",
        _isPulseVisible ? "0.6" : "0.0"
      );
    } catch (e) {
      print("Debug - Error animating pulse: $e");
    }
  }
} 