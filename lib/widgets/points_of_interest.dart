import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../models/point_of_interest.dart';
import '../config/app_config.dart';
import 'dart:math' as math;

class PointsOfInterest extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final Function(Point, {String? placeName, String? placeAddress}) onPoiSelected;
  final VoidCallback? onPoiUnselected;
  final TextEditingController? searchController;

  const PointsOfInterest({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.onPoiSelected,
    this.onPoiUnselected,
    this.searchController,
  }) : super(key: key);

  @override
  State<PointsOfInterest> createState() => _PointsOfInterestState();
}

class _PointsOfInterestState extends State<PointsOfInterest> {
  List<PointOfInterest> _pointsOfInterest = [];
  bool _isLoading = false;
  String? _selectedCategory; // Changed to nullable - no default selection
  PointOfInterest? _selectedPoi;
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Restaurants', 'value': 'restaurants', 'icon': Icons.restaurant},
    {'name': 'Hotels', 'value': 'hotels', 'icon': Icons.hotel},
    {'name': 'Hospitals', 'value': 'hospitals', 'icon': Icons.local_hospital},
    {'name': 'Gas Stations', 'value': 'gas_stations', 'icon': Icons.local_gas_station},
    {'name': 'ATMs', 'value': 'atms', 'icon': Icons.atm},
    {'name': 'Parking', 'value': 'parking', 'icon': Icons.local_parking},
  ];

  @override
  void initState() {
    super.initState();
    // Don't fetch POIs automatically - wait for user to select a category
  }

  @override
  void didUpdateWidget(PointsOfInterest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) {
      _fetchPointsOfInterest();
    }
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

  Future<void> _fetchPointsOfInterest() async {
    if (widget.latitude == null || widget.longitude == null || _selectedCategory == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = AppConfig.googleApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Google API key not configured');
      }

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=$_selectedCategory+in+nearby'
          '&location=${widget.latitude},${widget.longitude}'
          '&radius=5000'
          '&key=$apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'];
          final List<PointOfInterest> pois = [];

          for (var place in results) {
            final lat = place['geometry']['location']['lat'] as double;
            final lng = place['geometry']['location']['lng'] as double;
            
            // Calculate distance from current location
            final distance = _calculateDistance(
              widget.latitude!, 
              widget.longitude!, 
              lat, 
              lng
            );

            final poi = PointOfInterest(
              id: place['place_id'],
              name: place['name'],
              category: _selectedCategory ?? 'unknown',
              latitude: lat,
              longitude: lng,
              distance: distance,
              address: place['formatted_address'],
              icon: place['icon'],
            );
            
            pois.add(poi);
          }

          // Sort by distance
          pois.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

          setState(() {
            _pointsOfInterest = pois;
            _isLoading = false;
            // Clear selection when new POIs are loaded
            _selectedPoi = null;
          });
        } else {
          throw Exception('Failed to load places: ${data['status']}');
        }
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching POIs: $e');
    }
  }

  void _handlePoiTap(PointOfInterest poi) {
    // Check if this POI is already selected
    if (_selectedPoi?.id == poi.id) {
      // Unselect the POI
      _unselectPoi();
    } else {
      // Select the POI
      _selectPoi(poi);
    }
  }

  void _selectPoi(PointOfInterest poi) {
    setState(() {
      _selectedPoi = poi;
    });

    // Update search controller text if provided
    if (widget.searchController != null) {
      widget.searchController!.text = poi.name;
    }

    // Create a Mapbox Point from the POI coordinates
    final point = Point(
      coordinates: Position(
        poi.longitude, // Longitude first for Mapbox
        poi.latitude, // Latitude second for Mapbox
      ),
    );

    // Call the callback with the selected coordinates and place details
    widget.onPoiSelected(
      point,
      placeName: poi.name,
      placeAddress: poi.address,
    );
  }

  void _unselectPoi() {
    setState(() {
      _selectedPoi = null;
    });

    // Clear search controller text if provided
    if (widget.searchController != null) {
      widget.searchController!.text = '';
    }

    // Call the unselection callback if provided
    if (widget.onPoiUnselected != null) {
      widget.onPoiUnselected!();
    }
  }

  void _unselectCategory() {
    setState(() {
      _selectedCategory = null;
      _selectedPoi = null;
      _pointsOfInterest.clear();
      _isLoading = false;
    });

    // Clear search controller text if provided
    if (widget.searchController != null) {
      widget.searchController!.text = '';
    }

    // Call the unselection callback if provided
    if (widget.onPoiUnselected != null) {
      widget.onPoiUnselected!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category selection
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category['value'] == _selectedCategory;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(category['name']),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      // Select the category
                      setState(() {
                        _selectedCategory = category['value'];
                      });
                      _fetchPointsOfInterest();
                    } else {
                      // Unselect the category
                      _unselectCategory();
                    }
                  },
                ),
              );
            },
          ),
        ),
        
        // Only show spacing when a category is selected
        if (_selectedCategory != null) const SizedBox(height: 8),

        // POI list - only show when a category is selected
        if (_selectedCategory != null)
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pointsOfInterest.isEmpty
                    ? const Center(child: Text('No places found nearby'))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pointsOfInterest.length,
                      itemBuilder: (context, index) {
                        final poi = _pointsOfInterest[index];
                        final isSelected = _selectedPoi?.id == poi.id;
                        return GestureDetector(
                          onTap: () => _handlePoiTap(poi),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.location_on,
                                        size: 16,
                                        color: isSelected ? Colors.blue : null,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          poi.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isSelected ? Colors.blue.shade700 : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        poi.address ?? 'No address',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${poi.distance?.toStringAsFixed(1) ?? "?"} km away',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.blue,
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
                    ),
        ),
      ],
    );
  }
} 