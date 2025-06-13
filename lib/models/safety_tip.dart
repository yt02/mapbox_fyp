class SafetyTip {
  final String tip;
  final String shortTip; // Shorter version for display during driving
  final String category; // 'safety' or 'beginner'
  final int priority; // Higher priority tips shown more frequently
  final String? iconType; // Optional field to specify a custom icon to use
  final List<String> contexts; // Navigation contexts where this tip is relevant (e.g., 'roundabout', 'highway', etc.)

  SafetyTip({
    required this.tip,
    required this.category,
    required this.shortTip,
    this.priority = 1,
    this.iconType,
    this.contexts = const [], // Empty list means the tip is general and can be shown anytime
  });

  // Factory method to create a list of predefined safety tips
  static List<SafetyTip> getSafetyTips() {
    return [
      // Safety tips - General (no specific context)
      SafetyTip(
        tip: "Always maintain a safe following distance (3-second rule).",
        shortTip: "KEEP DISTANCE",
        category: "safety",
        priority: 3,
      ),
      SafetyTip(
        tip: "Use your turn signals well before making a turn or changing lanes.",
        shortTip: "USE SIGNALS",
        category: "safety",
        priority: 3,
      ),
      SafetyTip(
        tip: "Avoid using your phone while driving. Pull over if necessary.",
        shortTip: "NO PHONE",
        category: "safety",
        priority: 5,
      ),
      SafetyTip(
        tip: "Slow down in bad weather conditions.",
        shortTip: "SLOW IN RAIN",
        category: "safety",
        priority: 4,
      ),
      SafetyTip(
        tip: "Always wear your seatbelt and ensure all passengers do too.",
        shortTip: "SEATBELTS",
        category: "safety",
        priority: 5,
      ),
      SafetyTip(
        tip: "Don't drive when tired. Take breaks on long journeys.",
        shortTip: "REST WHEN TIRED",
        category: "safety",
        priority: 4,
      ),
      SafetyTip(
        tip: "Check your mirrors regularly.",
        shortTip: "CHECK MIRRORS",
        category: "safety",
        priority: 3,
      ),
      
      // Context-specific tips - Roundabouts
      SafetyTip(
        tip: "Slow down when approaching a roundabout and be prepared to give way.",
        shortTip: "SLOW FOR ROUNDABOUT",
        category: "safety",
        priority: 5,
        contexts: ['roundabout'],
      ),
      SafetyTip(
        tip: "Signal right when entering a roundabout from any entrance.",
        shortTip: "SIGNAL TO ENTER",
        category: "beginner",
        priority: 5,
        iconType: "turn_signal_right",
        contexts: ['roundabout'],
      ),
      SafetyTip(
        tip: "For roundabouts, signal left when exiting to inform other drivers.",
        shortTip: "EXIT SIGNAL",
        category: "safety",
        priority: 5,
        iconType: "turn_signal_left",
        contexts: ['roundabout'],
      ),
      SafetyTip(
        tip: "Give way to vehicles already on the roundabout.",
        shortTip: "GIVE WAY",
        category: "safety",
        priority: 5,
        contexts: ['roundabout'],
      ),
      SafetyTip(
        tip: "Look out for cyclists and motorcyclists when navigating roundabouts.",
        shortTip: "WATCH FOR BIKES",
        category: "safety",
        priority: 4,
        contexts: ['roundabout'],
      ),
      
      // Context-specific tips - Turns
      SafetyTip(
        tip: "Signal before turning left to alert other drivers of your intentions.",
        shortTip: "SIGNAL LEFT",
        category: "safety",
        priority: 4,
        iconType: "turn_signal_left",
        contexts: ['turn_left'],
      ),
      SafetyTip(
        tip: "Check your blind spot before making a left turn.",
        shortTip: "CHECK BLIND SPOT",
        category: "safety",
        priority: 4,
        contexts: ['turn_left'],
      ),
      SafetyTip(
        tip: "When turning right at a junction, activate your signal at least 30 meters before.",
        shortTip: "SIGNAL EARLY",
        category: "safety",
        priority: 4,
        iconType: "turn_signal_right",
        contexts: ['turn_right'],
      ),
      SafetyTip(
        tip: "Look for pedestrians when making a right turn at intersections.",
        shortTip: "WATCH FOR PEDESTRIANS",
        category: "safety",
        priority: 4,
        contexts: ['turn_right'],
      ),
      
      // Context-specific tips - Highway
      SafetyTip(
        tip: "Maintain a larger following distance at highway speeds.",
        shortTip: "EXTRA DISTANCE",
        category: "safety",
        priority: 4,
        contexts: ['highway', 'highway_enter'],
      ),
      SafetyTip(
        tip: "Use your turn signal when changing lanes on the highway.",
        shortTip: "SIGNAL LANE CHANGES",
        category: "safety",
        priority: 4,
        contexts: ['highway'],
      ),
      SafetyTip(
        tip: "Turn on your left signal in advance when exiting highways.",
        shortTip: "SIGNAL TO EXIT",
        category: "beginner",
        priority: 4,
        iconType: "turn_signal_left",
        contexts: ['highway_exit'],
      ),
      SafetyTip(
        tip: "Accelerate on the entry ramp to match highway speeds before merging.",
        shortTip: "MATCH SPEED",
        category: "beginner",
        priority: 4,
        contexts: ['highway_enter'],
      ),
      SafetyTip(
        tip: "Stay in the left lane unless overtaking on highways.",
        shortTip: "KEEP LEFT",
        category: "beginner",
        priority: 3,
        contexts: ['highway'],
      ),
      
      // Context-specific tips - Intersections
      SafetyTip(
        tip: "Be extra cautious at intersections.",
        shortTip: "CAREFUL AT JUNCTIONS",
        category: "safety",
        priority: 4,
        contexts: ['intersection'],
      ),
      SafetyTip(
        tip: "Look both ways even at controlled intersections.",
        shortTip: "LOOK BOTH WAYS",
        category: "safety",
        priority: 4,
        contexts: ['intersection'],
      ),
      SafetyTip(
        tip: "Yield to pedestrians at intersections.",
        shortTip: "YIELD TO PEDESTRIANS",
        category: "safety",
        priority: 4,
        contexts: ['intersection'],
      ),
      
      // Context-specific tips - Merging
      SafetyTip(
        tip: "Use your turn signal when merging into traffic.",
        shortTip: "SIGNAL WHEN MERGING",
        category: "safety",
        priority: 5,
        iconType: "turn_signal_right",
        contexts: ['merge'],
      ),
      SafetyTip(
        tip: "Check your blind spot before merging.",
        shortTip: "CHECK BLIND SPOT",
        category: "safety",
        priority: 5,
        contexts: ['merge'],
      ),
      SafetyTip(
        tip: "Adjust your speed to match the flow of traffic when merging.",
        shortTip: "MATCH TRAFFIC SPEED",
        category: "beginner",
        priority: 4,
        contexts: ['merge'],
      ),
      
      // Context-specific tips - Continue straight
      SafetyTip(
        tip: "Maintain your lane position when continuing straight.",
        shortTip: "STAY IN LANE",
        category: "beginner",
        priority: 3,
        contexts: ['continue'],
      ),
      SafetyTip(
        tip: "Keep a safe following distance from the vehicle ahead.",
        shortTip: "KEEP DISTANCE",
        category: "safety",
        priority: 4,
        contexts: ['continue'],
      ),
      
      // Context-specific tips - Arrival
      SafetyTip(
        tip: "Slow down gradually as you approach your destination.",
        shortTip: "SLOW GRADUALLY",
        category: "beginner",
        priority: 4,
        contexts: ['arrive'],
      ),
      SafetyTip(
        tip: "Watch for pedestrians when arriving at your destination.",
        shortTip: "WATCH FOR PEDESTRIANS",
        category: "safety",
        priority: 5,
        contexts: ['arrive'],
      ),
      SafetyTip(
        tip: "Use your turn signal when pulling over to park.",
        shortTip: "SIGNAL TO PARK",
        category: "beginner",
        priority: 4,
        iconType: "turn_signal_right",
        contexts: ['arrive'],
      ),
      
      // General beginner tips
      SafetyTip(
        tip: "Keep both hands on the wheel at the 9 and 3 o'clock positions.",
        shortTip: "BOTH HANDS ON WHEEL",
        category: "beginner",
        priority: 2,
      ),
      SafetyTip(
        tip: "Remember to cancel your turn signal after completing your turn.",
        shortTip: "CANCEL SIGNAL",
        category: "beginner",
        priority: 3,
        iconType: "turn_signal_off",
      ),
      SafetyTip(
        tip: "Adjust your mirrors before starting your journey.",
        shortTip: "CHECK MIRRORS",
        category: "beginner",
        priority: 2,
      ),
      SafetyTip(
        tip: "Use the MSPSL routine: Mirror, Signal, Position, Speed, Look.",
        shortTip: "MIRROR SIGNAL LOOK",
        category: "beginner",
        priority: 3,
      ),
      SafetyTip(
        tip: "Always give way to emergency vehicles with flashing lights.",
        shortTip: "GIVE WAY",
        category: "beginner",
        priority: 4,
      ),
      SafetyTip(
        tip: "When parallel parking, start by aligning with the car in front.",
        shortTip: "ALIGN TO PARK",
        category: "beginner",
        priority: 2,
      ),
      SafetyTip(
        tip: "Avoid driving in other vehicles' blind spots.",
        shortTip: "AVOID BLIND SPOTS",
        category: "beginner",
        priority: 3,
      ),
      SafetyTip(
        tip: "In Malaysia, exit on the left side of the road.",
        shortTip: "EXIT LEFT",
        category: "beginner",
        priority: 5,
      ),
    ];
  }
  
  // Check if this tip is relevant for a specific context
  bool isRelevantForContext(String context) {
    // If the tip has no specific contexts, it's a general tip that can be shown anytime
    if (contexts.isEmpty) {
      return true;
    }
    
    // Check if the tip's contexts include the specified context
    return contexts.contains(context);
  }
} 