import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:audioplayers/audioplayers.dart';
import '../config/app_config.dart';
import '../services/mapbox_service.dart';
import '../services/route_line_manager.dart';
import '../services/navigation_service.dart';
import '../services/safety_tip_service.dart';
import '../services/weather_service.dart';
import '../models/directions_model.dart' as directions;
import '../models/navigation_instruction.dart';
import '../models/safety_tip.dart';
import '../models/weather_model.dart';
import '../widgets/points_of_interest.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter/services.dart';
import 'profile_screen.dart';

// Add a custom SpeedIndicator widget with animation
class SpeedIndicator extends StatefulWidget {
  final double speed;
  final int speedLimit;
  final bool isOverLimit;
  final bool showSpeedLimit;
  
  const SpeedIndicator({
    Key? key,
    required this.speed,
    required this.speedLimit,
    required this.isOverLimit,
    this.showSpeedLimit = false,
  }) : super(key: key);
  
  @override
  State<SpeedIndicator> createState() => _SpeedIndicatorState();
}

class _SpeedIndicatorState extends State<SpeedIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(SpeedIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSpeedLimit != oldWidget.showSpeedLimit) {
      _animationController.forward(from: 0.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculate progress (0.0 to 1.0) based on speed relative to limit
    double progress = widget.speedLimit > 0 ? (widget.speed / widget.speedLimit) : 0.0;
    
    // Cap progress at 1.3 (130% of speed limit) for visual purposes
    progress = progress.clamp(0.0, 1.3);
    
    // Determine color based on speed
    Color progressColor;
    if (progress < 0.8) {
      progressColor = Colors.green;
    } else if (progress < 0.95) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                // Background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                // Progress indicator
                CustomPaint(
                  painter: SpeedProgressPainter(
                    progress: progress,
                    progressColor: progressColor,
                    strokeWidth: 5.0,
                  ),
                  size: const Size(80, 80),
                ),
                // Speed text
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.showSpeedLimit ? widget.speedLimit.toString() : widget.speed.round().toString(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.showSpeedLimit ? Colors.amber : (widget.isOverLimit ? Colors.red : Colors.white),
                        ),
                      ),
                      Text(
                        'km/h',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.showSpeedLimit ? Colors.amber.shade200 : Colors.white70,
                        ),
                      ),
                      if (widget.showSpeedLimit)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'LIMIT',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for the circular progress indicator
class SpeedProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final double strokeWidth;
  
  SpeedProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.strokeWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Define the center and radius
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    
    // Define the background paint (gray circle)
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    // Define the progress paint
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw the background circle
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw the progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from the top
      progress * 2 * math.pi, // Convert progress to radians
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  MapboxMap? mapboxMap;
  geo.Position? _currentPosition;
  bool _isFollowingUser = false;
  bool _isLoading = true;
  final MapboxService _mapboxService = MapboxService();
  final RouteLineManager _routeLineManager = RouteLineManager();
  final NavigationService _navigationService = NavigationService();
  final SafetyTipService _safetyTipService = SafetyTipService();
  final WeatherService _weatherService = WeatherService();
  StreamSubscription<geo.Position>? _positionStreamSubscription;
  String? _selectedPlaceName;
  String? _selectedPlaceAddress;
  double? _estimatedTime;
  double? _distance;
  List<Point> _waypoints = [];
  List<String> _waypointNames = [];
  List<String?> _waypointAddresses = [];
  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  List<Prediction> _predictions = [];
  
  bool _isInNavigationMode = false;
  bool _isSimulating = false;
  bool _isPaused = false;
  bool _isSimulationPanelCollapsed = false;
  Timer? _simulationTimer;
  List<List<double>> _simulationRoute = [];
  int _simulationIndex = 0;
  double _simulationBearing = 0;
  double _targetBearing = 0;
  double _simulationSpeed = 1.0; // Points to skip per update (now using double for finer control)
  
  // Variables for smooth interpolation
  List<double>? _currentSimPoint;
  List<double>? _nextSimPoint;
  double _interpolationProgress = 0.0;
  
  // Navigation instructions
  List<NavigationInstruction> _navigationInstructions = [];
  NavigationInstruction? _currentInstruction;
  
  // Animation controller for pulsing effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  // Source and layer IDs for current location marker
  static const String _currentLocationSourceId = 'current-location-source';
  static const String _currentLocationLayerId = 'current-location-layer';
  static const String _currentLocationOutlineLayerId = 'current-location-outline-layer';
  static const String _currentLocationPulseLayerId = 'current-location-pulse-layer';
  
  // Safety tips related variables
  SafetyTip? _currentTip;
  bool _showTip = false;
  Timer? _tipDisplayTimer;
  bool _showSafetyTips = true;
  bool _showBeginnerTips = true;
  bool _speakTipsEnabled = true;
  bool _soundsEnabled = true;
  
  // Add speed limit variable to the class state
  int _currentSpeedLimit = 80; // Default speed limit, this would normally come from navigation data
  bool _isOverSpeedLimit = false;
  
  // Add speed warning variables to the class state
  bool _showSpeedWarning = false;
  Timer? _speedWarningTimer;
  Timer? _speedCheckTimer;
  
  // Add speed warning setting to class state
  bool _enableSpeedWarnings = true;
  
  // Add a boolean to track whether to show speed limit in the speed indicator
  bool _showSpeedLimitInIndicator = false;
  
  // Track last speed warning time to avoid too frequent warnings
  DateTime? _lastSpeedWarningTime;
  
  // Weather related variables
  Weather? _currentWeather;
  bool _isLoadingWeather = false;
  bool _showWeatherDetail = false;
  Timer? _weatherRefreshTimer;

  // Overspeed warning animation (reuse existing animation controller)
  bool _wasOverSpeedLimit = false;

  // Turn signal indicator variables
  bool _showLeftTurnSignal = false;
  bool _showRightTurnSignal = false;
  bool _showStraightSignal = false;
  NavigationInstruction? _upcomingTurnInstruction;
  static const double _turnSignalDistance = 500.0; // Show signal 500m before turn

  // Search widget visibility
  bool _showSearchWidget = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for pulsing effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 15.0, end: 25.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
    )..addListener(() {
      _updatePulseEffect();
    });
    
    // Initialize navigation mode flag
    _isInNavigationMode = false;
    
    // Initialize voice and sound preferences (default to enabled)
    _speakTipsEnabled = true;
    _soundsEnabled = true;
    _enableSpeedWarnings = true;
    
    // Track last speed warning time to avoid too frequent warnings
    _lastSpeedWarningTime = null;
    
    // Connect the navigation service and safety tip service
    _navigationService.setSafetyTipService(_safetyTipService);
    
    _getCurrentLocation();
    
    // Request focus on search field after a short delay to allow the UI to initialize
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_isInNavigationMode && mounted) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      }
    });
    
    // Initialize safety tip categories
    _safetyTipService.setCategories(
      safety: _showSafetyTips,
      beginner: _showBeginnerTips
    );
    
    // Start periodic speed checks when in navigation mode
    _speedCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (_isInNavigationMode && _currentPosition != null && _enableSpeedWarnings) {
        _checkSpeedLimit();
      }
    });
    
    // Setup periodic weather updates (every 30 minutes)
    _weatherRefreshTimer = Timer.periodic(Duration(minutes: 30), (_) {
      if (_currentPosition != null) {
        _fetchWeatherData();
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _simulationTimer?.cancel();
    _tipDisplayTimer?.cancel();
    _speedWarningTimer?.cancel();
    _speedCheckTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    _safetyTipService.stopTips();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Update the pulse effect based on animation value
  void _updatePulseEffect() {
    if (mapboxMap == null) return;

    try {
      final style = mapboxMap!.style;
      style.setStyleLayerProperty(
        _currentLocationPulseLayerId,
        "circle-radius",
        _pulseAnimation.value.toString()
      );
      style.setStyleLayerProperty(
        _currentLocationPulseLayerId,
        "circle-opacity",
        (1.0 - _pulseAnimation.value / 30.0).toString()
      );
    } catch (e) {
      // Ignore errors if layer doesn't exist yet
    }

    // Handle overspeed state changes
    if (_isOverSpeedLimit != _wasOverSpeedLimit) {
      _wasOverSpeedLimit = _isOverSpeedLimit;
      if (mounted) {
        setState(() {}); // Trigger rebuild to show/hide overspeed overlay
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please enable location.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get current position with high accuracy
      print("Getting current position...");
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high
      );
      print("Current position obtained: ${position.latitude}, ${position.longitude}");
      
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _isFollowingUser = true;
      });

      // If map is already created, update the camera and add marker
      if (mapboxMap != null) {
        print("Map already created, centering on user location");
        _centerOnUserLocation();
        _updateCurrentLocationMarker();
      } else {
        print("Map not yet created, will center when map is ready");
      }

      // Start listening to position updates
      _positionStreamSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_updatePosition);
      
      // Fetch weather data for the current location
      _fetchWeatherData();
    } catch (e) {
      print("Error getting current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updatePosition(geo.Position position) {
    setState(() {
      _currentPosition = position;
    });

    if (mapboxMap != null) {
      _updateCurrentLocationMarker();
      
      // Update navigation instructions if in navigation mode
      if (_isInNavigationMode && _navigationInstructions.isNotEmpty) {
        _navigationService.updatePosition(position, _navigationInstructions);
        
        // Update the current instruction display
        if (_navigationService.currentInstructionIndex < _navigationInstructions.length) {
          setState(() {
            _currentInstruction = _navigationInstructions[_navigationService.currentInstructionIndex];
          });
          
          // Update safety tip service with upcoming instruction
          _updateSafetyTipContext();
        }
        
        // Update speed limit based on current road segment
        _updateSpeedLimit();
        
        // Update estimated time and distance
        _updateEstimatedTimeAndDistance(position);

        // Check for upcoming turn signals
        _checkForUpcomingTurnSignals(position);
      }
      
      if (_isFollowingUser) {
        if (_isInNavigationMode) {
          _updateNavigationUI();
        } else {
          _centerOnUserLocation();
        }
      }
    }
  }
  
  // Update safety tip service with current and upcoming navigation instructions
  void _updateSafetyTipContext() {
    if (_navigationInstructions.isEmpty || _navigationService.currentInstructionIndex >= _navigationInstructions.length) {
      return;
    }
    
    // Get current instruction
    NavigationInstruction currentInstruction = _navigationInstructions[_navigationService.currentInstructionIndex];
    
    // Look ahead for the next instruction if available
    NavigationInstruction? upcomingInstruction;
    if (_navigationService.currentInstructionIndex + 1 < _navigationInstructions.length) {
      upcomingInstruction = _navigationInstructions[_navigationService.currentInstructionIndex + 1];
      
      // Only consider it upcoming if it's within a reasonable distance (e.g., 300 meters)
      if (upcomingInstruction.distance > 300) {
        upcomingInstruction = null;
      }
    }
    
    // Calculate the distance to the current instruction
    int distanceToCurrentInstruction = currentInstruction.distance;
    
    // Determine which instruction to use for the context based on distance and content
    NavigationInstruction instructionForContext;
    String instructionText = currentInstruction.instruction.toLowerCase();
    String instructionType = currentInstruction.type.toLowerCase();
    String detailedType = currentInstruction.detailedType;
    
    // Check for special cases where we want to prioritize the current instruction regardless of distance
    bool isPriorityInstruction = 
        instructionText.contains("roundabout") || 
        instructionType.contains("roundabout") ||
        detailedType.contains("roundabout") ||
        instructionText.contains("exit") && instructionText.contains("highway") ||
        instructionText.contains("merge") ||
        instructionText.contains("keep") && (instructionText.contains("left") || instructionText.contains("right"));
    
    // If we're very close to the current instruction (within 50 meters) or it's a priority instruction, use it
    if (distanceToCurrentInstruction <= 50 || isPriorityInstruction) {
      instructionForContext = currentInstruction;
      print("MapScreen: Using current instruction for safety tips (distance: ${distanceToCurrentInstruction}m, priority: $isPriorityInstruction)");
    } 
    // If we're approaching the current instruction (50-150m) but not very close, use it
    else if (distanceToCurrentInstruction <= 150) {
      instructionForContext = currentInstruction;
      print("MapScreen: Approaching current instruction, using it for safety tips (distance: ${distanceToCurrentInstruction}m)");
    } 
    // If we have an upcoming instruction that's close, use that instead
    else if (upcomingInstruction != null) {
      instructionForContext = upcomingInstruction;
      print("MapScreen: Using upcoming instruction for safety tips (distance: ${upcomingInstruction.distance}m)");
    }
    // Otherwise, use the current instruction
    else {
      instructionForContext = currentInstruction;
      print("MapScreen: Using current instruction for safety tips (distance: ${distanceToCurrentInstruction}m)");
    }
    
    // Update the safety tip service with the selected instruction
    _safetyTipService.updateNavigationContext(instructionForContext);
  }
  
  // Fetch weather data based on current location
  Future<void> _fetchWeatherData() async {
    if (_currentPosition == null) return;
    
    setState(() {
      _isLoadingWeather = true;
    });
    
    try {
      final weather = await _weatherService.getWeatherForLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude
      );
      
      setState(() {
        _currentWeather = weather;
        _isLoadingWeather = false;
      });
      
      print('Weather data fetched: ${weather?.name}, ${weather?.getWeatherMain()}');
    } catch (e) {
      print('Error fetching weather data: $e');
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }
  
  // Fetch weather for a selected place
  Future<void> _fetchWeatherForSelectedPlace(double lat, double lng) async {
    try {
      final weather = await _weatherService.getWeatherForLocation(lat, lng);
      
      if (weather != null) {
        setState(() {
          _currentWeather = weather;
        });
        
        print('Weather data fetched for selected place: ${weather.name}, ${weather.getWeatherMain()}');
      }
    } catch (e) {
      print('Error fetching weather data for selected place: $e');
    }
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    print("Map created successfully");
    
    // Initialize route line manager
    _routeLineManager.initialize(mapboxMap);
    
    // Enable location tracking after map is created
    _enableLocationTracking();
    
    if (_currentPosition != null) {
      // Immediately center on current location when map is created
      _centerOnUserLocation();
      _addCurrentLocationMarker();
    }
  }
  
  void _enableLocationTracking() {
    mapboxMap?.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true, // Show direction the user is facing
        locationPuck: LocationPuck(
          locationPuck2D: LocationPuck2D(
            topImage: null,
            bearingImage: null,
            shadowImage: null,
            scaleExpression: null,
          ),
        ),
      ),
    );
  }
  
  void _centerOnUserLocation() {
    if (mapboxMap != null && _currentPosition != null) {
      mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude
            )
          ),
          zoom: 18.0, // More reasonable zoom level
          bearing: _currentPosition!.heading,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 500, startDelay: 0),
      );
    }
  }
  
  // Add a custom marker for current location
  Future<void> _addCurrentLocationMarker() async {
    if (mapboxMap == null || _currentPosition == null) return;
    
    final style = mapboxMap!.style;
    
    // Create a GeoJSON point for the current location
    final currentLocationFeature = {
      'type': 'Feature',
      'properties': {},
      'geometry': {
        'type': 'Point',
        'coordinates': [_currentPosition!.longitude, _currentPosition!.latitude]
      }
    };
    
    // Create a GeoJSON source with the current location
    final currentLocationSource = GeoJsonSource(
      id: _currentLocationSourceId,
      data: jsonEncode(currentLocationFeature),
    );
    
    try {
      // Add the source to the map
      await style.addSource(currentLocationSource);
      
      // Add a circle layer for the pulsing effect
      final pulseLayer = CircleLayer(
        id: _currentLocationPulseLayerId,
        sourceId: _currentLocationSourceId,
        circleRadius: 15.0,
        circleColor: Colors.blue.withOpacity(0.3).value,
        circleOpacity: 0.6,
        circleStrokeWidth: 0.0,
      );
      
      await style.addLayer(pulseLayer);
      
      // Add a circle layer for the marker outline (larger, different color)
      final outlineLayer = CircleLayer(
        id: _currentLocationOutlineLayerId,
        sourceId: _currentLocationSourceId,
        circleRadius: 12.0,
        circleColor: Colors.white.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      );
      
      await style.addLayer(outlineLayer);
      
      // Add a circle layer for the marker
      final circleLayer = CircleLayer(
        id: _currentLocationLayerId,
        sourceId: _currentLocationSourceId,
        circleRadius: 8.0,
        circleColor: Colors.blue.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      
      );
      
      await style.addLayer(circleLayer);
      
      print("Current location marker added");
    } catch (e) {
      print("Error adding current location marker: $e");
    }
  }
  
  // Update the current location marker position
  Future<void> _updateCurrentLocationMarker() async {
    if (mapboxMap == null || _currentPosition == null) return;
    
    final style = mapboxMap!.style;
    
    // Create a GeoJSON point for the current location
    final currentLocationFeature = {
      'type': 'Feature',
      'properties': {},
      'geometry': {
        'type': 'Point',
        'coordinates': [_currentPosition!.longitude, _currentPosition!.latitude]
      }
    };
    
    try {
      // Check if the source already exists
      bool sourceExists = false;
      try {
        // Try to get the source - if it doesn't exist, this will throw an error
        await style.getStyleSourceProperty(_currentLocationSourceId, "type");
        sourceExists = true;
      } catch (_) {
        sourceExists = false;
      }
      
      if (sourceExists) {
        // Update the source data
        await style.setStyleSourceProperty(
          _currentLocationSourceId,
          "data",
          jsonEncode(currentLocationFeature)
        );
      } else {
        // Add the marker if it doesn't exist
        _addCurrentLocationMarker();
      }
    } catch (e) {
      print("Error updating current location marker: $e");
      // Try to add the marker if updating fails
      try {
        _addCurrentLocationMarker();
      } catch (_) {}
    }
  }
  
  // Helper function to safely remove a layer
  Future<void> safelyRemoveLayer(StyleManager style, String layerId) async {
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
      }
    } catch (e) {
      print('Error checking/removing layer $layerId: $e');
    }
  }
  
  // Helper function to safely remove a source
  Future<void> safelyRemoveSource(StyleManager style, String sourceId) async {
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
      }
    } catch (e) {
      print('Error checking/removing source $sourceId: $e');
    }
  }
  
  // Add waypoint markers
  Future<void> _addWaypointMarkers() async {
    if (mapboxMap == null) return;
    
    final style = mapboxMap!.style;
    
    // First remove any existing waypoint markers
    for (int i = 0; i < 20; i++) { // Use a larger number to ensure all old markers are removed
      await safelyRemoveLayer(style, 'waypoint-layer-$i');
      await safelyRemoveLayer(style, 'waypoint-background-$i');
      await safelyRemoveLayer(style, 'waypoint-shadow-$i');
      await safelyRemoveSource(style, 'waypoint-source-$i');
    }
    
    // If no waypoints, just return after clearing
    if (_waypoints.isEmpty) return;
    
    // Add a marker for each waypoint
    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];
      
      // Create a GeoJSON point for the waypoint
      final waypointFeature = {
        'type': 'Feature',
        'properties': {
          'index': i,
          'title': i < _waypointNames.length ? _waypointNames[i] : 'Waypoint ${i + 1}'
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [waypoint.coordinates.lng, waypoint.coordinates.lat]
        }
      };
      
      // Create a GeoJSON source with the waypoint
      final waypointSource = GeoJsonSource(
        id: 'waypoint-source-$i',
        data: jsonEncode(waypointFeature),
      );
      
      try {
        // Add the source to the map
        await style.addSource(waypointSource);
        
        // Add a shadow/outline circle layer
        final shadowLayer = CircleLayer(
          id: 'waypoint-shadow-$i',
          sourceId: 'waypoint-source-$i',
          circleRadius: 18.0,
          circleColor: Colors.black.withOpacity(0.2).value,
          circleBlur: 1.0,
        );
        
        await style.addLayer(shadowLayer);
        
        // Add a circle layer for the marker background
        final backgroundLayer = CircleLayer(
          id: 'waypoint-background-$i',
          sourceId: 'waypoint-source-$i',
          circleRadius: 14.0,
          circleColor: Colors.white.value,
        );
        
        await style.addLayer(backgroundLayer);
        
        // Add a circle layer for the marker
        final circleLayer = CircleLayer(
          id: 'waypoint-layer-$i',
          sourceId: 'waypoint-source-$i',
          circleRadius: 10.0,
          circleColor: i == 0 ? Colors.green.value : Colors.red.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        );
        
        await style.addLayer(circleLayer);
      } catch (e) {
        print("Error adding waypoint marker $i: $e");
      }
    }
  }
  
  void _addWaypoint(Point point, {String? placeName, String? placeAddress}) {
    setState(() {
      _waypoints.add(point);
      _waypointNames.add(placeName ?? 'Waypoint ${_waypoints.length}');
      _waypointAddresses.add(placeAddress);
    });
    
    // Add markers for waypoints
    _addWaypointMarkers();
    
    // Move camera to the selected waypoint
    _moveToWaypoint(point);
    
    // If we have at least 2 points (current location + destination), get directions
    if (_waypoints.isNotEmpty) {
      _getDirectionsWithWaypoints(placeName: placeName, placeAddress: placeAddress);
    }
  }
  
  void _moveToWaypoint(Point point) {
    if (mapboxMap == null) return;
    
    mapboxMap!.flyTo(
      CameraOptions(
        center: point,
        zoom: 18.0, // More reasonable zoom level
        pitch: 0.0,
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
  }
  
  void _removeWaypoint(int index) {
    if (mapboxMap != null) {
      final style = mapboxMap!.style;
      // Remove the specific waypoint marker layers
      try {
        safelyRemoveLayer(style, 'waypoint-layer-$index');
        safelyRemoveLayer(style, 'waypoint-background-$index');
        safelyRemoveLayer(style, 'waypoint-shadow-$index');
        safelyRemoveSource(style, 'waypoint-source-$index');
      } catch (e) {
        print("Error removing waypoint marker: $e");
      }
    }
    
    setState(() {
      _waypoints.removeAt(index);
      _waypointNames.removeAt(index);
      _waypointAddresses.removeAt(index);
    });
    
    // Only redraw waypoints if we still have any
    if (_waypoints.isNotEmpty) {
      // Delay the redraw slightly to avoid frame drops
      Future.delayed(Duration(milliseconds: 100), () {
        _addWaypointMarkers();
        _getDirectionsWithWaypoints();
      });
    } else {
      _clearRoute();
    }
  }
  
  void _getDirectionsWithWaypoints({String? placeName, String? placeAddress}) async {
    if (_currentPosition == null || _waypoints.isEmpty) {
      return;
    }
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
      _selectedPlaceName = placeName ?? _selectedPlaceName;
      _selectedPlaceAddress = placeAddress ?? _selectedPlaceAddress;
      _estimatedTime = null;
      _distance = null;
      // Hide search widget when a place is selected
      _showSearchWidget = false;
    });
    
    // Create a list of coordinates starting with current position
    List<List<double>> coordinates = [
      [_currentPosition!.longitude.toDouble(), _currentPosition!.latitude.toDouble()]
    ];
    
    // Add all waypoints
    for (var waypoint in _waypoints) {
      coordinates.add([
        waypoint.coordinates.lng.toDouble(),
        waypoint.coordinates.lat.toDouble()
      ]);
    }
    
    // Get directions with multiple waypoints
    final directions = await _mapboxService.getDirectionsWithMultipleWaypoints(coordinates);
    
    // Hide loading indicator
    setState(() {
      _isLoading = false;
    });
    
    if (directions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get directions')),
      );
      return;
    }
    
    // Extract navigation instructions
    _navigationInstructions = _mapboxService.extractInstructions(directions);
    
    // Set the current instruction if available
    if (_navigationInstructions.isNotEmpty) {
      setState(() {
        _currentInstruction = _navigationInstructions.first;
      });
    }
    
    // Draw the route using RouteLineManager
    await _routeLineManager.drawRoute(directions, isNavigationMode: _isInNavigationMode);
    
    // Make sure waypoint markers are shown on top of the route
    await _addWaypointMarkers();
    
    // Update UI with route details
    if (directions.routes.isNotEmpty) {
      final route = directions.routes.first;
      setState(() {
        _estimatedTime = route.duration / 60; // Convert to minutes
        _distance = route.distance / 1000; // Convert to kilometers
      });
      
      // If this is the first time getting directions, fit the map to show the entire route
      if (_waypoints.length == 1) {
        _fitRouteInView();
      }
    }
  }
  
  // Fit the map view to show both current location and all waypoints
  void _fitRouteInView() {
    if (mapboxMap == null || _currentPosition == null || _waypoints.isEmpty) return;
    
    // Create a list of points including current location and all waypoints
    List<Point> points = [
      Point(
        coordinates: Position(
          _currentPosition!.longitude,
          _currentPosition!.latitude
        )
      ),
    ];
    
    // Add all waypoints
    for (var waypoint in _waypoints) {
      points.add(waypoint);
    }
    
    // Create edge insets for padding
    MbxEdgeInsets padding = MbxEdgeInsets(top: 100, left: 50, bottom: 300, right: 50);
    
    // Calculate the camera options to fit all points
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
  
  void _startNavigation(Point destination, {String? placeName, String? placeAddress}) {
    _addWaypoint(destination, placeName: placeName, placeAddress: placeAddress);
  }
  
  void _clearRoute() {
    _routeLineManager.clearRoute();
    
    // Remove all waypoint markers
    if (mapboxMap != null) {
      final style = mapboxMap!.style;
      // Use a delayed execution to avoid frame drops
      Future.delayed(Duration(milliseconds: 50), () {
        for (int i = 0; i < 20; i++) { // Use a larger number to ensure all markers are removed
          safelyRemoveLayer(style, 'waypoint-layer-$i');
          safelyRemoveLayer(style, 'waypoint-background-$i');
          safelyRemoveLayer(style, 'waypoint-shadow-$i');
          safelyRemoveSource(style, 'waypoint-source-$i');
        }
      });
    }
    
    setState(() {
      _waypoints.clear();
      _waypointNames.clear();
      _waypointAddresses.clear();
      _selectedPlaceName = null;
      _selectedPlaceAddress = null;
      _estimatedTime = null;
      _distance = null;
    });
  }
  
  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c; // Distance in km
    return distance;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  void _selectPlace(Prediction prediction) {
    if (prediction.lat != null && prediction.lng != null) {
      try {
        final double lat = double.parse(prediction.lat!);
        final double lng = double.parse(prediction.lng!);
        
        // Create a Mapbox Point from the Google Places coordinates
        final point = Point(
          coordinates: Position(
            lng, // Longitude first for Mapbox
            lat, // Latitude second for Mapbox
          ),
        );
        
        // Extract place name (first part of description)
        String? placeName = prediction.description?.split(',').firstOrNull?.trim();
        
        // Call the callback with the selected coordinates and place details
        _startNavigation(
          point,
          placeName: placeName,
          placeAddress: prediction.description,
        );
        
        // Fetch weather data for the selected location
        _fetchWeatherForSelectedPlace(lat, lng);
        
        // Clear search
        setState(() {
          _predictions = [];
          _searchController.clear();
        });
      } catch (e) {
        print("Error parsing coordinates: $e");
        // Don't show error message here as it might be confusing if route still works
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: const Text('ICDA Navigation'),
        actions: [
          // Profile button - only show when not in navigation or simulation mode
          if (!_isInNavigationMode && !_isSimulating)
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              tooltip: 'Profile',
            ),
          // GPS button
          IconButton(
            icon: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() {
                _isFollowingUser = !_isFollowingUser;
                // Exit navigation mode if we stop following
                if (!_isFollowingUser) {
                  _isInNavigationMode = false;
                }
              });
              if (_isFollowingUser) {
                _centerOnUserLocation();
              }
            },
          ),
          // Clear route button
          if (_waypoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (_isSimulating) {
                  _stopSimulation();
                } else if (_isInNavigationMode) {
                  _stopNavigation();
                } else {
                  _clearRoute();
                  setState(() {
                    _isInNavigationMode = false;
                  });
                }
                // Always center on user's current GPS location
                _centerOnUserLocation();
              },
              tooltip: 'Clear Route',
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search component - show when _showSearchWidget is true OR when no waypoints exist (initial state)
              if ((_showSearchWidget || _waypoints.isEmpty) && !_isInNavigationMode)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _searchController,
                        googleAPIKey: AppConfig.googleApiKey ?? '',
                        inputDecoration: InputDecoration(
                          hintText: 'Search for a destination',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _predictions = [];
                                  });
                                },
                              )
                            : null,
                        ),
                        debounceTime: 500,
                        countries: const ["my"], // Malaysia
                        isLatLngRequired: true,
                        getPlaceDetailWithLatLng: (Prediction prediction) {
                          _selectPlace(prediction);
                        },
                        itemClick: (Prediction prediction) {
                          _searchController.text = prediction.description ?? "";
                          _searchController.selection = TextSelection.fromPosition(
                            TextPosition(offset: prediction.description?.length ?? 0)
                          );
                          setState(() {
                            _predictions = [];
                          });
                          _selectPlace(prediction);
                        },
                        isCrossBtnShown: false,
                        containerVerticalPadding: 12,
                        // Custom item builder with distance calculation
                        itemBuilder: (context, index, Prediction prediction) {
                          // Calculate distance if coordinates are available
                          String distanceText = '';
                          if (_currentPosition != null && 
                              prediction.lat != null && 
                              prediction.lng != null) {
                            try {
                              final double predLat = double.parse(prediction.lat!);
                              final double predLng = double.parse(prediction.lng!);
                              final double distance = _calculateDistance(
                                _currentPosition!.latitude, _currentPosition!.longitude, 
                                predLat, predLng);
                              
                              distanceText = ' (${distance.toStringAsFixed(1)} km)';
                            } catch (e) {
                              // Ignore parsing errors
                            }
                          }
                          
                          // Get place name (first part of the description)
                          String title = prediction.description?.split(',').firstOrNull?.trim() ?? "";
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        prediction.description ?? "",
                                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                if (distanceText.isNotEmpty)
                                  Text(
                                    distanceText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
              // Points of Interest - show when search widget is visible OR when no waypoints exist, and not in navigation mode
              if ((_showSearchWidget || _waypoints.isEmpty) && !_isInNavigationMode && _currentPosition != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: PointsOfInterest(
                    latitude: _currentPosition!.latitude,
                    longitude: _currentPosition!.longitude,
                    onPoiSelected: _startNavigation,
                    onPoiUnselected: _clearRoute,
                    searchController: _searchController,
                  ),
                ),
              
              // Map container
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Hide weather detail when tapping on the map
                    if (_showWeatherDetail) {
                      setState(() {
                        _showWeatherDetail = false;
                      });
                    }
                  },
                  child: MapWidget(
                    key: const ValueKey("mapWidget"),
                    styleUri: AppConfig.mapboxStyleUrl ?? 'mapbox://styles/mapbox/streets-v12',
                    onMapCreated: _onMapCreated,
                    // Don't set initial camera position here - we'll do it in _onMapCreated
                    // to ensure we use the actual current location
                  ),
                ),
              ),
            ],
          ),
          


          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
            
          // Remove standalone weather test button



          // Current instruction display
          if (_isInNavigationMode && _currentInstruction != null)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getInstructionIcon(_currentInstruction!.detailedType),
                                  color: Colors.green,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentInstruction!.instruction,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_currentInstruction!.distance > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 40),
                                child: Text(
                                  _formatDistance(_currentInstruction!.distance),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Speed limit indicator
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 60,
                        height: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isOverSpeedLimit ? Colors.red.withOpacity(0.2) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isOverSpeedLimit ? Colors.red.shade700 : Colors.red,
                                  width: _isOverSpeedLimit ? 3.5 : 3,
                                ),
                              ),
                              child: Text(
                                '$_currentSpeedLimit',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isOverSpeedLimit ? Colors.red.shade700 : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'km/h',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isOverSpeedLimit ? Colors.red.shade700 : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Weather widget - positioned as a small circular icon
          if (_currentWeather != null && _isInNavigationMode)
            Positioned(
              top: 16,
              right: 70, // Position to the left of the settings button
              child: GestureDetector(
                onTap: () {
                  // Toggle weather detail container visibility
                  setState(() {
                    _showWeatherDetail = !_showWeatherDetail;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Weather icon
                      _currentWeather!.getIconUrl().isNotEmpty
                          ? Image.network(
                              _currentWeather!.getIconUrl(),
                              width: 36,
                              height: 36,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.cloud,
                                  size: 26,
                                  color: Colors.blue,
                                );
                              },
                            )
                          : Icon(
                              Icons.cloud,
                              size: 26,
                              color: Colors.blue,
                            ),
                      // Temperature overlay at the bottom
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentWeather!.getTemperatureCelsius().round().toString() + '°',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Weather detail container - shows when weather icon is clicked
          if (_showWeatherDetail && _currentWeather != null && _isInNavigationMode)
            Positioned(
              top: 70, // Below the weather icon
              right: 16,
              left: 16, // Add left constraint to prevent overflow
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Weather Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _showWeatherDetail = false;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Weather content
                        Row(
                          children: [
                            // Weather icon
                            _currentWeather!.getIconUrl().isNotEmpty
                                ? Image.network(
                                    _currentWeather!.getIconUrl(),
                                    width: 50,
                                    height: 50,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.cloud,
                                        size: 40,
                                        color: Colors.blue,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.cloud,
                                    size: 40,
                                    color: Colors.blue,
                                  ),
                            const SizedBox(width: 12),
                            // Weather info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentWeather!.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    _currentWeather!.getFormattedTemperature(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    _currentWeather!.getWeatherDescription(),
                                    style: const TextStyle(fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Weather details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCompactWeatherDetail(
                              Icons.water_drop,
                              '${_currentWeather!.main.humidity}%',
                              'Humidity',
                            ),
                            _buildCompactWeatherDetail(
                              Icons.air,
                              '${_currentWeather!.wind.speed.toStringAsFixed(1)} m/s',
                              'Wind',
                            ),
                            _buildCompactWeatherDetail(
                              Icons.thermostat,
                              '${(_currentWeather!.main.feelsLike - 273.15).toStringAsFixed(1)}°C',
                              'Feels like',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Turn signal indicators positioned under the instruction container
          if ((_isInNavigationMode || _isSimulating) && (_showLeftTurnSignal || _showRightTurnSignal || _showStraightSignal))
            Positioned(
              top: 170, // Under the instruction container (70 + 70 for instruction height)
              left: 16,
              right: 16,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_animationController.value * 0.25), // Increased pulsing effect
                      child: Container(
                        width: 60, // Bigger container
                        height: 60, // Bigger container
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 199, 17).withOpacity(0.95),
                          shape: BoxShape.circle, // Circular shape for better visual impact
                          border: Border.all(color: Colors.orange.shade700, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            // Add glow effect
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _showLeftTurnSignal ? Icons.arrow_back :
                            _showRightTurnSignal ? Icons.arrow_forward :
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 36, // Bigger icon
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Speed display - positioned above bottom panel in navigation/simulation mode
          if ((_isInNavigationMode || _isSimulating) && _currentPosition != null)
            Positioned(
              bottom: () {
                if (_waypoints.isEmpty) return 16.0; // No bottom panel

                // Calculate bottom panel height
                double bottomPanelHeight = 195.0; // Base panel height
                if (_isSimulating && !_isSimulationPanelCollapsed) {
                  bottomPanelHeight = 340.0; // Expanded simulation panel
                }

                return bottomPanelHeight + 16.0; // 16px above the bottom panel
              }(),
              left: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showSpeedLimitInIndicator = !_showSpeedLimitInIndicator;
                  });
                },
                child: SpeedIndicator(
                  speed: _currentPosition!.speed * 3.6, // Convert m/s to km/h
                  speedLimit: _currentSpeedLimit,
                  isOverLimit: _isOverSpeedLimit,
                  showSpeedLimit: _showSpeedLimitInIndicator,
                ),
              ),
            ),
            
          // Route details panel
          if (_waypoints.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with destination and exit button (if in navigation mode)
                    if (_isInNavigationMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _waypointNames.isNotEmpty ? _waypointNames.last : 'Destination',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.red),
                            onPressed: () {
                              if (_isSimulating) {
                                _stopSimulation();
                              } else {
                                _stopNavigation();
                              }
                              // Always center on user's current GPS location
                              _centerOnUserLocation();
                            },
                            tooltip: 'Exit Navigation',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                        
                    // Show detailed weather information when clicked (moved compact weather to route summary row)
                    if (_showWeatherDetail && _currentWeather != null && !_isInNavigationMode)
                      _buildDetailedWeatherWidget(),
                        
                    // Compact waypoints list (for multiple waypoints)
                    if (_waypoints.length > 1)
                      SizedBox(
                        height: 80, // Fixed height for waypoints list
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _waypoints.length,
                          itemBuilder: (context, i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        i < _waypointNames.length ? _waypointNames[i] : 'Waypoint ${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (i < _waypointAddresses.length && _waypointAddresses[i] != null)
                                        Text(
                                          _waypointAddresses[i]!.length > 25 
                                            ? '${_waypointAddresses[i]!.substring(0, 25)}...' 
                                            : _waypointAddresses[i]!,
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  if (!_isInNavigationMode)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeWaypoint(i),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    
                    // Integrated compact route summary with action buttons
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Compact route summary row
                          Row(
                            children: [
                              // Add Stop button (search icon)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showSearchWidget = !_showSearchWidget;
                                  });
                                  if (_showSearchWidget) {
                                    // Focus the search field when showing
                                    Future.delayed(Duration(milliseconds: 100), () {
                                      FocusScope.of(context).requestFocus(_searchFocusNode);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (_showSearchWidget || _waypoints.isEmpty) ? Colors.blue.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: (_showSearchWidget || _waypoints.isEmpty) ? Colors.blue.shade600 : Colors.grey.shade600,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // ETA and route info (compact)
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ETA time (prominent)
                                    if (_estimatedTime != null)
                                      Text(
                                        _getEstimatedArrivalTime(_estimatedTime!),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),

                                    // Duration and distance (compact single line)
                                    if (_estimatedTime != null && _distance != null)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${_estimatedTime!.toStringAsFixed(0)} min',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 6),
                                            width: 3,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade400,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            _distance! < 1
                                                ? '${(_distance! * 1000).toStringAsFixed(0)} m'
                                                : '${_distance!.toStringAsFixed(1)} km',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              // Weather icon (compact)
                              if (_currentWeather != null && !_isInNavigationMode)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showWeatherDetail = !_showWeatherDetail;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Weather icon
                                        _currentWeather!.getIconUrl().isNotEmpty
                                            ? Image.network(
                                                _currentWeather!.getIconUrl(),
                                                width: 16,
                                                height: 16,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.cloud,
                                                    size: 16,
                                                    color: Colors.blue.shade600,
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.cloud,
                                                size: 16,
                                                color: Colors.blue.shade600,
                                              ),
                                        const SizedBox(width: 4),
                                        // Temperature
                                        Text(
                                          '${_currentWeather!.getTemperatureCelsius().round()}°',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Action buttons row
                          if (!_isInNavigationMode)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startTurnByTurnNavigation,
                                    icon: const Icon(Icons.navigation),
                                    label: const Text('Start'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _startSimulation,
                                    icon: const Icon(Icons.directions_run),
                                    label: const Text('Simulate'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    if (_isSimulating)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isPaused ? 'PAUSED' : 'SIMULATION MODE',
                                  style: TextStyle(
                                    color: _isPaused ? Colors.red[700] : Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Pause/Resume button
                                IconButton(
                                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                                  onPressed: _togglePauseResume,
                                  color: _isPaused ? Colors.red[700] : Colors.amber[800],
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                                // Toggle panel visibility button
                                IconButton(
                                  icon: Icon(_isSimulationPanelCollapsed ? Icons.expand_more : Icons.expand_less),
                                  onPressed: () {
                                    setState(() {
                                      _isSimulationPanelCollapsed = !_isSimulationPanelCollapsed;
                                    });
                                  },
                                  color: Colors.amber[800],
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (!_isSimulationPanelCollapsed) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Speed: '),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: _decreaseSimulationSpeed,
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_simulationSpeed.toStringAsFixed(1)}×',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: _increaseSimulationSpeed,
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Add manual instruction controls
                              if (_navigationInstructions.isNotEmpty)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Instructions: '),
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous),
                                      onPressed: _previousInstruction,
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_navigationService.currentInstructionIndex + 1}/${_navigationInstructions.length}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next),
                                      onPressed: _nextInstruction,
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Navigation settings button
          if (_isInNavigationMode)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  _showSettingsDialog();
                },
                tooltip: 'Navigation Settings',
                child: const Icon(Icons.settings, color: Colors.black54),
              ),
            ),
          
          // Add debug controls for safety tips
          if (_isInNavigationMode)
            _buildDebugControls(),
        ],
      ),
    ),

        // Full-screen twinkling overspeed warning overlay
        if (_isOverSpeedLimit && _isInNavigationMode)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              // Create twinkling effect with multiple frequencies for more dynamic effect
              double time = _animationController.value * 2 * math.pi;

              // Combine multiple sine waves for complex twinkling pattern
              double twinkle1 = math.sin(time * 4); // Fast twinkle
              double twinkle2 = math.sin(time * 2.5); // Medium twinkle
              double twinkle3 = math.sin(time * 1.5); // Slow twinkle

              // Create sharp on/off effect with varying intensities
              double combinedTwinkle = (twinkle1 + twinkle2 * 0.7 + twinkle3 * 0.5) / 2.2;

              // Sharp threshold for dramatic twinkling
              double opacity;
              if (combinedTwinkle > 0.3) {
                opacity = 0.25; // Bright flash
              } else if (combinedTwinkle > -0.2) {
                opacity = 0.12; // Medium flash
              } else {
                opacity = 0.03; // Almost off
              }

              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(opacity),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  
  String _getEstimatedArrivalTime(double minutes) {
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: minutes.round()));
    final hour = arrivalTime.hour;
    final minute = arrivalTime.minute;
    
    // Format as HH:MM AM/PM
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    
    return '$formattedHour:$formattedMinute $period';
  }

  // Start turn-by-turn navigation mode
  void _startTurnByTurnNavigation() {
    if (_currentPosition == null || _waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start navigation without current location or destination')),
      );
      return;
    }
    
    // Set camera to follow user with heading up orientation
    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude
          )
        ),
        zoom: 18.0,
        bearing: _currentPosition!.heading,
        pitch: 60.0, // Tilt the map for better navigation view
      ),
      MapAnimationOptions(duration: 1000, startDelay: 0),
    );
    
    // Enable follow mode with heading
    setState(() {
      _isFollowingUser = true;
      _isInNavigationMode = true;
    });
    
    // Update route line to thicker style for navigation
    _routeLineManager.updateRouteForNavigation();
    
    // Start voice navigation if we have instructions
    if (_navigationInstructions.isNotEmpty) {
      _navigationService.startNavigation(_navigationInstructions);
    }
    
    // Initialize estimated time and distance
    if (_currentPosition != null) {
      _updateEstimatedTimeAndDistance(_currentPosition!);
    }
    
    // Start safety tips
    _startSafetyTips();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation started - following your position')),
    );
  }
  
  // Update the UI based on navigation mode
  void _updateNavigationUI() {
    if (_isInNavigationMode && mapboxMap != null && _currentPosition != null) {
      // Keep the map centered on user position with heading up
      mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude
            )
          ),
          bearing: _currentPosition!.heading,
          // Keep the current zoom level
          zoom: 18.0,
          pitch: 60.0,
        ),
        MapAnimationOptions(duration: 300, startDelay: 0),
      );
    }
  }

  // Start simulation mode for testing navigation
  void _startSimulation() {
    if (_waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _isSimulationPanelCollapsed = false; // Ensure panel is expanded when starting
    });
    
    // Temporarily disable real position updates during simulation
    _positionStreamSubscription?.pause();
    
    // Get the route coordinates for simulation
    _getSimulationRoute().then((directions) {
      setState(() {
        _isLoading = false;
        _isSimulating = true;
        _isInNavigationMode = true;
        _isFollowingUser = true;
        _simulationIndex = 0;
        _simulationSpeed = 1.0; // Reset to default speed
        _interpolationProgress = 0.0;
        _isPaused = false;
        
        // Initialize interpolation points
        if (_simulationRoute.isNotEmpty) {
          _currentSimPoint = _simulationRoute[0];
          _nextSimPoint = _simulationIndex + 1 < _simulationRoute.length 
              ? _simulationRoute[1] 
              : null;
              
          // Initialize bearing if we have at least two points
          if (_nextSimPoint != null) {
            _targetBearing = _calculateBearing(
              _currentSimPoint![1], // lat1
              _currentSimPoint![0], // lon1
              _nextSimPoint![1],    // lat2
              _nextSimPoint![0]     // lon2
            );
            _simulationBearing = _targetBearing;
          }
        }
      });
      
      // Update route line to thicker style for navigation
      _routeLineManager.updateRouteForNavigation();
      
      // Extract navigation instructions if we have directions
      if (directions != null) {
        _navigationInstructions = _mapboxService.extractInstructions(directions);
        
        // Set the current instruction if available
        if (_navigationInstructions.isNotEmpty) {
          setState(() {
            _currentInstruction = _navigationInstructions.first;
          });
          
          // Log the instructions for debugging
          for (int i = 0; i < _navigationInstructions.length; i++) {
            final instr = _navigationInstructions[i];
            print("Instruction $i: ${instr.instruction}, type: ${instr.type}, distance: ${instr.distance}");
            if (instr.location != null) {
              print("  Location: ${instr.location![0]}, ${instr.location![1]}");
            }
          }
          
          // Create initial position and update UI
          if (_simulationRoute.isNotEmpty) {
            // Create a simulated position based on the first point
            final initialPosition = _createSimulatedPosition(
              _currentSimPoint![1], 
              _currentSimPoint![0],
              _simulationBearing, 
              0.0
            );

            setState(() {
              _currentPosition = initialPosition;
            });
            
            _updateCurrentLocationMarker();
            
            // Start navigation service with initial position
            Future.delayed(Duration(milliseconds: 500), () {
              // Initialize navigation service
              _navigationService.startNavigation(_navigationInstructions);
              
              // Force update all instruction distances based on initial position
              _updateAllInstructionDistances(initialPosition);
              
              // Start safety tips
              _startSafetyTips();
            });
          }
        }
      }
      
      // Create a simulated position based on the first point
      if (_simulationRoute.isNotEmpty) {
        // Start the simulation timer - update more frequently for smoother animation
        _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          _updateSimulatedPosition();
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation simulation started')),
      );
    });
  }
  
  // Get route coordinates for simulation
  Future<directions.Directions?> _getSimulationRoute() async {
    if (_currentPosition == null || _waypoints.isEmpty) return null;
    
    // Create a list of coordinates starting with current position
    List<List<double>> coordinates = [
      [_currentPosition!.longitude.toDouble(), _currentPosition!.latitude.toDouble()]
    ];
    
    // Add all waypoints
    for (var waypoint in _waypoints) {
      coordinates.add([
        waypoint.coordinates.lng.toDouble(),
        waypoint.coordinates.lat.toDouble()
      ]);
    }
    
    // Get directions with multiple waypoints
    final directions = await _mapboxService.getDirectionsWithMultipleWaypoints(coordinates);
    
    if (directions == null || directions.routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get route for simulation')),
      );
      return null;
    }
    
    // Extract coordinates from the route geometry
    _simulationRoute = _extractRouteCoordinates(directions.routes.first);
    
    print("Simulation route has ${_simulationRoute.length} points");
    
    return directions;
  }
  
  // Extract coordinates from route geometry
  List<List<double>> _extractRouteCoordinates(directions.Route route) {
    List<List<double>> coordinates = [];
    
    if (route.geometry is Map) {
      // This is a GeoJSON object
      if (route.geometry['type'] == 'LineString' && route.geometry['coordinates'] != null) {
        var coords = route.geometry['coordinates'];
        if (coords is List) {
          coordinates = List<List<double>>.from(coords.map((coord) {
            if (coord is List) {
              return List<double>.from(coord.map((v) => v.toDouble()));
            }
            return <double>[];
          }));
        }
      }
    }
    
    return coordinates;
  }
  
  // Update the simulated position
  void _updateSimulatedPosition() {
    if (_simulationRoute.isEmpty || 
        _currentSimPoint == null || 
        (_nextSimPoint == null && _interpolationProgress >= 1.0)) {
      // End of route, stop simulation
      if (_isSimulating) {
        _stopSimulation();
      }
      return;
    }
    
    // Skip updates if paused
    if (_isPaused) {
      return;
    }
    
    // If we need to move to the next point pair
    if (_interpolationProgress >= 1.0) {
      _simulationIndex += 1;
      _interpolationProgress = 0.0;
      
      // Update current and next points
      _currentSimPoint = _nextSimPoint;
      _nextSimPoint = _simulationIndex + 1 < _simulationRoute.length 
          ? _simulationRoute[_simulationIndex + 1] 
          : null;
      
      // Check if we're close to any instruction point
      if (_isInNavigationMode && _navigationInstructions.isNotEmpty) {
        _checkForNearbyInstructions(_currentSimPoint!);
      }
      
      // If we've reached the end
      if (_nextSimPoint == null) {
        // Create final position at the destination
        if (_currentSimPoint != null) {
          final finalPosition = _createSimulatedPosition(
            _currentSimPoint![1], 
            _currentSimPoint![0],
            _simulationBearing, 
            0.0
          );
          
          setState(() {
            _currentPosition = finalPosition;
          });
          
          _updateCurrentLocationMarker();
          _updateNavigationUI();
          
          // Check for final instruction update
          if (_isInNavigationMode && _navigationInstructions.isNotEmpty) {
            _navigationService.updatePosition(finalPosition, _navigationInstructions);
            _updateCurrentInstructionDisplay();
            
            // Announce arrival at destination
            if (_navigationService.currentInstructionIndex == _navigationInstructions.length - 1) {
              _navigationService.speakInstruction(_navigationInstructions.last);
            }
          }
          
          // Wait a moment at the destination before stopping
          Future.delayed(const Duration(seconds: 2), () {
            if (_isSimulating) {
              _stopSimulation();
            }
          });
        }
        return;
      }
    }
    
    // If we have both current and next points, interpolate between them
    if (_currentSimPoint != null && _nextSimPoint != null) {
      // Calculate target bearing to next point
      _targetBearing = _calculateBearing(
        _currentSimPoint![1], // lat1
        _currentSimPoint![0], // lon1
        _nextSimPoint![1],    // lat2
        _nextSimPoint![0]     // lon2
      );
      
      // Calculate the angle difference for the turn
      double angleDiff = (_targetBearing - _simulationBearing).abs();
      if (angleDiff > 180) angleDiff = 360 - angleDiff;
      
      // Calculate the segment length
      double segmentLength = _calculateDistance(
        _currentSimPoint![1], _currentSimPoint![0],
        _nextSimPoint![1], _nextSimPoint![0]
      ) * 1000; // Convert to meters
      
      // Look ahead to check if we're in a curve (series of short segments with direction changes)
      bool isInCurve = false;
      double curvature = 0.0;
      
      if (_simulationIndex + 2 < _simulationRoute.length) {
        // Get the next-next point
        List<double> nextNextPoint = _simulationRoute[_simulationIndex + 2];
        
        // Calculate the angle between current->next and next->nextnext segments
        double nextBearing = _calculateBearing(
          _nextSimPoint![1], _nextSimPoint![0],
          nextNextPoint[1], nextNextPoint[0]
        );
        
        double nextAngleDiff = (nextBearing - _targetBearing).abs();
        if (nextAngleDiff > 180) nextAngleDiff = 360 - nextAngleDiff;
        
        // If there's a significant angle change and segments are short, we're in a curve
        double nextSegmentLength = _calculateDistance(
          _nextSimPoint![1], _nextSimPoint![0],
          nextNextPoint[1], nextNextPoint[0]
        ) * 1000; // Convert to meters
        
        isInCurve = (nextAngleDiff > 20 && segmentLength < 50 && nextSegmentLength < 50);
        curvature = nextAngleDiff / 180.0; // Normalized curvature (0-1)
      }
      
      // Adjust speed factor based on segment properties
      double speedFactor;
      
      if (isInCurve) {
        // In curves, maintain a consistent but slower speed
        speedFactor = 0.03 * _simulationSpeed * (1 - curvature * 0.5);
      } else if (segmentLength < 20) {
        // For very short segments (likely part of a complex shape), move faster
        speedFactor = 0.04 * _simulationSpeed;
      } else if (angleDiff > 45) {
        // Slow down for sharp turns
        speedFactor = 0.02 * _simulationSpeed * (1 - (angleDiff / 180) * 0.7);
      } else {
        // Normal speed for straight segments
        speedFactor = 0.025 * _simulationSpeed;
      }
      
      // Ensure minimum speed
      speedFactor = math.max(speedFactor, 0.005);
      
      _interpolationProgress += speedFactor;
      _interpolationProgress = math.min(_interpolationProgress, 1.0);
      
      // Linear interpolation between points
      double lat = _linearInterpolate(_currentSimPoint![1], _nextSimPoint![1], _interpolationProgress);
      double lng = _linearInterpolate(_currentSimPoint![0], _nextSimPoint![0], _interpolationProgress);
      
      // Smoothly interpolate bearing - adjust factor based on context
      double bearingFactor;
      if (isInCurve) {
        // Faster bearing changes in curves for smoother appearance
        bearingFactor = 0.2;
      } else if (angleDiff > 45) {
        // Faster rotation for sharp turns
        bearingFactor = 0.15;
      } else {
        // Normal rotation for gentle turns
        bearingFactor = 0.08;
      }
      
      _simulationBearing = _interpolateBearing(_simulationBearing, _targetBearing, bearingFactor);
      
      // Calculate speed based on context (in m/s)
      double speed;
      if (isInCurve) {
        // Lower speed in curves
        speed = 10.0 * _simulationSpeed * (1 - curvature * 0.5);
      } else if (angleDiff > 30) {
        // Lower speed in turns
        speed = 8.0 * _simulationSpeed * (1 - (angleDiff / 180) * 0.5);
      } else if (_currentSpeedLimit < 60) {
        // Lower speed in low speed limit areas
        speed = 8.0 * _simulationSpeed;
      } else {
        // Normal speed with adjustment for turns
        speed = 15.0 * _simulationSpeed * (1 - (angleDiff / 180) * 0.5);
      }
      
      // Create a simulated position
      final simulatedPosition = _createSimulatedPosition(
        lat, 
        lng,
        _simulationBearing, 
        speed
      );
      
      // Update current position with simulated one
      setState(() {
        _currentPosition = simulatedPosition;
      });
      
      // Update the UI
      if (mapboxMap != null) {
        _updateCurrentLocationMarker();
        
        // Update navigation instructions based on simulated position
        if (_isInNavigationMode && _navigationInstructions.isNotEmpty) {
          // Check for nearby instructions every few frames
          if (_simulationIndex % 5 == 0) {
            _checkForNearbyInstructions([lng, lat]);
          }
          
          // Update the current instruction display
          if (_navigationService.currentInstructionIndex < _navigationInstructions.length) {
            setState(() {
              _currentInstruction = _navigationInstructions[_navigationService.currentInstructionIndex];
            });
          }
          
          // Periodically update the instruction distances
          if (_simulationIndex % 10 == 0) {
            _updateAllInstructionDistances(simulatedPosition);
            _updateEstimatedTimeAndDistance(simulatedPosition);
            _checkForUpcomingTurnSignals(simulatedPosition);
          }
        }
        
        if (_isInNavigationMode) {
          _updateNavigationUI();
        }
      }
    }
  }
  
  // Check for upcoming turn signals when within 500m of turn instructions
  void _checkForUpcomingTurnSignals(geo.Position position) {
    if (!_isInNavigationMode || _navigationInstructions.isEmpty) {
      // Reset turn signals if not in navigation mode
      if (_showLeftTurnSignal || _showRightTurnSignal || _showStraightSignal) {
        setState(() {
          _showLeftTurnSignal = false;
          _showRightTurnSignal = false;
          _showStraightSignal = false;
          _upcomingTurnInstruction = null;
        });
      }
      return;
    }

    NavigationInstruction? nextTurnInstruction;
    double closestTurnDistance = double.infinity;

    // Look for the next turn instruction within 500m
    for (int i = _navigationService.currentInstructionIndex; i < _navigationInstructions.length; i++) {
      final instruction = _navigationInstructions[i];

      // Skip if no location data
      if (instruction.location == null) continue;

      // Calculate distance to this instruction
      final distance = _calculateDistance(
        position.latitude, position.longitude,
        instruction.location![1], instruction.location![0]
      ) * 1000; // Convert to meters

      print("Checking instruction $i: '${instruction.instruction}', distance: ${distance.toInt()}m");

      // Check if this is a turn instruction within 500m
      if (_isTurnInstruction(instruction) && distance <= 500 && distance < closestTurnDistance) {
        nextTurnInstruction = instruction;
        closestTurnDistance = distance;
        print("Found turn instruction within 500m: '${instruction.instruction}' at ${distance.toInt()}m");
        break; // Take the first (closest) turn instruction
      }
    }

    // Update turn signal state based on upcoming turn
    bool newLeftSignal = false;
    bool newRightSignal = false;
    bool newStraightSignal = false;

    if (nextTurnInstruction != null) {
      final direction = _getTurnDirection(nextTurnInstruction);
      print("Turn signal debug: Upcoming instruction: '${nextTurnInstruction.instruction}', Type: '${nextTurnInstruction.type}', Modifier: '${nextTurnInstruction.modifier}', Distance: ${closestTurnDistance.toInt()}m, Detected direction: '$direction'");
      switch (direction) {
        case 'left':
          newLeftSignal = true;
          print("Setting LEFT turn signal to true");
          break;
        case 'right':
          newRightSignal = true;
          print("Setting RIGHT turn signal to true");
          break;
        case 'straight':
          newStraightSignal = true;
          print("Setting STRAIGHT turn signal to true");
          break;
      }
    }

    // Update state if signals have changed
    if (newLeftSignal != _showLeftTurnSignal ||
        newRightSignal != _showRightTurnSignal ||
        newStraightSignal != _showStraightSignal ||
        nextTurnInstruction != _upcomingTurnInstruction) {
      print("Turn signal state update: Left=$newLeftSignal, Right=$newRightSignal, Straight=$newStraightSignal");
      setState(() {
        _showLeftTurnSignal = newLeftSignal;
        _showRightTurnSignal = newRightSignal;
        _showStraightSignal = newStraightSignal;
        _upcomingTurnInstruction = nextTurnInstruction;
      });
      print("Turn signal state after update: _showLeftTurnSignal=$_showLeftTurnSignal, _showRightTurnSignal=$_showRightTurnSignal, _showStraightSignal=$_showStraightSignal");
    }
  }

  // Check if an instruction is a turn instruction
  bool _isTurnInstruction(NavigationInstruction instruction) {
    final lowerType = instruction.type.toLowerCase();
    final lowerInstruction = instruction.instruction.toLowerCase();

    return lowerType.contains('turn') ||
           lowerType.contains('exit') ||
           lowerType.contains('roundabout') ||
           lowerType.contains('rotary') ||
           lowerInstruction.contains('turn') ||
           lowerInstruction.contains('exit') ||
           lowerInstruction.contains('roundabout') ||
           lowerInstruction.contains('rotary');
  }

  // Get turn direction from instruction based on keywords
  String _getTurnDirection(NavigationInstruction instruction) {
    final lowerInstruction = instruction.instruction.toLowerCase();

    print("Analyzing instruction: '$lowerInstruction'");

    // Check for specific keywords in the instruction text
    if (lowerInstruction.contains('turn left') ||
        lowerInstruction.contains('left turn') ||
        lowerInstruction.contains('bear left') ||
        lowerInstruction.contains('keep left') ||
        lowerInstruction.contains('exit') ||  // Exit is typically left
        lowerInstruction.contains('take the exit')) {
      print("Detected LEFT turn from instruction");
      return 'left';
    } else if (lowerInstruction.contains('turn right') ||
               lowerInstruction.contains('right turn') ||
               lowerInstruction.contains('bear right') ||
               lowerInstruction.contains('keep right')) {
      print("Detected RIGHT turn from instruction");
      return 'right';
    } else if (lowerInstruction.contains('straight') ||
               lowerInstruction.contains('continue') ||
               lowerInstruction.contains('go straight')) {
      print("Detected STRAIGHT from instruction");
      return 'straight';
    }

    // Default to straight for unclear instructions
    print("No clear direction detected, defaulting to straight");
    return 'straight';
  }

  // Update distances for all instructions based on current position
  void _updateAllInstructionDistances(geo.Position position) {
    for (int i = 0; i < _navigationInstructions.length; i++) {
      final instruction = _navigationInstructions[i];
      if (instruction.location != null) {
        // Calculate distance to the instruction point
        final distance = _calculateDistance(
          position.latitude, position.longitude,
          instruction.location![1], instruction.location![0]
        ) * 1000; // Convert to meters
        
        // Update the distance
        instruction.distance = distance.toInt();
      }
    }
    
    // If we're displaying an instruction, refresh it
    if (_currentInstruction != null) {
      setState(() {
        // This will trigger a UI refresh with the updated distance
      });
    }
  }
  
  // Check if we're close to any instruction points and force update if needed
  void _checkForNearbyInstructions(List<double> position) {
    final double lat = position[1];
    final double lng = position[0];
    
    // First check the current instruction
    int currentIndex = _navigationService.currentInstructionIndex;
    if (currentIndex < _navigationInstructions.length) {
      final instruction = _navigationInstructions[currentIndex];
      if (instruction.location != null) {
        final double instructionLat = instruction.location![1];
        final double instructionLng = instruction.location![0];
        
        // Calculate distance to instruction point
        final double distance = _calculateDistance(
          lat, lng, instructionLat, instructionLng
        ) * 1000; // Convert to meters
        
        print("Current instruction ($currentIndex) distance: $distance meters");
        
        // Update the distance of the current instruction
        instruction.distance = distance.toInt();
        
        // If we're close enough to the instruction point during simulation, announce it
        if (distance < 30 && _isSimulating) {
          print("REACHED INSTRUCTION POINT $currentIndex at distance $distance meters - ANNOUNCING");
          _navigationService.speakInstruction(instruction);
          
          // Move to the next instruction after a short delay
          if (currentIndex < _navigationInstructions.length - 1) {
            Future.delayed(Duration(milliseconds: 1500), () {
              if (_isSimulating) {
                _navigationService.currentInstructionIndex = currentIndex + 1;
                _updateCurrentInstructionDisplay();
              }
            });
          }
        }
      }
    }
    
    // Look ahead for upcoming instructions to see if we should advance
    for (int i = currentIndex + 1; i < _navigationInstructions.length; i++) {
      final instruction = _navigationInstructions[i];
      if (instruction.location != null) {
        final double instructionLat = instruction.location![1];
        final double instructionLng = instruction.location![0];
        
        // Calculate distance to instruction point
        final double distance = _calculateDistance(
          lat, lng, instructionLat, instructionLng
        ) * 1000; // Convert to meters
        
        // If we're very close to an instruction point
        if (distance < 20) {
          print("ADVANCING to nearby instruction at index $i, distance: $distance meters");
          _navigationService.currentInstructionIndex = i;
          _navigationService.speakInstruction(instruction);
          _updateCurrentInstructionDisplay();
          break;
        }
      }
    }
  }
  
  // Helper method to update the current instruction display
  void _updateCurrentInstructionDisplay() {
    if (_navigationService.currentInstructionIndex < _navigationInstructions.length) {
      int newIndex = _navigationService.currentInstructionIndex;
      NavigationInstruction newInstruction = _navigationInstructions[newIndex];
      
      // Only update if the instruction has actually changed
      if (_currentInstruction == null || 
          _currentInstruction!.instruction != newInstruction.instruction ||
          _currentInstruction!.type != newInstruction.type) {
        
        print("Updating instruction display to index $newIndex: ${newInstruction.instruction}");
        setState(() {
          _currentInstruction = newInstruction;
        });
      }
    }
  }
  
  // Linear interpolation between two values
  double _linearInterpolate(double start, double end, double progress) {
    return start + (end - start) * progress;
  }
  
  // Calculate bearing between two coordinates
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final y = math.sin(dLon) * math.cos(_degreesToRadians(lat2));
    final x = math.cos(_degreesToRadians(lat1)) * math.sin(_degreesToRadians(lat2)) -
              math.sin(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * math.cos(dLon);
    
    final bearing = math.atan2(y, x);
    return (_radiansToDegrees(bearing) + 360) % 360; // Convert to degrees and normalize
  }
  
  // Convert radians to degrees
  double _radiansToDegrees(double radians) {
    return radians * 180.0 / math.pi;
  }

  // Interpolate between two bearing angles (handling the 0/360 degree wrap)
  double _interpolateBearing(double currentBearing, double targetBearing, double factor) {
    // Normalize angles to 0-360
    currentBearing = (currentBearing % 360 + 360) % 360;
    targetBearing = (targetBearing % 360 + 360) % 360;
    
    // Find the shortest path (clockwise or counterclockwise)
    double diff = targetBearing - currentBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    
    // Apply interpolation factor
    double newBearing = currentBearing + diff * factor;
    
    // Normalize result
    return (newBearing % 360 + 360) % 360;
  }

  // Increase simulation speed
  void _increaseSimulationSpeed() {
    setState(() {
      // Cap at a reasonable maximum
      if (_simulationSpeed < 10.0) {
        _simulationSpeed += 0.1;
      }
    });
  }
  
  // Decrease simulation speed
  void _decreaseSimulationSpeed() {
    setState(() {
      if (_simulationSpeed > 1.0) {
        _simulationSpeed -= 0.1;
      }
    });
  }

  // Pause the simulation
  void _pauseSimulation() {
    if (!_isSimulating || _isPaused) return;
    
    _simulationTimer?.cancel();
    _simulationTimer = null;
    
    setState(() {
      _isPaused = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulation paused')),
    );
  }
  
  // Resume the simulation
  void _resumeSimulation() {
    if (!_isSimulating || !_isPaused) return;
    
    setState(() {
      _isPaused = false;
    });
    
    // Restart the timer
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateSimulatedPosition();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulation resumed')),
    );
  }
  
  // Toggle pause/resume
  void _togglePauseResume() {
    if (_isPaused) {
      _resumeSimulation();
    } else {
      _pauseSimulation();
    }
  }

  // Get an appropriate icon for the instruction type
  IconData _getInstructionIcon(String type) {
    // Define driving side: true for right-hand side driving (like Malaysia)
    const bool isRightHandDriving = true;
    
    final String lowerType = type.toLowerCase();
    
    if (lowerType.contains('turn')) {
      if (lowerType.contains('left')) {
        return isRightHandDriving ? Icons.turn_left : Icons.turn_right;
      } else if (lowerType.contains('right')) {
        return isRightHandDriving ? Icons.turn_right : Icons.turn_left;
      } else {
        return Icons.turn_right;
      }
    } else if (lowerType.contains('depart')) {
      return Icons.play_arrow;
    } else if (lowerType.contains('arrive')) {
      return Icons.location_on;
    } else if (lowerType.contains('merge')) {
      return Icons.merge_type;
    } else if (lowerType.contains('fork')) {
      return Icons.call_split;
    } else if (lowerType.contains('roundabout')) {
      return isRightHandDriving ? Icons.roundabout_right : Icons.roundabout_left;
    } else if (lowerType.contains('rotary')) {
      return isRightHandDriving ? Icons.roundabout_right : Icons.roundabout_left;
    } else if (lowerType.contains('exit')) {
      if (lowerType.contains('roundabout') || lowerType.contains('rotary')) {
        return Icons.turn_left;
      } else if (lowerType.contains('left')) {
        return isRightHandDriving ? Icons.subdirectory_arrow_left : Icons.subdirectory_arrow_right;
      } else if (lowerType.contains('right')) {
        return isRightHandDriving ? Icons.subdirectory_arrow_right : Icons.subdirectory_arrow_left;
      } else {
        return isRightHandDriving ? Icons.subdirectory_arrow_right : Icons.subdirectory_arrow_left;
      }
    } else if (lowerType.contains('keep') || lowerType.contains('continue')) {
      if (lowerType.contains('left')) {
        return isRightHandDriving ? Icons.arrow_left : Icons.arrow_right;
      } else if (lowerType.contains('right')) {
        return isRightHandDriving ? Icons.arrow_right : Icons.arrow_left;
      } else {
        return Icons.turn_left;
      }
    } else if (lowerType.contains('use lane')) {
      return Icons.airline_stops;
    } else if (lowerType.contains('uturn')) {
      return isRightHandDriving ? Icons.u_turn_right : Icons.u_turn_left;
    } else {
      return Icons.turn_slight_left;
    }
  }
  
  // Format distance for display
  String _formatDistance(int distanceInMeters) {
    if (distanceInMeters >= 1000) {
      final double distanceInKm = distanceInMeters / 1000.0;
      return "${distanceInKm.toStringAsFixed(1)} km";
    } else {
      return "$distanceInMeters m";
    }
  }

  // Stop navigation
  void _stopNavigation() {
    setState(() {
      _isInNavigationMode = false;
      // Reset turn signals
      _showLeftTurnSignal = false;
      _showRightTurnSignal = false;
      _showStraightSignal = false;
      _upcomingTurnInstruction = null;
      if (_isSimulating) {
        _stopSimulation();
        return; // _stopSimulation will handle the rest
      }
    });
    
    // Reset route line style to default
    _routeLineManager.resetRouteStyle();
    
    // Stop voice navigation
    _navigationService.stopNavigation();
    
    // Stop safety tips
    _stopSafetyTips();
    
    // Clear the route and waypoints
    _clearRoute();
    
    // Reset camera view to current location
    _centerOnUserLocation();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation ended')),
    );
  }

  // Stop the simulation
  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    
    setState(() {
      _isSimulating = false;
      _isInNavigationMode = false;
      _currentSimPoint = null;
      _nextSimPoint = null;
      _isPaused = false;
      _isSimulationPanelCollapsed = false;
      // Reset turn signals
      _showLeftTurnSignal = false;
      _showRightTurnSignal = false;
      _showStraightSignal = false;
      _upcomingTurnInstruction = null;
    });
    
    // Stop voice navigation
    _navigationService.stopNavigation();
    
    // Stop safety tips
    _stopSafetyTips();
    
    // Clear the route and waypoints
    _clearRoute();
    
    // Resume real position updates
    _positionStreamSubscription?.resume();
    
    // Restore the actual current position
    if (_positionStreamSubscription != null) {
      _getCurrentLocation();
    } else {
      // If no position subscription, at least center on current position if available
      _centerOnUserLocation();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation simulation stopped')),
    );
  }

  // Add manual instruction controls
  void _previousInstruction() {
    if (_navigationService.currentInstructionIndex > 0) {
      int newIndex = _navigationService.currentInstructionIndex - 1;
      _navigationService.jumpToInstruction(newIndex);
      _updateCurrentInstructionDisplay();
      // Update safety tips context for the new instruction
      _updateSafetyTipContext();
    }
  }

  void _nextInstruction() {
    if (_navigationService.currentInstructionIndex < _navigationInstructions.length - 1) {
      int newIndex = _navigationService.currentInstructionIndex + 1;
      _navigationService.jumpToInstruction(newIndex);
      _updateCurrentInstructionDisplay();
      // Update safety tips context for the new instruction
      _updateSafetyTipContext();
    }
  }

  // Helper method to create a simulated position
  geo.Position _createSimulatedPosition(double lat, double lng, double bearing, double speed) {
    return geo.Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: bearing,
      speed: speed,
      speedAccuracy: 1.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
  }

  // Start showing safety tips
  void _startSafetyTips() {
    print("MapScreen: Starting safety tips");
    
    // Make sure we have a valid reference to the safety tip service
    if (_safetyTipService == null) {
      print("MapScreen: Error - Safety tip service is null");
      return;
    }
    
    // Set tip categories based on user preferences
    _safetyTipService.setCategories(
      safety: _showSafetyTips,
      beginner: _showBeginnerTips
    );
    
    // Reset the current tip and display state
    setState(() {
      _currentTip = null;
      _showTip = false;
    });
    
    // Start the safety tip service
    _safetyTipService.startTips(
      (tip) {
        print("MapScreen: Received new safety tip: ${tip.shortTip}");
        if (mounted) {
          setState(() {
            _currentTip = tip;
            _showTip = true;
          });
          
          // Hide the tip after a few seconds
          _tipDisplayTimer?.cancel();
          _tipDisplayTimer = Timer(Duration(seconds: 8), () {
            if (mounted) {
              setState(() {
                _showTip = false;
              });
            }
          });
        }
      },
      isSimulation: _isSimulating,
      speakTips: _speakTipsEnabled,
      playSounds: _soundsEnabled
    );
    
    // Initialize the navigation context if we already have instructions
    if (_navigationInstructions.isNotEmpty && _currentInstruction != null) {
      _updateSafetyTipContext();
    }
    
    // Force show a tip after startup to ensure tips are working
    Future.delayed(Duration(seconds: 5), () {
      if (_isInNavigationMode && mounted) {
        _forceSafetyTip();
      }
    });
  }
  
  // Force a safety tip to display
  void _forceSafetyTip() {
    print("MapScreen: Forcing a safety tip to display");
    _safetyTipService.showTipNow(speak: _speakTipsEnabled, playSound: _soundsEnabled);
  }
  
  // Stop safety tips
  void _stopSafetyTips() {
    _safetyTipService.stopTips();
    _tipDisplayTimer?.cancel();
    setState(() {
      _showTip = false;
      _currentTip = null;
    });
  }

  // Toggle safety tips
  void _toggleSafetyTips(bool value) {
    setState(() {
      _showSafetyTips = value;
    });
    
    if (_isInNavigationMode) {
      // Update the tip categories if we're currently navigating
      _safetyTipService.setCategories(
        safety: _showSafetyTips,
        beginner: _showBeginnerTips
      );
    }
  }
  
  // Toggle beginner tips
  void _toggleBeginnerTips(bool value) {
    setState(() {
      _showBeginnerTips = value;
    });
    
    if (_isInNavigationMode) {
      // Update the tip categories if we're currently navigating
      _safetyTipService.setCategories(
        safety: _showSafetyTips,
        beginner: _showBeginnerTips
      );
    }
  }
  
  // Toggle speak tips
  void _toggleSpeakTips(bool value) {
    setState(() {
      _speakTipsEnabled = value;
    });
    
    if (_isInNavigationMode) {
      // Update the TTS setting
      _safetyTipService.setVoiceEnabled(value);
    }
  }
  
  // Toggle sound effects
  void _toggleSounds(bool value) {
    setState(() {
      _soundsEnabled = value;
    });
    
    if (_isInNavigationMode) {
      // Update the sound setting
      _safetyTipService.setSoundsEnabled(value);
    }
  }
  
  // Toggle speed warnings
  void _toggleSpeedWarnings(bool value) {
    setState(() {
      _enableSpeedWarnings = value;
      
      // If turning off, hide any active warning
      if (!value && _showSpeedWarning) {
        _showSpeedWarning = false;
        _speedWarningTimer?.cancel();
      }
    });
  }
  
  // Show settings dialog with tip preferences
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Navigation Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Safety Tips'),
              subtitle: Text('Show safety reminders during navigation'),
              value: _showSafetyTips,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleSafetyTips(value);
              },
            ),
            SwitchListTile(
              title: Text('Beginner Tips'),
              subtitle: Text('Show helpful driving tips for beginners'),
              value: _showBeginnerTips,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleBeginnerTips(value);
              },
            ),
            SwitchListTile(
              title: Text('Speak Tips Aloud'),
              subtitle: Text('Use voice to announce safety tips'),
              value: _speakTipsEnabled,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleSpeakTips(value);
              },
            ),
            SwitchListTile(
              title: Text('Sound Effects'),
              subtitle: Text('Play sounds with tips'),
              value: _soundsEnabled,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleSounds(value);
              },
            ),
            SwitchListTile(
              title: Text('Speed Warnings'),
              subtitle: Text('Alert when exceeding speed limit'),
              value: _enableSpeedWarnings,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleSpeedWarnings(value);
              },
            ),
            if (_isInNavigationMode) ...[
              Divider(),
              ListTile(
                title: Text('Show Tip Now'),
                leading: Icon(Icons.tips_and_updates),
                onTap: () {
                  Navigator.pop(context);
                  _safetyTipService.showTipNow(speak: _speakTipsEnabled, playSound: _soundsEnabled);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper method to get icon for safety tip
  IconData _getTipIcon(SafetyTip tip) {
    // If tip has a specific icon type, use that
    if (tip.iconType != null) {
      switch (tip.iconType) {
        case 'turn_signal_left':
          return Icons.switch_left;
        case 'turn_signal_right':
          return Icons.switch_right;
        case 'turn_signal_off':
          return Icons.highlight_off;
        default:
          break;
      }
    }
    
    // Default icons based on category
    return tip.category == 'safety' ? Icons.shield : Icons.lightbulb;
  }

  // Format speed for display
  String _formatSpeed(double speedInMetersPerSecond) {
    // Convert from m/s to km/h
    final speedInKmh = speedInMetersPerSecond * 3.6;
    
    // Round to nearest integer
    final speedValue = speedInKmh.round();
    
    // Check if over speed limit
    setState(() {
      _isOverSpeedLimit = speedValue > _currentSpeedLimit;
    });
    
    return speedValue.toString();
  }

  // Update the speed limit based on the current road segment
  void _updateSpeedLimit() {
    // In a real app, this would come from the navigation data or map data
    // For now, we'll simulate changing speed limits based on the current instruction
    
    if (_currentInstruction != null) {
      String instructionType = _currentInstruction!.type.toLowerCase();
      
      // Set speed limit based on road type
      if (instructionType.contains('highway') || instructionType.contains('motorway')) {
        _currentSpeedLimit = 110;
      } else if (instructionType.contains('trunk') || instructionType.contains('primary')) {
        _currentSpeedLimit = 80;
      } else if (instructionType.contains('secondary')) {
        _currentSpeedLimit = 60;
      } else if (instructionType.contains('residential') || instructionType.contains('tertiary')) {
        _currentSpeedLimit = 50;
      } else if (instructionType.contains('roundabout') || instructionType.contains('rotary')) {
        _currentSpeedLimit = 40;
      } else {
        // Default speed limit
        _currentSpeedLimit = 60;
      }
      
      // If the instruction contains certain keywords, adjust the speed limit
      if (instructionType.contains('school') || 
          _currentInstruction!.instruction.toLowerCase().contains('school')) {
        _currentSpeedLimit = 30;
      } else if (instructionType.contains('construction') || 
                _currentInstruction!.instruction.toLowerCase().contains('construction')) {
        _currentSpeedLimit = 40;
      }
    }
  }

  // Check if the current speed exceeds the speed limit
  void _checkSpeedLimit() {
    if (_currentPosition == null) return;
    
    // Convert speed from m/s to km/h
    final speedKmh = _currentPosition!.speed * 3.6;
    
    // Update UI to show if we're over the speed limit
    final bool wasOverLimit = _isOverSpeedLimit;
    final bool isOverLimit = speedKmh > _currentSpeedLimit;
    
    if (wasOverLimit != isOverLimit) {
      setState(() {
        _isOverSpeedLimit = isOverLimit;
      });
    }
    
    // If speed exceeds limit, show warning
    if (speedKmh > _currentSpeedLimit) {
      // Visual warning (UI element)
      if (!_showSpeedWarning) {
        setState(() {
          _showSpeedWarning = true;
        });
        
        // Play warning sound
        if (_soundsEnabled) {
          try {
            _audioPlayer.play(AssetSource('sounds/speed_warning.mp3'));
          } catch (e) {
            // Fallback to system sound if custom sound fails
            SystemSound.play(SystemSoundType.alert);
            print("Failed to play custom speed warning sound: $e");
          }
        }
        
        // Hide warning after 3 seconds
        _speedWarningTimer?.cancel();
        _speedWarningTimer = Timer(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSpeedWarning = false;
            });
          }
        });
      }
      
      // If significantly over the limit, also trigger a voice safety tip
      // but only if we're more than 10 km/h over and it's been a while since the last warning
      if (_enableSpeedWarnings && 
          speedKmh > (_currentSpeedLimit + 10) &&
          (_lastSpeedWarningTime == null || 
           DateTime.now().difference(_lastSpeedWarningTime!).inSeconds > 30)) {
        
        // Send to safety tip service for voice announcement
        _safetyTipService.showSpeedWarning(speedKmh, _currentSpeedLimit);
        
        // Remember when we last showed a speed warning
        _lastSpeedWarningTime = DateTime.now();
      }
    } else {
      // If speed is back under limit, hide warning immediately
      if (_showSpeedWarning) {
        setState(() {
          _showSpeedWarning = false;
        });
        _speedWarningTimer?.cancel();
      }
    }
  }

  // Format remaining time for display
  String _formatRemainingTime(double minutes) {
    if (minutes < 60) {
      return '${minutes.round()} min remaining';
    } else {
      int hours = (minutes / 60).floor();
      int mins = (minutes % 60).round();
      return '$hours h ${mins > 0 ? '$mins min' : ''} remaining';
    }
  }

  // Update estimated time and distance based on current position
  void _updateEstimatedTimeAndDistance(geo.Position position) {
    if (_waypoints.isEmpty) return;
    
    // Calculate remaining distance to destination
    double remainingDistance = 0.0;
    
    // If we have navigation instructions, use the distance from the current instruction to the end
    if (_navigationInstructions.isNotEmpty && _navigationService.currentInstructionIndex < _navigationInstructions.length) {
      // Sum up the distances of all remaining instructions
      for (int i = _navigationService.currentInstructionIndex; i < _navigationInstructions.length; i++) {
        remainingDistance += _navigationInstructions[i].distance / 1000.0; // Convert to km
      }
    } else {
      // Fallback: calculate direct distance to destination
      final destination = _waypoints.last;
      remainingDistance = _calculateDistance(
        position.latitude, position.longitude,
        destination.coordinates.lat.toDouble(), destination.coordinates.lng.toDouble()
      );
    }
    
    // Calculate remaining time based on current speed
    double avgSpeed;
    
    // Use current speed if it's reasonable (above 7.2 km/h)
    if (position.speed > 2.0) { 
      avgSpeed = position.speed * 3.6; // Convert m/s to km/h
    } else if (_isSimulating) {
      // During simulation, use a more realistic speed based on road type
      avgSpeed = _currentSpeedLimit * 0.8; // 80% of speed limit is typical average speed
    } else {
      // Default average speed when stationary or moving very slowly
      avgSpeed = 40.0; // km/h
    }
    
    // Apply adjustment for traffic conditions (could be expanded with real traffic data)
    // Here we're just using a simple model based on time of day
    final hour = DateTime.now().hour;
    double trafficFactor = 1.0;
    
    // Rush hours: slower speeds
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      trafficFactor = 0.8; // 20% slower during rush hour
    }
    
    // Apply traffic factor
    avgSpeed *= trafficFactor;
    
    // Calculate estimated time in minutes, ensuring we don't divide by zero
    double remainingTime = avgSpeed > 0 ? (remainingDistance / avgSpeed) * 60 : 0;
    
    // Update the state only if values have changed significantly
    if (_distance == null || 
        _estimatedTime == null || 
        (_distance! - remainingDistance).abs() > 0.1 || 
        (_estimatedTime! - remainingTime).abs() > 0.5) {
      setState(() {
        _distance = remainingDistance;
        _estimatedTime = remainingTime;
      });
    }
    
    // Schedule another update shortly if we're navigating
    // This ensures continuous updates even when not receiving new positions
    if (_isInNavigationMode && !_isSimulating) {
      Future.delayed(Duration(seconds: 3), () {
        if (mounted && _isInNavigationMode && _currentPosition != null) {
          _updateEstimatedTimeAndDistance(_currentPosition!);
        }
      });
    }
  }

  // Add debug controls for safety tips
  Widget _buildDebugControls() {
    if (!_isInNavigationMode) return const SizedBox.shrink();

    // Calculate bottom panel height to position debug controls above it
    double bottomPanelHeight = 0;
    if (_waypoints.isNotEmpty) {
      bottomPanelHeight = 170; // Base panel height
      if (_isSimulating && !_isSimulationPanelCollapsed) {
        bottomPanelHeight = 350; // Expanded simulation panel
      }
    }

    return Positioned(
      bottom: bottomPanelHeight + 20, // 20px above the bottom panel
      right: 16,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: "showTipNow",
            onPressed: _forceSafetyTip,
            child: const Icon(Icons.tips_and_updates),
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "restartTips",
            onPressed: () {
              print("Restarting safety tips");
              _stopSafetyTips();
              _startSafetyTips();
            },
            child: const Icon(Icons.refresh),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 8),
          // Add a button to bypass the navigation block
          FloatingActionButton.small(
            heroTag: "unblockTips",
            onPressed: () {
              print("Manually unblocking safety tips");
              _safetyTipService.notifyNavigationInstructionFinished();
            },
            child: const Icon(Icons.pan_tool),
            backgroundColor: Colors.red,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  // Test weather API connectivity
  void _testWeatherAPI() async {
    // First check if API key is configured
    if (!_weatherService.isApiKeyConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ OpenWeatherMap API key not configured. Add OPENWEATHER_API_KEY to your .env file.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location available. Cannot test weather API.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing weather API...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    try {
      setState(() {
        _isLoadingWeather = true;
      });
      
      final weather = await _weatherService.getWeatherForLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude
      );
      
      setState(() {
        _currentWeather = weather;
        _isLoadingWeather = false;
      });
      
      if (weather != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Weather API connected successfully!'),
                Text('Location: ${weather.name}, ${weather.sys.country}'),
                Text('Temperature: ${weather.getFormattedTemperature()}'),
                Text('Condition: ${weather.getWeatherDescription()}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        print('Weather API test successful:');
        print('- Location: ${weather.name}, ${weather.sys.country}');
        print('- Temperature: ${weather.getFormattedTemperature()}');
        print('- Feels like: ${(weather.main.feelsLike - 273.15).toStringAsFixed(1)}°C');
        print('- Condition: ${weather.getWeatherMain()} (${weather.getWeatherDescription()})');
        print('- Humidity: ${weather.main.humidity}%');
        print('- Wind: ${weather.wind.speed} m/s');
        print('- Visibility: ${weather.visibility / 1000} km');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to connect to Weather API. Check your API key and internet connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        print('Weather API test failed: No data returned');
      }
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error testing Weather API: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      
      print('Weather API test error: $e');
    }
  }
  
  // Build weather widget
  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }
    
    if (_currentWeather == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weather icon
          _currentWeather!.getIconUrl().isNotEmpty
              ? Image.network(
                  _currentWeather!.getIconUrl(),
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.cloud,
                      size: 40,
                      color: Colors.blue,
                    );
                  },
                )
              : Icon(
                  Icons.cloud,
                  size: 40,
                  color: Colors.blue,
                ),
          const SizedBox(width: 8),
          // Temperature and description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentWeather!.getFormattedTemperature(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentWeather!.getWeatherDescription(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Build detailed weather widget for place details panel
  Widget _buildDetailedWeatherWidget() {
    if (_currentWeather == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Weather icon
              _currentWeather!.getIconUrl().isNotEmpty
                  ? Image.network(
                      _currentWeather!.getIconUrl(),
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.cloud,
                          size: 40,
                          color: Colors.blue,
                        );
                      },
                    )
                  : Icon(
                      Icons.cloud,
                      size: 40,
                      color: Colors.blue,
                    ),
              const SizedBox(width: 12),
              // Temperature and location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentWeather!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          _currentWeather!.getFormattedTemperature(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' (Feels like ${(_currentWeather!.main.feelsLike - 273.15).toStringAsFixed(1)}°C)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currentWeather!.getWeatherDescription(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional weather details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherDetail(
                Icons.water_drop,
                '${_currentWeather!.main.humidity}%',
                'Humidity',
              ),
              _buildWeatherDetail(
                Icons.air,
                '${_currentWeather!.wind.speed.toStringAsFixed(1)} m/s',
                'Wind',
              ),
              _buildWeatherDetail(
                Icons.visibility,
                '${(_currentWeather!.visibility / 1000).toStringAsFixed(1)} km',
                'Visibility',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper method to build weather detail items
  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // Build compact weather detail for the popup container
  Widget _buildCompactWeatherDetail(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.blue[700]),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Build compact weather widget for place details (clickable to show full details)
  Widget _buildCompactWeatherWidget() {
    if (_currentWeather == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showWeatherDetail = !_showWeatherDetail;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weather icon
            _currentWeather!.getIconUrl().isNotEmpty
                ? Image.network(
                    _currentWeather!.getIconUrl(),
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.cloud,
                        size: 28,
                        color: Colors.blue,
                      );
                    },
                  )
                : Icon(
                    Icons.cloud,
                    size: 28,
                    color: Colors.blue,
                  ),
            const SizedBox(width: 8),
            // Temperature
            Text(
              _currentWeather!.getFormattedTemperature(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            // Tap hint icon
            Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.blue.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  // Build enhanced route info card with custom styling
  Widget _buildRouteInfoCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    bool isTime = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with background
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),

        // Value and unit
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isTime ? 14 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),

        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}