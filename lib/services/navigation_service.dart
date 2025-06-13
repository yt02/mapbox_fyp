import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/navigation_instruction.dart';
import '../services/safety_tip_service.dart';

class NavigationService {
  final FlutterTts _flutterTts = FlutterTts();
  List<NavigationInstruction> _instructions = [];
  int _currentInstructionIndex = 0;
  Timer? _instructionTimer;
  bool _isNavigating = false;
  bool _isSpeaking = false;
  double _initialAnnouncementThreshold = 100; // meters before announcing an instruction initially
  double _repeatAnnouncementThreshold = 50; // meters before repeating the instruction
  bool _hasAnnouncedInitial = false; // Track if we've announced the initial instruction
  bool _hasAnnouncedRepeat = false; // Track if we've announced the repeat instruction
  SafetyTipService? _safetyTipService;
  
  // Getter for current instruction index
  int get currentInstructionIndex => _currentInstructionIndex;
  
  // Setter for current instruction index
  set currentInstructionIndex(int index) {
    if (index >= 0 && index < _instructions.length) {
      _currentInstructionIndex = index;
      _hasAnnouncedInitial = false;
      _hasAnnouncedRepeat = false;
    }
  }
  
  NavigationService() {
    _initTts();
    print("NavigationService: Initialized");
  }
  
  // Set the safety tip service for coordination
  void setSafetyTipService(SafetyTipService safetyTipService) {
    _safetyTipService = safetyTipService;
    print("NavigationService: Safety tip service connected");
  }
  
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slower speech rate for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      print("NavigationService: TTS speech completed");
      // Notify safety tip service that we're done speaking
      if (_safetyTipService != null) {
        _safetyTipService!.notifyNavigationInstructionFinished();
      } else {
        print("NavigationService: Cannot notify safety tip service (null)");
      }
    });
  }
  
  // Start navigation with the given instructions
  void startNavigation(List<NavigationInstruction> instructions) {
    if (instructions.isEmpty) {
      print("NavigationService: Cannot start navigation with empty instructions");
      return;
    }
    
    print("NavigationService: Starting navigation with ${instructions.length} instructions");
    
    _instructions = List.from(instructions); // Create a copy to avoid modifying the original
    _currentInstructionIndex = 0;
    _isNavigating = true;
    _hasAnnouncedInitial = false;
    _hasAnnouncedRepeat = false;
    
    // Announce the first instruction
    speakInstruction(_instructions[0]);
    _hasAnnouncedInitial = true;
    
    // Start monitoring for upcoming instructions
    _instructionTimer?.cancel(); // Cancel any existing timer
    _instructionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkForUpcomingInstructions();
    });
  }
  
  // Stop navigation
  void stopNavigation() {
    print("NavigationService: Stopping navigation");
    _isNavigating = false;
    _instructionTimer?.cancel();
    _instructionTimer = null;
    _flutterTts.stop();
    _isSpeaking = false;
    
    // Notify safety tip service that navigation is finished
    if (_safetyTipService != null) {
      _safetyTipService!.notifyNavigationInstructionFinished();
    } else {
      print("NavigationService: Cannot notify safety tip service (null)");
    }
  }
  
  // Check if we should announce the next instruction based on current position
  void _checkForUpcomingInstructions() {
    if (!_isNavigating || _currentInstructionIndex >= _instructions.length) return;
    
    // Get the current instruction
    final instruction = _instructions[_currentInstructionIndex];
    
    // If we're close enough to the next instruction point, announce it
    if (instruction.distance < _initialAnnouncementThreshold && !_hasAnnouncedInitial && !_isSpeaking) {
      print("NavigationService: Initial announcement for approaching instruction point");
      speakInstruction(instruction);
      _hasAnnouncedInitial = true;
    }
    // If we're getting very close to the instruction and haven't repeated it yet
    else if (instruction.distance < _repeatAnnouncementThreshold && _hasAnnouncedInitial && !_hasAnnouncedRepeat && !_isSpeaking) {
      print("NavigationService: Repeat announcement for imminent instruction point");
      speakInstruction(instruction, isRepeat: true);
      _hasAnnouncedRepeat = true;
    }
    // If we've passed this instruction, move to the next one
    else if (instruction.distance < 20) { // 20 meters threshold for "passed"
      _currentInstructionIndex++;
      _hasAnnouncedInitial = false;
      _hasAnnouncedRepeat = false;
      print("NavigationService: Advanced to next instruction index: $_currentInstructionIndex");
      
      // If we've reached the last instruction, stop navigation after a delay
      if (_currentInstructionIndex >= _instructions.length) {
        print("NavigationService: Reached last instruction, will stop navigation soon");
        Future.delayed(const Duration(seconds: 5), () {
          stopNavigation();
        });
      }
    }
  }
  
  // Update the current position to calculate distances to upcoming instructions
  void updatePosition(geo.Position position, List<NavigationInstruction> instructions) {
    if (!_isNavigating || instructions.isEmpty) return;
    
    // Update our instruction list if it changed
    if (_instructions != instructions) {
      _instructions = List.from(instructions); // Create a copy
      _currentInstructionIndex = 0;
      _hasAnnouncedInitial = false;
      _hasAnnouncedRepeat = false;
      print("NavigationService: Instructions list updated with ${_instructions.length} instructions");
    }
    
    // Skip instructions we've already passed
    while (_currentInstructionIndex < _instructions.length) {
      final instruction = _instructions[_currentInstructionIndex];
      if (instruction.location == null) {
        _currentInstructionIndex++;
        _hasAnnouncedInitial = false;
        _hasAnnouncedRepeat = false;
        print("NavigationService: Skipping instruction without location, new index: $_currentInstructionIndex");
        continue;
      }
      
      // Calculate distance to the next instruction point
      final double distanceToInstruction = _calculateDistance(
        position.latitude, position.longitude,
        instruction.location![1], instruction.location![0]
      );
      
      // If we've passed this instruction, move to the next one
      if (distanceToInstruction < 20) { // 20 meters threshold for "passed"
        _currentInstructionIndex++;
        _hasAnnouncedInitial = false;
        _hasAnnouncedRepeat = false;
        print("NavigationService: Passed instruction, new index: $_currentInstructionIndex");
        
        // Announce the next instruction if available
        if (_currentInstructionIndex < _instructions.length && !_isSpeaking) {
          print("NavigationService: Announcing next instruction after passing previous one");
          speakInstruction(_instructions[_currentInstructionIndex]);
          _hasAnnouncedInitial = true;
        }
      } else {
        break;
      }
    }
    
    // Check if we should announce the next instruction
    if (_currentInstructionIndex < _instructions.length) {
      final instruction = _instructions[_currentInstructionIndex];
      
      // Calculate distance to the next instruction point
      if (instruction.location != null) {
        final double distanceToInstruction = _calculateDistance(
          position.latitude, position.longitude,
          instruction.location![1], instruction.location![0]
        );
        
        // Update the instruction's distance
        instruction.distance = distanceToInstruction.toInt();
        
        // Initial announcement when approaching
        if (distanceToInstruction < _initialAnnouncementThreshold && !_hasAnnouncedInitial && !_isSpeaking) {
          print("NavigationService: Approaching instruction at distance $distanceToInstruction meters");
          speakInstruction(instruction);
          _hasAnnouncedInitial = true;
        }
        // Repeat announcement when very close
        else if (distanceToInstruction < _repeatAnnouncementThreshold && _hasAnnouncedInitial && !_hasAnnouncedRepeat && !_isSpeaking) {
          print("NavigationService: Very close to instruction at distance $distanceToInstruction meters - repeating");
          speakInstruction(instruction, isRepeat: true);
          _hasAnnouncedRepeat = true;
        }
      }
    }
  }
  
  // Speak an instruction using TTS - made public for direct access
  Future<void> speakInstruction(NavigationInstruction instruction, {bool isRepeat = false}) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      print("NavigationService: Stopped previous speech to announce new instruction");
    }
    
    // Notify safety tip service that we're about to speak
    if (_safetyTipService != null) {
      _safetyTipService!.notifyNavigationInstructionStarted();
    } else {
      print("NavigationService: Cannot notify safety tip service (null)");
    }
    
    // Modify speech text for repeat announcements
    String speechText = isRepeat 
        ? "${instruction.speechText} now" 
        : instruction.speechText;
    
    print("NavigationService: Speaking instruction: $speechText");
    _isSpeaking = true;
    
    try {
      await _flutterTts.speak(speechText);
    } catch (e) {
      print("NavigationService: Error speaking instruction: $e");
      _isSpeaking = false;
      
      // Ensure we still release the safety tip service even if TTS fails
      if (_safetyTipService != null) {
        _safetyTipService!.notifyNavigationInstructionFinished();
      }
    }
    
    // Add a shorter delay before allowing safety tips again
    // The TTS completion handler should handle this, but this is a backup
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isSpeaking && _safetyTipService != null) {
        print("NavigationService: Ensuring navigation instruction is marked as finished");
        _safetyTipService!.notifyNavigationInstructionFinished();
      }
    });
  }
  
  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * 
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;
    return distance;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  // Force update to a specific instruction (used for simulation)
  void jumpToInstruction(int index) {
    if (!_isNavigating || _instructions.isEmpty) return;
    if (index < 0 || index >= _instructions.length) return;
    
    print("NavigationService: Forcing jump to instruction $index");
    
    _currentInstructionIndex = index;
    _hasAnnouncedInitial = false;
    _hasAnnouncedRepeat = false;
    speakInstruction(_instructions[index]);
    _hasAnnouncedInitial = true;
  }
  
  // Checks if the safety tip service is active and not blocked
  bool get canShowSafetyTips {
    if (_safetyTipService == null) return false;
    
    return _safetyTipService!.isActive && !_safetyTipService!.isTipsBlocked && !_isSpeaking;
  }
} 