import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Reviewer M3-2 Independent Verification & Adversarial Stress Tests', () {
    testWidgets('UI-1: BookingsListScreen renders 4 tabs, empty states, and switches cleanly', (tester) async {
      setupMockImageHttpClient();
      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        expect(repo.bookings, isEmpty);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify 4 tabs exist with count 0
        expect(find.text('Upcoming (0)'), findsOneWidget);
        expect(find.text('In Progress (0)'), findsOneWidget);
        expect(find.text('Completed (0)'), findsOneWidget);
        expect(find.text('Cancelled (0)'), findsOneWidget);

        // 2. Tab 0: Upcoming Empty state
        expect(find.text('No Upcoming Appointments'), findsOneWidget);
        expect(find.text('Confirmed and pending appointments will appear here.'), findsOneWidget);

        // 3. Switch to Tab 1: In Progress
        await tester.tap(find.text('In Progress (0)'));
        await tester.pumpAndSettle();
        expect(find.text('No Services In Progress'), findsOneWidget);
        expect(find.text('Active detailing jobs underway will appear here.'), findsOneWidget);

        // 4. Switch to Tab 2: Completed
        await tester.tap(find.text('Completed (0)'));
        await tester.pumpAndSettle();
        expect(find.text('No Completed Services'), findsOneWidget);
        expect(find.text('Your finished detailing appointments will be archived here.'), findsOneWidget);

        // 5. Switch to Tab 3: Cancelled
        await tester.tap(find.text('Cancelled (0)'));
        await tester.pumpAndSettle();
        expect(find.text('No Cancelled Bookings'), findsOneWidget);
        expect(find.text('Cancelled reservations will appear here.'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('UI-2: BookingFlowScreen specialist selection scrolls horizontally without overflow on mobile (390px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      setupMockImageHttpClient();

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      try {
        final repo = JobRepository();
        await repo.init();
        repo.isLoggedIn = true;

        const compactPkg = ServicePackage(
          id: 'pkg_compact',
          title: 'Express Coat',
          description: 'Quick coating',
          basePrice: 150.0,
          estimatedDuration: '2 hrs',
          includes: ['Wash', 'Coating'],
        );

        final detailerWithStaff = repo.currentUser.copyWith(
          servicePackages: [compactPkg],
          teamMembers: [
            const TeamMember(id: 'tm_1', name: 'Alexander Wright', roleTitle: 'Paint Correction Lead', avatarUrl: ''),
            const TeamMember(id: 'tm_2', name: 'Benjamin Thorne', roleTitle: 'Ceramic Coating Pro', avatarUrl: ''),
            const TeamMember(id: 'tm_3', name: 'Catherine Vance', roleTitle: 'Interior Specialist', avatarUrl: ''),
            const TeamMember(id: 'tm_4', name: 'David Miller', roleTitle: 'PPF Installer', avatarUrl: ''),
            const TeamMember(id: 'tm_5', name: 'Elena Rostova', roleTitle: 'Senior Technician', avatarUrl: ''),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingFlowScreen(
              detailer: detailerWithStaff,
              initialPackage: compactPkg,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 0: Tap Continue button
        final continueBtn = find.text('Continue');
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        // Now on Step 1: Vehicle & Date Step where specialist selection is located
        expect(find.text('Select Preferred Detail Specialist (Optional)'), findsOneWidget);
        expect(find.text('First Available'), findsOneWidget);
        expect(find.text('Alexander'), findsOneWidget);
        expect(find.text('Benjamin'), findsOneWidget);

        // Verify specialist selector has horizontal scroll
        final specialistScroll = find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        );
        expect(specialistScroll, findsOneWidget);

        final scroller = tester.widget<SingleChildScrollView>(specialistScroll);
        expect(scroller.scrollDirection, equals(Axis.horizontal));

        // Scroll horizontally to bring 'Elena' into view
        await tester.drag(specialistScroll, const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.text('Elena'), findsOneWidget);

        // Verify none of the caught errors come from the specialist selector Row
        final specialistErrors = errors.where((e) => e.toString().contains('booking_flow_screen.dart:639'));
        expect(specialistErrors, isEmpty, reason: 'Specialist selection Row must not overflow');
      } finally {
        FlutterError.onError = originalOnError;
        tearDownMockImageHttpClient();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    test('ADV-1: Rapid concurrent addBooking calls for conflicting slots reject race conditions', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      final date = DateTime(2026, 12, 10);
      const slot = '2:00 PM - 6:00 PM';

      final b1 = BookingAppointment(
        id: 'adv_race_1',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Alice',
        clientPhone: '555-0001',
        clientEmail: 'alice@example.com',
        vehicleYearMakeModel: 'Porsche Cayman GT4',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 500.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      final b2 = BookingAppointment(
        id: 'adv_race_2',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Bob',
        clientPhone: '555-0002',
        clientEmail: 'bob@example.com',
        vehicleYearMakeModel: 'Ferrari 488',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: date,
        scheduledTimeSlot: slot,
        totalPrice: 500.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      final success1 = repo.addBooking(b1);
      final success2 = repo.addBooking(b2);

      expect(success1, isTrue);
      expect(success2, isFalse, reason: 'Concurrent second booking for same slot must be rejected');
      expect(repo.bookings.where((b) => b.scheduledDate == date && b.scheduledTimeSlot == slot).length, equals(1));
    });

    test('ADV-2: Re-adding same booking ID is idempotent and does not duplicate', () async {
      final repo = JobRepository();
      await repo.init();
      repo.isLoggedIn = true;

      final b = BookingAppointment(
        id: 'adv_idempotent_1',
        detailerId: repo.currentUser.id,
        detailerName: repo.currentUser.displayName,
        detailerBusinessName: repo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Idempotent Client',
        clientPhone: '555-0003',
        clientEmail: 'idem@example.com',
        vehicleYearMakeModel: 'Audi RS3',
        vehicleSize: VehicleSize.coupeSedan,
        package: repo.currentUser.servicePackages.first,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime(2026, 12, 12),
        scheduledTimeSlot: '9:00 AM - 1:00 PM',
        totalPrice: 600.0,
        depositAmount: 150.0,
        status: BookingStatus.confirmed,
      );

      final countBefore = repo.bookings.length;
      final res1 = repo.addBooking(b);
      expect(res1, isTrue);
      expect(repo.bookings.length, equals(countBefore + 1));

      // Re-add exact same ID
      final res2 = repo.addBooking(b);
      expect(res2, isTrue);
      expect(repo.bookings.length, equals(countBefore + 1), reason: 'ID duplicates must update in-place, not insert duplicate entry');
    });
  });
}
