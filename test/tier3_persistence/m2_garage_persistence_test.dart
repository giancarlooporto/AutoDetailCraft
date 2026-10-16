import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/screens/vehicle_editor_dialog.dart';
import '../core/test_harness.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M2: My Garage Persistence & Lifecycle Hardening', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1: Add vehicle persists immediately to dedicated storage and survives browser refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      expect(repo1.currentUser.myGarage, isEmpty);

      final photoBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      final testVeh = UserVehicle(
        id: 'veh_test_gt3',
        year: 2024,
        make: 'Porsche',
        model: '911 GT3 RS',
        colorName: 'Shark Blue',
        paintCode: 'D5C',
        imageUrl: 'https://media.autodetailcraft.com/usr_you/gt3.jpg',
        localImageBytes: photoBytes,
        lastDetailService: 'Full PPF & Ceramic Coating',
        lastDetailDate: DateTime(2026, 5, 20),
      );

      // 1. Add vehicle
      repo1.addVehicleToGarage(testVeh);
      expect(repo1.currentUser.myGarage.length, 1);
      expect(repo1.currentUser.myGarage.first.id, 'veh_test_gt3');

      // Verify dedicated storage has it immediately
      final dedicatedVehicles = await LocalStorageService.loadGarageVehicles();
      expect(dedicatedVehicles.length, 1);
      expect(dedicatedVehicles.first.id, 'veh_test_gt3');
      expect(dedicatedVehicles.first.make, 'Porsche');
      expect(dedicatedVehicles.first.model, '911 GT3 RS');
      expect(dedicatedVehicles.first.paintCode, 'D5C');
      expect(dedicatedVehicles.first.localImageBytes, equals(photoBytes));

      // 2. Simulate browser refresh (Cmd+R)
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.myGarage.length, 1);
      final restored = repo2.currentUser.myGarage.first;
      expect(restored.id, 'veh_test_gt3');
      expect(restored.year, 2024);
      expect(restored.make, 'Porsche');
      expect(restored.model, '911 GT3 RS');
      expect(restored.colorName, 'Shark Blue');
      expect(restored.paintCode, 'D5C');
      expect(restored.imageUrl, 'https://media.autodetailcraft.com/usr_you/gt3.jpg');
      expect(restored.localImageBytes, equals(photoBytes));
      expect(restored.lastDetailService, 'Full PPF & Ceramic Coating');
      expect(restored.lastDetailDate, equals(DateTime(2026, 5, 20)));
    });

    test('T2: Update vehicle in garage updates dedicated storage and survives refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const testVeh = UserVehicle(
        id: 'veh_m4_cs',
        year: 2025,
        make: 'BMW',
        model: 'M4 CS',
        colorName: 'Riviera Blue',
        paintCode: 'P5C',
        imageUrl: 'https://media.autodetailcraft.com/usr_you/m4.jpg',
      );
      repo1.addVehicleToGarage(testVeh);

      // Update vehicle properties
      final updatedVeh = testVeh.copyWith(
        colorName: 'Isle of Man Green',
        paintCode: 'C4G',
        lastDetailService: 'Stage 2 Paint Correction',
        lastDetailDate: DateTime(2026, 8, 10),
      );
      repo1.updateVehicleInGarage(updatedVeh);

      // Verify repo1 in memory
      expect(repo1.currentUser.myGarage.first.colorName, 'Isle of Man Green');
      expect(repo1.currentUser.myGarage.first.paintCode, 'C4G');

      // Verify dedicated storage
      final dedicated = await LocalStorageService.loadGarageVehicles();
      expect(dedicated.first.colorName, 'Isle of Man Green');
      expect(dedicated.first.paintCode, 'C4G');

      // Refresh simulation
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.myGarage.length, 1);
      final refreshed = repo2.currentUser.myGarage.first;
      expect(refreshed.colorName, 'Isle of Man Green');
      expect(refreshed.paintCode, 'C4G');
      expect(refreshed.lastDetailService, 'Stage 2 Paint Correction');
    });

    test('T3: Remove vehicle from garage updates dedicated storage and survives refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const v1 = UserVehicle(id: 'v_1', year: 2023, make: 'Audi', model: 'RS6 Avant', colorName: 'Nardo Grey', imageUrl: '');
      const v2 = UserVehicle(id: 'v_2', year: 2024, make: 'Ferrari', model: '296 GTB', colorName: 'Rosso Corsa', imageUrl: '');
      repo1.addVehicleToGarage(v1);
      repo1.addVehicleToGarage(v2);
      expect(repo1.currentUser.myGarage.length, 2);

      repo1.removeVehicleFromGarage('v_1');
      expect(repo1.currentUser.myGarage.length, 1);
      expect(repo1.currentUser.myGarage.first.id, 'v_2');

      // Refresh simulation
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.myGarage.length, 1);
      expect(repo2.currentUser.myGarage.first.id, 'v_2');
      expect(repo2.currentUser.myGarage.first.model, '296 GTB');
    });

    test('T4: Cloud refresh non-destructive merge preserves local vehicles when Supabase returns empty', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      const localVeh = UserVehicle(
        id: 'veh_custom_local',
        year: 2024,
        make: 'Lucid',
        model: 'Air Sapphire',
        colorName: 'Sapphire Blue',
        imageUrl: '',
      );
      repo1.addVehicleToGarage(localVeh);
      expect(repo1.currentUser.myGarage.any((v) => v.id == 'veh_custom_local'), isTrue);

      // Verify that dedicated storage has the vehicle
      final dedicatedBefore = await LocalStorageService.loadGarageVehicles();
      expect(dedicatedBefore.any((v) => v.id == 'veh_custom_local'), isTrue);

      // Simulate a refresh where cloud database returns empty vehicles (e.g. unconfigured or offline)
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.currentUser.myGarage.any((v) => v.id == 'veh_custom_local'), isTrue);
      expect(repo2.currentUser.myGarage.first.model, 'Air Sapphire');
    });

    testWidgets('T5: VehicleEditorDialog validation displays user-visible SnackBar feedback on empty make/model', (tester) async {
      debugNetworkImageHttpClientProvider = () => MockHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = await TestHarness.createSession(isLoggedIn: true);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VehicleEditorDialog(repository: repo),
          ),
        ));
        await tester.pumpAndSettle();

        // Switch to manual entry mode
        await tester.tap(find.text('+ Type manually'));
        await tester.pumpAndSettle();

        // Clear the custom make textfield
        await tester.enterText(
          find.widgetWithText(TextField, 'Make (e.g. Lucid, Koenigsegg, Pagani, Lotus)'),
          '',
        );
        await tester.pumpAndSettle();

        // Tap 'Add to Garage'
        await tester.tap(find.text('Add to Garage'));
        await tester.pumpAndSettle();

        // Verify error feedback is displayed
        expect(find.text('Please specify vehicle make and model.'), findsOneWidget);
        expect(repo.currentUser.myGarage, isEmpty);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    });
  });
}
