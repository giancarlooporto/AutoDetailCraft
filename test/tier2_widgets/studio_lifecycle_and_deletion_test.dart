import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/message_model.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Studio Lifecycle & Account Protection Tests', () {
    test('Detailer with active bookings cannot pause or quit until cancelled', () async {
      final repo = JobRepository();
      await repo.init();

      const testPkg = ServicePackage(
        id: 'pkg_1',
        title: 'Full Ceramic Pro',
        description: '5-year pro grade ceramic coating',
        estimatedDuration: '4 hrs',
        basePrice: 650.0,
        includes: ['Paint Prep', 'Ceramic 5yr'],
      );

      // Configure detailer studio user
      final studioDetailer = UserProfile(
        id: 'studio_host_01',
        role: UserRole.detailer,
        username: 'marcus_vance',
        displayName: 'Marcus Vance',
        businessName: 'Apex Detail Lab',
        location: 'Austin, TX',
        servicePackages: const [testPkg],
      );
      await repo.updateCurrentUser(studioDetailer);

      // Create an active confirmed booking for this studio
      final activeBooking = BookingAppointment(
        id: 'bk_active_101',
        clientId: 'client_bob_99',
        detailerId: 'studio_host_01',
        detailerName: 'Marcus Vance',
        detailerBusinessName: 'Apex Detail Lab',
        detailerAvatar: '',
        clientName: 'Bob Customer',
        clientEmail: 'bob@example.com',
        clientPhone: '(512) 555-1234',
        vehicleYearMakeModel: '2023 Porsche 911',
        vehicleSize: VehicleSize.coupeSedan,
        package: testPkg,
        locationType: ServiceLocationType.shop,
        clientAddress: '100 Studio Way',
        scheduledDate: DateTime.now().add(const Duration(days: 2)),
        scheduledTimeSlot: '10:00 AM',
        totalPrice: 650.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );
      repo.addBooking(activeBooking);

      // 1. Verify studio has active bookings
      expect(repo.hasActiveStudioBookings, isTrue);
      expect(repo.activeStudioBookings.length, 1);

      // 2. Attempting to pause studio MUST fail while customer is booked
      final pauseResult = await repo.setStudioPaused(true);
      expect(pauseResult.success, isFalse);
      expect(pauseResult.error, contains('Cannot pause studio operations while you have active customer appointments'));
      expect(repo.currentUser.isStudioPaused, isFalse);

      // 3. Attempting to quit detailing MUST fail while customer is booked
      final quitResult = await repo.quitDetailing();
      expect(quitResult.success, isFalse);
      expect(quitResult.error, contains('Cannot quit detailing while you have active customer appointments'));
      expect(repo.currentUser.role, equals(UserRole.detailer));

      // 4. Cancel active booking with client notification
      await repo.cancelStudioBookingWithClientNotification(
        activeBooking.id,
        reason: 'Studio temporarily pausing operations',
      );

      // Verify booking is now cancelled
      expect(repo.hasActiveStudioBookings, isFalse);
      final updatedBooking = repo.studioBookings.firstWhere((b) => b.id == activeBooking.id);
      expect(updatedBooking.status, equals(BookingStatus.cancelled));

      // 5. Now pausing studio succeeds!
      final pauseSuccess = await repo.setStudioPaused(true);
      expect(pauseSuccess.success, isTrue);
      expect(repo.currentUser.isStudioPaused, isTrue);

      // 6. Verify paused studio is hidden from public discovery and search
      expect(repo.publicDetailers.any((d) => d.id == 'studio_host_01'), isFalse);

      // 7. Resuming studio makes it live again
      final resumeSuccess = await repo.setStudioPaused(false);
      expect(resumeSuccess.success, isTrue);
      expect(repo.currentUser.isStudioPaused, isFalse);
      expect(repo.publicDetailers.any((d) => d.id == 'studio_host_01'), isTrue);
    });

    test('Quit detailing deletes studio services & inventory while reverting to client mode and preserving garage vehicles', () async {
      final repo = JobRepository();
      await repo.init();

      const testPkg = ServicePackage(
        id: 'pkg_paint_corr',
        title: 'Multi-Stage Correction',
        description: 'Paint correction and polish',
        estimatedDuration: '6 hrs',
        basePrice: 850.0,
        includes: ['Compound', 'Polish'],
      );

      const personalCar = UserVehicle(
        id: 'veh_personal_01',
        year: 2022,
        make: 'BMW',
        model: 'M3 Competition',
        colorName: 'Isle of Man Green',
        imageUrl: '',
      );

      final studioDetailer = UserProfile(
        id: 'studio_host_02',
        role: UserRole.detailer,
        username: 'david_miller',
        displayName: 'David Miller',
        businessName: 'Miller Detailing Co',
        location: 'Dallas, TX',
        servicePackages: const [testPkg],
        myGarage: const [personalCar],
      );
      await repo.updateCurrentUser(studioDetailer);

      // Add inventory item to studio
      const item = InventoryItem(
        id: 'inv_comp_01',
        name: 'Menzerna Heavy Cut 400',
        category: InventoryCategory.chemicals,
      );
      repo.addInventoryItem(item);
      expect(repo.inventoryItems.length, 1);

      // Add a studio conversation
      final studioConv = Conversation(
        id: 'conv_client_to_studio',
        participantA: 'client_123',
        participantB: 'studio_host_02',
        updatedAt: DateTime.now(),
        otherUserName: 'Customer Alice',
        otherUserAvatar: '',
      );
      await LocalStorageService.saveConversations([studioConv]);
      await repo.loadConversations();
      expect(repo.studioConversations.length, 1);

      // No active bookings -> quit succeeds
      final quitResult = await repo.quitDetailing();
      expect(quitResult.success, isTrue);

      // 1. User role is now reverted to client (Vehicle Owner)
      expect(repo.currentUser.role, equals(UserRole.client));

      // 2. Studio services are deleted from studio side
      expect(repo.currentUser.servicePackages.isEmpty, isTrue);

      // 3. Studio inventory is deleted from studio side
      expect(repo.inventoryItems.isEmpty, isTrue);

      // 4. Studio messages & conversations are deleted
      expect(repo.studioConversations.isEmpty, isTrue);

      // 5. Client mode is NOT deleted: personal vehicles in garage are preserved!
      expect(repo.currentUser.myGarage.length, 1);
      expect(repo.currentUser.myGarage.first.model, 'M3 Competition');

      // 6. Studio is hidden from public discovery / search / explore
      expect(repo.publicDetailers.any((d) => d.id == 'studio_host_02'), isFalse);

      // 7. Re-entering detailer mode later starts with clean state (no old studio messages or services)
      repo.toggleHostMode(targetRole: UserRole.detailer);
      expect(repo.studioConversations.isEmpty, isTrue);
      expect(repo.currentUser.servicePackages.isEmpty, isTrue);
      expect(repo.inventoryItems.isEmpty, isTrue);
    });

    test('Studio pause state persistence survives cloud refresh without reverting to live', () async {
      final repo = JobRepository();
      await repo.init();

      final studioDetailer = UserProfile(
        id: 'studio_pause_test',
        role: UserRole.detailer,
        username: 'pause_user',
        displayName: 'Pause Tester',
        businessName: 'Pause Studio Co',
        location: 'Dallas, TX',
        servicePackages: const [],
        isStudioPaused: false,
      );
      await repo.updateCurrentUser(studioDetailer);
      expect(repo.currentUser.isStudioPaused, isFalse);

      // 1. Pause the studio
      final pauseRes = await repo.setStudioPaused(true);
      expect(pauseRes.success, isTrue);
      expect(repo.currentUser.isStudioPaused, isTrue);

      // 2. Verify stored local user has isStudioPaused = true
      final stored = await LocalStorageService.loadCurrentUser();
      expect(stored?.isStudioPaused, isTrue);

      // 3. Resume studio
      final resumeRes = await repo.setStudioPaused(false);
      expect(resumeRes.success, isTrue);
      expect(repo.currentUser.isStudioPaused, isFalse);

      final storedAfterResume = await LocalStorageService.loadCurrentUser();
      expect(storedAfterResume?.isStudioPaused, isFalse);
    });
  });
}
