import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/profile_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/widgets/split_slider_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3: My Garage Service History & Care Log', () {
    test('updateBookingStatus(completed) updates matching garage vehicle lastDetailService & lastDetailDate', () async {
      final repo = JobRepository();
      final vehicle = UserVehicle(
        id: 'veh_1',
        year: 2022,
        make: 'Porsche',
        model: '911 GT3',
        vehicleType: 'Coupe',
        colorName: 'Guards Red',
        imageUrl: '',
      );
      repo.addVehicleToGarage(vehicle);

      final scheduled = DateTime(2026, 10, 15, 10, 0);
      final booking = BookingAppointment(
        id: 'bk_unit_1',
        clientId: repo.currentUser.id,
        clientName: repo.currentUser.displayName,
        clientPhone: '555-0100',
        clientEmail: 'client@example.com',
        clientAddress: '123 Main St',
        detailerId: 'det_1',
        detailerName: 'Apex Detail',
        detailerBusinessName: 'Apex Ceramic Studio',
        detailerAvatar: '',
        package: ServicePackage(
          id: 'pkg_1',
          title: '2-Stage Paint Correction',
          description: 'Full correction',
          basePrice: 1200,
          estimatedDuration: '8 hrs',
          includes: const ['2-Stage Polish'],
        ),
        scheduledDate: scheduled,
        scheduledTimeSlot: '10:00 AM',
        vehicleYearMakeModel: '2022 Porsche 911 GT3',
        vehicleSize: VehicleSize.values.first,
        locationType: ServiceLocationType.values.first,
        totalPrice: 1200,
        depositAmount: 200,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(booking);

      await repo.updateBookingStatus('bk_unit_1', BookingStatus.completed);

      final updatedVeh = repo.currentUser.myGarage.firstWhere((v) => v.id == 'veh_1');
      expect(updatedVeh.lastDetailService, '2-Stage Paint Correction');
      expect(updatedVeh.lastDetailDate, scheduled);
    });

    testWidgets('Completed booking appears in My Garage Service History with notes, slider, and Re-Book navigates to BookingFlowScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = JobRepository();
      repo.isLoggedIn = true;
      // Ensure client mode so My Garage is visible
      repo.updateProfile(repo.currentUser.copyWith(role: UserRole.client));

      final vehicle = UserVehicle(
        id: 'veh_gt3',
        year: 2022,
        make: 'Porsche',
        model: '911 GT3',
        vehicleType: 'Coupe',
        colorName: 'Shark Blue',
        imageUrl: '',
      );
      repo.addVehicleToGarage(vehicle);

      final booking = BookingAppointment(
        id: 'bk_hist_1',
        clientId: repo.currentUser.id,
        clientName: repo.currentUser.displayName,
        clientPhone: '555-0100',
        clientEmail: 'client@example.com',
        clientAddress: '123 Main St',
        detailerId: 'det_apex',
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Ceramic Studio',
        detailerAvatar: '',
        package: ServicePackage(
          id: 'pkg_ceramic',
          title: '5-Year Ceramic Coating',
          description: 'Full ceramic protection',
          basePrice: 1500,
          estimatedDuration: '6 hrs',
          includes: const ['9H Ceramic'],
        ),
        scheduledDate: DateTime(2026, 9, 20, 9, 0),
        scheduledTimeSlot: '9:00 AM',
        vehicleYearMakeModel: '2022 Porsche 911 GT3',
        vehicleSize: VehicleSize.values.first,
        locationType: ServiceLocationType.values.first,
        totalPrice: 1500,
        depositAmount: 250,
        status: BookingStatus.completed,
        completionNotes: 'Removed 95% of wash marring and applied 2 coats of 9H ceramic.',
        beforePhotos: ['https://example.com/before.jpg'],
        afterPhotos: ['https://example.com/after.jpg'],
      );
      repo.addBooking(booking);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final myGarageTab = find.text('My Garage');
      if (myGarageTab.evaluate().isNotEmpty) {
        await tester.tap(myGarageTab);
        await tester.pumpAndSettle();
      }

      // Service History (1) button should be visible on the vehicle card
      final historyBtn = find.text('Service History (1)');
      await tester.scrollUntilVisible(
        historyBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(historyBtn, findsOneWidget);

      await tester.ensureVisible(historyBtn);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      // Verify Service History sheet contents
      expect(find.text('Service History & Care Log'), findsOneWidget);
      expect(find.text('5-Year Ceramic Coating'), findsWidgets);
      expect(find.text('Apex Ceramic Studio'), findsOneWidget);
      expect(find.text('Removed 95% of wash marring and applied 2 coats of 9H ceramic.'), findsOneWidget);
      expect(find.byType(SplitSliderWidget), findsOneWidget);

      // Tap Re-Book and verify navigation to BookingFlowScreen
      final rebookBtn = find.text('Re-Book');
      expect(rebookBtn, findsOneWidget);
      await tester.ensureVisible(rebookBtn);
      await tester.tap(rebookBtn);
      await tester.pumpAndSettle();

      expect(find.byType(BookingFlowScreen), findsOneWidget);
    });

    testWidgets('Vehicle with no completed bookings renders cleanly without Service History button or overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = JobRepository();
      repo.isLoggedIn = true;
      repo.updateProfile(repo.currentUser.copyWith(role: UserRole.client));

      final vehicle = UserVehicle(
        id: 'veh_clean',
        year: 2024,
        make: 'BMW',
        model: 'M3',
        vehicleType: 'Sedan',
        colorName: 'Isle of Man Green',
        imageUrl: '',
      );
      repo.addVehicleToGarage(vehicle);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final myGarageTab = find.text('My Garage');
      if (myGarageTab.evaluate().isNotEmpty) {
        await tester.tap(myGarageTab);
        await tester.pumpAndSettle();
      }

      final vehicleFinder = find.text('2024 BMW M3');
      await tester.scrollUntilVisible(
        vehicleFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(vehicleFinder, findsOneWidget);
      expect(find.textContaining('Service History'), findsNothing);
    });

    test('completeBookingAndPublishToPortfolio updates matching garage vehicle lastDetailService & lastDetailDate', () async {
      final repo = JobRepository();

      final vehicle = UserVehicle(
        id: 'veh_pub_1',
        year: 2022,
        make: 'Audi',
        model: 'RS6',
        vehicleType: 'Wagon',
        colorName: 'Nardo Gray',
        imageUrl: '',
      );
      repo.addVehicleToGarage(vehicle);

      final scheduled = DateTime(2026, 10, 5, 14, 0);
      final booking = BookingAppointment(
        id: 'bk_pub_1',
        clientId: repo.currentUser.id,
        clientName: repo.currentUser.displayName,
        clientPhone: '555-0100',
        clientEmail: 'client@example.com',
        clientAddress: '123 Main St',
        detailerId: 'det_1',
        detailerName: 'Apex Detailers',
        detailerBusinessName: 'Apex Auto Spa',
        detailerAvatar: '',
        package: ServicePackage(
          id: 'pkg_pub_1',
          title: 'Full Paint Correction',
          description: '2-stage correction',
          basePrice: 950,
          estimatedDuration: '5 hrs',
          includes: const ['2-Stage Polish'],
        ),
        scheduledDate: scheduled,
        scheduledTimeSlot: '2:00 PM',
        vehicleYearMakeModel: '2022 Audi RS6',
        vehicleSize: VehicleSize.values.first,
        locationType: ServiceLocationType.values.first,
        totalPrice: 950,
        depositAmount: 150,
        status: BookingStatus.inProgress,
      );
      repo.addBooking(booking);

      await repo.completeBookingAndPublishToPortfolio(
        'bk_pub_1',
        beforePhotos: const ['https://example.com/before.jpg'],
        afterPhotos: const ['https://example.com/after.jpg'],
        completionNotes: 'Mirror finish achieved.',
      );

      final updated = repo.currentUser.myGarage.firstWhere((v) => v.id == 'veh_pub_1');
      expect(updated.lastDetailService, 'Full Paint Correction');
      expect(updated.lastDetailDate, scheduled);
    });
  });
}
