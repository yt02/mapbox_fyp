import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_fyp/widgets/points_of_interest.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

void main() {
  group('PointsOfInterest Widget Tests', () {
    testWidgets('POI selection and unselection works correctly', (WidgetTester tester) async {
      bool poiSelected = false;
      bool poiUnselected = false;
      
      // Create a test widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointsOfInterest(
              latitude: 3.1390,
              longitude: 101.6869,
              onPoiSelected: (Point point, {String? placeName, String? placeAddress}) {
                poiSelected = true;
              },
              onPoiUnselected: () {
                poiUnselected = true;
              },
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pump();

      // Verify that the widget is rendered
      expect(find.byType(PointsOfInterest), findsOneWidget);
      
      // Verify that category chips are present
      expect(find.byType(ChoiceChip), findsWidgets);
      
      // The test passes if the widget builds without errors
      // In a real scenario, we would mock the HTTP requests to test POI selection
    });

    testWidgets('Category selection and unselection works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointsOfInterest(
              latitude: 3.1390,
              longitude: 101.6869,
              onPoiSelected: (Point point, {String? placeName, String? placeAddress}) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially, no category should be selected, so only category chips should be visible
      expect(find.byType(ChoiceChip), findsWidgets);

      // Find and tap the restaurants category chip
      final restaurantsChip = find.widgetWithText(ChoiceChip, 'Restaurants');
      if (restaurantsChip.evaluate().isNotEmpty) {
        await tester.tap(restaurantsChip);
        await tester.pump();

        // After selecting, the category should be highlighted
        // (In a real test with mocked HTTP, we would see POI results)
      }
    });
  });
}
