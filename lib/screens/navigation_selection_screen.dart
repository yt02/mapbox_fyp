import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'map_screen.dart';
import 'dashcam_connection_page.dart';
import '../config/app_config.dart';

class NavigationSelectionScreen extends StatefulWidget {
  const NavigationSelectionScreen({Key? key}) : super(key: key);

  @override
  State<NavigationSelectionScreen> createState() => _NavigationSelectionScreenState();
}

class _NavigationSelectionScreenState extends State<NavigationSelectionScreen> {
  MapboxMap? _preloadedMap;
  geo.Position? _currentPosition;
  bool _isMapPreloaded = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _preloadMapAndLocation();
  }

  // Pre-load map and get current location in background
  Future<void> _preloadMapAndLocation() async {
    try {
      // Get current location
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          print('Location permissions are denied');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      print('Location preloaded: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error preloading location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _preloadedMap = mapboxMap;
    setState(() {
      _isMapPreloaded = true;
    });
    print('Map preloaded successfully');

    // Initialize map with current location if available
    if (_currentPosition != null) {
      mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 0, startDelay: 0), // No animation for preload
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Options'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Hidden map widget for preloading
          Positioned(
            left: -1000, // Hide off-screen
            top: -1000,
            width: 100,
            height: 100,
            child: MapWidget(
              key: const ValueKey("preloadMapWidget"),
              styleUri: 'mapbox://styles/mapbox/streets-v12',
              onMapCreated: _onMapCreated,
            ),
          ),

          // Main content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Colors.white,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // App logo with loading indicator
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          size: 80,
                          color: Theme.of(context).primaryColor,
                        ),
                        if (_isLoadingLocation)
                          Positioned(
                            bottom: -5,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App name
                  Center(
                    child: Text(
                      'Intelligent Car Driving Assistant (ICDA)',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Status text
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _isLoadingLocation
                        ? 'Preparing navigation...'
                        : _isMapPreloaded
                          ? 'Ready to navigate!'
                          : 'Loading map...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Standard Navigation Option
                  _buildNavigationOption(
                    context,
                    title: 'Smart Navigation',
                    description: 'Intelligent turn-by-turn navigation with AI-powered safety assistance',
                    icon: Icons.navigation,
                    isReady: !_isLoadingLocation,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Dashcam Detection Option
                  _buildNavigationOption(
                    context,
                    title: 'AI Vision Assistant',
                    description: 'Connect to dashcam for intelligent real-time object detection',
                    icon: Icons.camera_alt,
                    isReady: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DashcamConnectionPage()),
                      );
                    },
                  ),

                  const Spacer(),

                  // Footer text
                  Center(
                    child: Text(
                      'Choose your preferred navigation mode',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationOption(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool isReady = true,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isReady ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isReady ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                      if (!isReady)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 