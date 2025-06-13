import 'package:flutter/material.dart';
import '../models/directions_model.dart';

class NavigationInstructions extends StatelessWidget {
  final Directions directions;
  final int currentStepIndex;
  final VoidCallback onCancel;

  const NavigationInstructions({
    super.key,
    required this.directions,
    required this.currentStepIndex,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final currentLeg = directions.routes[0].legs[0];
    final currentStep = currentLeg.steps[currentStepIndex];
    
    // Calculate remaining distance and time
    double remainingDistance = 0;
    double remainingDuration = 0;
    
    for (int i = currentStepIndex; i < currentLeg.steps.length; i++) {
      remainingDistance += currentLeg.steps[i].distance;
      remainingDuration += currentLeg.steps[i].duration;
    }
    
    // Format distance
    String distanceText = '';
    if (remainingDistance > 1000) {
      distanceText = '${(remainingDistance / 1000).toStringAsFixed(1)} km';
    } else {
      distanceText = '${remainingDistance.toInt()} m';
    }
    
    // Format duration (in minutes)
    final minutes = (remainingDuration / 60).ceil();
    final minutesText = '$minutes min';
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  distanceText,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  minutesText,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Current instruction
            Row(
              children: [
                _buildManeuverIcon(currentStep.maneuver.type),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    currentStep.maneuver.instruction,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Next instruction (if available)
            if (currentStepIndex < currentLeg.steps.length - 1)
              Row(
                children: [
                  const Icon(Icons.arrow_downward, size: 16.0),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      'Then ${currentLeg.steps[currentStepIndex + 1].maneuver.instruction}',
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16.0),
            
            // Cancel navigation button
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('End navigation'),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildManeuverIcon(String maneuverType) {
    IconData iconData;
    
    // Map maneuver types to icons
    switch (maneuverType) {
      case 'turn':
        iconData = Icons.turn_right;
        break;
      case 'depart':
        iconData = Icons.play_arrow;
        break;
      case 'arrive':
        iconData = Icons.location_on;
        break;
      case 'merge':
        iconData = Icons.merge_type;
        break;
      case 'fork':
        iconData = Icons.call_split;
        break;
      case 'roundabout':
        iconData = Icons.roundabout_left;
        break;
      default:
        iconData = Icons.arrow_forward;
    }
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Icon(
        iconData,
        color: Colors.white,
        size: 24.0,
      ),
    );
  }
} 