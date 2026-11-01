import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import 'simulated_realtime_bus.dart';

/// Test harness orchestrator for spinning up multiple isolated JobRepository
/// sessions representing distinct physical devices and roles (Device A, Device B, Detailer),
/// all interconnected via a deterministic [SimulatedRealtimeBus].
class MultiDeviceTestHarness {
  final SimulatedRealtimeBus bus = SimulatedRealtimeBus();
  final List<JobRepository> _createdSessions = [];

  List<JobRepository> get sessions => List.unmodifiable(_createdSessions);

  /// Creates and initializes an isolated repository session for a given user profile.
  Future<JobRepository> createDeviceSession({
    required UserProfile user,
    bool isLoggedIn = true,
    List<BookingAppointment>? initialBookings,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    if (isLoggedIn) {
      await LocalStorageService.saveCurrentUser(user);
      await LocalStorageService.saveIsGuest(false);
    }

    final repo = JobRepository();
    repo.isLoggedIn = isLoggedIn;
    await repo.updateCurrentUser(user);

    if (initialBookings != null && initialBookings.isNotEmpty) {
      for (final booking in initialBookings) {
        repo.addBooking(booking, allowOverbooking: true, syncToCloud: false);
      }
    }

    bus.register(repo);
    _createdSessions.add(repo);
    return repo;
  }

  /// Convenience factory to spin up a Client session for a specific device.
  Future<JobRepository> createClientDeviceSession({
    String deviceId = 'device_client_a',
    String userId = 'usr_client_01',
    String email = 'client@example.com',
    String displayName = 'Alex Mercer',
    List<BookingAppointment>? initialBookings,
    bool isLoggedIn = true,
  }) async {
    final clientProfile = UserProfile(
      id: userId,
      role: UserRole.client,
      username: email,
      displayName: displayName,
      businessName: '',
      avatarUrl: '',
      coverUrl: '',
      servicePackages: const [],
    );

    return createDeviceSession(
      user: clientProfile,
      isLoggedIn: isLoggedIn,
      initialBookings: initialBookings,
    );
  }

  /// Convenience factory to spin up a Studio Detailer session.
  Future<JobRepository> createDetailerSession({
    String detailerId = 'usr_detailer_pro',
    String email = 'marcus@apexprecision.com',
    String displayName = 'Marcus Vance',
    String businessName = 'Apex Precision Detailing',
    List<BookingAppointment>? initialBookings,
    bool isLoggedIn = true,
  }) async {
    final detailerProfile = UserProfile(
      id: detailerId,
      role: UserRole.detailer,
      username: email,
      displayName: displayName,
      businessName: businessName,
      avatarUrl: '',
      coverUrl: '',
      servicePackages: MockDataService.standardPackages,
    );

    return createDeviceSession(
      user: detailerProfile,
      isLoggedIn: isLoggedIn,
      initialBookings: initialBookings,
    );
  }

  /// Broadcasts a booking change from sender to all peer sessions on the bus.
  void syncBookingChange(
    JobRepository sender,
    BookingAppointment booking, {
    bool isDelete = false,
  }) {
    bus.broadcastBookingChange(
      sender: sender,
      booking: booking,
      isDelete: isDelete,
    );
  }

  /// Broadcasts a raw CDC record from sender to all peer sessions on the bus.
  void syncRawPayload(
    JobRepository sender,
    Map<String, dynamic> record, {
    bool isDelete = false,
  }) {
    bus.broadcastRawPayload(
      sender: sender,
      record: record,
      isDelete: isDelete,
    );
  }

  /// Disposes and unregisters all created repository sessions.
  void dispose() {
    for (final session in _createdSessions) {
      bus.unregister(session);
      try {
        session.dispose();
      } catch (_) {}
    }
    _createdSessions.clear();
    bus.clear();
  }
}
