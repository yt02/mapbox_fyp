# Intelligent Car Driving Assistant (ICDA)

An advanced Flutter application that combines AI-powered navigation with intelligent safety features to provide a comprehensive driving assistance system.

## 🚗 Overview

ICDA is more than just a navigation app - it's your intelligent driving companion that provides:
- **Smart Navigation**: Turn-by-turn navigation with AI-powered safety assistance
- **AI Vision Assistant**: Real-time object detection through dashcam integration
- **Safety Intelligence**: Context-aware driving tips and warnings
- **Weather Integration**: Real-time weather information for route planning

## ✨ Key Features

### 🧭 Smart Navigation
- **Interactive Mapbox Integration**: High-quality maps with real-time location tracking
- **Intelligent Route Planning**: Optimized routes with multiple waypoint support
- **Turn Signal Indicators**: Visual reminders for upcoming turns (500m advance warning)
- **Voice Navigation**: Clear turn-by-turn voice instructions
- **Speed Monitoring**: Real-time speed tracking with limit warnings
- **Simulation Mode**: Test navigation routes without actual driving

### 🤖 AI Vision Assistant
- **Real-time Object Detection**: YOLOv8-powered detection of vehicles, pedestrians, and road signs
- **Dashcam Integration**: Connect external cameras for enhanced safety monitoring
- **Smart Alerts**: Context-aware warnings based on detected objects

### 🛡️ Safety Intelligence
- **Context-Aware Safety Tips**: Driving tips based on current navigation context
- **Time-Based Reminders**: Automatic headlight reminders during dawn/dusk/night
- **Speed Limit Warnings**: Visual and audio alerts for speeding
- **Emergency Situations**: Priority safety tips for critical driving scenarios

### 🌤️ Weather Integration
- **Real-time Weather Data**: Current conditions along your route
- **Weather-Aware Planning**: Route adjustments based on weather conditions
- **Visibility Warnings**: Alerts for poor weather driving conditions

### 👤 User Experience
- **Firebase Authentication**: Secure user accounts with Google Sign-In
- **Personalized Profiles**: Save preferences and driving history
- **Offline Capabilities**: Core navigation features work without internet
- **Multi-platform Support**: Android and iOS compatibility

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (3.8.0 or higher)
- Android Studio / Xcode for mobile development
- Firebase account
- Mapbox account
- Google Cloud Platform account (for Places API)

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd mapbox_fyp
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure API Keys

#### Mapbox Setup
1. Create a Mapbox account at [mapbox.com](https://www.mapbox.com/)
2. Get your access token from the account dashboard
3. Open `assets/config.properties` and add your tokens:
   ```properties
   MAPBOX_ACCESS_TOKEN=your_mapbox_access_token_here
   MAPBOX_DOWNLOADS_TOKEN=your_mapbox_downloads_token_here
   GOOGLE_API_KEY=your_google_places_api_key_here
   OPENWEATHER_API_KEY=your_openweather_api_key_here
   ```

#### Google Places API Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Places API
3. Create an API key and add it to your config file

#### OpenWeather API Setup
1. Sign up at [OpenWeatherMap](https://openweathermap.org/api)
2. Get your free API key
3. Add it to your config file

### 4. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Authentication and Firestore Database

#### Configure Firebase for Flutter
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Configure FlutterFire: `dart pub global activate flutterfire_cli`
4. Run: `flutterfire configure`

#### Enable Authentication Methods
1. In Firebase Console, go to Authentication > Sign-in method
2. Enable Email/Password and Google sign-in
3. For Google sign-in, add your app's SHA-1 fingerprint

#### Firestore Security Rules
Set up Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own profile data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Allow users to query for usernames during registration/login
    match /users/{document} {
      allow read: if request.auth != null &&
                     resource.data.keys().hasAny(['username', 'email']);
    }
  }
}
```

### 5. Platform-Specific Setup

#### Android
1. Add permissions to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
   ```

2. Set minimum SDK version in `android/app/build.gradle`:
   ```gradle
   minSdkVersion 21
   compileSdkVersion 34
   ```

#### iOS
1. Add permissions to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs location access for navigation.</string>
   <key>NSCameraUsageDescription</key>
   <string>This app needs camera access for AI vision features.</string>
   <key>NSMicrophoneUsageDescription</key>
   <string>This app needs microphone access for voice commands.</string>
   <key>io.flutter.embedded_views_preview</key>
   <true/>
   ```

2. Set minimum iOS version in `ios/Podfile`:
   ```ruby
   platform :ios, '12.0'
   ```

## 🏃‍♂️ Running the App

### Development Mode
```bash
flutter run
```

### Release Mode
```bash
flutter run --release
```

### Build APK (Android)
```bash
flutter build apk --release
```

### Build IPA (iOS)
```bash
flutter build ios --release
```

## 📱 How to Use

### Getting Started
1. **Launch the App**: Open ICDA and sign in with your Google account
2. **Grant Permissions**: Allow location, camera, and microphone access
3. **Choose Mode**: Select "Smart Navigation" or "AI Vision Assistant"

### Smart Navigation Mode
1. **Search Destination**: Tap the search icon to find your destination
2. **Plan Route**: The app calculates the optimal route with real-time traffic
3. **Start Navigation**: Choose "Start" for real navigation or "Simulate" for testing
4. **Follow Instructions**:
   - Turn-by-turn voice guidance
   - Visual turn signal indicators (500m before turns)
   - Real-time speed monitoring
   - Weather-aware route adjustments

### AI Vision Assistant Mode
1. **Connect Dashcam**: Follow the connection wizard to link your camera
2. **Real-time Detection**: The AI identifies vehicles, pedestrians, and road signs
3. **Smart Alerts**: Receive context-aware safety warnings
4. **Recording**: Optionally record and analyze driving sessions

### Key Features in Action
- **Turn Signal Reminders**: 🔄 Visual indicators appear 500m before turns
- **Speed Warnings**: ⚠️ Alerts when exceeding speed limits
- **Weather Integration**: 🌤️ Real-time weather data affects route planning
- **Safety Tips**: 💡 Context-aware driving advice based on road conditions
- **Night Mode**: 🌙 Automatic headlight reminders during low-light conditions

## Dependencies

- `mapbox_gl`: For map rendering and interaction
- `dio`: For HTTP requests
- `flutter_dotenv`: For environment variables management
- `location`: For location services
- `flutter_polyline_points`: For polyline decoding
- `geolocator`: For geolocation services
