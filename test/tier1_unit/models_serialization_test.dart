import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/paint_gauge_point.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. ServicePackage Model Serialization & Deserialization
  // =========================================================================
  group('ServicePackage JSON Serialization & Deserialization', () {
    test('1.1 Roundtrip: Full package with all fields populated', () {
      const package = ServicePackage(
        id: 'pkg_ceramic_pro_01',
        title: 'Master Ceramic & Paint Correction',
        description: 'Multi-stage paint correction followed by 5-year 9H ceramic coating.',
        basePrice: 899.99,
        estimatedDuration: '6-8 hrs',
        includes: [
          'Decon foam wash & clay bar treatment',
          '2-Stage compound & polish',
          'CarPro Cquartz UK 3.0 dual-layer application',
          'Wheel faces & glass hydrophobic treatment',
        ],
        isPopular: true,
        recipeId: 'rcp_001',
        recipeName: 'Standard 2-Stage German Clear Formula',
      );

      final json = package.toJson();
      final restored = ServicePackage.fromJson(json);

      expect(restored.id, package.id);
      expect(restored.title, package.title);
      expect(restored.description, package.description);
      expect(restored.basePrice, package.basePrice);
      expect(restored.estimatedDuration, package.estimatedDuration);
      expect(restored.includes, package.includes);
      expect(restored.isPopular, true);
      expect(restored.recipeId, 'rcp_001');
      expect(restored.recipeName, 'Standard 2-Stage German Clear Formula');
    });

    test('1.2 Roundtrip: Minimal package with optional fields null', () {
      const package = ServicePackage(
        id: 'pkg_express_02',
        title: 'Express Wash & Seal',
        description: 'Single-pass wash with SiO2 spray sealant.',
        basePrice: 95.0,
        estimatedDuration: '1 hr',
        includes: ['Foam wash', 'Wheel cleaning', 'Spray sealant'],
        isPopular: false,
      );

      final json = package.toJson();
      expect(json.containsKey('recipeId'), isFalse);
      expect(json.containsKey('recipeName'), isFalse);

      final restored = ServicePackage.fromJson(json);
      expect(restored.id, 'pkg_express_02');
      expect(restored.isPopular, isFalse);
      expect(restored.recipeId, isNull);
      expect(restored.recipeName, isNull);
    });

    test('1.3 Fallback: Deserializing empty JSON map provides resilient defaults', () {
      final restored = ServicePackage.fromJson({});

      expect(restored.id.startsWith('pkg_'), isTrue);
      expect(restored.title, '');
      expect(restored.description, '');
      expect(restored.basePrice, 100.0);
      expect(restored.estimatedDuration, '2-3 hrs');
      expect(restored.includes, isEmpty);
      expect(restored.isPopular, isFalse);
      expect(restored.recipeId, isNull);
      expect(restored.recipeName, isNull);
    });

    test('1.4 Adversarial: Special characters, escaping, unicode and HTML tags', () {
      const package = ServicePackage(
        id: 'pkg_adv_01',
        title: 'Ceramic Pro® 9H Gold | 3-Stage Cut & Polish ✨ \n\t "Special" <script>',
        description: 'Multi-lingual description: München, Köln, 911 GT3 RS™ & 812 Superfast®',
        basePrice: 1499.50,
        estimatedDuration: '8+ hrs \r\n (2 Days)',
        includes: [
          'Wash with pH-neutral soap & warm H₂O',
          'IPA wipe (15% alcohol) "streak-free"',
          '<tag>alert("XSS")</tag>',
        ],
        isPopular: true,
      );

      final jsonString = jsonEncode(package.toJson());
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final restored = ServicePackage.fromJson(decoded);

      expect(restored.title, package.title);
      expect(restored.description, package.description);
      expect(restored.estimatedDuration, package.estimatedDuration);
      expect(restored.includes, package.includes);
    });

    test('1.5 Numeric Coercion: Integer price in JSON parses to double, boundary prices', () {
      final jsonIntPrice = {
        'id': 'pkg_num_01',
        'title': 'Int Price Test',
        'basePrice': 250, // int instead of double
      };

      final restored = ServicePackage.fromJson(jsonIntPrice);
      expect(restored.basePrice, 250.0);
      expect(restored.basePrice, isA<double>());

      final jsonZeroPrice = {
        'id': 'pkg_zero_01',
        'title': 'Free Inspection',
        'basePrice': 0.0,
      };
      final restoredZero = ServicePackage.fromJson(jsonZeroPrice);
      expect(restoredZero.basePrice, 0.0);
    });

    test('1.6 Immutability: copyWith updates target fields and retains others', () {
      const package = ServicePackage(
        id: 'pkg_copy_01',
        title: 'Original Title',
        description: 'Original Description',
        basePrice: 200.0,
        estimatedDuration: '2 hrs',
        includes: ['Step 1'],
        isPopular: false,
      );

      final updated = package.copyWith(
        title: 'New Title',
        basePrice: 250.0,
        isPopular: true,
      );

      expect(updated.id, 'pkg_copy_01');
      expect(updated.title, 'New Title');
      expect(updated.description, 'Original Description');
      expect(updated.basePrice, 250.0);
      expect(updated.isPopular, isTrue);
      expect(updated.includes, ['Step 1']);
    });
  });

  // =========================================================================
  // 2. UserVehicle Model Serialization & Deserialization
  // =========================================================================
  group('UserVehicle JSON Serialization & Deserialization', () {
    test('2.1 Roundtrip: Full vehicle with all fields and binary image bytes', () {
      final sampleBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03]);
      final vehicle = UserVehicle(
        id: 'veh_911_gt3',
        year: 2023,
        make: 'Porsche',
        model: '911 GT3 RS',
        colorName: 'Python Green',
        paintCode: 'M6C',
        imageUrl: 'https://images.unsplash.com/photo-sample.jpg',
        localImageBytes: sampleBytes,
        lastDetailService: 'Full Paint Protection Film & Ceramic',
        lastDetailDate: DateTime(2026, 9, 15, 14, 30),
      );

      final json = vehicle.toJson();
      final restored = UserVehicle.fromJson(json);

      expect(restored.id, vehicle.id);
      expect(restored.year, 2023);
      expect(restored.make, 'Porsche');
      expect(restored.model, '911 GT3 RS');
      expect(restored.colorName, 'Python Green');
      expect(restored.paintCode, 'M6C');
      expect(restored.imageUrl, vehicle.imageUrl);
      expect(restored.localImageBytes, isNotNull);
      expect(restored.localImageBytes, equals(sampleBytes));
      expect(restored.lastDetailService, 'Full Paint Protection Film & Ceramic');
      expect(restored.lastDetailDate, DateTime(2026, 9, 15, 14, 30));
    });

    test('2.2 Roundtrip: Minimal vehicle with null optional fields', () {
      const vehicle = UserVehicle(
        id: 'veh_min_01',
        year: 2021,
        make: 'Tesla',
        model: 'Model S Plaid',
        colorName: 'Midnight Silver Metallic',
        imageUrl: 'https://example.com/tesla.jpg',
      );

      final json = vehicle.toJson();
      expect(json['paintCode'], isNull);
      expect(json['localImageBytes'], isNull);
      expect(json['lastDetailService'], isNull);
      expect(json['lastDetailDate'], isNull);

      final restored = UserVehicle.fromJson(json);
      expect(restored.id, 'veh_min_01');
      expect(restored.paintCode, isNull);
      expect(restored.localImageBytes, isNull);
      expect(restored.lastDetailDate, isNull);
    });

    test('2.3 Binary Encoding: localImageBytes preserves arbitrary byte values', () {
      final binaryPayload = Uint8List.fromList(List.generate(256, (i) => i));
      final vehicle = UserVehicle(
        id: 'veh_bin_01',
        year: 2024,
        make: 'Audi',
        model: 'RS6 Avant',
        colorName: 'Nardo Grey',
        imageUrl: '',
        localImageBytes: binaryPayload,
      );

      final jsonString = jsonEncode(vehicle.toJson());
      final restored = UserVehicle.fromJson(jsonDecode(jsonString));

      expect(restored.localImageBytes, isNotNull);
      expect(restored.localImageBytes!.length, 256);
      expect(restored.localImageBytes, equals(binaryPayload));
    });

    test('2.4 Fallback: Deserializing empty JSON map provides resilient defaults', () {
      final restored = UserVehicle.fromJson({});

      expect(restored.id.startsWith('veh_'), isTrue);
      expect(restored.year, 2024);
      expect(restored.make, '');
      expect(restored.model, '');
      expect(restored.colorName, '');
      expect(restored.paintCode, isNull);
      expect(restored.imageUrl, '');
      expect(restored.localImageBytes, isNull);
      expect(restored.lastDetailService, isNull);
      expect(restored.lastDetailDate, isNull);
    });

    test('2.5 Adversarial: Escaping and special characters in vehicle make/model/code', () {
      const vehicle = UserVehicle(
        id: 'veh_adv_01',
        year: 2025,
        make: 'Mercedes-Benz / AMG®',
        model: 'G 63 "4x4²" <Special Edition>',
        colorName: 'Designo Magno Night Black (Matte 100%)',
        paintCode: '056/9056 & Special',
        imageUrl: 'https://example.com/car?query=1&type=amg#details',
      );

      final jsonString = jsonEncode(vehicle.toJson());
      final restored = UserVehicle.fromJson(jsonDecode(jsonString));

      expect(restored.make, 'Mercedes-Benz / AMG®');
      expect(restored.model, 'G 63 "4x4²" <Special Edition>');
      expect(restored.colorName, 'Designo Magno Night Black (Matte 100%)');
      expect(restored.paintCode, '056/9056 & Special');
    });

    test('2.6 Computed Property: fullName returns formatted string', () {
      const vehicle = UserVehicle(
        id: 'veh_name_01',
        year: 2022,
        make: 'BMW',
        model: 'M3 Competition',
        colorName: 'Isle of Man Green',
        imageUrl: '',
      );

      expect(vehicle.fullName, '2022 BMW M3 Competition');
    });
  });

  // =========================================================================
  // 3. TeamMember Model Serialization & Deserialization
  // =========================================================================
  group('TeamMember JSON Serialization & Deserialization', () {
    test('3.1 Roundtrip: Full member with customWeeklySchedule and avatar bytes', () {
      final avatarBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x11, 0x22]);
      final schedule = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '07:30 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '07:30 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '07:30 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '07:30 AM', closeTime: '04:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '07:30 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: false, openTime: '08:00 AM', closeTime: '02:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '08:00 AM', closeTime: '02:00 PM'),
      ];

      final member = TeamMember(
        id: 'tm_carlos_01',
        name: 'Carlos Ruiz',
        roleTitle: 'Ceramic Coating Lead',
        avatarUrl: 'https://example.com/carlos.jpg',
        localAvatarBytes: avatarBytes,
        rating: 4.95,
        completedJobsCount: 142,
        isAvailable: true,
        isFounder: true,
        customWeeklySchedule: schedule,
      );

      final json = member.toJson();
      final restored = TeamMember.fromJson(json);

      expect(restored.id, member.id);
      expect(restored.name, 'Carlos Ruiz');
      expect(restored.roleTitle, 'Ceramic Coating Lead');
      expect(restored.avatarUrl, member.avatarUrl);
      expect(restored.localAvatarBytes, equals(avatarBytes));
      expect(restored.rating, 4.95);
      expect(restored.completedJobsCount, 142);
      expect(restored.isAvailable, isTrue);
      expect(restored.isFounder, isTrue);
      expect(restored.customWeeklySchedule, isNotNull);
      expect(restored.customWeeklySchedule!.length, 7);
      expect(restored.customWeeklySchedule![0].weekday, 1);
      expect(restored.customWeeklySchedule![0].isOpen, isTrue);
      expect(restored.customWeeklySchedule![0].openTime, '07:30 AM');
      expect(restored.customWeeklySchedule![5].isOpen, isFalse);
    });

    test('3.2 Roundtrip: Member without custom schedule inherits studio defaults', () {
      const member = TeamMember(
        id: 'tm_jake_02',
        name: 'Jake Vance',
        roleTitle: 'Apprentice Detailer',
        avatarUrl: '',
        rating: 4.8,
        completedJobsCount: 24,
        isAvailable: false,
        isFounder: false,
      );

      final json = member.toJson();
      expect(json.containsKey('customWeeklySchedule'), isFalse);

      final restored = TeamMember.fromJson(json);
      expect(restored.id, 'tm_jake_02');
      expect(restored.customWeeklySchedule, isNull);
      expect(restored.isAvailable, isFalse);
      expect(restored.isFounder, isFalse);
    });

    test('3.3 Fallback: Deserializing empty JSON map provides resilient defaults', () {
      final restored = TeamMember.fromJson({});

      expect(restored.id.startsWith('tm_'), isTrue);
      expect(restored.name, '');
      expect(restored.roleTitle, 'Detail Specialist');
      expect(restored.avatarUrl, '');
      expect(restored.localAvatarBytes, isNull);
      expect(restored.rating, 5.0);
      expect(restored.completedJobsCount, 0);
      expect(restored.isAvailable, isTrue);
      expect(restored.isFounder, isFalse);
      expect(restored.customWeeklySchedule, isNull);
    });

    test('3.4 DayBusinessHours: Weekday names and short names match ISO standards', () {
      for (int i = 1; i <= 7; i++) {
        final hours = DayBusinessHours(weekday: i);
        expect(hours.weekdayName.isNotEmpty, isTrue);
        expect(hours.weekdayShort.length, 3);
      }
      expect(const DayBusinessHours(weekday: 1).weekdayName, 'Monday');
      expect(const DayBusinessHours(weekday: 7).weekdayName, 'Sunday');
      expect(const DayBusinessHours(weekday: 5).weekdayShort, 'Fri');
    });

    test('3.5 Status Label & Availability: Available vs On Job', () {
      const availableMember = TeamMember(
        id: 'tm_stat_1',
        name: 'Sara',
        roleTitle: 'Lead',
        avatarUrl: '',
        isAvailable: true,
      );
      expect(availableMember.statusLabel, 'Available');

      const busyMember = TeamMember(
        id: 'tm_stat_2',
        name: 'Alex',
        roleTitle: 'Tech',
        avatarUrl: '',
        isAvailable: false,
      );
      expect(busyMember.statusLabel, 'On Job');
    });

    test('3.6 Adversarial: Integer rating coercion and unicode name characters', () {
      final json = {
        'id': 'tm_adv_01',
        'name': 'René François-Chauveau 佐藤 健',
        'roleTitle': 'Maître Detailer & Polierer',
        'rating': 5, // int instead of double
        'completedJobsCount': 250,
      };

      final restored = TeamMember.fromJson(json);
      expect(restored.rating, 5.0);
      expect(restored.rating, isA<double>());
      expect(restored.name, 'René François-Chauveau 佐藤 健');
    });

    test('3.7 Immutability: copyWith produces accurate updated instance', () {
      const original = TeamMember(
        id: 'tm_orig',
        name: 'Maria',
        roleTitle: 'Junior Tech',
        avatarUrl: 'https://example.com/orig.jpg',
      );

      final updated = original.copyWith(
        roleTitle: 'Senior Specialist',
        rating: 4.95,
        isAvailable: false,
      );

      expect(updated.id, 'tm_orig');
      expect(updated.name, 'Maria');
      expect(updated.roleTitle, 'Senior Specialist');
      expect(updated.rating, 4.95);
      expect(updated.isAvailable, isFalse);
    });
  });

  // =========================================================================
  // 4. InventoryItem Model Serialization & Deserialization
  // =========================================================================
  group('InventoryItem JSON Serialization & Deserialization', () {
    test('4.1 Roundtrip: Chemical item with fill level, dilution specs & safety notes', () {
      const item = InventoryItem(
        id: 'inv_chem_01',
        name: 'Koch Chemie H9.02 Heavy Cut',
        category: InventoryCategory.chemicals,
        brand: 'Koch Chemie',
        subCategory: 'Heavy Cut Compound',
        specs: {
          'Cut': '9.0 / 10.0',
          'Gloss': '5.0 / 10.0',
          'pH Level': 'Neutral',
          'VOC Compliant': 'Yes',
        },
        dilutionSpecs: '1:4 for heavy degreasing, 1:10 for general engine bay cleaning',
        dilutionRatio: '1:4',
        cureTimeOrFlashTime: 'Flash in 60s, cure in 24h',
        safetyNotes: 'Use nitrile gloves and NIOSH-approved respirator in enclosed bays.',
        status: 'Full',
        location: 'Bay 1 Chemical Cabinet - Shelf 2',
        notes: 'Primary heavy cut compound for German clear coats.',
      );

      final json = item.toJson();
      final restored = InventoryItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.category, InventoryCategory.chemicals);
      expect(restored.brand, 'Koch Chemie');
      expect(restored.subCategory, 'Heavy Cut Compound');
      expect(restored.specs['Cut'], '9.0 / 10.0');
      expect(restored.specs['VOC Compliant'], 'Yes');
      expect(restored.dilutionSpecs, item.dilutionSpecs);
      expect(restored.dilutionRatio, '1:4');
      expect(restored.cureTimeOrFlashTime, item.cureTimeOrFlashTime);
      expect(restored.safetyNotes, item.safetyNotes);
      expect(restored.status, 'Full'); // Chemical fill level
      expect(restored.location, item.location);
    });

    test('4.2 Roundtrip: Hardware item with machine specs and maintenance schedule', () {
      const item = InventoryItem(
        id: 'inv_hw_01',
        name: 'Rupes LHR15 Mark III',
        category: InventoryCategory.hardware,
        brand: 'Rupes',
        subCategory: 'Dual Action Polisher',
        specs: {
          'Orbit': '15mm',
          'Backing Plate': '5 inch (125mm)',
          'Power': '500W',
          'OPM': '3000-5200',
        },
        maintenance: 'Blow out cooling vents with dry compressed air every 20 hours. Inspect brushes every 100 hours.',
        assignedPadOrChemical: 'Lake Country Microfiber & Yellow Foam Pads',
        status: 'In Service',
        location: 'Polisher Tool Wall #3',
      );

      final json = item.toJson();
      final restored = InventoryItem.fromJson(json);

      expect(restored.id, 'inv_hw_01');
      expect(restored.category, InventoryCategory.hardware);
      expect(restored.specs['Orbit'], '15mm');
      expect(restored.maintenance, item.maintenance);
      expect(restored.assignedPadOrChemical, item.assignedPadOrChemical);
      expect(restored.status, 'In Service');
    });

    test('4.3 Roundtrip: Recipe item with multiple nested RecipeStage objects', () {
      const item = InventoryItem(
        id: 'inv_rcp_01',
        name: 'Porsche Hard Clear Correction Formula',
        category: InventoryCategory.recipe,
        brand: 'DetailCraft Studio Pro',
        subCategory: 'Multi-Stage Paint Correction',
        recipeStages: [
          RecipeStage(
            stageName: 'Chemical Decontamination',
            machine: 'Grit Guard Wash Setup',
            pad: 'Rag Company Cyclone Mitt',
            chemical: 'CarPro IronX & TarX',
            technique: 'Dwell for 5 minutes, rinse thoroughly before contact wash',
            dilution: 'Neat (undiluted)',
            notes: 'Do not allow to dry on glass or hot surfaces',
          ),
          RecipeStage(
            stageName: 'Heavy Compounding Cut',
            machine: 'Rupes LHR15 Mark III',
            pad: 'Lake Country HDO Microfiber Heavy Cutting Pad',
            chemical: 'Koch Chemie H9.02',
            technique: '4 crosshatch passes @ speed 4.5, slow arm speed, 5-8 lbs pressure',
            dilution: 'Neat',
            notes: 'Prime pad with 4 pea-sized drops; blow out with air after each section',
          ),
          RecipeStage(
            stageName: 'Jeweling Polish & Finish',
            machine: 'Rupes LHR15 Mark III',
            pad: 'Rupes Yellow Fine Foam Pad',
            chemical: 'Sonax Profiline Perfect Finish',
            technique: '3 light passes @ speed 3.0, zero downward pressure',
            dilution: 'Neat',
            notes: 'IPA 15% wipe-down to inspect true paint condition without fillers',
          ),
        ],
      );

      final json = item.toJson();
      final restored = InventoryItem.fromJson(json);

      expect(restored.category, InventoryCategory.recipe);
      expect(restored.recipeStages.length, 3);
      expect(restored.recipeStages[0].stageName, 'Chemical Decontamination');
      expect(restored.recipeStages[1].machine, 'Rupes LHR15 Mark III');
      expect(restored.recipeStages[1].pad, 'Lake Country HDO Microfiber Heavy Cutting Pad');
      expect(restored.recipeStages[2].chemical, 'Sonax Profiline Perfect Finish');
      expect(restored.recipeStages[2].dilution, 'Neat');
    });

    test('4.4 Fill Levels & Statuses: Full, Half, Low, Empty, Repair', () {
      final statuses = ['Full', 'Half', 'Low', 'Empty', 'In Service', 'Repair'];
      for (final status in statuses) {
        final item = InventoryItem(
          id: 'inv_test_$status',
          name: 'Chemical $status',
          category: InventoryCategory.chemicals,
          status: status,
        );
        final restored = InventoryItem.fromJson(item.toJson());
        expect(restored.status, status);
      }
    });

    test('4.5 Fallback: Deserializing empty JSON map provides resilient defaults', () {
      final restored = InventoryItem.fromJson({});

      expect(restored.id.startsWith('inv_'), isTrue);
      expect(restored.name, '');
      expect(restored.category, InventoryCategory.hardware);
      expect(restored.status, 'In Service');
      expect(restored.specs, isEmpty);
      expect(restored.recipeStages, isEmpty);
      expect(restored.dilutionSpecs, '');
      expect(restored.dilutionRatio, isNull);
    });

    test('4.6 Adversarial: Unknown category string falls back gracefully to hardware', () {
      final json = {
        'id': 'inv_unknown_cat',
        'name': 'Unknown Cat Item',
        'category': 'INVALID_CATEGORY_NAME',
      };

      final restored = InventoryItem.fromJson(json);
      expect(restored.category, InventoryCategory.hardware);
    });
  });

  // =========================================================================
  // 5. CalendarAvailabilityBlock & Preferences Serialization & Deserialization
  // =========================================================================
  group('CalendarAvailabilityBlock JSON Serialization & Deserialization', () {
    test('5.1 Roundtrip: Studio-wide all day block with reason', () {
      final block = CalendarAvailabilityBlock(
        id: 'block_sema_01',
        detailerId: 'usr_you',
        teamMemberId: null, // Studio-wide
        date: DateTime(2026, 11, 4),
        isAllDay: true,
        blockedSlots: const [],
        reason: 'Studio Closed for SEMA Show Las Vegas',
        createdAt: DateTime(2026, 10, 1, 10, 0),
      );

      final json = block.toJson();
      expect(json.containsKey('teamMemberId'), isFalse);

      final restored = CalendarAvailabilityBlock.fromJson(json);
      expect(restored.id, 'block_sema_01');
      expect(restored.detailerId, 'usr_you');
      expect(restored.teamMemberId, isNull);
      expect(restored.isAllDay, isTrue);
      expect(restored.reason, 'Studio Closed for SEMA Show Las Vegas');
      expect(restored.date.year, 2026);
      expect(restored.date.month, 11);
      expect(restored.date.day, 4);
    });

    test('5.2 Roundtrip: Specific staff member partial slot block', () {
      final block = CalendarAvailabilityBlock(
        id: 'block_partial_02',
        detailerId: 'usr_you',
        teamMemberId: 'tm_carlos_01',
        date: DateTime(2026, 10, 20),
        isAllDay: false,
        blockedSlots: const ['8:00 AM - 11:00 AM', '1:00 PM - 4:00 PM'],
        reason: 'Off-site mobile warranty inspection',
        createdAt: DateTime(2026, 10, 15, 8, 30),
      );

      final json = block.toJson();
      final restored = CalendarAvailabilityBlock.fromJson(json);

      expect(restored.id, 'block_partial_02');
      expect(restored.teamMemberId, 'tm_carlos_01');
      expect(restored.isAllDay, isFalse);
      expect(restored.blockedSlots, ['8:00 AM - 11:00 AM', '1:00 PM - 4:00 PM']);
      expect(restored.reason, 'Off-site mobile warranty inspection');
    });

    test('5.3 Roundtrip: Custom extra slots override for high-demand weekend', () {
      final block = CalendarAvailabilityBlock(
        id: 'block_custom_slots_03',
        detailerId: 'usr_you',
        date: DateTime(2026, 10, 24),
        isAllDay: false,
        hasCustomSlotsOverride: true,
        customSlots: const ['6:00 AM - 9:00 AM', '6:00 PM - 9:00 PM'],
        blockedSlots: const [],
        reason: 'Extended twilight detailing hours',
        createdAt: DateTime(2026, 10, 16, 9, 0),
      );

      final json = block.toJson();
      final restored = CalendarAvailabilityBlock.fromJson(json);

      expect(restored.hasCustomSlotsOverride, isTrue);
      expect(restored.customSlots, ['6:00 AM - 9:00 AM', '6:00 PM - 9:00 PM']);
      expect(restored.blockedSlots, isEmpty);
    });

    test('5.4 Fallback: Deserializing empty JSON map provides resilient defaults', () {
      final restored = CalendarAvailabilityBlock.fromJson({});

      expect(restored.id.startsWith('block_'), isTrue);
      expect(restored.detailerId, '');
      expect(restored.teamMemberId, isNull);
      expect(restored.isAllDay, isTrue);
      expect(restored.blockedSlots, isEmpty);
      expect(restored.customSlots, isEmpty);
      expect(restored.hasCustomSlotsOverride, isFalse);
      expect(restored.reason, isNull);
    });

    test('5.5 Roundtrip: DetailerCalendarPreferences full configuration', () {
      final schedule = [
        const DayBusinessHours(weekday: 1, isOpen: true, openTime: '07:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: 2, isOpen: true, openTime: '07:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: 3, isOpen: true, openTime: '07:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: 4, isOpen: true, openTime: '07:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: 5, isOpen: true, openTime: '07:00 AM', closeTime: '07:00 PM'),
        const DayBusinessHours(weekday: 6, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: 7, isOpen: false, openTime: '08:00 AM', closeTime: '05:00 PM'),
      ];
      final prefs = DetailerCalendarPreferences(
        weeklySchedule: schedule,
        advanceNoticeHours: 12,
        bufferMinutesBetweenJobs: 45,
        maxAdvanceBookingDays: 90,
        autoConfirmBookings: false,
        slotDurationHours: 4,
        customTimeSlots: const [
          '7:00 AM - 11:00 AM',
          '11:45 AM - 3:45 PM',
          '4:30 PM - 8:30 PM',
        ],
      );

      final json = prefs.toJson();
      final restored = DetailerCalendarPreferences.fromJson(json);

      expect(restored.advanceNoticeHours, 12);
      expect(restored.bufferMinutesBetweenJobs, 45);
      expect(restored.maxAdvanceBookingDays, 90);
      expect(restored.autoConfirmBookings, isFalse);
      expect(restored.slotDurationHours, 4);
      expect(restored.customTimeSlots, prefs.customTimeSlots);
      expect(restored.weeklySchedule.length, 7);
      expect(restored.weeklySchedule[0].openTime, '07:00 AM');
      expect(restored.weeklySchedule[6].isOpen, isFalse);
    });

    test('5.6 Adversarial: Reason with special characters, emojis & quotes', () {
      final block = CalendarAvailabilityBlock(
        id: 'block_adv_01',
        detailerId: 'usr_you',
        date: DateTime(2026, 12, 25),
        isAllDay: true,
        reason: '🎄 Christmas & New Year Holiday Closure! "No exceptions" <closed>',
        createdAt: DateTime.now(),
      );

      final jsonString = jsonEncode(block.toJson());
      final restored = CalendarAvailabilityBlock.fromJson(jsonDecode(jsonString));

      expect(restored.reason, '🎄 Christmas & New Year Holiday Closure! "No exceptions" <closed>');
    });
  });

  // =========================================================================
  // 6. BookingAppointment Model Serialization & Deserialization
  // =========================================================================
  group('BookingAppointment JSON Serialization & Deserialization', () {
    const samplePackage = ServicePackage(
      id: 'pkg_booking_sample',
      title: 'Full Exterior & Ceramic Coating',
      description: 'Paint decontamination & 2-year ceramic coating.',
      basePrice: 450.0,
      estimatedDuration: '4-5 hrs',
      includes: ['Foam wash', 'Clay bar', '1-Stage polish', 'Ceramic coating'],
    );

    test('6.1 Roundtrip: Full appointment with assigned team member & warranty passport', () {
      final booking = BookingAppointment(
        id: 'bk_full_001',
        clientId: 'usr_client_01',
        detailerId: 'usr_detailer_you',
        detailerName: 'Giancarlo Oporto',
        detailerBusinessName: 'AutoDetailCraft Master Studio',
        detailerAvatar: 'https://example.com/avatar.jpg',
        clientName: 'Alexander Hayes',
        clientPhone: '(512) 555-0199',
        clientEmail: 'alex.hayes@example.com',
        vehicleYearMakeModel: '2023 Porsche 911 GT3',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.mobile,
        clientAddress: '12400 Amber Trail, Austin TX 78759',
        scheduledDate: DateTime(2026, 10, 22),
        scheduledTimeSlot: '9:00 AM - 12:00 PM',
        totalPrice: 450.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
        clientNotes: 'Gate code #4022. Please text 15 minutes before arrival.',
        preInspectionSummary: 'Minor wash marring on rear quarter panels; no deep scratches.',
        warrantyPassportId: 'WARR-2026-911-001',
        assignedTeamMemberId: 'tm_carlos_01',
        assignedTeamMemberName: 'Carlos Ruiz',
      );

      final json = booking.toJson();
      final restored = BookingAppointment.fromJson(json);

      expect(restored.id, 'bk_full_001');
      expect(restored.clientId, 'usr_client_01');
      expect(restored.detailerId, 'usr_detailer_you');
      expect(restored.detailerName, 'Giancarlo Oporto');
      expect(restored.clientName, 'Alexander Hayes');
      expect(restored.clientPhone, '(512) 555-0199');
      expect(restored.vehicleYearMakeModel, '2023 Porsche 911 GT3');
      expect(restored.vehicleSize, VehicleSize.coupeSedan);
      expect(restored.locationType, ServiceLocationType.mobile);
      expect(restored.clientAddress, '12400 Amber Trail, Austin TX 78759');
      expect(restored.totalPrice, 450.0);
      expect(restored.depositAmount, 100.0);
      expect(restored.status, BookingStatus.confirmed);
      expect(restored.clientNotes, contains('Gate code #4022'));
      expect(restored.warrantyPassportId, 'WARR-2026-911-001');
      expect(restored.assignedTeamMemberId, 'tm_carlos_01');
      expect(restored.assignedTeamMemberName, 'Carlos Ruiz');
      expect(restored.package.title, samplePackage.title);
    });

    test('6.2 Roundtrip: Minimal appointment with null optional fields', () {
      final booking = BookingAppointment(
        id: 'bk_min_002',
        detailerId: 'usr_detailer_02',
        detailerName: 'Detail Pro',
        detailerBusinessName: 'Pro Detailing',
        detailerAvatar: '',
        clientName: 'Jane Doe',
        clientPhone: '555-0100',
        clientEmail: 'jane@example.com',
        vehicleYearMakeModel: '2022 BMW M4',
        vehicleSize: VehicleSize.coupeSedan,
        package: samplePackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '',
        scheduledDate: DateTime(2026, 10, 25),
        scheduledTimeSlot: '1:00 PM - 4:00 PM',
        totalPrice: 350.0,
        depositAmount: 0.0,
        status: BookingStatus.pending,
      );

      final json = booking.toJson();
      expect(json['clientId'], isNull);
      expect(json['clientNotes'], isNull);
      expect(json['preInspectionSummary'], isNull);
      expect(json['warrantyPassportId'], isNull);
      expect(json['assignedTeamMemberId'], isNull);

      final restored = BookingAppointment.fromJson(json);
      expect(restored.id, 'bk_min_002');
      expect(restored.clientId, isNull);
      expect(restored.clientNotes, isNull);
      expect(restored.assignedTeamMemberId, isNull);
      expect(restored.locationType, ServiceLocationType.shop);
      expect(restored.status, BookingStatus.pending);
    });

    test('6.3 Status Lifecycle: All BookingStatus enum values roundtrip accurately', () {
      final statuses = [
        BookingStatus.pending,
        BookingStatus.confirmed,
        BookingStatus.inProgress,
        BookingStatus.completed,
        BookingStatus.cancelled,
      ];

      for (final status in statuses) {
        final booking = BookingAppointment(
          id: 'bk_status_${status.name}',
          detailerId: 'usr_d1',
          detailerName: 'D Name',
          detailerBusinessName: 'Biz',
          detailerAvatar: '',
          clientName: 'Client',
          clientPhone: '555',
          clientEmail: 'c@c.com',
          vehicleYearMakeModel: 'Car',
          vehicleSize: VehicleSize.coupeSedan,
          package: samplePackage,
          locationType: ServiceLocationType.shop,
          clientAddress: '',
          scheduledDate: DateTime(2026, 10, 20),
          scheduledTimeSlot: '9:00 AM',
          totalPrice: 100.0,
          depositAmount: 50.0,
          status: status,
        );

        final restored = BookingAppointment.fromJson(booking.toJson());
        expect(restored.status, status);
      }
    });

    test('6.4 Enum Fallbacks: Unrecognized enum strings fall back to safe defaults', () {
      final json = {
        'id': 'bk_fallback_01',
        'detailerId': 'usr_d1',
        'detailerName': 'Detailer',
        'detailerBusinessName': 'Biz',
        'detailerAvatar': '',
        'clientName': 'Client',
        'clientPhone': '555',
        'clientEmail': 'test@test.com',
        'vehicleYearMakeModel': 'Car',
        'vehicleSize': 'UNRECOGNIZED_SIZE',
        'package': samplePackage.toJson(),
        'locationType': 'UNKNOWN_LOCATION',
        'status': 'UNKNOWN_STATUS',
      };

      final restored = BookingAppointment.fromJson(json);
      expect(restored.vehicleSize, VehicleSize.coupeSedan);
      expect(restored.locationType, ServiceLocationType.mobile);
      expect(restored.status, BookingStatus.confirmed);
    });

    test('6.5 Numeric Coercion: Integer totalPrice and depositAmount parse to double', () {
      final json = {
        'id': 'bk_num_01',
        'detailerId': 'usr_d1',
        'detailerName': 'Detailer',
        'detailerBusinessName': 'Biz',
        'detailerAvatar': '',
        'clientName': 'Client',
        'clientPhone': '555',
        'clientEmail': 'test@test.com',
        'vehicleYearMakeModel': 'Car',
        'package': samplePackage.toJson(),
        'totalPrice': 500, // int
        'depositAmount': 150, // int
      };

      final restored = BookingAppointment.fromJson(json);
      expect(restored.totalPrice, 500.0);
      expect(restored.depositAmount, 150.0);
      expect(restored.totalPrice, isA<double>());
      expect(restored.depositAmount, isA<double>());
    });

    test('6.6 Adversarial: Multi-line notes, special symbols & address escaping', () {
      final booking = BookingAppointment(
        id: 'bk_adv_01',
        detailerId: 'usr_d1',
        detailerName: 'Detailer',
        detailerBusinessName: 'Biz',
        detailerAvatar: '',
        clientName: 'O\'Connor & Sons, LLC',
        clientPhone: '+1 (512) 555-0199 ext. 42',
        clientEmail: 'billing+detailcraft@oconnor-sons.co.uk',
        vehicleYearMakeModel: '2024 Mercedes-Benz AMG G 63 (4x4²)',
        vehicleSize: VehicleSize.truckVan,
        package: samplePackage,
        locationType: ServiceLocationType.mobile,
        clientAddress: 'Apt #402-B "The Oaks", 1000 N. Loop 1 #B\nAustin, TX',
        scheduledDate: DateTime(2026, 10, 31),
        scheduledTimeSlot: '1:00 PM - 4:00 PM',
        totalPrice: 652.50,
        depositAmount: 200.0,
        clientNotes: 'Please ring unit 402 & do not honk. Dog is sensitive to noise! 🐶',
      );

      final jsonString = jsonEncode(booking.toJson());
      final restored = BookingAppointment.fromJson(jsonDecode(jsonString));

      expect(restored.clientName, 'O\'Connor & Sons, LLC');
      expect(restored.clientAddress, contains('Apt #402-B "The Oaks"'));
      expect(restored.clientNotes, contains('🐶'));
    });
  });

  // =========================================================================
  // 7. DetailJob Model Serialization & Deserialization
  // =========================================================================
  group('DetailJob JSON Serialization & Deserialization', () {
    const authorProfile = UserProfile(
      id: 'usr_author_01',
      username: 'masterdetailer',
      displayName: 'Marcus Sterling',
      businessName: 'Sterling Craft Detailing',
      avatarUrl: 'https://example.com/avatar.jpg',
      location: 'Dallas, TX',
      bio: 'Master certified IDA paint correction specialist.',
    );

    test('7.1 Roundtrip: Full complex job with stages, gauge points, zones, comments', () {
      final job = DetailJob(
        id: 'job_gt3_ceramic_01',
        author: authorProfile,
        createdAt: DateTime(2026, 9, 20, 11, 0),
        title: '2023 GT3 RS Track Car Revived: 2-Stage Cut + 9H Quartz',
        description: 'Heavy track marring and rubber streaks removed. 88% defect removal achieved.',
        vehicleYear: 2023,
        vehicleMake: 'Porsche',
        vehicleModel: '911 GT3 RS',
        paintColorName: 'Shark Blue',
        paintCode: 'D5C',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 135.0,
        finalPaintThicknessMicrons: 131.5,
        paintGaugePoints: const [
          PaintGaugePoint(id: 'hood', label: 'Hood Center', initialMicrons: 138.0, postPolishMicrons: 134.0),
          PaintGaugePoint(id: 'roof', label: 'Carbon Roof', initialMicrons: 140.0, postPolishMicrons: 137.0),
          PaintGaugePoint(id: 'trunk', label: 'Engine Deck', initialMicrons: 132.0, postPolishMicrons: 129.0),
        ],
        defectSeverity: 3,
        defectStage: DefectStage.stage3,
        correctionPercentage: 90,
        serviceType: 'Multi-Stage Paint Correction & Ceramic',
        recipeStages: const [
          RecipeStage(
            stageName: 'Chemical Decon',
            chemical: 'CarPro IronX',
            technique: 'Foam & dwell 5 min',
          ),
          RecipeStage(
            stageName: 'Heavy Cut',
            chemical: 'Koch Chemie H9.02',
            pad: 'Microfiber Cut',
            technique: '4 passes @ speed 4.5',
          ),
        ],
        beforeImageUrl: 'https://images.unsplash.com/before.jpg',
        afterImageUrl: 'https://images.unsplash.com/after.jpg',
        defectBadge: 'Stage 3: Severe RIDS',
        beforePhotos: const ['https://images.unsplash.com/before1.jpg', 'https://images.unsplash.com/before2.jpg'],
        afterPhotos: const ['https://images.unsplash.com/after1.jpg', 'https://images.unsplash.com/after2.jpg'],
        mediaZones: const [
          JobMediaZone(
            id: 'zone_hood',
            zoneName: 'Front Hood',
            beforeImageUrl: 'https://images.unsplash.com/b_hood.jpg',
            afterImageUrl: 'https://images.unsplash.com/a_hood.jpg',
            defectBadge: 'Heavy RIDS',
            initialMicrons: 138.0,
            finalMicrons: 134.0,
          ),
        ],
        durationHours: 14.5,
        quotedPrice: 1650.0,
        likesCount: 38,
        isLiked: true,
        savesCount: 14,
        isSaved: true,
        comments: [
          JobComment(
            id: 'cmt_001',
            authorName: 'David K.',
            authorAvatar: 'https://example.com/david.jpg',
            text: 'Incredible clarity on that Shark Blue! What pad did you finish with?',
            createdAt: DateTime(2026, 9, 21, 8, 30),
            isVerifiedPro: true,
          ),
          JobComment(
            id: 'cmt_002',
            authorName: 'Marcus Sterling',
            authorAvatar: 'https://example.com/avatar.jpg',
            text: 'Used a Rupes Yellow Fine foam pad with Sonax Perfect Finish.',
            createdAt: DateTime(2026, 9, 21, 9, 15),
            isVerifiedPro: true,
            parentId: 'cmt_001',
            replyToAuthorName: 'David K.',
          ),
        ],
      );

      final json = job.toJson();
      final restored = DetailJob.fromJson(json);

      expect(restored.id, 'job_gt3_ceramic_01');
      expect(restored.author.displayName, 'Marcus Sterling');
      expect(restored.vehicleYear, 2023);
      expect(restored.vehicleMake, 'Porsche');
      expect(restored.vehicleModel, '911 GT3 RS');
      expect(restored.paintColorName, 'Shark Blue');
      expect(restored.paintHardness, PaintHardness.hard);
      expect(restored.defectStage, DefectStage.stage3);
      expect(restored.defectSeverity, 3);
      expect(restored.correctionPercentage, 90);
      expect(restored.recipeStages.length, 2);
      expect(restored.paintGaugePoints.length, 3);
      expect(restored.beforePhotos.length, 2);
      expect(restored.afterPhotos.length, 2);
      expect(restored.mediaZones.length, 1);
      expect(restored.durationHours, 14.5);
      expect(restored.quotedPrice, 1650.0);
      expect(restored.likesCount, 38);
      expect(restored.isLiked, isTrue);
      expect(restored.savesCount, 14);
      expect(restored.isSaved, isTrue);
      expect(restored.comments.length, 2);
      expect(restored.comments[1].parentId, 'cmt_001');
      expect(restored.comments[1].replyToAuthorName, 'David K.');
    });

    test('7.2 Computed Getters: effectiveMediaZones, allBeforePhotos, micronsRemoved', () {
      final job = DetailJob(
        id: 'job_computed_01',
        author: authorProfile,
        createdAt: DateTime.now(),
        title: 'Computed Getters Test',
        description: 'Testing fallback photo getters and calculations',
        vehicleYear: 2024,
        vehicleMake: 'BMW',
        vehicleModel: 'M2',
        paintColorName: 'Zandvoort Blue',
        paintCode: 'C6E',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 125.0,
        finalPaintThicknessMicrons: 121.0,
        defectSeverity: 2,
        serviceType: '1-Stage Enhancement',
        recipeStages: const [],
        beforeImageUrl: 'https://example.com/hero_before.jpg',
        afterImageUrl: 'https://example.com/hero_after.jpg',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
      );

      // Hero photo fallbacks
      expect(job.allBeforePhotos, ['https://example.com/hero_before.jpg']);
      expect(job.allAfterPhotos, ['https://example.com/hero_after.jpg']);

      // Effective media zone created automatically from hero before/after
      expect(job.effectiveMediaZones.length, 1);
      expect(job.effectiveMediaZones.first.id, 'hero_zone');
      expect(job.effectiveMediaZones.first.beforeImageUrl, 'https://example.com/hero_before.jpg');

      // Microns removed calculation
      expect(job.micronsRemoved, closeTo(4.0, 0.1));
      expect(job.vehicleFullName, '2024 BMW M2');
      expect(job.detailerId, 'usr_author_01');
    });

    test('7.3 DefectStage: Enum mapping and string resolution backwards compatibility', () {
      expect(DefectStage.fromString('stage1'), DefectStage.stage1);
      expect(DefectStage.fromString('stage2'), DefectStage.stage2);
      expect(DefectStage.fromString('stage3'), DefectStage.stage3);
      expect(DefectStage.fromString('stage4'), DefectStage.stage4);
      expect(DefectStage.fromStageNumber(1), DefectStage.stage1);
      expect(DefectStage.fromStageNumber(2), DefectStage.stage2);
      expect(DefectStage.fromStageNumber(3), DefectStage.stage3);
      expect(DefectStage.fromStageNumber(4), DefectStage.stage4);

      // Backward compatibility from defectSeverity in JSON without defectStage field
      final legacyJson = {
        'id': 'job_legacy_01',
        'defectSeverity': 3,
        'title': 'Legacy Job',
        'author': authorProfile.toJson(),
      };
      final restored = DetailJob.fromJson(legacyJson);
      expect(restored.defectStage, DefectStage.stage3);
    });

    test('7.4 PaintHardness: Enum values roundtrip and fallback to medium', () {
      for (final hardness in PaintHardness.values) {
        final job = DetailJob(
          id: 'job_h_${hardness.name}',
          author: authorProfile,
          createdAt: DateTime.now(),
          title: 'Hardness Test',
          description: '',
          vehicleYear: 2022,
          vehicleMake: 'Car',
          vehicleModel: 'Model',
          paintColorName: 'Black',
          paintCode: '040',
          paintHardness: hardness,
          initialPaintThicknessMicrons: 120.0,
          finalPaintThicknessMicrons: 118.0,
          defectSeverity: 2,
          serviceType: 'Test',
          recipeStages: const [],
          beforeImageUrl: '',
          afterImageUrl: '',
        );
        final restored = DetailJob.fromJson(job.toJson());
        expect(restored.paintHardness, hardness);
      }

      final unknownJson = {
        'id': 'job_unknown_hardness',
        'paintHardness': 'EXTRA_DIAMOND_HARD',
      };
      final fallbackRestored = DetailJob.fromJson(unknownJson);
      expect(fallbackRestored.paintHardness, PaintHardness.medium);
    });

    test('7.5 Microns Removed Calculation: Paint gauge point averages clamp correctly', () {
      const points = [
        PaintGaugePoint(id: 'p1', label: 'Hood', initialMicrons: 140.0, postPolishMicrons: 136.0),
        PaintGaugePoint(id: 'p2', label: 'Roof', initialMicrons: 130.0, postPolishMicrons: 128.0),
      ];

      final job = DetailJob(
        id: 'job_gauge_calc',
        author: authorProfile,
        createdAt: DateTime.now(),
        title: 'Gauge Calc',
        description: '',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: 'Cayman',
        paintColorName: 'White',
        paintCode: '0Q',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 135.0,
        finalPaintThicknessMicrons: 132.0,
        paintGaugePoints: points,
        defectSeverity: 2,
        serviceType: 'Correction',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
      );

      expect(job.overallInitialAverage, 135.0);
      expect(job.overallPostPolishAverage, 132.0);
      expect(job.micronsRemoved, 3.0);
    });

    test('7.6 JobComment: Threaded reply comment serialization', () {
      final parentComment = JobComment(
        id: 'cmt_parent',
        authorName: 'Sarah Jenkins',
        authorAvatar: 'https://example.com/sarah.jpg',
        text: 'Did you use a rotary or DA on the front bumper?',
        createdAt: DateTime(2026, 9, 22, 10, 0),
        isVerifiedPro: false,
      );

      final replyComment = JobComment(
        id: 'cmt_reply',
        authorName: 'Marcus Sterling',
        authorAvatar: 'https://example.com/marcus.jpg',
        text: 'Used a 3-inch DA (Flex PXE 80) for bumper curves.',
        createdAt: DateTime(2026, 9, 22, 10, 30),
        isVerifiedPro: true,
        parentId: 'cmt_parent',
        replyToAuthorName: 'Sarah Jenkins',
      );

      final restoredParent = JobComment.fromJson(parentComment.toJson());
      final restoredReply = JobComment.fromJson(replyComment.toJson());

      expect(restoredParent.id, 'cmt_parent');
      expect(restoredParent.parentId, isNull);
      expect(restoredParent.replyToAuthorName, isNull);

      expect(restoredReply.id, 'cmt_reply');
      expect(restoredReply.parentId, 'cmt_parent');
      expect(restoredReply.replyToAuthorName, 'Sarah Jenkins');
      expect(restoredReply.isVerifiedPro, isTrue);
    });

    test('7.7 Adversarial: Integer duration and price in JSON parses cleanly to double', () {
      final json = {
        'id': 'job_num_coerce',
        'title': 'Int Duration Test',
        'durationHours': 10, // int
        'quotedPrice': 1200, // int
        'defectSeverity': 2,
      };

      final restored = DetailJob.fromJson(json);
      expect(restored.durationHours, 10.0);
      expect(restored.durationHours, isA<double>());
      expect(restored.quotedPrice, 1200.0);
      expect(restored.quotedPrice, isA<double>());
    });
  });

  // =========================================================================
  // 8. TestHarness & Refresh Simulation Core Verification
  // =========================================================================
  group('TestHarness Session & Browser Refresh Verification', () {
    test('8.1 createSession initializes clean repository instance with initial data', () async {
      final repo = await createSession(isLoggedIn: false);

      expect(repo.isInitialized, isTrue);
      expect(repo.isGuestMode, isTrue);
      expect(repo.jobs, isA<List<DetailJob>>());
      expect(repo.publicDetailers, isA<List<UserProfile>>());
    });

    test('8.2 createSession preloads custom UserProfile in host mode', () async {
      const customUser = UserProfile(
        id: 'usr_custom_host_99',
        username: 'austindetailer',
        displayName: 'Austin Detail Lab',
        businessName: 'Austin Detail Lab LLC',
        avatarUrl: 'https://example.com/adl.jpg',
        location: 'Austin, Texas',
        bio: 'Premier exotic vehicle paint correction.',
        role: UserRole.detailer,
        isVerifiedHost: true,
      );

      final repo = await createSession(
        isLoggedIn: true,
        currentUser: customUser,
      );

      expect(repo.isInitialized, isTrue);
      expect(repo.isLoggedIn, isTrue);
      expect(repo.currentUser.id, 'usr_custom_host_99');
      expect(repo.currentUser.displayName, 'Austin Detail Lab');
    });

    test('8.3 simulateBrowserRefresh preserves mock local storage changes across reload', () async {
      final initialRepo = await createSession(isLoggedIn: true);

      // Save a new custom booking into repository / local storage
      const customPackage = ServicePackage(
        id: 'pkg_refresh_test',
        title: 'Refresh Verification Package',
        description: 'Test package to ensure persistence across browser reload.',
        basePrice: 399.0,
        estimatedDuration: '3 hrs',
        includes: ['Step A', 'Step B'],
      );

      final newBooking = BookingAppointment(
        id: 'bk_refresh_test_01',
        detailerId: initialRepo.currentUser.id,
        detailerName: initialRepo.currentUser.displayName,
        detailerBusinessName: initialRepo.currentUser.businessName,
        detailerAvatar: '',
        clientName: 'Test Client',
        clientPhone: '555-9999',
        clientEmail: 'test@refresh.com',
        vehicleYearMakeModel: '2024 Porsche 911',
        vehicleSize: VehicleSize.coupeSedan,
        package: customPackage,
        locationType: ServiceLocationType.shop,
        clientAddress: '',
        scheduledDate: DateTime(2026, 11, 15),
        scheduledTimeSlot: '9:00 AM - 12:00 PM',
        totalPrice: 399.0,
        depositAmount: 100.0,
        status: BookingStatus.confirmed,
      );

      initialRepo.addBooking(newBooking);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(initialRepo.bookings.any((b) => b.id == 'bk_refresh_test_01'), isTrue);

      // Simulate browser refresh (Cmd+R / F5)
      final refreshedRepo = await simulateBrowserRefresh(initialRepo);

      expect(refreshedRepo.isInitialized, isTrue);
      final persistedBookings = await LocalStorageService.loadBookings();
      expect(persistedBookings, isNotNull);
      expect(persistedBookings!.any((b) => b.id == 'bk_refresh_test_01'), isTrue);
      expect(refreshedRepo.bookings.any((b) => b.id == 'bk_refresh_test_01'), isTrue);
    });
  });
}
