class NavigationInstruction {
  final String instruction;      // Text instruction (e.g., "Turn right onto Main Street")
  final String type;             // Instruction type (e.g., "turn", "arrive", "continue", etc.)
  int distance;                  // Distance to the maneuver in meters (mutable for updates)
  final String modifier;         // Direction modifier (e.g., "right", "left", "slight right", etc.)
  final String? name;            // Name of the road/street
  final List<double>? location;  // [longitude, latitude] of the maneuver

  NavigationInstruction({
    required this.instruction,
    required this.type,
    required this.distance,
    this.location,
    this.modifier = '',
    this.name,
  });

  factory NavigationInstruction.fromJson(Map<String, dynamic> json) {
    return NavigationInstruction(
      instruction: json['instruction'] ?? '',
      type: json['type'] ?? '',
      distance: json['distance']?.toInt() ?? 0,
      modifier: json['modifier'] ?? '',
      name: json['name'],
      location: json['location'] != null 
          ? List<double>.from(json['location'].map((x) => x.toDouble())) 
          : null,
    );
  }

  // Get speech text that's appropriate for TTS
  String get speechText {
    // Clean up text for speech by removing some unnecessary info
    String cleanText = instruction
        .replaceAll(RegExp(r'(in \d+ meters)'), '')
        .replaceAll(RegExp(r'(in \d+ m)'), '')
        .trim();
    
    // Special case for arrival
    if (type.toLowerCase() == 'arrive') {
      return 'You have arrived at your destination';
    }
    
    // Special case for departure
    if (type.toLowerCase() == 'depart') {
      return 'Starting navigation. ${name != null ? "Head onto $name" : ""}';
    }
    
    // If instruction is very short, expand it for clarity
    if (cleanText.length < 10 && distance > 0) {
      return "In ${_formatDistanceForSpeech(distance)}, $cleanText";
    }
    
    return cleanText;
  }
  
  // Format distance for speech
  String _formatDistanceForSpeech(int distanceInMeters) {
    if (distanceInMeters >= 1000) {
      final double distanceInKm = distanceInMeters / 1000.0;
      return "${distanceInKm.toStringAsFixed(1)} kilometers";
    } else {
      return "$distanceInMeters meters";
    }
  }
  
  // Get the direction (left/right/straight) from the instruction
  String get direction {
    final String lowerInstruction = instruction.toLowerCase();
    
    if (lowerInstruction.contains('left')) {
      return 'left';
    } else if (lowerInstruction.contains('right')) {
      return 'right';
    } else if (lowerInstruction.contains('straight') || 
               lowerInstruction.contains('continue') || 
               lowerInstruction.contains('ahead')) {
      return 'straight';
    } else if (lowerInstruction.contains('u-turn')) {
      return 'u-turn';
    } else {
      return '';
    }
  }
  
  // Get a more specific instruction type based on text analysis
  String get detailedType {
    final String lowerInstruction = instruction.toLowerCase();
    final String lowerType = type.toLowerCase();
    
    if (lowerType == 'turn') {
      if (direction == 'left' || direction == 'right') {
        return 'turn_$direction';
      }
    } else if (lowerType == 'exit') {
      if (direction == 'left' || direction == 'right') {
        return 'exit_$direction';
      }
    } else if (lowerInstruction.contains('highway')) {
      if (lowerInstruction.contains('exit')) {
        return 'highway_exit';
      } else if (lowerInstruction.contains('enter')) {
        return 'highway_enter';
      }
    } else if (lowerInstruction.contains('roundabout')) {
      return 'roundabout';
    }
    
    // Return the original type if no detailed type is found
    return lowerType;
  }
} 