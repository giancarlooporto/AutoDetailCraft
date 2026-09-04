import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/team_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobRepository Tests', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('initializes with mock jobs and public detailers', () {
      expect(repo.jobs.isNotEmpty, true);
      expect(repo.publicDetailers.isNotEmpty, true);
      expect(repo.bookings, isA<List<BookingAppointment>>());
    });

    test('filters jobs by service type', () {
      repo.setServiceFilter('Ceramic');
      expect(repo.filteredJobs.every((j) => j.serviceType.toLowerCase().contains('ceramic')), true);
    });

    test('toggles host mode and manages company hired staff', () {
      expect(repo.currentUser.role, isNotNull);
      repo.toggleHostMode();
      
      final initialTeamCount = repo.currentUser.teamMembers.length;
      final newStaff = const TeamMember(
        id: 'staff_1',
        name: 'Carlos Ruiz',
        roleTitle: 'Ceramic Lead',
        avatarUrl: 'https://example.com/avatar.jpg',
      );
      repo.addTeamMember(newStaff);
      expect(repo.currentUser.teamMembers.length, initialTeamCount + 1);

      repo.removeTeamMember('staff_1');
      expect(repo.currentUser.teamMembers.length, initialTeamCount);
    });
  });
}
