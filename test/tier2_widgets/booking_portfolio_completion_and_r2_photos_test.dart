import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/screens/bookings_list_screen.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/screens/create_job_screen.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/r2_storage_service.dart';
import 'package:detail_craft/services/image_picker_service.dart';
import 'package:detail_craft/widgets/split_slider_widget.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Booking Inspection Photos (Cloudflare R2) & Studio Portfolio Publishing Tests', () {
    late JobRepository repo;
    final List<({String userId, Uint8List bytes, String? customFileName})> r2Uploads = [];
    final List<String> r2Deletions = [];

    const samplePackage = ServicePackage(
      id: 'pkg_ceramic_01',
      title: '2-Stage Paint Correction & Ceramic Coating',
      description: 'Compound, polish, and 5-year 9H ceramic coating protection.',
      basePrice: 950.0,
      estimatedDuration: '6 hrs',
      includes: ['2-stage correction', '5-Yr Ceramic Coating', 'IR Cure'],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      r2Uploads.clear();
      r2Deletions.clear();

      R2StorageService.mockUploadOverride = ({
        required String userId,
        required Uint8List bytes,
        String contentType = 'image/jpeg',
        String? customFileName,
      }) async {
        r2Uploads.add((userId: userId, bytes: bytes, customFileName: customFileName));
        final fileName = customFileName ?? 'photo_${r2Uploads.length}.jpg';
        return 'https://media.autodetailcraft.com/$userId/$fileName';
      };

      R2StorageService.mockDeleteOverride = (String imageUrl) async {
        r2Deletions.add(imageUrl);
        return true;
      };

      mockPickImageOverride = () async => (
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
            name: 'inspection_photo.jpg',
          );

      repo = JobRepository();
      await repo.init();
    });

    tearDown(() {
      R2StorageService.mockUploadOverride = null;
      R2StorageService.mockDeleteOverride = null;
      mockPickImageOverride = null;
      mockPickMultipleImagesOverride = null;
    });

    test('1. BookingAppointment Serialization & Deserialization of beforePhotos, afterPhotos, completionNotes, and portfolioJobId', () {
      const r2Before = 'https://media.autodetailcraft.com/usr_d1/booking_bk_1_before_1001.jpg';
      const r2After = 'https://media.autodetailcraft.com/usr_d1/booking_bk_1_after_1002.jpg';

      final booking = BookingAppointment(
        id: 'bk_ser_01',
        clientId: 'usr_client_1',
        detailerId: 'usr_d1',
        detailerName: 'Apex Detailer',
        detailerBusinessName: 'Apex Auto Studio',
        detailerAvatar: '',
        clientName: 'Marcus Vance',
        clientPhone: '512-555-0199',
        clientEmail: 'marcus@example.com',
        vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '500 Congress Ave, Austin, TX',
        scheduledDate: DateTime(2026, 11, 15),
        scheduledTimeSlot: '09:00 AM - 03:00 PM',
        totalPrice: 950.0,
        depositAmount: 190.0,
        status: BookingStatus.completed,
        beforePhotos: const [r2Before],
        afterPhotos: const [r2After],
        completionNotes: 'Achieved 92% defect removal and cured 2 layers of ceramic.',
        portfolioJobId: 'job_portfolio_999',
      );

      // Verify toJson / fromJson roundtrip (camelCase)
      final jsonMap = booking.toJson();
      expect(jsonMap['beforePhotos'], equals([r2Before]));
      expect(jsonMap['afterPhotos'], equals([r2After]));
      expect(jsonMap['completionNotes'], equals('Achieved 92% defect removal and cured 2 layers of ceramic.'));
      expect(jsonMap['portfolioJobId'], equals('job_portfolio_999'));

      final fromJsonBooking = BookingAppointment.fromJson(jsonMap);
      expect(fromJsonBooking.beforePhotos, equals([r2Before]));
      expect(fromJsonBooking.afterPhotos, equals([r2After]));
      expect(fromJsonBooking.completionNotes, equals('Achieved 92% defect removal and cured 2 layers of ceramic.'));
      expect(fromJsonBooking.portfolioJobId, equals('job_portfolio_999'));

      // Verify toSupabase / fromSupabase roundtrip (snake_case)
      final supaMap = booking.toSupabase();
      expect(supaMap['before_photos'], equals([r2Before]));
      expect(supaMap['after_photos'], equals([r2After]));
      expect(supaMap['completion_notes'], equals('Achieved 92% defect removal and cured 2 layers of ceramic.'));
      expect(supaMap['portfolio_job_id'], equals('job_portfolio_999'));

      // Ensure no raw base64 data is ever stored in Supabase payload
      for (final url in (supaMap['before_photos'] as List)) {
        expect(url.toString().startsWith('https://media.autodetailcraft.com/'), isTrue);
        expect(url.toString().contains('base64'), isFalse);
      }
      for (final url in (supaMap['after_photos'] as List)) {
        expect(url.toString().startsWith('https://media.autodetailcraft.com/'), isTrue);
        expect(url.toString().contains('base64'), isFalse);
      }

      final fromSupaBooking = BookingAppointment.fromSupabase(supaMap);
      expect(fromSupaBooking.beforePhotos, equals([r2Before]));
      expect(fromSupaBooking.afterPhotos, equals([r2After]));
      expect(fromSupaBooking.completionNotes, equals('Achieved 92% defect removal and cured 2 layers of ceramic.'));
      expect(fromSupaBooking.portfolioJobId, equals('job_portfolio_999'));

      // Verify copyWith
      final updatedCopy = fromSupaBooking.copyWith(
        beforePhotos: [r2Before, 'https://media.autodetailcraft.com/usr_d1/booking_bk_1_before_1003.jpg'],
        completionNotes: 'Updated notes',
      );
      expect(updatedCopy.beforePhotos.length, equals(2));
      expect(updatedCopy.completionNotes, equals('Updated notes'));
      expect(updatedCopy.portfolioJobId, equals('job_portfolio_999'));
    });

    testWidgets('2. DetailerWorkbenchView uploads Before & After photos exclusively to Cloudflare R2 and renders live 50/50 SplitSliderWidget', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_r2',
          role: UserRole.detailer,
          displayName: 'R2 Studio Pro',
          businessName: 'R2 Detailing Lab',
        );
        await repo.loginUser(detailerUser);

        final inProgressBooking = BookingAppointment(
          id: 'bk_r2_upload_01',
          clientId: 'usr_client_r2',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Elena Rostova',
          clientPhone: '512-555-0888',
          clientEmail: 'elena@example.com',
          vehicleYearMakeModel: '2023 BMW M4 Competition',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Congress Ave, Austin, TX',
          scheduledDate: DateTime.now(),
          scheduledTimeSlot: '10:00 AM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.inProgress,
        );

        repo.addBooking(inProgressBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inspection Photos card is visible
        expect(find.byKey(const Key('booking_inspection_photos_card')), findsOneWidget);
        expect(find.text('📸 Before & After Inspection Photos (Cloudflare R2)'), findsOneWidget);

        // Upload a Before photo
        final beforeBtn = find.byKey(const Key('booking_upload_before_photo_btn'));
        await tester.ensureVisible(beforeBtn);
        await tester.pumpAndSettle();
        await tester.tap(beforeBtn);
        await tester.pumpAndSettle();

        expect(r2Uploads.length, equals(1));
        expect(r2Uploads.first.userId, equals('usr_detailer_r2'));
        expect(r2Uploads.first.customFileName, startsWith('booking_bk_r2_upload_01_before_'));

        // Upload an After photo
        final afterBtn = find.byKey(const Key('booking_upload_after_photo_btn'));
        await tester.ensureVisible(afterBtn);
        await tester.pumpAndSettle();
        await tester.tap(afterBtn);
        await tester.pumpAndSettle();

        expect(r2Uploads.length, equals(2));
        expect(r2Uploads.last.userId, equals('usr_detailer_r2'));
        expect(r2Uploads.last.customFileName, startsWith('booking_bk_r2_upload_01_after_'));

        // Verify booking model in repository only stores R2 CDN URLs (never base64)
        final updatedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_r2_upload_01');
        expect(updatedBooking.beforePhotos.length, equals(1));
        expect(updatedBooking.afterPhotos.length, equals(1));
        expect(updatedBooking.beforePhotos.first, startsWith('https://media.autodetailcraft.com/usr_detailer_r2/booking_bk_r2_upload_01_before_'));
        expect(updatedBooking.afterPhotos.first, startsWith('https://media.autodetailcraft.com/usr_detailer_r2/booking_bk_r2_upload_01_after_'));
        expect(updatedBooking.beforePhotos.first.contains('base64'), isFalse);
        expect(updatedBooking.afterPhotos.first.contains('base64'), isFalse);

        // Live 50/50 SplitSliderWidget preview is now displayed inside the Booking Inspector card
        expect(find.byKey(const Key('booking_inspector_split_slider')), findsOneWidget);

        // Remove Before photo and verify R2StorageService.deleteImage is invoked with the R2 URL
        final removeBeforeBtn = find.byKey(const Key('remove_before_photo_0'));
        await tester.ensureVisible(removeBeforeBtn);
        await tester.pumpAndSettle();
        await tester.tap(removeBeforeBtn);
        await tester.pumpAndSettle();

        expect(r2Deletions.length, equals(1));
        expect(r2Deletions.first, startsWith('https://media.autodetailcraft.com/usr_detailer_r2/booking_bk_r2_upload_01_before_'));
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_r2_upload_01').beforePhotos, isEmpty);
        // 50/50 SplitSliderWidget hides when one side has 0 photos
        expect(find.byKey(const Key('booking_inspector_split_slider')), findsNothing);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('3. Completing a job with "Publish to Studio Portfolio" enabled marks booking completed, creates DetailJob with R2 URLs, and links portfolioJobId', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_pub',
          role: UserRole.detailer,
          displayName: 'Portfolio Master',
          businessName: 'Master Craft Studio',
        );
        await repo.loginUser(detailerUser);

        const r2BeforeUrl = 'https://media.autodetailcraft.com/usr_detailer_pub/booking_bk_pub_01_before_111.jpg';
        const r2AfterUrl = 'https://media.autodetailcraft.com/usr_detailer_pub/booking_bk_pub_01_after_222.jpg';

        final booking = BookingAppointment(
          id: 'bk_pub_01',
          clientId: 'usr_client_pub',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Liam Neeson',
          clientPhone: '512-555-0999',
          clientEmail: 'liam@example.com',
          vehicleYearMakeModel: '2024 Porsche 911 GT3 RS',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Studio Rd',
          scheduledDate: DateTime.now(),
          scheduledTimeSlot: '09:00 AM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.inProgress,
          beforePhotos: const [r2BeforeUrl],
          afterPhotos: const [r2AfterUrl],
        );

        repo.addBooking(booking);
        final initialJobCount = repo.jobs.length;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Complete Job button
        final completeBtn = find.byKey(const Key('booking_complete_job_btn'));
        await tester.ensureVisible(completeBtn);
        await tester.pumpAndSettle();
        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        // Complete Job & Portfolio modal appears
        expect(find.byKey(const Key('complete_job_portfolio_modal')), findsOneWidget);
        expect(find.text('Complete Job & Portfolio'), findsOneWidget);

        // Enter completion notes
        await tester.enterText(
          find.byKey(const Key('booking_completion_notes_input')),
          'Full 2-stage correction and 5-year ceramic coating completed.',
        );
        await tester.pumpAndSettle();

        // Because before & after photos are present, Publish to Studio Portfolio is enabled by default
        expect(find.text('Complete & Publish to Portfolio'), findsOneWidget);

        // Confirm & Publish
        await tester.tap(find.byKey(const Key('confirm_complete_booking_btn')));
        await tester.pumpAndSettle();

        // Verify booking is completed and linked to created portfolio job
        final completedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_pub_01');
        expect(completedBooking.status, equals(BookingStatus.completed));
        expect(completedBooking.completionNotes, equals('Full 2-stage correction and 5-year ceramic coating completed.'));
        expect(completedBooking.portfolioJobId, isNotNull);
        expect(completedBooking.portfolioJobId!.isNotEmpty, isTrue);

        // Verify new DetailJob was added to repository.jobs with R2 URLs & parsed vehicle details
        expect(repo.jobs.length, equals(initialJobCount + 1));
        final publishedJob = repo.jobs.firstWhere((j) => j.id == completedBooking.portfolioJobId);
        expect(publishedJob.vehicleYear, equals(2024));
        expect(publishedJob.vehicleMake, equals('Porsche'));
        expect(publishedJob.vehicleModel, equals('911 GT3 RS'));
        expect(publishedJob.beforeImageUrl, equals(r2BeforeUrl));
        expect(publishedJob.afterImageUrl, equals(r2AfterUrl));
        expect(publishedJob.beforePhotos, equals([r2BeforeUrl]));
        expect(publishedJob.afterPhotos, equals([r2AfterUrl]));
        expect(publishedJob.quotedPrice, equals(950.0));

        // Verify "✓ Published to Portfolio" badge is rendered on the completed booking
        expect(find.byKey(const Key('booking_published_portfolio_badge')), findsOneWidget);
        expect(find.text('✓ Published to Portfolio'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('4. Completing a job WITHOUT publishing to portfolio marks booking completed privately without creating a public DetailJob', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_priv',
          role: UserRole.detailer,
          displayName: 'Private Detailer',
          businessName: 'Stealth Detail Studio',
        );
        await repo.loginUser(detailerUser);

        final booking = BookingAppointment(
          id: 'bk_priv_01',
          clientId: 'usr_client_priv',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Bruce Wayne',
          clientPhone: '512-555-0001',
          clientEmail: 'bruce@wayne.com',
          vehicleYearMakeModel: '2024 Lamborghini Revuelto',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '100 Batcave Rd',
          scheduledDate: DateTime.now(),
          scheduledTimeSlot: '01:00 PM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.inProgress,
        );

        repo.addBooking(booking);
        final initialJobCount = repo.jobs.length;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Complete & Portfolio button to open modal
        final completeModalBtn = find.byKey(const Key('booking_complete_and_portfolio_btn'));
        await tester.ensureVisible(completeModalBtn);
        await tester.pumpAndSettle();
        await tester.tap(completeModalBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('complete_job_portfolio_modal')), findsOneWidget);

        // Enter private completion notes for client without uploading photos (Publish toggle is OFF)
        await tester.enterText(
          find.byKey(const Key('booking_completion_notes_input')),
          'Completed stealth detail privately per client request.',
        );
        await tester.pumpAndSettle();

        // Submit completion with publishToPortfolio == false
        await tester.tap(find.byKey(const Key('confirm_complete_booking_btn')));
        await tester.pumpAndSettle();

        final completedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_priv_01');
        expect(completedBooking.status, equals(BookingStatus.completed));
        expect(completedBooking.completionNotes, equals('Completed stealth detail privately per client request.'));
        expect(completedBooking.portfolioJobId, isNull);

        // No public DetailJob was created
        expect(repo.jobs.length, equals(initialJobCount));

        // On completed booking without portfolioJobId, "Publish to Portfolio" button is available for later
        expect(find.byKey(const Key('booking_publish_to_portfolio_btn')), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('5. Client BookingsListScreen displays Before/After Transformation SplitSliderWidget, thumbnails, and completion notes on completed booking', (tester) async {
      setupMockImageHttpClient();
      try {
        final clientUser = repo.currentUser.copyWith(
          id: 'usr_client_gallery',
          role: UserRole.client,
          displayName: 'Sophia Loren',
        );
        await repo.loginUser(clientUser);

        const r2BeforeUrl = 'https://media.autodetailcraft.com/usr_studio_1/booking_bk_client_01_before_1.jpg';
        const r2AfterUrl = 'https://media.autodetailcraft.com/usr_studio_1/booking_bk_client_01_after_1.jpg';

        final completedBooking = BookingAppointment(
          id: 'bk_client_01',
          clientId: clientUser.id,
          detailerId: 'usr_studio_1',
          detailerName: 'Apex Detailer',
          detailerBusinessName: 'Apex Studio Austin',
          detailerAvatar: '',
          clientName: clientUser.displayName,
          clientPhone: '512-555-0777',
          clientEmail: 'sophia@example.com',
          vehicleYearMakeModel: '2024 Ferrari Roma',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '200 Congress Ave, Austin, TX',
          scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
          scheduledTimeSlot: '09:00 AM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.completed,
          beforePhotos: const [r2BeforeUrl],
          afterPhotos: const [r2AfterUrl],
          completionNotes: 'Mirror finish achieved on Rosso Corsa paintwork. Keep dry for 24 hours.',
          portfolioJobId: 'job_roma_01',
        );

        repo.addBooking(completedBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: BookingsListScreen(
              repository: repo,
              initialTabIndex: 3, // Completed tab
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Completed tab displays the vehicle, Before & After Transformation section, 50/50 SplitSliderWidget, and completion notes
        expect(find.text('2024 Ferrari Roma'), findsOneWidget);
        expect(find.byKey(const Key('client_booking_transformation_bk_client_01_card')), findsOneWidget);
        expect(find.byKey(const Key('client_booking_split_slider_bk_client_01_card')), findsOneWidget);
        expect(find.byType(SplitSliderWidget), findsOneWidget);
        expect(find.text('1 Before • 1 After'), findsOneWidget);
        expect(find.text('Mirror finish achieved on Rosso Corsa paintwork. Keep dry for 24 hours.'), findsOneWidget);

        // Verify persistence across simulated browser refresh
        final repo2 = await TestHarness.simulateBrowserRefresh(repo);
        final restored = repo2.bookings.firstWhere((b) => b.id == 'bk_client_01');
        expect(restored.beforePhotos, equals([r2BeforeUrl]));
        expect(restored.afterPhotos, equals([r2AfterUrl]));
        expect(restored.completionNotes, equals('Mirror finish achieved on Rosso Corsa paintwork. Keep dry for 24 hours.'));
        expect(restored.portfolioJobId, equals('job_roma_01'));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('6. CreateJobScreen pre-fills vehicle details, price, notes, and R2 photos from sourceBooking and links portfolioJobId on save', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_editor',
          role: UserRole.detailer,
          displayName: 'Studio Editor',
          businessName: 'Precision Auto Spa',
        );
        await repo.loginUser(detailerUser);

        const r2BeforeUrl = 'https://media.autodetailcraft.com/usr_detailer_editor/booking_bk_edit_01_before_1.jpg';
        const r2AfterUrl = 'https://media.autodetailcraft.com/usr_detailer_editor/booking_bk_edit_01_after_1.jpg';

        final sourceBooking = BookingAppointment(
          id: 'bk_edit_01',
          clientId: 'usr_client_edit',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Arthur Pendragon',
          clientPhone: '512-555-0444',
          clientEmail: 'arthur@camelot.org',
          vehicleYearMakeModel: '2023 Aston Martin Vantage',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '300 Kingdom Way',
          scheduledDate: DateTime.now(),
          scheduledTimeSlot: '10:00 AM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.inProgress,
          beforePhotos: const [r2BeforeUrl],
          afterPhotos: const [r2AfterUrl],
          completionNotes: 'British Racing Green restored to concourse level.',
        );

        repo.addBooking(sourceBooking);

        await tester.binding.setSurfaceSize(const Size(1280, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: CreateJobScreen(
                repository: repo,
                sourceBooking: sourceBooking,
                onJobCreated: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll slightly to Vehicle & Service Details in CreateJobScreen ListView
        await tester.drag(find.byKey(const Key('create_job_scroll_view')), const Offset(0, -500));
        await tester.pumpAndSettle();

        // Verify pre-filled fields from sourceBooking
        expect(find.text('2023'), findsOneWidget);
        expect(find.text('Aston Martin'), findsOneWidget);
        expect(find.text('Vantage'), findsOneWidget);
        expect(find.text('950'), findsOneWidget);
        expect(find.text('British Racing Green restored to concourse level.'), findsOneWidget);

        // Publish Recipe
        await tester.tap(find.text('Publish Recipe'));
        await tester.pumpAndSettle();

        final updatedBooking = repo.bookings.firstWhere((b) => b.id == 'bk_edit_01');
        expect(updatedBooking.status, equals(BookingStatus.completed));
        expect(updatedBooking.portfolioJobId, isNotNull);
        final createdJob = repo.jobs.firstWhere((j) => j.id == updatedBooking.portfolioJobId);
        expect(createdJob.vehicleMake, equals('Aston Martin'));
        expect(createdJob.vehicleModel, equals('Vantage'));
        expect(createdJob.beforeImageUrl, equals(r2BeforeUrl));
        expect(createdJob.afterImageUrl, equals(r2AfterUrl));
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    test('7. Vehicle Year/Make/Model Parser & Realtime Sync edge cases (missing year, multi-word make, empty input, duplicate publish guard)', () async {
      // Edge cases for parseVehicleYearMakeModel
      final emptyParsed = JobRepository.parseVehicleYearMakeModel('   ');
      expect(emptyParsed.make, equals('Custom'));
      expect(emptyParsed.model, equals('Vehicle'));

      final noYearParsed = JobRepository.parseVehicleYearMakeModel('Porsche 911 Turbo S');
      expect(noYearParsed.make, equals('Porsche'));
      expect(noYearParsed.model, equals('911 Turbo S'));

      final multiWordParsed = JobRepository.parseVehicleYearMakeModel('2025 Land Rover Range Rover SV');
      expect(multiWordParsed.year, equals(2025));
      expect(multiWordParsed.make, equals('Land Rover'));
      expect(multiWordParsed.model, equals('Range Rover SV'));

      // Duplicate publish guard: calling completeBookingAndPublishToPortfolio on an already published booking updates existing job instead of duplicating
      const r2B = 'https://media.autodetailcraft.com/usr_d1/booking_dup_before.jpg';
      const r2A = 'https://media.autodetailcraft.com/usr_d1/booking_dup_after.jpg';
      final b = BookingAppointment(
        id: 'bk_dup_guard_01',
        clientId: 'usr_c1',
        detailerId: repo.currentUser.id,
        detailerName: 'Pro',
        detailerBusinessName: 'Pro Studio',
        detailerAvatar: '',
        clientName: 'Client',
        clientPhone: '555-0100',
        clientEmail: 'c@example.com',
        vehicleYearMakeModel: '2024 Audi R8 V10',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: 'Studio',
        scheduledDate: DateTime.now(),
        scheduledTimeSlot: '9:00 AM',
        totalPrice: 950.0,
        depositAmount: 190.0,
        status: BookingStatus.inProgress,
        beforePhotos: const [r2B],
        afterPhotos: const [r2A],
      );
      repo.addBooking(b);

      final countBefore = repo.jobs.length;
      final job1 = await repo.completeBookingAndPublishToPortfolio(
        'bk_dup_guard_01',
        publishToPortfolio: true,
        completionNotes: 'First publish',
      );
      expect(job1, isNotNull);
      expect(repo.jobs.length, equals(countBefore + 1));

      // Second call with updated notes must NOT create a duplicate DetailJob
      final job2 = await repo.completeBookingAndPublishToPortfolio(
        'bk_dup_guard_01',
        publishToPortfolio: true,
        completionNotes: 'Updated second publish',
      );
      expect(job2, isNotNull);
      expect(job2!.id, equals(job1!.id));
      expect(repo.jobs.length, equals(countBefore + 1));
      expect(repo.jobs.firstWhere((j) => j.id == job1.id).description, equals('Updated second publish'));

      // Realtime payload syncs before_photos, after_photos, completion_notes, and portfolio_job_id
      repo.simulateRealtimeBookingPayload({
        'id': 'bk_dup_guard_01',
        'status': 'completed',
        'before_photos': [r2B, 'https://media.autodetailcraft.com/usr_d1/booking_dup_before_2.jpg'],
        'after_photos': [r2A],
        'completion_notes': 'Synced from Supabase Realtime',
        'portfolio_job_id': job1.id,
      });

      final synced = repo.bookings.firstWhere((item) => item.id == 'bk_dup_guard_01');
      expect(synced.beforePhotos.length, equals(2));
      expect(synced.completionNotes, equals('Synced from Supabase Realtime'));
      expect(synced.portfolioJobId, equals(job1.id));

      // Deleting the portfolio job unlinks portfolioJobId on the booking without deleting R2 photos still referenced by the booking
      r2Deletions.clear();
      repo.deleteJob(job1.id);
      final afterDeleteBooking = repo.bookings.firstWhere((item) => item.id == 'bk_dup_guard_01');
      expect(afterDeleteBooking.portfolioJobId, isNull);
      expect(afterDeleteBooking.beforePhotos.length, equals(2));
      expect(afterDeleteBooking.afterPhotos, equals([r2A]));
      expect(r2Deletions, isEmpty);
    });

    testWidgets('8. Clicking "Complete Job" and pressing Cancel in modal does NOT prematurely mark the booking completed, and R2 upload failure does NOT save base64 to booking', (tester) async {
      setupMockImageHttpClient();
      try {
        final detailerUser = repo.currentUser.copyWith(
          id: 'usr_detailer_edge',
          role: UserRole.detailer,
          displayName: 'Edge Tester',
          businessName: 'Edge Studio',
        );
        await repo.loginUser(detailerUser);

        final inProgressBooking = BookingAppointment(
          id: 'bk_edge_cancel_01',
          clientId: 'usr_client_edge',
          detailerId: detailerUser.id,
          detailerName: detailerUser.displayName,
          detailerBusinessName: detailerUser.businessName,
          detailerAvatar: '',
          clientName: 'Diana Prince',
          clientPhone: '512-555-0123',
          clientEmail: 'diana@themyscira.org',
          vehicleYearMakeModel: '2024 McLaren 750S',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '500 Olympus Way',
          scheduledDate: DateTime.now(),
          scheduledTimeSlot: '11:00 AM',
          totalPrice: 950.0,
          depositAmount: 190.0,
          status: BookingStatus.inProgress,
        );

        repo.addBooking(inProgressBooking);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(
                repository: repo,
                initialHubSection: StudioHubSection.booked,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Simulate R2 upload returning null (network failure) and verify booking beforePhotos remains empty (no base64 fallback)
        R2StorageService.mockUploadOverride = ({
          required String userId,
          required Uint8List bytes,
          String contentType = 'image/jpeg',
          String? customFileName,
        }) async {
          return null;
        };

        final beforeBtn = find.byKey(const Key('booking_upload_before_photo_btn'));
        await tester.ensureVisible(beforeBtn);
        await tester.pumpAndSettle();
        await tester.tap(beforeBtn);
        await tester.pumpAndSettle();

        expect(find.text('Cloudflare R2 upload failed. Please check your connection and try again.'), findsOneWidget);
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_edge_cancel_01').beforePhotos, isEmpty);

        // 2. Tap "Complete Job" to open modal, then tap "Cancel" -> status must remain BookingStatus.inProgress!
        final completeBtn = find.byKey(const Key('booking_complete_job_btn'));
        await tester.ensureVisible(completeBtn);
        await tester.pumpAndSettle();
        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('complete_job_portfolio_modal')), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('complete_job_portfolio_modal')), findsNothing);
        expect(repo.bookings.firstWhere((b) => b.id == 'bk_edge_cancel_01').status, equals(BookingStatus.inProgress));
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
