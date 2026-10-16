import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M2 Empirical Challenger Stress Suite: Garage & Teams Multi-Refresh', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // =========================================================================
    // SECTION 1: Garage Rapid Mutations & Multi-Refresh Persistence
    // =========================================================================
    group('1. Garage Rapid Mutations & Multi-Refresh Persistence', () {
      test('1.1: Mission 1 - Add 5 vehicles, update 3, delete 2, execute 2 simulated refreshes and verify 0 state loss', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);
        expect(repo1.currentUser.myGarage, isEmpty);

        final sampleBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE]);

        // Step 1: Add 5 vehicles with various paint codes, image URLs, and properties
        final v1 = UserVehicle(
          id: 'veh_01',
          year: 2024,
          make: 'Porsche',
          model: '911 GT3 RS',
          colorName: 'Shark Blue',
          paintCode: 'D5C',
          imageUrl: 'https://cdn.autodetailcraft.com/vehicles/gt3rs.jpg',
          lastDetailService: 'Full PPF & Ceramic Coating',
          lastDetailDate: DateTime(2026, 4, 10),
        );

        final v2 = UserVehicle(
          id: 'veh_02',
          year: 2023,
          make: 'BMW',
          model: 'M4 CSL',
          colorName: 'Frozen Brooklyn Grey',
          paintCode: 'C4G',
          imageUrl: 'https://cdn.autodetailcraft.com/vehicles/m4csl.jpg',
          localImageBytes: sampleBytes,
          lastDetailService: 'Stage 1 Polish',
          lastDetailDate: DateTime(2026, 3, 15),
        );

        final v3 = UserVehicle(
          id: 'veh_03',
          year: 2025,
          make: 'Ferrari',
          model: '296 GTB',
          colorName: 'Rosso Corsa',
          paintCode: 'FER322',
          imageUrl: 'https://cdn.autodetailcraft.com/vehicles/296gtb.jpg',
        );

        final v4 = UserVehicle(
          id: 'veh_04',
          year: 2022,
          make: 'Lucid',
          model: 'Air Sapphire',
          colorName: 'Sapphire Blue Metallic',
          paintCode: 'LUC01',
          imageUrl: 'https://cdn.autodetailcraft.com/vehicles/lucid.jpg',
        );

        final v5 = UserVehicle(
          id: 'veh_05',
          year: 1994,
          make: 'McLaren',
          model: 'F1',
          colorName: 'Magnesium Silver',
          paintCode: 'MCL01',
          imageUrl: 'https://cdn.autodetailcraft.com/vehicles/f1.jpg',
        );

        repo1.addVehicleToGarage(v1);
        repo1.addVehicleToGarage(v2);
        repo1.addVehicleToGarage(v3);
        repo1.addVehicleToGarage(v4);
        repo1.addVehicleToGarage(v5);

        expect(repo1.currentUser.myGarage.length, equals(5));

        // Step 2: Update 3 vehicles (changing colors, models, and paint codes)
        final v2Updated = v2.copyWith(
          model: 'M4 Competition xDrive',
          colorName: 'Isle of Man Green',
          paintCode: 'C4E',
          lastDetailService: 'Stage 2 Paint Correction & Graphene',
          lastDetailDate: DateTime(2026, 7, 22),
        );

        final v3Updated = v3.copyWith(
          model: '296 GTS Spider',
          colorName: 'Giallo Modena',
          paintCode: 'FER102',
          lastDetailService: 'Ceramic Wheel & Caliper Coating',
          lastDetailDate: DateTime(2026, 8, 5),
        );

        final v5Updated = v5.copyWith(
          model: 'McLaren F1 LM',
          colorName: 'Papaya Orange',
          paintCode: 'MCL-LM',
          lastDetailService: 'Museum Preservation Treatment',
          lastDetailDate: DateTime(2026, 9, 1),
        );

        repo1.updateVehicleInGarage(v2Updated);
        repo1.updateVehicleInGarage(v3Updated);
        repo1.updateVehicleInGarage(v5Updated);

        // Step 3: Delete 2 vehicles (veh_01 and veh_04)
        repo1.removeVehicleFromGarage('veh_01');
        repo1.removeVehicleFromGarage('veh_04');

        // Step 4: Verify in-memory state before refresh
        expect(repo1.currentUser.myGarage.length, equals(3));
        expect(repo1.currentUser.myGarage.map((v) => v.id).toList(), equals(['veh_02', 'veh_03', 'veh_05']));

        // Step 4b: Verify dedicated storage directly
        final dedicatedVehicles = await LocalStorageService.loadGarageVehicles();
        expect(dedicatedVehicles.length, equals(3));
        expect(dedicatedVehicles.map((v) => v.id).toList(), equals(['veh_02', 'veh_03', 'veh_05']));
        expect(dedicatedVehicles[0].model, equals('M4 Competition xDrive'));
        expect(dedicatedVehicles[1].model, equals('296 GTS Spider'));
        expect(dedicatedVehicles[2].model, equals('McLaren F1 LM'));

        // Step 5: Simulate FIRST browser refresh (Cmd+R / F5)
        final repo2 = JobRepository();
        await repo2.init();

        // Verify exact list length, order, and properties after first refresh
        expect(repo2.currentUser.myGarage.length, equals(3),
            reason: 'Garage must retain exactly 3 vehicles after 1st refresh');
        expect(repo2.currentUser.myGarage.map((v) => v.id).toList(), equals(['veh_02', 'veh_03', 'veh_05']),
            reason: 'Order of vehicles must be strictly preserved after refresh');

        // Check V2 restored properties
        final restoredV2 = repo2.currentUser.myGarage[0];
        expect(restoredV2.id, equals('veh_02'));
        expect(restoredV2.year, equals(2023));
        expect(restoredV2.make, equals('BMW'));
        expect(restoredV2.model, equals('M4 Competition xDrive'));
        expect(restoredV2.colorName, equals('Isle of Man Green'));
        expect(restoredV2.paintCode, equals('C4E'));
        expect(restoredV2.imageUrl, equals('https://cdn.autodetailcraft.com/vehicles/m4csl.jpg'));
        expect(restoredV2.localImageBytes, equals(sampleBytes));
        expect(restoredV2.lastDetailService, equals('Stage 2 Paint Correction & Graphene'));
        expect(restoredV2.lastDetailDate, equals(DateTime(2026, 7, 22)));

        // Check V3 restored properties
        final restoredV3 = repo2.currentUser.myGarage[1];
        expect(restoredV3.id, equals('veh_03'));
        expect(restoredV3.year, equals(2025));
        expect(restoredV3.make, equals('Ferrari'));
        expect(restoredV3.model, equals('296 GTS Spider'));
        expect(restoredV3.colorName, equals('Giallo Modena'));
        expect(restoredV3.paintCode, equals('FER102'));
        expect(restoredV3.lastDetailService, equals('Ceramic Wheel & Caliper Coating'));
        expect(restoredV3.lastDetailDate, equals(DateTime(2026, 8, 5)));

        // Check V5 restored properties
        final restoredV5 = repo2.currentUser.myGarage[2];
        expect(restoredV5.id, equals('veh_05'));
        expect(restoredV5.year, equals(1994));
        expect(restoredV5.make, equals('McLaren'));
        expect(restoredV5.model, equals('McLaren F1 LM'));
        expect(restoredV5.colorName, equals('Papaya Orange'));
        expect(restoredV5.paintCode, equals('MCL-LM'));
        expect(restoredV5.lastDetailService, equals('Museum Preservation Treatment'));
        expect(restoredV5.lastDetailDate, equals(DateTime(2026, 9, 1)));

        // Deleted vehicles must NOT exist
        expect(repo2.currentUser.myGarage.any((v) => v.id == 'veh_01'), isFalse);
        expect(repo2.currentUser.myGarage.any((v) => v.id == 'veh_04'), isFalse);

        // Step 6: Execute SECOND simulated browser refresh
        final repo3 = JobRepository();
        await repo3.init();

        // Verify ZERO state loss across 2nd refresh
        expect(repo3.currentUser.myGarage.length, equals(3),
            reason: 'Garage must retain 3 vehicles after 2nd refresh without loss');
        expect(repo3.currentUser.myGarage.map((v) => v.id).toList(), equals(['veh_02', 'veh_03', 'veh_05']));

        final r3V2 = repo3.currentUser.myGarage[0];
        expect(r3V2.model, equals('M4 Competition xDrive'));
        expect(r3V2.colorName, equals('Isle of Man Green'));
        expect(r3V2.paintCode, equals('C4E'));
        expect(r3V2.localImageBytes, equals(sampleBytes));

        final r3V3 = repo3.currentUser.myGarage[1];
        expect(r3V3.model, equals('296 GTS Spider'));
        expect(r3V3.colorName, equals('Giallo Modena'));
        expect(r3V3.paintCode, equals('FER102'));

        final r3V5 = repo3.currentUser.myGarage[2];
        expect(r3V5.model, equals('McLaren F1 LM'));
        expect(r3V5.colorName, equals('Papaya Orange'));
        expect(r3V5.paintCode, equals('MCL-LM'));
      });

      test('1.2: Stress test rapid interleaved burst mutations (10 additions, 5 updates, 5 deletes, 3 refreshes)', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);

        // Add 10 vehicles in rapid succession
        for (int i = 0; i < 10; i++) {
          repo1.addVehicleToGarage(UserVehicle(
            id: 'burst_veh_$i',
            year: 2020 + i,
            make: 'Brand_$i',
            model: 'Initial_Model_$i',
            colorName: 'Initial_Color_$i',
            paintCode: 'PC_$i',
            imageUrl: 'https://cdn.example.com/veh_$i.jpg',
          ));
        }
        expect(repo1.currentUser.myGarage.length, equals(10));

        // Update all even index vehicles
        for (int i = 0; i < 10; i += 2) {
          final current = repo1.currentUser.myGarage.firstWhere((v) => v.id == 'burst_veh_$i');
          repo1.updateVehicleInGarage(current.copyWith(
            model: 'Mutated_Model_$i',
            colorName: 'Mutated_Color_$i',
            paintCode: 'MUTATED_$i',
          ));
        }

        // Delete all odd index vehicles
        for (int i = 1; i < 10; i += 2) {
          repo1.removeVehicleFromGarage('burst_veh_$i');
        }

        expect(repo1.currentUser.myGarage.length, equals(5));
        final expectedIds = ['burst_veh_0', 'burst_veh_2', 'burst_veh_4', 'burst_veh_6', 'burst_veh_8'];
        expect(repo1.currentUser.myGarage.map((v) => v.id).toList(), equals(expectedIds));

        // Refresh 1
        var currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(5));
        expect(currentRepo.currentUser.myGarage.map((v) => v.id).toList(), equals(expectedIds));
        for (int i = 0; i < 10; i += 2) {
          final veh = currentRepo.currentUser.myGarage.firstWhere((v) => v.id == 'burst_veh_$i');
          expect(veh.model, equals('Mutated_Model_$i'));
          expect(veh.colorName, equals('Mutated_Color_$i'));
          expect(veh.paintCode, equals('MUTATED_$i'));
        }

        // Refresh 2
        currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(5));

        // Refresh 3
        currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(5));
        expect(currentRepo.currentUser.myGarage.map((v) => v.id).toList(), equals(expectedIds));
      });

      test('1.3: Vehicle edge cases - binary payload roundtrip, Unicode characters, and defensive no-op mutations', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);

        // 32KB simulated image byte array
        final largeBytes = Uint8List.fromList(List<int>.generate(32768, (i) => i % 256));

        final edgeVehicle = UserVehicle(
          id: 'veh_unicode_edge',
          year: 2026,
          make: 'Koenigsegg',
          model: 'Jesko Absolut ⚡️ Special Edition',
          colorName: 'Bjørn’s Midnight Blue / 漆黒',
          paintCode: '#001A33 / PTS-889',
          imageUrl: '',
          localImageBytes: largeBytes,
          lastDetailService: 'Ceramic & PPF + Graphene 🌟',
          lastDetailDate: DateTime(2026, 12, 31, 23, 59, 59),
        );
        repo1.addVehicleToGarage(edgeVehicle);

        // Defensive checks: Updating non-existent vehicle ID must not crash or corrupt list
        const ghostVehicle = UserVehicle(
          id: 'veh_ghost_999',
          year: 2020,
          make: 'Ghost',
          model: 'Phantom',
          colorName: 'Shadow',
          imageUrl: '',
        );
        repo1.updateVehicleInGarage(ghostVehicle);
        expect(repo1.currentUser.myGarage.length, equals(1));

        // Defensive checks: Deleting non-existent vehicle ID must be a safe no-op
        repo1.removeVehicleFromGarage('veh_non_existent');
        expect(repo1.currentUser.myGarage.length, equals(1));

        // Simulate refresh
        final repo2 = JobRepository();
        await repo2.init();

        expect(repo2.currentUser.myGarage.length, equals(1));
        final restored = repo2.currentUser.myGarage.first;
        expect(restored.id, equals('veh_unicode_edge'));
        expect(restored.model, equals('Jesko Absolut ⚡️ Special Edition'));
        expect(restored.colorName, equals('Bjørn’s Midnight Blue / 漆黒'));
        expect(restored.paintCode, equals('#001A33 / PTS-889'));
        expect(restored.lastDetailService, equals('Ceramic & PPF + Graphene 🌟'));
        expect(restored.lastDetailDate, equals(DateTime(2026, 12, 31, 23, 59, 59)));
        expect(restored.localImageBytes, isNotNull);
        expect(restored.localImageBytes!.length, equals(32768));
        expect(restored.localImageBytes, equals(largeBytes));
      });
    });

    // =========================================================================
    // SECTION 2: Teams Rapid Mutations & Custom Schedule Persistence
    // =========================================================================
    group('2. Teams Rapid Mutations & Custom Schedule Persistence', () {
      test('2.1: Mission 2 - Add 3 technicians with custom weekly schedules, update shifts, refresh and verify 0 state loss', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);
        expect(repo1.currentUser.teamMembers, isEmpty);

        // Custom Schedule 1: Marcus - Mon to Fri (07:30 AM - 04:30 PM), Sat/Sun closed
        final marcusSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        // Custom Schedule 2: Sofia - Tue to Sat (10:00 AM - 07:00 PM), Sun/Mon closed
        final sofiaSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        // Custom Schedule 3: Devon - Mon, Wed, Fri (08:00 AM - 06:00 PM), others closed
        final devonSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        final tech1 = TeamMember(
          id: 'tech_marcus',
          name: 'Marcus Vance',
          roleTitle: 'PPF & Ceramic Lead',
          avatarUrl: 'https://images.unsplash.com/photo-marcus',
          rating: 4.9,
          completedJobsCount: 42,
          customWeeklySchedule: marcusSchedule,
        );

        final tech2 = TeamMember(
          id: 'tech_sofia',
          name: 'Sofia Lin',
          roleTitle: 'Paint Correction Artisan',
          avatarUrl: 'https://images.unsplash.com/photo-sofia',
          rating: 5.0,
          completedJobsCount: 58,
          customWeeklySchedule: sofiaSchedule,
        );

        final tech3 = TeamMember(
          id: 'tech_devon',
          name: 'Devon Reed',
          roleTitle: 'Interior Restoration Tech',
          avatarUrl: 'https://images.unsplash.com/photo-devon',
          rating: 4.8,
          completedJobsCount: 19,
          customWeeklySchedule: devonSchedule,
        );

        // Step 1: Add 3 technicians
        repo1.addTeamMember(tech1);
        repo1.addTeamMember(tech2);
        repo1.addTeamMember(tech3);

        expect(repo1.currentUser.teamMembers.length, equals(3));

        // Step 2: Update weekly shift schedules
        // Update Marcus: Monday becomes closed, Saturday becomes open (09:00 AM - 03:00 PM)
        final marcusUpdatedSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: false), // Monday now OFF
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '07:30 AM', closeTime: '04:30 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '09:00 AM', closeTime: '03:00 PM'), // Sat now ON
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];
        repo1.updateTeamMemberWeeklySchedule('tech_marcus', marcusUpdatedSchedule);

        // Update Sofia: Sunday opens (11:00 AM - 04:00 PM), Tuesday closeTime extended to 08:00 PM
        final sofiaUpdatedSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '10:00 AM', closeTime: '08:00 PM'), // Extended
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '10:00 AM', closeTime: '07:00 PM'),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: true, openTime: '11:00 AM', closeTime: '04:00 PM'), // Sun now ON
        ];
        repo1.updateTeamMemberWeeklySchedule('tech_sofia', sofiaUpdatedSchedule);

        // Update Devon: Thursday opens (08:00 AM - 06:00 PM), Friday closeTime shortened to 04:00 PM
        final devonUpdatedSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'), // Thu now ON
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'), // Shortened
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];
        repo1.updateTeamMemberWeeklySchedule('tech_devon', devonUpdatedSchedule);

        // Step 3: Simulate FIRST browser refresh
        final repo2 = JobRepository();
        await repo2.init();

        // Verify all 3 technicians exist and schedules survived intact
        expect(repo2.currentUser.teamMembers.length, equals(3),
            reason: 'All 3 technicians must survive browser refresh');

        // Verify Tech 1 (Marcus)
        final rMarcus = repo2.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_marcus');
        expect(rMarcus.name, equals('Marcus Vance'));
        expect(rMarcus.roleTitle, equals('PPF & Ceramic Lead'));
        expect(rMarcus.customWeeklySchedule, isNotNull,
            reason: 'Marcus schedule must not reset to null');
        expect(rMarcus.customWeeklySchedule!.length, equals(7));
        expect(rMarcus.customWeeklySchedule![0].isOpen, isFalse,
            reason: 'Monday must be persisted as closed for Marcus');
        expect(rMarcus.customWeeklySchedule![5].isOpen, isTrue,
            reason: 'Saturday must be persisted as open for Marcus');
        expect(rMarcus.customWeeklySchedule![5].openTime, equals('09:00 AM'));
        expect(rMarcus.customWeeklySchedule![5].closeTime, equals('03:00 PM'));

        // Verify Tech 2 (Sofia)
        final rSofia = repo2.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_sofia');
        expect(rSofia.name, equals('Sofia Lin'));
        expect(rSofia.customWeeklySchedule, isNotNull);
        expect(rSofia.customWeeklySchedule!.length, equals(7));
        expect(rSofia.customWeeklySchedule![1].closeTime, equals('08:00 PM'),
            reason: 'Tuesday close time must be updated to 08:00 PM');
        expect(rSofia.customWeeklySchedule![6].isOpen, isTrue,
            reason: 'Sunday must be persisted as open for Sofia');
        expect(rSofia.customWeeklySchedule![6].openTime, equals('11:00 AM'));
        expect(rSofia.customWeeklySchedule![6].closeTime, equals('04:00 PM'));

        // Verify Tech 3 (Devon)
        final rDevon = repo2.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_devon');
        expect(rDevon.name, equals('Devon Reed'));
        expect(rDevon.customWeeklySchedule, isNotNull);
        expect(rDevon.customWeeklySchedule!.length, equals(7));
        expect(rDevon.customWeeklySchedule![3].isOpen, isTrue,
            reason: 'Thursday must be persisted as open for Devon');
        expect(rDevon.customWeeklySchedule![4].closeTime, equals('04:00 PM'),
            reason: 'Friday close time must be shortened to 04:00 PM');

        // Step 4: Simulate SECOND browser refresh
        final repo3 = JobRepository();
        await repo3.init();

        expect(repo3.currentUser.teamMembers.length, equals(3),
            reason: '2nd refresh must maintain 3 technicians');

        final r3Marcus = repo3.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_marcus');
        expect(r3Marcus.customWeeklySchedule![0].isOpen, isFalse);
        expect(r3Marcus.customWeeklySchedule![5].isOpen, isTrue);
        expect(r3Marcus.customWeeklySchedule![5].openTime, equals('09:00 AM'));

        final r3Sofia = repo3.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_sofia');
        expect(r3Sofia.customWeeklySchedule![1].closeTime, equals('08:00 PM'));
        expect(r3Sofia.customWeeklySchedule![6].isOpen, isTrue);

        final r3Devon = repo3.currentUser.teamMembers.firstWhere((m) => m.id == 'tech_devon');
        expect(r3Devon.customWeeklySchedule![3].isOpen, isTrue);
        expect(r3Devon.customWeeklySchedule![4].closeTime, equals('04:00 PM'));
      });

      test('2.2: Slot capacity and duty validation preserves staff availability before and after refresh', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);

        // Add 2 technicians with contrasting schedules:
        // Alex: Mon & Wed only
        final alexSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        // Chloe: Tue & Thu only
        final chloeSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        repo1.addTeamMember(TeamMember(
          id: 'tech_alex',
          name: 'Alex Turner',
          roleTitle: 'Correction Lead',
          avatarUrl: '',
          customWeeklySchedule: alexSchedule,
        ));

        repo1.addTeamMember(TeamMember(
          id: 'tech_chloe',
          name: 'Chloe Bennett',
          roleTitle: 'PPF Specialist',
          avatarUrl: '',
          customWeeklySchedule: chloeSchedule,
        ));

        // Find reference dates for Monday and Tuesday
        DateTime refMonday = DateTime.now();
        while (refMonday.weekday != DateTime.monday) {
          refMonday = refMonday.add(const Duration(days: 1));
        }
        final monDate = DateTime(refMonday.year, refMonday.month, refMonday.day);

        DateTime refTuesday = DateTime.now();
        while (refTuesday.weekday != DateTime.tuesday) {
          refTuesday = refTuesday.add(const Duration(days: 1));
        }
        final tueDate = DateTime(refTuesday.year, refTuesday.month, refTuesday.day);

        // Pre-refresh checks:
        // On Monday: Alex is on duty, Chloe is off duty
        expect(repo1.isMemberOnDutyOnDate('tech_alex', monDate), isTrue);
        expect(repo1.isMemberOnDutyOnDate('tech_chloe', monDate), isFalse);

        // On Tuesday: Alex is off duty, Chloe is on duty
        expect(repo1.isMemberOnDutyOnDate('tech_alex', tueDate), isFalse);
        expect(repo1.isMemberOnDutyOnDate('tech_chloe', tueDate), isTrue);

        // Simulate refresh
        final repo2 = JobRepository();
        await repo2.init();

        // Post-refresh checks: Capacity & duty queries must yield identical results
        expect(repo2.isMemberOnDutyOnDate('tech_alex', monDate), isTrue,
            reason: 'Alex must remain on duty on Monday after refresh');
        expect(repo2.isMemberOnDutyOnDate('tech_chloe', monDate), isFalse,
            reason: 'Chloe must remain off duty on Monday after refresh');

        expect(repo2.isMemberOnDutyOnDate('tech_alex', tueDate), isFalse,
            reason: 'Alex must remain off duty on Tuesday after refresh');
        expect(repo2.isMemberOnDutyOnDate('tech_chloe', tueDate), isTrue,
            reason: 'Chloe must remain on duty on Tuesday after refresh');
      });

      test('2.3: Rapid technician lifecycle transitions, role updates, and deletions across multi-refresh', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);

        // 1. Add tech initially with null schedule (inheriting studio hours)
        final tech = TeamMember(
          id: 'tech_evolving',
          name: 'Ethan Cole',
          roleTitle: 'Apprentice Detailer',
          avatarUrl: '',
          rating: 4.5,
          completedJobsCount: 5,
        );
        repo1.addTeamMember(tech);
        expect(repo1.currentUser.teamMembers.first.customWeeklySchedule, isNull);

        // 2. Assign custom schedule
        final newSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '04:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];
        repo1.updateTeamMemberWeeklySchedule('tech_evolving', newSchedule);

        // 3. Promote role & increase completed jobs
        final promoted = repo1.currentUser.teamMembers.first.copyWith(
          roleTitle: 'Senior Detail Specialist',
          completedJobsCount: 25,
          rating: 4.9,
        );
        repo1.updateTeamMember(promoted);

        // Refresh 1
        var repo2 = JobRepository();
        await repo2.init();

        final restored = repo2.currentUser.teamMembers.first;
        expect(restored.roleTitle, equals('Senior Detail Specialist'));
        expect(restored.completedJobsCount, equals(25));
        expect(restored.rating, equals(4.9));
        expect(restored.customWeeklySchedule, isNotNull);
        expect(restored.customWeeklySchedule![0].closeTime, equals('04:00 PM'));

        // 4. Add another tech and remove the first
        repo2.addTeamMember(const TeamMember(
          id: 'tech_second',
          name: 'Sarah Connor',
          roleTitle: 'Shop Manager',
          avatarUrl: '',
        ));
        repo2.removeTeamMember('tech_evolving');

        // Refresh 2
        var repo3 = JobRepository();
        await repo3.init();

        expect(repo3.currentUser.teamMembers.length, equals(1));
        expect(repo3.currentUser.teamMembers.first.id, equals('tech_second'));
        expect(repo3.currentUser.teamMembers.first.name, equals('Sarah Connor'));
        expect(repo3.currentUser.teamMembers.any((m) => m.id == 'tech_evolving'), isFalse);
      });
    });

    // =========================================================================
    // SECTION 3: Simultaneous Garage & Teams Multi-Module Stress Hardening
    // =========================================================================
    group('3. Simultaneous Garage & Teams Multi-Module Stress Hardening', () {
      test('3.1: Heavy interleaved mutations across Garage and Teams survive 4 consecutive browser refreshes', () async {
        final repo1 = await TestHarness.createSession(isLoggedIn: true);

        // 1. Populate Garage and Teams concurrently
        repo1.addVehicleToGarage(const UserVehicle(
          id: 'cross_veh_1',
          year: 2024,
          make: 'Aston Martin',
          model: 'Vantage',
          colorName: 'Cosmos Orange',
          imageUrl: '',
        ));
        repo1.addVehicleToGarage(const UserVehicle(
          id: 'cross_veh_2',
          year: 2025,
          make: 'Lamborghini',
          model: 'Revuelto',
          colorName: 'Verde Scandal',
          imageUrl: '',
        ));

        final crossSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '06:00 AM', closeTime: '02:00 PM'),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '06:00 AM', closeTime: '02:00 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '06:00 AM', closeTime: '02:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '06:00 AM', closeTime: '02:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '06:00 AM', closeTime: '02:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];

        repo1.addTeamMember(TeamMember(
          id: 'cross_tech_1',
          name: 'Nico Rosberg',
          roleTitle: 'Master Detailer',
          avatarUrl: '',
          customWeeklySchedule: crossSchedule,
        ));

        // 2. Refresh 1
        var currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(2));
        expect(currentRepo.currentUser.teamMembers.length, equals(1));

        // 3. Mutate both in Refresh 1
        currentRepo.updateVehicleInGarage(const UserVehicle(
          id: 'cross_veh_1',
          year: 2024,
          make: 'Aston Martin',
          model: 'Vantage F1 Edition',
          colorName: 'Aston Martin Racing Green',
          imageUrl: '',
        ));

        final updatedCrossSchedule = [
          const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
          const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
          const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
          const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
          const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
          const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '08:00 AM', closeTime: '12:00 PM'),
          const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
        ];
        currentRepo.updateTeamMemberWeeklySchedule('cross_tech_1', updatedCrossSchedule);

        // 4. Refresh 2
        currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.firstWhere((v) => v.id == 'cross_veh_1').model, equals('Vantage F1 Edition'));
        expect(currentRepo.currentUser.teamMembers.firstWhere((m) => m.id == 'cross_tech_1').customWeeklySchedule![0].isOpen, isFalse);

        // 5. Refresh 3 (Idle refresh)
        currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(2));
        expect(currentRepo.currentUser.teamMembers.length, equals(1));

        // 6. Refresh 4 (Idle refresh)
        currentRepo = JobRepository();
        await currentRepo.init();
        expect(currentRepo.currentUser.myGarage.length, equals(2));
        expect(currentRepo.currentUser.teamMembers.length, equals(1));

        final finalVeh = currentRepo.currentUser.myGarage.firstWhere((v) => v.id == 'cross_veh_1');
        expect(finalVeh.model, equals('Vantage F1 Edition'));
        expect(finalVeh.colorName, equals('Aston Martin Racing Green'));

        final finalTech = currentRepo.currentUser.teamMembers.firstWhere((m) => m.id == 'cross_tech_1');
        expect(finalTech.name, equals('Nico Rosberg'));
        expect(finalTech.customWeeklySchedule![0].isOpen, isFalse);
        expect(finalTech.customWeeklySchedule![5].isOpen, isTrue);
        expect(finalTech.customWeeklySchedule![5].openTime, equals('08:00 AM'));
        expect(finalTech.customWeeklySchedule![5].closeTime, equals('12:00 PM'));
      });
    });
  });
}
