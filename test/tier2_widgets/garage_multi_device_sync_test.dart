import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/profile_screen.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileScreen Garage Multi-Device Pull-to-Refresh & Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('ProfileScreen My Garage tab renders RefreshIndicator and AlwaysScrollableScrollPhysics ListView', (tester) async {
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = JobRepository();
        repo.isLoggedIn = true;
        expect(repo.currentUser.myGarage, isEmpty);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProfileScreen(repository: repo),
        ));
        await tester.pumpAndSettle();

        // Verify My Garage tab is active
        expect(find.text('My Garage'), findsOneWidget);
        expect(find.text('No Vehicles in Garage Yet'), findsOneWidget);

        // Verify RefreshIndicator exists
        expect(find.byType(RefreshIndicator), findsOneWidget);

        // Verify ListView exists with AlwaysScrollableScrollPhysics
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsOneWidget);
        final listView = tester.widget<ListView>(listViewFinder);
        expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });

    testWidgets('Pull to refresh gesture triggers refreshGarage without errors', (tester) async {
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = JobRepository();
        repo.isLoggedIn = true;
        const testVehicle = UserVehicle(
          id: 'veh_ui_01',
          year: 2024,
          make: 'Porsche',
          model: '911 Carrera GTS',
          colorName: 'Carmine Red',
          paintCode: '0L',
          imageUrl: '',
        );
        repo.addVehicleToGarage(testVehicle);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProfileScreen(repository: repo),
        ));
        await tester.pumpAndSettle();

        expect(find.text('2024 Porsche 911 Carrera GTS'), findsOneWidget);

        // Trigger pull to refresh gesture by dragging down on the ListView
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();
        // Pump past RefreshIndicator animation and async refreshGarage completion
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // UI should still be rendered stably
        expect(find.text('2024 Porsche 911 Carrera GTS'), findsOneWidget);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });

    testWidgets('UI dynamically updates when garage vehicle is added and removed across sessions', (tester) async {
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = JobRepository();
        repo.isLoggedIn = true;

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProfileScreen(repository: repo),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No Vehicles in Garage Yet'), findsOneWidget);

        // Add vehicle
        const v1 = UserVehicle(
          id: 'veh_multi_01',
          year: 2025,
          make: 'Ferrari',
          model: 'Roma Spider',
          colorName: 'Grigio Titanio',
          paintCode: 'FER704',
          imageUrl: '',
        );
        repo.addVehicleToGarage(v1);
        await tester.pumpAndSettle();

        expect(find.text('2025 Ferrari Roma Spider'), findsOneWidget);
        expect(find.text('Paint Color: Grigio Titanio'), findsOneWidget);

        // Remove vehicle
        repo.removeVehicleFromGarage('veh_multi_01');
        await tester.pumpAndSettle();

        expect(find.text('2025 Ferrari Roma Spider'), findsNothing);
        expect(find.text('No Vehicles in Garage Yet'), findsOneWidget);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });
  });
}
