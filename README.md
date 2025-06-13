# Mapbox Turn-by-Turn Navigation App

A Flutter application that provides turn-by-turn navigation using Mapbox services.

## Features

- Interactive map with current location tracking
- Search for destinations
- Turn-by-turn navigation with real-time instructions
- Route visualization
- ETA and distance calculation

## Setup Instructions

### 1. Get Mapbox Access Tokens

1. Create a Mapbox account at [mapbox.com](https://www.mapbox.com/)
2. Navigate to your account dashboard and get your access token
3. For some features, you might also need a Mapbox Downloads token

### 2. Configure Environment Variables

1. Open the `assets/config.properties` file
2. Replace the placeholder values with your actual Mapbox tokens:
   ```
   MAPBOX_ACCESS_TOKEN=your_mapbox_access_token_here
   MAPBOX_DOWNLOADS_TOKEN=your_mapbox_downloads_token_here
   ```

### 3. Firebase Setup

#### Firestore Security Rules

You need to set up Firestore security rules to allow authenticated users to read and write their own data. In your Firebase Console:

1. Go to Firestore Database
2. Click on "Rules" tab
3. Replace the default rules with:

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

4. Click "Publish" to apply the rules

### 4. Platform-Specific Setup

#### Android

1. Add the following permissions to your `android/app/src/main/AndroidManifest.xml` file:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

2. Set the minimum SDK version in `android/app/build.gradle`:
   ```gradle
   minSdkVersion 20
   ```

#### iOS

1. Add the following to your `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs access to location when open.</string>
   <key>io.flutter.embedded_views_preview</key>
   <true/>
   ```

2. Set the minimum iOS version in `ios/Podfile`:
   ```ruby
   platform :ios, '11.0'
   ```

## Running the App

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Usage

1. The app will open with a map centered on your current location (if permission is granted)
2. Tap the search button (floating action button) to search for a destination
3. Select a destination from the search results
4. The app will calculate the route and start turn-by-turn navigation
5. Follow the instructions displayed at the top of the screen
6. You can tap the close button to end navigation at any time

## Dependencies

- `mapbox_gl`: For map rendering and interaction
- `dio`: For HTTP requests
- `flutter_dotenv`: For environment variables management
- `location`: For location services
- `flutter_polyline_points`: For polyline decoding
- `geolocator`: For geolocation services
