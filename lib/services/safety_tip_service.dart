import 'dart:async';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/safety_tip.dart';
import '../models/navigation_instruction.dart';

class SafetyTipService {
  List<SafetyTip> _tips = [];
  Timer? _tipTimer;
  Function(SafetyTip)? _onNewTip;
  bool _isSimulationMode = false;
  bool _enableVoice = true;
  bool _enableSounds = true;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;
  bool _navigationInProgress = false;
  bool _isServiceActive = false;
  
  // Current navigation context
  String _currentContext = '';
  NavigationInstruction? _upcomingInstruction;
  
  // Minimum time between tips in seconds
  final int _minTipInterval = 120; // 2 minutes
  final int _maxTipInterval = 300; // 5 minutes
  
  // Shorter intervals for simulation mode
  final int _simMinTipInterval = 30; // 30 seconds in simulation
  final int _simMaxTipInterval = 60; // 1 minute in simulation
  
  // Constructor
  SafetyTipService() {
    _tips = SafetyTip.getSafetyTips();
    _initTts();
    print("SafetyTipService: Initialized with ${_tips.length} tips");
  }
  
  // Initialize TTS
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.4); // Slower speech rate for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      print("SafetyTipService: TTS speech completed");
    });
  }
  
  // Start showing tips periodically
  void startTips(Function(SafetyTip) onNewTip, {
    bool isSimulation = false,
    bool speakTips = true,
    bool playSounds = true,
  }) {
    print("SafetyTipService: Starting tips service");
    print("  - Simulation mode: $isSimulation");
    print("  - Speech enabled: $speakTips");
    print("  - Sounds enabled: $playSounds");

    // Cancel any existing timer to avoid duplicates
    _tipTimer?.cancel();
    _tipTimer = null;

    _onNewTip = onNewTip;
    _isSimulationMode = isSimulation;
    _enableVoice = speakTips;
    _enableSounds = playSounds;
    _isServiceActive = true;

    // Make sure navigation is not marked as in progress when starting
    _navigationInProgress = false;

    // Check if headlights should be turned on and show as first tip
    print("SafetyTipService: Checking if headlight reminder is needed");
    Future.delayed(Duration(seconds: 3), () {
      if (_isServiceActive) {
        if (_shouldShowHeadlightReminder()) {
          print("SafetyTipService: Showing headlight reminder as first tip");
          _showHeadlightReminder();
          // Schedule regular tips after headlight reminder
          Future.delayed(Duration(seconds: 15), () {
            if (_isServiceActive) {
              _scheduleTip();
            }
          });
        } else {
          print("SafetyTipService: No headlight reminder needed, showing regular first tip");
          _showRandomTip();
          // Set up timer for subsequent tips
          _scheduleTip();
        }
      }
    });
  }
  
  // Stop showing tips
  void stopTips() {
    print("SafetyTipService: Stopping tips service");
    _isServiceActive = false;
    _tipTimer?.cancel();
    _tipTimer = null;
    _onNewTip = null;
    _isSimulationMode = false;
    _upcomingInstruction = null;
    _currentContext = '';
    
    // Stop any ongoing speech
    if (_isSpeaking) {
      _flutterTts.stop();
      _isSpeaking = false;
    }
  }
  
  // Update the current navigation context based on upcoming instruction
  void updateNavigationContext(NavigationInstruction? upcomingInstruction) {
    if (upcomingInstruction == null) {
      _upcomingInstruction = null;
      _currentContext = '';
      print("SafetyTipService: Navigation context cleared");
      return;
    }
    
    // Store the instruction
    _upcomingInstruction = upcomingInstruction;
    
    // Determine the context based on the instruction type
    String newContext = '';
    final String detailedType = upcomingInstruction.detailedType;
    final String type = upcomingInstruction.type.toLowerCase();
    final String instruction = upcomingInstruction.instruction.toLowerCase();
    
    // Map the instruction type to a context
    if (detailedType.contains('roundabout')) {
      newContext = 'roundabout';
    } else if (detailedType.contains('turn_left')) {
      newContext = 'turn_left';
    } else if (detailedType.contains('turn_right')) {
      newContext = 'turn_right';
    } else if (detailedType.contains('highway_exit')) {
      newContext = 'highway_exit';
    } else if (detailedType.contains('highway_enter')) {
      newContext = 'highway_enter';
    } else if (type.contains('highway') || instruction.contains('highway')) {
      newContext = 'highway';
    } else if (type.contains('intersection') || type.contains('junction') || 
               instruction.contains('intersection') || instruction.contains('junction')) {
      newContext = 'intersection';
    } else if (instruction.contains('merge') || type.contains('merge')) {
      newContext = 'merge';
    } else if (instruction.contains('continue straight') || instruction.contains('keep straight')) {
      newContext = 'continue';
    } else if (instruction.contains('arrive')) {
      newContext = 'arrive';
    }
    
    // Calculate urgency based on distance to the instruction
    bool isUrgent = upcomingInstruction.distance < 100; // Consider instructions within 100m as urgent
    bool isVeryClose = upcomingInstruction.distance < 50; // Consider instructions within 50m as very close
    
    // Only update if the context has changed or if the instruction is very close
    if (newContext != _currentContext || isVeryClose) {
      _currentContext = newContext;
      print("SafetyTipService: Navigation context updated to '$_currentContext' (distance: ${upcomingInstruction.distance}m)");
      
      // If we have a significant context, show a relevant tip soon
      if (_currentContext.isNotEmpty) {
        _scheduleContextSpecificTip(isUrgent);
      }
    }
  }
  
  // Schedule a context-specific tip to be shown soon
  void _scheduleContextSpecificTip(bool isUrgent) {
    if (!_isServiceActive || _currentContext.isEmpty) return;
    
    // Cancel any existing timer
    _tipTimer?.cancel();
    
    // Determine delay based on urgency
    int delaySeconds = isUrgent ? 2 : 5;
    
    print("SafetyTipService: Scheduling context-specific tip for '$_currentContext' in $delaySeconds seconds");
    
    // Show a tip related to the current context after a short delay
    _tipTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isServiceActive && !_navigationInProgress) {
        _showContextSpecificTip();
      }
    });
  }
  
  // Show a tip specific to the current navigation context
  void _showContextSpecificTip() {
    if (_onNewTip == null || _tips.isEmpty || _currentContext.isEmpty) {
      print("SafetyTipService: Cannot show context-specific tip - invalid state");
      return;
    }
    
    print("SafetyTipService: Showing tip for context '$_currentContext'");
    
    // Filter tips that are relevant for the current context
    List<SafetyTip> relevantTips = _tips.where((tip) => 
      tip.contexts.contains(_currentContext)
    ).toList();
    
    if (relevantTips.isEmpty) {
      print("SafetyTipService: No tips found for context '$_currentContext', showing general tip instead");
      _showRandomTip();
      return;
    }
    
    // Determine if this is an urgent instruction (very close)
    bool isUrgent = _upcomingInstruction != null && _upcomingInstruction!.distance < 50;
    
    // Create a weighted random selection based on priority
    // For urgent instructions, we'll increase the weight of higher priority tips
    int totalWeight = 0;
    for (var tip in relevantTips) {
      // For urgent instructions, square the priority to heavily favor high-priority tips
      totalWeight += isUrgent ? (tip.priority * tip.priority) : tip.priority;
    }
    
    int randomWeight = Random().nextInt(totalWeight);
    
    int cumulativeWeight = 0;
    SafetyTip selectedTip = relevantTips.first; // Default in case of error
    
    for (var tip in relevantTips) {
      // For urgent instructions, square the priority
      int effectivePriority = isUrgent ? (tip.priority * tip.priority) : tip.priority;
      cumulativeWeight += effectivePriority;
      if (randomWeight < cumulativeWeight) {
        selectedTip = tip;
        break;
      }
    }
    
    print("SafetyTipService: Selected context-specific tip - ${selectedTip.shortTip} (${selectedTip.category})");
    if (isUrgent) {
      print("SafetyTipService: This is an URGENT tip for imminent instruction!");
    }
    
    // Play alert sound if enabled
    if (_enableSounds) {
      _playAlertSound(selectedTip.category, isUrgent);
    }
    
    // Deliver the tip
    try {
      _onNewTip!(selectedTip);
      print("SafetyTipService: Context-specific tip delivered to UI");
    } catch (e) {
      print("SafetyTipService: Error delivering context-specific tip to UI: $e");
    }
    
    // Speak the tip if voice is enabled
    if (_enableVoice) {
      _speakTip(selectedTip, isUrgent);
    }
    
    // Schedule the next regular tip
    _scheduleTip();
  }
  
  // Show a random tip based on priority weighting
  void _showRandomTip() {
    if (_onNewTip == null || _tips.isEmpty) {
      print("SafetyTipService: Cannot show tip - callback is null or no tips available");
      return;
    }
    
    // Don't show tip if navigation instruction is in progress
    if (_navigationInProgress) {
      print("SafetyTipService: Navigation instruction is in progress, postponing tip");
      // Reschedule for later
      _scheduleTip();
      return;
    }
    
    // If we have a current context, try to show a context-specific tip
    if (_currentContext.isNotEmpty) {
      // 70% chance to show a context-specific tip if available
      if (Random().nextDouble() < 0.7) {
        List<SafetyTip> contextTips = _tips.where((tip) => 
          tip.contexts.contains(_currentContext)
        ).toList();
        
        if (contextTips.isNotEmpty) {
          print("SafetyTipService: Showing context-specific tip instead of random tip");
          _showContextSpecificTip();
          return;
        }
      }
    }
    
    // Filter to only general tips (no specific context)
    List<SafetyTip> generalTips = _tips.where((tip) => tip.contexts.isEmpty).toList();
    
    // Create a weighted random selection based on priority
    int totalWeight = generalTips.fold(0, (sum, tip) => sum + tip.priority);
    int randomWeight = Random().nextInt(totalWeight);
    
    int cumulativeWeight = 0;
    SafetyTip selectedTip = generalTips.first; // Default in case of error
    
    for (var tip in generalTips) {
      cumulativeWeight += tip.priority;
      if (randomWeight < cumulativeWeight) {
        selectedTip = tip;
        break;
      }
    }
    
    print("SafetyTipService: Selected general tip - ${selectedTip.shortTip} (${selectedTip.category})");
    
    // Play alert sound if enabled
    if (_enableSounds) {
      _playAlertSound(selectedTip.category, false);
    }
    
    // Deliver the tip
    try {
      _onNewTip!(selectedTip);
      print("SafetyTipService: General tip delivered to UI");
    } catch (e) {
      print("SafetyTipService: Error delivering tip to UI: $e");
    }
    
    // Speak the tip if voice is enabled
    if (_enableVoice) {
      _speakTip(selectedTip, false);
    }
  }
  
  // Play an alert sound based on the tip category
  Future<void> _playAlertSound(String category, bool isUrgent) async {
    try {
      // Use different sounds based on tip category
      if (category == 'safety') {
        // Try to play a custom sound if available
        try {
          // For urgent safety tips, use a more attention-grabbing sound
          if (isUrgent) {
            await _audioPlayer.play(AssetSource('sounds/urgent_safety_alert.mp3'));
            print("SafetyTipService: Played urgent safety alert sound");
          } else {
            await _audioPlayer.play(AssetSource('sounds/safety_alert.mp3'));
            print("SafetyTipService: Played safety alert sound");
          }
        } catch (e) {
          // Fallback to system sound if custom sound fails
          SystemSound.play(SystemSoundType.alert);
          print("SafetyTipService: Played fallback system alert sound");
        }
      } else if (category == 'beginner') {
        try {
          await _audioPlayer.play(AssetSource('sounds/tip_alert.mp3'));
          print("SafetyTipService: Played beginner tip alert sound");
        } catch (e) {
          SystemSound.play(SystemSoundType.alert);
          print("SafetyTipService: Played fallback system alert sound");
        }
      } else {
        // Default sound
        SystemSound.play(SystemSoundType.alert);
        print("SafetyTipService: Played default alert sound");
      }
    } catch (e) {
      print('SafetyTipService: Error playing sound: $e');
    }
  }
  
  // Speak the tip using TTS
  Future<void> _speakTip(SafetyTip tip, bool isUrgent) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      print("SafetyTipService: Stopped previous speech");
    }
    
    // Don't speak if navigation instruction is in progress
    if (_navigationInProgress) {
      print("SafetyTipService: Cannot speak - navigation instruction in progress");
      return;
    }
    
    _isSpeaking = true;
    
    // Use the full tip directly without category prefix for clearer speech
    String speechText = tip.tip;
    
    // For urgent tips, add an attention-grabbing prefix
    if (isUrgent) {
      speechText = "Attention! " + speechText;
    }
    
    print("SafetyTipService: Speaking tip - $speechText");
    
    // Wait a short moment for the alert sound to play
    await Future.delayed(Duration(milliseconds: 800));
    
    // For urgent tips, use higher volume and slightly faster speech
    if (isUrgent) {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.45);
    } else {
      await _flutterTts.setVolume(0.9);
      await _flutterTts.setSpeechRate(0.4);
    }
    
    await _flutterTts.speak(speechText);
  }
  
  // Schedule the next tip
  void _scheduleTip() {
    // Cancel any existing timer
    _tipTimer?.cancel();
    
    // Use appropriate interval range based on mode
    int minInterval = _isSimulationMode ? _simMinTipInterval : _minTipInterval;
    int maxInterval = _isSimulationMode ? _simMaxTipInterval : _maxTipInterval;
    
    // Random interval between min and max
    int interval = minInterval + Random().nextInt(maxInterval - minInterval);
    
    print("SafetyTipService: Scheduling next tip in $interval seconds");
    
    _tipTimer = Timer(Duration(seconds: interval), () {
      if (_isServiceActive) {
        print("SafetyTipService: Timer triggered, showing next tip");
        _showRandomTip();
        _scheduleTip(); // Schedule the next tip
      } else {
        print("SafetyTipService: Timer triggered but service is not active");
      }
    });
  }
  
  // Show a tip now (can be called manually)
  void showTipNow({bool speak = true, bool playSound = true}) {
    print("SafetyTipService: Manually showing tip now");
    
    // Don't show tip if navigation instruction is in progress
    if (_navigationInProgress) {
      print("SafetyTipService: Cannot show manual tip - navigation instruction in progress");
      return;
    }
    
    // Store current settings and restore them after
    bool previousVoiceSetting = _enableVoice;
    bool previousSoundSetting = _enableSounds;
    
    _enableVoice = speak;
    _enableSounds = playSound;
    
    // If we have a current context, show a context-specific tip
    if (_currentContext.isNotEmpty) {
      _showContextSpecificTip();
    } else {
      _showRandomTip();
    }
    
    // Restore original settings
    _enableVoice = previousVoiceSetting;
    _enableSounds = previousSoundSetting;
    
    // Reset the timer
    _scheduleTip();
  }
  
  // Filter tips by category
  void setCategories({bool safety = true, bool beginner = true}) {
    print("SafetyTipService: Setting tip categories - safety: $safety, beginner: $beginner");
    
    // Get all tips
    List<SafetyTip> allTips = SafetyTip.getSafetyTips();
    
    // Filter based on selected categories
    _tips = allTips.where((tip) {
      if (tip.category == 'safety') return safety;
      if (tip.category == 'beginner') return beginner;
      return false;
    }).toList();
    
    print("SafetyTipService: After filtering, ${_tips.length} tips are available");
    
    if (_tips.isEmpty) {
      print("WARNING: No tips are available after filtering! Check category settings.");
    }
  }
  
  // Set simulation mode
  void setSimulationMode(bool isSimulation) {
    if (_isSimulationMode != isSimulation) {
      print("SafetyTipService: Setting simulation mode to $isSimulation");
      _isSimulationMode = isSimulation;
      // Reschedule with new intervals if already running
      if (_tipTimer != null) {
        _scheduleTip();
      }
    }
  }
  
  // Enable or disable voice tips
  void setVoiceEnabled(bool enable) {
    print("SafetyTipService: Setting voice enabled to $enable");
    _enableVoice = enable;
    
    // If disabling voice and currently speaking, stop speech
    if (!enable && _isSpeaking) {
      _flutterTts.stop();
      _isSpeaking = false;
    }
  }
  
  // Enable or disable sound effects
  void setSoundsEnabled(bool enable) {
    print("SafetyTipService: Setting sounds enabled to $enable");
    _enableSounds = enable;
  }
  
  // Notify that navigation instruction is starting
  void notifyNavigationInstructionStarted() {
    print("SafetyTipService: Navigation instruction started");
    _navigationInProgress = true;
    
    // If currently speaking a tip, stop it
    if (_isSpeaking) {
      _flutterTts.stop();
      _isSpeaking = false;
      print("SafetyTipService: Stopped speaking due to navigation instruction");
    }
    
    // Start a timer to automatically clear the navigation in progress state
    // in case the notifyNavigationInstructionFinished is never called
    Future.delayed(Duration(seconds: 15), () {
      if (_navigationInProgress) {
        print("SafetyTipService: Automatically clearing navigation in progress state after timeout");
        _navigationInProgress = false;
      }
    });
  }
  
  // Notify that navigation instruction is finished
  void notifyNavigationInstructionFinished() {
    print("SafetyTipService: Navigation instruction finished");
    _navigationInProgress = false;
    
    // Schedule a safety tip to appear shortly after navigation instruction
    // This ensures tips appear periodically even during navigation
    if (_isServiceActive && _onNewTip != null) {
      print("SafetyTipService: Scheduling a tip to appear after navigation instruction");
      
      // Cancel any existing timers to avoid duplicates
      _tipTimer?.cancel();
      
      // Show a tip after a short delay to give the user time to process the navigation instruction
      _tipTimer = Timer(Duration(seconds: 10), () {
        if (_isServiceActive && !_navigationInProgress) {
          print("SafetyTipService: Showing tip after navigation instruction");
          _showRandomTip();
          // Resume normal tip scheduling
          _scheduleTip();
        }
      });
    }
  }
  
  // Check if safety tips are currently blocked
  bool get isTipsBlocked => _navigationInProgress;
  
  // Check if service is active
  bool get isActive => _isServiceActive;
  
  // Print debug info about the current state
  void printDebugInfo() {
    print("\n--- SAFETY TIP SERVICE DEBUG INFO ---");
    print("Service active: $_isServiceActive");
    print("Navigation in progress: $_navigationInProgress");
    print("Timer active: ${_tipTimer != null && _tipTimer!.isActive}");
    print("Speaking: $_isSpeaking");
    print("Voice enabled: $_enableVoice");
    print("Sounds enabled: $_enableSounds");
    print("Simulation mode: $_isSimulationMode");
    print("Current context: ${_currentContext.isEmpty ? 'None' : _currentContext}");
    print("Upcoming instruction: ${_upcomingInstruction?.instruction ?? 'None'}");
    print("Available tips: ${_tips.length}");
    print("Context-specific tips available: ${_tips.where((tip) => tip.contexts.isNotEmpty).length}");
    print("Callback registered: ${_onNewTip != null}");
    print("-------------------------------------\n");
  }
  
  // Add speed-based safety tips
  void showSpeedWarning(double currentSpeed, int speedLimit) {
    if (!_isServiceActive || _navigationInProgress) return;
    
    // Calculate how much over the limit we are
    int overSpeed = (currentSpeed - speedLimit).round();
    
    if (overSpeed <= 0) return; // Not speeding
    
    String warningMessage = "";
    bool isUrgent = false;
    
    if (overSpeed > 20) {
      warningMessage = "Slow down immediately. You're driving dangerously over the speed limit.";
      isUrgent = true; // This is an urgent warning
    } else if (overSpeed > 10) {
      warningMessage = "You're significantly exceeding the speed limit. Please slow down.";
      isUrgent = true; // This is also quite urgent
    } else {
      warningMessage = "You're over the speed limit. Please reduce your speed.";
      isUrgent = false; // Less urgent
    }
    
    print("SafetyTipService: Speed warning - $warningMessage");
    
    // Create a temporary safety tip for the speed warning
    SafetyTip speedTip = SafetyTip(
      tip: warningMessage,
      shortTip: "SLOW DOWN",
      category: "safety",
      priority: 5, // High priority
    );
    
    // Cancel any existing timer to avoid duplicates
    _tipTimer?.cancel();
    
    // Play alert sound
    if (_enableSounds) {
      try {
        // Use a more urgent sound for speed warnings
        try {
          _audioPlayer.play(AssetSource('sounds/speed_warning.mp3'));
          print("SafetyTipService: Played speed warning sound");
        } catch (e) {
          SystemSound.play(SystemSoundType.alert);
          print("SafetyTipService: Played fallback system alert sound for speed warning");
        }
      } catch (e) {
        print('SafetyTipService: Error playing sound: $e');
      }
    }
    
    // Deliver the tip
    try {
      if (_onNewTip != null) {
        _onNewTip!(speedTip);
        print("SafetyTipService: Speed warning delivered to UI");
      }
    } catch (e) {
      print("SafetyTipService: Error delivering speed warning to UI: $e");
    }
    
    // Speak the warning if voice is enabled
    if (_enableVoice) {
      _speakTip(speedTip, isUrgent);
    }
    
    // Resume normal tip scheduling after the warning
    _scheduleTip();
  }

  // Check if headlight reminder should be shown based on time of day
  bool _shouldShowHeadlightReminder() {
    final now = DateTime.now();
    final hour = now.hour;

    // Show headlight reminder during:
    // - Early morning: 5:00 AM - 7:00 AM (dawn)
    // - Evening: 6:00 PM - 8:00 PM (dusk)
    // - Night: 8:00 PM - 5:00 AM (dark hours)

    bool isDawn = hour >= 5 && hour < 7;
    bool isDusk = hour >= 18 && hour < 20;
    bool isNight = hour >= 20 || hour < 5;

    bool shouldRemind = isDawn || isDusk || isNight;

    print("SafetyTipService: Time check - Hour: $hour, Dawn: $isDawn, Dusk: $isDusk, Night: $isNight, Should remind: $shouldRemind");

    return shouldRemind;
  }

  // Show headlight reminder as first driving tip
  void _showHeadlightReminder() {
    if (_onNewTip == null) {
      print("SafetyTipService: Cannot show headlight reminder - callback is null");
      return;
    }

    final now = DateTime.now();
    final hour = now.hour;

    String reminderMessage = "";
    String shortMessage = "";

    if (hour >= 20 || hour < 5) {
      // Night time
      reminderMessage = "It's nighttime. Make sure your headlights are on for safe driving.";
      shortMessage = "TURN ON HEADLIGHTS";
    } else if (hour >= 18 && hour < 20) {
      // Dusk
      reminderMessage = "It's getting dark. Turn on your headlights for better visibility.";
      shortMessage = "HEADLIGHTS ON";
    } else if (hour >= 5 && hour < 7) {
      // Dawn
      reminderMessage = "It's early morning with low light. Consider turning on your headlights.";
      shortMessage = "HEADLIGHTS RECOMMENDED";
    } else {
      // Fallback (shouldn't happen if _shouldShowHeadlightReminder works correctly)
      reminderMessage = "Check your headlights are appropriate for current lighting conditions.";
      shortMessage = "CHECK HEADLIGHTS";
    }

    // Create headlight reminder tip
    SafetyTip headlightTip = SafetyTip(
      tip: reminderMessage,
      shortTip: shortMessage,
      category: "safety",
      priority: 5, // High priority for safety
    );

    print("SafetyTipService: Showing headlight reminder - $reminderMessage");

    // Play alert sound if enabled
    if (_enableSounds) {
      _playAlertSound("safety", false);
    }

    // Deliver the tip
    try {
      _onNewTip!(headlightTip);
      print("SafetyTipService: Headlight reminder delivered to UI");
    } catch (e) {
      print("SafetyTipService: Error delivering headlight reminder to UI: $e");
    }

    // Speak the tip if voice is enabled
    if (_enableVoice) {
      _speakTip(headlightTip, false);
    }
  }
}