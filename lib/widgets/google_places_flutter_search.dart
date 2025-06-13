import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../config/app_config.dart';
import 'dart:math' as math;

class GooglePlacesFlutterSearch extends StatefulWidget {
  final Function(mapbox.Point, {String? placeName, String? placeAddress}) onDestinationSelected;
  final double? currentLatitude;
  final double? currentLongitude;

  const GooglePlacesFlutterSearch({
    super.key,
    required this.onDestinationSelected,
    this.currentLatitude,
    this.currentLongitude,
  });

  @override
  State<GooglePlacesFlutterSearch> createState() => _GooglePlacesFlutterSearchState();
}

class _GooglePlacesFlutterSearchState extends State<GooglePlacesFlutterSearch> {
  final TextEditingController _searchController = TextEditingController();
  List<Prediction> _predictions = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    print("Debug - Selected prediction: ${prediction.toString()}");
    
    if (prediction.lat != null && prediction.lng != null) {
      print("Debug - Raw coordinates: lat=${prediction.lat}, lng=${prediction.lng}");
      
      try {
        final double lat = double.parse(prediction.lat!);
        final double lng = double.parse(prediction.lng!);
        
        print("Debug - Parsed coordinates: lat=$lat, lng=$lng");
        
        // Create a Mapbox Point from the Google Places coordinates
        final point = mapbox.Point(
          coordinates: mapbox.Position(
            lng, // Longitude first for Mapbox
            lat, // Latitude second for Mapbox
          ),
        );
        
        print("Debug - Mapbox Point: ${point.coordinates.lng}, ${point.coordinates.lat}");
        
        // Extract place name (first part of description)
        String? placeName = prediction.description?.split(',').firstOrNull?.trim();
        
        print("Debug - Extracted place name: $placeName");
        print("Debug - Full address: ${prediction.description}");
        
        // Call the callback with the selected coordinates and place details
        widget.onDestinationSelected(
          point,
          placeName: placeName,
          placeAddress: prediction.description,
        );
      } catch (e) {
        print("Debug - Error parsing coordinates: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error parsing location coordinates')),
        );
      }
    } else {
      print("Debug - Missing coordinates in prediction");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showSearchModal(context),
      child: const Icon(Icons.search),
    );
  }
  
  void _showSearchModal(BuildContext context) {
    print("Debug - Current location: lat=${widget.currentLatitude}, lng=${widget.currentLongitude}");
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildSearchModal(context),
    );
  }
  
  Widget _buildSearchModal(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              
              // Search input
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GooglePlaceAutoCompleteTextField(
                  textEditingController: _searchController,
                  googleAPIKey: AppConfig.googleApiKey ?? '',
                  inputDecoration: InputDecoration(
                    hintText: 'Search for a destination',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  debounceTime: 500,
                  countries: const ["my"], // Malaysia
                  isLatLngRequired: true,
                  getPlaceDetailWithLatLng: (Prediction prediction) {
                    // Handle when coordinates are received
                    print("Debug - Place selected with lat/lng: ${prediction.description}");
                    print("Debug - Received coordinates: lat=${prediction.lat}, lng=${prediction.lng}");
                    Navigator.pop(context);
                    _selectPlace(prediction);
                  },
                  itemClick: (Prediction prediction) {
                    _searchController.text = prediction.description ?? "";
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: prediction.description?.length ?? 0)
                    );
                  },
                  isCrossBtnShown: true,
                  containerVerticalPadding: 12,
                  // Custom item builder with distance calculation
                  itemBuilder: (context, index, Prediction prediction) {
                    // Calculate distance if coordinates are available
                    String distanceText = '';
                    if (widget.currentLatitude != null && 
                        widget.currentLongitude != null && 
                        prediction.lat != null && 
                        prediction.lng != null) {
                      try {
                        final double predLat = double.parse(prediction.lat!);
                        final double predLng = double.parse(prediction.lng!);
                        final double distance = _calculateDistance(
                          widget.currentLatitude!, widget.currentLongitude!, 
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
            ],
          ),
        );
      },
    );
  }
} 