import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/calendar_availability_block.dart';
import 'package:detail_craft/models/team_member.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/services/job_repository.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3 Challenger 1: Rapid Inventory Mutations & Browser Reload', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('INV-STRESS-1: 10 items added, rapid chemical fill transitions (Full -> Half -> Low -> Empty), deletions, and browser refresh verify exact list identity, status values, and custom fields', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // Define 10 distinct items across Hardware (3), Chemicals (4), Recipes (3) with rich custom metadata
      final items = [
        // 1. Hardware: Rotary Polisher
        const InventoryItem(
          id: 'inv_hw_flex_rotary_901',
          name: 'Flex PE 14-2 150 Rotary Polisher',
          category: InventoryCategory.hardware,
          brand: 'Flex',
          subCategory: 'Rotary Polishers',
          specs: {'Motor': '1400W', 'Spindle': 'M14', 'RPM Range': '380-2100 RPM', 'Weight': '2.2kg'},
          maintenance: 'Inspect carbon brushes every 100 operating hours',
          location: 'Station 1 - Cabinet B',
          status: 'Optimal',
          notes: 'High-torque rotary for heavy defect correction on clear coats.',
        ),
        // 2. Chemical: Heavy Cut Compound
        const InventoryItem(
          id: 'inv_chem_heavy_cut_902',
          name: 'Koch Chemie Heavy Cut H9.02',
          category: InventoryCategory.chemicals,
          brand: 'Koch Chemie',
          subCategory: 'Compounds',
          status: 'Full',
          location: 'Chemical Bay Rack 1',
          dilutionSpecs: 'Apply 4 pea-sized drops neat to microfiber cutting pad',
          dilutionRatio: 'Neat',
          cureTimeOrFlashTime: 'None (wiped off immediately after cycle)',
          safetyNotes: 'Wear nitrile gloves, eye protection, and organic vapor respirator in enclosed spaces.',
        ),
        // 3. Recipe: 2-Stage German Clear Correction
        const InventoryItem(
          id: 'inv_rec_german_clear_903',
          name: 'Hard German Ceramic Clear 2-Stage Formula',
          category: InventoryCategory.recipe,
          brand: 'Detail Craft Labs',
          subCategory: 'Correction Recipes',
          status: 'Active',
          location: 'Lab Station Alpha',
          recipeStages: [
            RecipeStage(
              stageName: 'Stage 1: Heavy Compounding Cut',
              machine: 'Rupes LHR21 Mark III (21mm)',
              chemical: 'Koch Chemie H9.02',
              pad: 'CarPro Twisted Wool Pad 6 inch',
              technique: 'Speed 4.5, 4 crosshatch passes with moderate downward pressure',
              dilution: 'Neat',
            ),
            RecipeStage(
              stageName: 'Stage 2: Gloss Refining & Jewel Polish',
              machine: 'Rupes LHR15 Mark III (15mm)',
              chemical: 'Sonax Perfect Finish',
              pad: 'Lake Country Yellow Foam Pad',
              technique: 'Speed 3, 3 light passes to achieve swirl-free clarity',
              dilution: 'Neat',
            ),
          ],
        ),
        // 4. Chemical: Finishing Polish
        const InventoryItem(
          id: 'inv_chem_finish_polish_904',
          name: 'Sonax Profiline Perfect Finish 04-06',
          category: InventoryCategory.chemicals,
          brand: 'Sonax',
          subCategory: 'Finishing Polishes',
          status: 'Full',
          location: 'Chemical Bay Rack 1',
          dilutionSpecs: 'Use neat on medium or soft foam pads',
          dilutionRatio: 'Neat',
          cureTimeOrFlashTime: 'None',
          safetyNotes: 'Standard PPE required',
        ),
        // 5. Hardware: High-CRI LED Inspection Light
        const InventoryItem(
          id: 'inv_hw_scangrip_light_905',
          name: 'Scangrip Sunmatch 4 Handheld CRI+ Light',
          category: InventoryCategory.hardware,
          brand: 'Scangrip',
          subCategory: 'Inspection Lighting',
          specs: {'CRI': '96+ CRI+', 'CCT': '2500K-6500K 5-step', 'Lumens': '500lm', 'Battery': 'Li-ion 3.7V 2600mAh'},
          maintenance: 'Clean optical lens with lint-free microfiber; recharge after every shift',
          location: 'Inspection Station Mobile Cart',
          status: 'Calibrated',
        ),
        // 6. Chemical: Professional Ceramic Coating
        const InventoryItem(
          id: 'inv_chem_ceramic_pro_906',
          name: 'Gtechniq Crystal Serum Ultra (10H)',
          category: InventoryCategory.chemicals,
          brand: 'Gtechniq',
          subCategory: 'Ceramic Coatings',
          status: 'Full',
          location: 'Cleanroom Coating Vault',
          dilutionSpecs: 'Apply neat in crosshatch pattern using applicator block with suede cloth',
          dilutionRatio: 'Neat',
          cureTimeOrFlashTime: 'Flash: 1-2 min; Dry cure: 12h; Full hydrophobic chemical cure: 7 days',
          safetyNotes: 'MANDATORY: 3M organic vapor cartridge respirator and clean nitrile gloves.',
        ),
        // 7. Recipe: Leather Interior Rejuvenation
        const InventoryItem(
          id: 'inv_rec_leather_rejuv_907',
          name: 'Aniline & Nappa Leather Deep Hydration Protocol',
          category: InventoryCategory.recipe,
          brand: 'Colourlock Craft',
          subCategory: 'Interior Recipes',
          status: 'Active',
          location: 'Interior Station',
          recipeStages: [
            RecipeStage(
              stageName: 'Stage 1: Low-Moisture Steam Decontamination',
              machine: 'Optima Steamer XE Dry Vapor',
              chemical: 'Colourlock Mild Leather Cleaner',
              pad: 'Horsehair Brush',
              technique: 'Agitate foam in circular motion, wipe immediately with warm damp microfiber',
              dilution: '1:1 with distilled water',
            ),
            RecipeStage(
              stageName: 'Stage 2: Collagen Feeding & Matte UV Seal',
              machine: 'Manual Hand Application',
              chemical: 'Colourlock Leather Shield',
              pad: 'Soft Microfiber Applicator Pad',
              technique: 'Buff gently along seam lines, allow 2 hours dry time before client delivery',
              dilution: 'Neat',
            ),
          ],
        ),
        // 8. Chemical: Concentrated Alkaline All Purpose Cleaner
        const InventoryItem(
          id: 'inv_chem_apc_cleaner_908',
          name: 'Bilt Hamber Surfex HD All Purpose Cleaner',
          category: InventoryCategory.chemicals,
          brand: 'Bilt Hamber',
          subCategory: 'All Purpose Cleaners',
          status: 'Full',
          location: 'Wash Bay Chemical Dispenser',
          dilutionSpecs: '1:200 for paint decon foam, 1:20 for interior plastics, 1:5 for engine degreasing',
          dilutionRatio: '1:20',
          cureTimeOrFlashTime: 'Dwell: 3-5 minutes, do not allow to dry on hot paint or direct sun',
          safetyNotes: 'Alkaline pH ~12. Eye protection and gloves required.',
        ),
        // 9. Hardware: Ultrasonic Paint Depth Gauge
        const InventoryItem(
          id: 'inv_hw_paint_gauge_909',
          name: 'DeFelsko PosiTector 200 Advanced Paint Gauge',
          category: InventoryCategory.hardware,
          brand: 'DeFelsko',
          subCategory: 'Measurement Instruments',
          specs: {'Measurement Type': 'Non-destructive ultrasonic', 'Substrates': 'Steel, Aluminum, Carbon Fiber, Plastic', 'Range': '13 - 1000 microns'},
          maintenance: 'Zero-point calibration check against certified shims prior to each inspection',
          location: 'Chief Detailer Office Safe',
          status: 'Certified',
        ),
        // 10. Recipe: Hydrophobic Glass Ceramic Coating
        const InventoryItem(
          id: 'inv_rec_glass_ceramic_910',
          name: 'Windshield Hydrophobic Ceramic Barrier',
          category: InventoryCategory.recipe,
          brand: 'Gyeon Craft',
          subCategory: 'Glass Recipes',
          status: 'Active',
          location: 'Wash Bay Glass Station',
          recipeStages: [
            RecipeStage(
              stageName: 'Stage 1: Cerium Oxide Glass Polish',
              machine: 'Rupes LHR75E Mini (3 inch)',
              chemical: 'CarPro Ceriglass',
              pad: 'Rayon Glass Polishing Pad',
              technique: 'Moderate pressure to strip wiper haze and mineral staining',
              dilution: 'Neat with water mist',
            ),
          ],
        ),
      ];

      // Add all 10 items
      for (final item in items) {
        repo1.addInventoryItem(item);
      }

      // Verify all 10 are registered
      for (final item in items) {
        expect(repo1.inventoryItems.any((i) => i.id == item.id), isTrue);
      }

      // Rapidly mutate chemical fill levels repeatedly across Full -> Half -> Low -> Empty -> Full -> Low
      // Chemical 2: Full -> Half -> Low -> Empty -> Full -> Low
      repo1.updateChemicalFillStatus('inv_chem_heavy_cut_902', 'Half');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').fillStatus, equals('Half'));
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').status, equals('Half'));

      repo1.updateChemicalFillStatus('inv_chem_heavy_cut_902', 'Low');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').fillStatus, equals('Low'));

      repo1.updateChemicalFillStatus('inv_chem_heavy_cut_902', 'Empty');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').fillStatus, equals('Empty'));

      repo1.updateChemicalFillStatus('inv_chem_heavy_cut_902', 'Full'); // Restocked
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').fillStatus, equals('Full'));

      repo1.updateChemicalFillStatus('inv_chem_heavy_cut_902', 'Low'); // Depleted to Low
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902').fillStatus, equals('Low'));

      // Chemical 4: Full -> Half -> Low -> Empty
      repo1.updateChemicalFillStatus('inv_chem_finish_polish_904', 'Half');
      repo1.updateChemicalFillStatus('inv_chem_finish_polish_904', 'Low');
      repo1.updateChemicalFillStatus('inv_chem_finish_polish_904', 'Empty');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_finish_polish_904').fillStatus, equals('Empty'));

      // Chemical 6: Full -> Half -> Low
      repo1.updateChemicalFillStatus('inv_chem_ceramic_pro_906', 'Half');
      repo1.updateChemicalFillStatus('inv_chem_ceramic_pro_906', 'Low');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_ceramic_pro_906').fillStatus, equals('Low'));

      // Chemical 8: Full -> Empty -> Half (re-ordered half jug)
      repo1.updateChemicalFillStatus('inv_chem_apc_cleaner_908', 'Empty');
      repo1.updateChemicalFillStatus('inv_chem_apc_cleaner_908', 'Half');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_apc_cleaner_908').fillStatus, equals('Half'));

      // Delete 3 items (1 hardware, 1 chemical, 1 recipe)
      // Delete Item 1 (Hardware Rotary)
      repo1.removeInventoryItem('inv_hw_flex_rotary_901');
      // Delete Item 4 (Chemical Finish Polish)
      repo1.removeInventoryItem('inv_chem_finish_polish_904');
      // Delete Item 7 (Recipe Leather Rejuvenation)
      repo1.removeInventoryItem('inv_rec_leather_rejuv_907');

      // Verify immediate state in repo1
      expect(repo1.inventoryItems.any((i) => i.id == 'inv_hw_flex_rotary_901'), isFalse);
      expect(repo1.inventoryItems.any((i) => i.id == 'inv_chem_finish_polish_904'), isFalse);
      expect(repo1.inventoryItems.any((i) => i.id == 'inv_rec_leather_rejuv_907'), isFalse);

      // Verify the 7 surviving items exist
      final survivingIds = [
        'inv_chem_heavy_cut_902',
        'inv_rec_german_clear_903',
        'inv_hw_scangrip_light_905',
        'inv_chem_ceramic_pro_906',
        'inv_chem_apc_cleaner_908',
        'inv_hw_paint_gauge_909',
        'inv_rec_glass_ceramic_910',
      ];
      for (final id in survivingIds) {
        expect(repo1.inventoryItems.any((i) => i.id == id), isTrue, reason: '$id must be present in repo1');
      }

      // Simulate browser refresh using explicit syntax:
      // final repo2 = JobRepository(); await repo2.init();
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      // Verify exact list identity in repo2:
      // 1. Deleted items must NOT be present
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_hw_flex_rotary_901'), isFalse, reason: 'Deleted hardware polisher must not reappear after browser refresh');
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_chem_finish_polish_904'), isFalse, reason: 'Deleted finish polish chemical must not reappear after browser refresh');
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_rec_leather_rejuv_907'), isFalse, reason: 'Deleted leather recipe must not reappear after browser refresh');

      // 2. All 7 surviving items must be present
      for (final id in survivingIds) {
        expect(repo2.inventoryItems.any((i) => i.id == id), isTrue, reason: '$id must survive browser refresh in repo2');
      }

      // 3. Verify status and fillStatus values survived reload accurately
      final reloadedChem2 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_heavy_cut_902');
      expect(reloadedChem2.fillStatus, equals('Low'));
      expect(reloadedChem2.status, equals('Low'));
      expect(reloadedChem2.dilutionSpecs, equals('Apply 4 pea-sized drops neat to microfiber cutting pad'));
      expect(reloadedChem2.dilutionRatio, equals('Neat'));
      expect(reloadedChem2.safetyNotes, equals('Wear nitrile gloves, eye protection, and organic vapor respirator in enclosed spaces.'));

      final reloadedChem6 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_ceramic_pro_906');
      expect(reloadedChem6.fillStatus, equals('Low'));
      expect(reloadedChem6.status, equals('Low'));
      expect(reloadedChem6.cureTimeOrFlashTime, equals('Flash: 1-2 min; Dry cure: 12h; Full hydrophobic chemical cure: 7 days'));

      final reloadedChem8 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_apc_cleaner_908');
      expect(reloadedChem8.fillStatus, equals('Half'));
      expect(reloadedChem8.status, equals('Half'));
      expect(reloadedChem8.dilutionRatio, equals('1:20'));
      expect(reloadedChem8.dilutionSpecs, equals('1:200 for paint decon foam, 1:20 for interior plastics, 1:5 for engine degreasing'));

      // 4. Verify custom fields on Hardware & Recipes survived reload
      final reloadedHw5 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_hw_scangrip_light_905');
      expect(reloadedHw5.specs['CRI'], equals('96+ CRI+'));
      expect(reloadedHw5.specs['Lumens'], equals('500lm'));
      expect(reloadedHw5.maintenance, contains('Clean optical lens'));
      expect(reloadedHw5.status, equals('Calibrated'));

      final reloadedHw9 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_hw_paint_gauge_909');
      expect(reloadedHw9.specs['Measurement Type'], equals('Non-destructive ultrasonic'));
      expect(reloadedHw9.specs['Range'], equals('13 - 1000 microns'));
      expect(reloadedHw9.maintenance, equals('Zero-point calibration check against certified shims prior to each inspection'));

      final reloadedRec3 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_rec_german_clear_903');
      expect(reloadedRec3.recipeStages.length, equals(2));
      expect(reloadedRec3.recipeStages[0].stageName, equals('Stage 1: Heavy Compounding Cut'));
      expect(reloadedRec3.recipeStages[0].pad, equals('CarPro Twisted Wool Pad 6 inch'));
      expect(reloadedRec3.recipeStages[1].stageName, equals('Stage 2: Gloss Refining & Jewel Polish'));

      final reloadedRec10 = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_rec_glass_ceramic_910');
      expect(reloadedRec10.recipeStages.length, equals(1));
      expect(reloadedRec10.recipeStages[0].chemical, equals('CarPro Ceriglass'));

      repo2.dispose();
    });

    test('INV-STRESS-2: Rapid continuous status updates and unicode custom fields survive browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      const complexItem = InventoryItem(
        id: 'inv_chem_unicode_nano_polish',
        name: 'Nano-Clear™ Ultra Coat (日本制 / Céramique)',
        category: InventoryCategory.chemicals,
        brand: 'Kamikaze Collection 神風',
        subCategory: 'Hybrid Coating',
        status: 'Full',
        specs: {'Density': '1.02 g/cm³', 'Refractive Index': 'η = 1.485'},
        dilutionSpecs: 'Neat — 3滴 per 40cm × 40cm section',
        dilutionRatio: '1:0',
        safetyNotes: '⚠️ Keep away from open flames. Flash point > 65°C.',
        notes: 'Premium Japanese coating with fluorocarbon polymers.',
      );

      repo1.addInventoryItem(complexItem);

      // Perform 10 rapid alternating fill status cycles
      final cycle = ['Half', 'Low', 'Empty', 'Full', 'Half', 'Low', 'Empty', 'Full', 'Half', 'Low'];
      for (final s in cycle) {
        repo1.updateChemicalFillStatus('inv_chem_unicode_nano_polish', s);
      }

      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_unicode_nano_polish').fillStatus, equals('Low'));
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_unicode_nano_polish').status, equals('Low'));

      // Reload
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      final reloaded = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_unicode_nano_polish');
      expect(reloaded.fillStatus, equals('Low'));
      expect(reloaded.status, equals('Low'));
      expect(reloaded.name, equals('Nano-Clear™ Ultra Coat (日本制 / Céramique)'));
      expect(reloaded.brand, equals('Kamikaze Collection 神風'));
      expect(reloaded.specs['Refractive Index'], equals('η = 1.485'));
      expect(reloaded.dilutionSpecs, equals('Neat — 3滴 per 40cm × 40cm section'));
      expect(reloaded.safetyNotes, contains('⚠️ Keep away from open flames'));

      repo2.dispose();
    });
  });

  group('Milestone M3 Challenger 1: Multi-Tech Calendar Stress & Schedule Isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CAL-STRESS-1: Multi-specialist setup with distinct schedules, concurrent full & partial blocks on same date, zero cross-impact during add/remove/toggle, and browser reload survival', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // 1. Set up multiple specialists with distinct schedules
      // Tech A (Carlos - Paint Specialist): On duty Tue-Sat (8am-5pm), recurring off Sun-Mon
      final carlosSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '08:00 AM', closeTime: '05:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      // Tech B (Elena - Interior Specialist): On duty Wed-Sun (9am-6pm), recurring off Mon-Tue
      final elenaSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: true, openTime: '09:00 AM', closeTime: '06:00 PM'),
      ];

      // Tech C (Marcus - Tint & PPF Lead): On duty Mon-Fri (7am-3pm), recurring off Sat-Sun
      final marcusSchedule = [
        const DayBusinessHours(weekday: DateTime.monday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: DateTime.tuesday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: DateTime.wednesday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: DateTime.thursday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: DateTime.friday, isOpen: true, openTime: '07:00 AM', closeTime: '03:00 PM'),
        const DayBusinessHours(weekday: DateTime.saturday, isOpen: false),
        const DayBusinessHours(weekday: DateTime.sunday, isOpen: false),
      ];

      repo1.addTeamMember(TeamMember(
        id: 'tech_carlos',
        name: 'Carlos Mendoza',
        roleTitle: 'Paint Specialist',
        avatarUrl: '',
        customWeeklySchedule: carlosSchedule,
      ));

      repo1.addTeamMember(TeamMember(
        id: 'tech_elena',
        name: 'Elena Rostova',
        roleTitle: 'Interior Specialist',
        avatarUrl: '',
        customWeeklySchedule: elenaSchedule,
      ));

      repo1.addTeamMember(TeamMember(
        id: 'tech_marcus',
        name: 'Marcus Vance',
        roleTitle: 'Tint & PPF Lead',
        avatarUrl: '',
        customWeeklySchedule: marcusSchedule,
      ));

      // Choose a Friday (e.g. Nov 13, 2026): All 3 techs + founder are on duty
      final stressDate = DateTime(2026, 11, 13);
      expect(stressDate.weekday, equals(DateTime.friday));

      // Verify baseline availability: all 3 specialists are on duty
      expect(repo1.isMemberOnDutyOnDate('tech_carlos', stressDate), isTrue);
      expect(repo1.isMemberOnDutyOnDate('tech_elena', stressDate), isTrue);
      expect(repo1.isMemberOnDutyOnDate('tech_marcus', stressDate), isTrue);

      final baselineStatus = repo1.getSlotStaffingStatus(stressDate, '9:00 AM - 12:00 PM');
      expect(baselineStatus.onDutyCount, equals(4), reason: 'Founder + Carlos + Elena + Marcus');
      expect(baselineStatus.isBlocked, isFalse);
      expect(baselineStatus.availableCapacity, equals(4));

      // 2. Add full-day block for Tech A (Carlos) and partial-day block for Tech B (Elena) on SAME date
      // Carlos: Full-day block (Offsite Training)
      final blockCarlosFull = CalendarAvailabilityBlock(
        id: 'block_carlos_full_day',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tech_carlos',
        date: stressDate,
        isAllDay: true,
        reason: 'Sema Show Offsite Training',
        createdAt: DateTime.now(),
      );
      repo1.addAvailabilityBlock(blockCarlosFull);

      // Elena: Partial-day block (Blocked for 9:00 AM - 12:00 PM slot for Dentist appointment)
      final blockElenaPartial = CalendarAvailabilityBlock(
        id: 'block_elena_partial_morning',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tech_elena',
        date: stressDate,
        isAllDay: false,
        blockedSlots: ['9:00 AM - 12:00 PM'],
        reason: 'Medical Appointment Morning',
        createdAt: DateTime.now(),
      );
      repo1.addAvailabilityBlock(blockElenaPartial);

      // Verify coexistence on same date
      expect(repo1.availabilityBlocks.length, equals(2));
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_carlos'), isTrue);
      expect(repo1.isMemberOnDutyOnDate('tech_carlos', stressDate), isFalse);

      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_elena'), isFalse, reason: 'Elena is only partially blocked, not all day');
      expect(repo1.isMemberOnDutyOnDate('tech_elena', stressDate), isTrue, reason: 'Elena is on duty for the day as a whole');
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_elena'), isTrue);
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_elena'), isFalse);

      // Tech C (Marcus) must be completely unaffected
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_marcus'), isFalse);
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_marcus'), isFalse);

      // Verify staffing breakdown across slots
      final morningStaff = repo1.getSlotStaffingStatus(stressDate, '9:00 AM - 12:00 PM');
      // In morning: Carlos off (all-day block), Elena off (partial slot block). Founder + Marcus on duty = 2
      expect(morningStaff.onDutyCount, equals(2));
      expect(morningStaff.onDutyMemberIds, containsAll(['founder', 'tech_marcus']));
      expect(morningStaff.offMemberIds, containsAll(['tech_carlos', 'tech_elena']));
      expect(morningStaff.isBlocked, isFalse);

      final afternoonStaff = repo1.getSlotStaffingStatus(stressDate, '1:00 PM - 4:00 PM');
      // In afternoon: Carlos off (all-day block). Elena on duty. Founder + Marcus on duty = 3
      expect(afternoonStaff.onDutyCount, equals(3));
      expect(afternoonStaff.onDutyMemberIds, containsAll(['founder', 'tech_elena', 'tech_marcus']));
      expect(afternoonStaff.offMemberIds, contains('tech_carlos'));

      // 3. ADVERSARIAL MUTATION: Unblock Tech A (Carlos)
      // Removing Carlos's block MUST NOT delete or impact Tech B's (Elena's) partial block!
      repo1.removeAvailabilityBlock('block_carlos_full_day');

      // Verify Carlos is unblocked
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_carlos'), isFalse);
      expect(repo1.isMemberOnDutyOnDate('tech_carlos', stressDate), isTrue);

      // CRITICAL MULTI-TECH ISOLATION CHECK: Elena's block must remain strictly intact
      expect(repo1.availabilityBlocks.any((b) => b.id == 'block_elena_partial_morning'), isTrue, reason: 'Elena block must survive Carlos removal');
      final elenaBlockCheck = repo1.availabilityBlocks.firstWhere((b) => b.id == 'block_elena_partial_morning');
      expect(elenaBlockCheck.isAllDay, isFalse);
      expect(elenaBlockCheck.blockedSlots, contains('9:00 AM - 12:00 PM'));
      expect(elenaBlockCheck.teamMemberId, equals('tech_elena'));
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_elena'), isTrue);

      // Slot staffing check after unblocking Carlos:
      // Morning: Carlos now on duty + Founder + Marcus = 3. Elena still off.
      final morningStaffPostCarlosUnblock = repo1.getSlotStaffingStatus(stressDate, '9:00 AM - 12:00 PM');
      expect(morningStaffPostCarlosUnblock.onDutyCount, equals(3));
      expect(morningStaffPostCarlosUnblock.offMemberIds, contains('tech_elena'));
      expect(morningStaffPostCarlosUnblock.onDutyMemberIds, contains('tech_carlos'));

      // 4. ADVERSARIAL MUTATION: Add partial block for Tech A (Carlos) on an afternoon slot ('1:00 PM - 4:00 PM')
      // using toggleBlockSlot. Verify Elena's morning slot is untouched!
      repo1.toggleBlockSlot(stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_carlos', reason: 'Carlos afternoon spray booth maintenance');

      // Both Carlos and Elena have distinct partial blocks on the same date!
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_carlos'), isTrue);
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_carlos'), isFalse);

      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_elena'), isTrue);
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_elena'), isFalse);

      // Check slot staffing with staggered blocks:
      // Morning: Elena off, Carlos on duty -> 3 on duty
      expect(repo1.getSlotStaffingStatus(stressDate, '9:00 AM - 12:00 PM').onDutyCount, equals(3));
      // Afternoon: Carlos off, Elena on duty -> 3 on duty
      expect(repo1.getSlotStaffingStatus(stressDate, '1:00 PM - 4:00 PM').onDutyCount, equals(3));

      // 5. ADVERSARIAL MUTATION: Toggle Elena's morning slot off (unblock Elena)
      repo1.toggleBlockSlot(stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_elena');

      // Elena is now fully unblocked
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_elena'), isFalse);

      // CRITICAL CHECK: Carlos's afternoon block must remain intact!
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_carlos'), isTrue);

      // 6. ADVERSARIAL MUTATION: Now full-day block Elena via toggleBlockDay
      repo1.toggleBlockDay(stressDate, teamMemberId: 'tech_elena', reason: 'Elena unexpected emergency');
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_elena'), isTrue);

      // CRITICAL CHECK: Carlos's afternoon block must STILL be intact!
      expect(repo1.isSlotExplicitlyBlocked(repo1.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_carlos'), isTrue);

      // 7. SIMULATE BROWSER REFRESH (Cmd+R / F5)
      // final repo2 = JobRepository(); await repo2.init();
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      // Verify multi-tech specialists survived refresh
      expect(repo2.currentUser.teamMembers.length, equals(3));
      expect(repo2.currentUser.teamMembers.any((m) => m.id == 'tech_carlos'), isTrue);
      expect(repo2.currentUser.teamMembers.any((m) => m.id == 'tech_elena'), isTrue);
      expect(repo2.currentUser.teamMembers.any((m) => m.id == 'tech_marcus'), isTrue);

      // Verify surviving multi-tech blocks survived refresh
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, stressDate, teamMemberId: 'tech_elena'), isTrue, reason: 'Elena full day block must survive reload');
      expect(repo2.isSlotExplicitlyBlocked(repo2.currentUser.id, stressDate, '1:00 PM - 4:00 PM', teamMemberId: 'tech_carlos'), isTrue, reason: 'Carlos afternoon block must survive reload');
      expect(repo2.isSlotExplicitlyBlocked(repo2.currentUser.id, stressDate, '9:00 AM - 12:00 PM', teamMemberId: 'tech_carlos'), isFalse);

      // Check staffing status on reloaded repository
      // Slot 9:00 AM - 12:00 PM: Elena off (full-day block), Carlos on duty, Marcus on duty, Founder on duty = 3
      final reloadedMorningStaff = repo2.getSlotStaffingStatus(stressDate, '9:00 AM - 12:00 PM');
      expect(reloadedMorningStaff.onDutyCount, equals(3));
      expect(reloadedMorningStaff.offMemberIds, contains('tech_elena'));
      expect(reloadedMorningStaff.onDutyMemberIds, containsAll(['founder', 'tech_carlos', 'tech_marcus']));

      // Slot 1:00 PM - 4:00 PM: Elena off (full-day block), Carlos off (partial slot block). Founder + Marcus on duty = 2
      final reloadedAfternoonStaff = repo2.getSlotStaffingStatus(stressDate, '1:00 PM - 4:00 PM');
      expect(reloadedAfternoonStaff.onDutyCount, equals(2));
      expect(reloadedAfternoonStaff.offMemberIds, containsAll(['tech_carlos', 'tech_elena']));
      expect(reloadedAfternoonStaff.onDutyMemberIds, containsAll(['founder', 'tech_marcus']));

      repo2.dispose();
    });

    test('CAL-STRESS-2: Concurrent full-day blocks for Tech A and Tech B, unblocking Tech A leaves Tech B blocked, reload survival', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      final stressDate = DateTime(2026, 12, 4); // Friday

      repo1.addTeamMember(const TeamMember(id: 'tech_alpha', name: 'Alpha Specialist', roleTitle: 'Pro', avatarUrl: ''));
      repo1.addTeamMember(const TeamMember(id: 'tech_beta', name: 'Beta Specialist', roleTitle: 'Pro', avatarUrl: ''));

      // Add full-day blocks for both
      repo1.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_alpha_full',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tech_alpha',
        date: stressDate,
        isAllDay: true,
        reason: 'Alpha Conference',
        createdAt: DateTime.now(),
      ));

      repo1.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_beta_full',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tech_beta',
        date: stressDate,
        isAllDay: true,
        reason: 'Beta Sick Day',
        createdAt: DateTime.now(),
      ));

      expect(repo1.availabilityBlocks.length, equals(2));
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_alpha'), isTrue);
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_beta'), isTrue);

      // Unblock Alpha via toggleBlockDay
      repo1.toggleBlockDay(stressDate, teamMemberId: 'tech_alpha');

      // Alpha is now unblocked
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_alpha'), isFalse);

      // Beta MUST STILL BE BLOCKED
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, stressDate, teamMemberId: 'tech_beta'), isTrue);
      expect(repo1.availabilityBlocks.any((b) => b.teamMemberId == 'tech_beta'), isTrue);

      // Browser refresh
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, stressDate, teamMemberId: 'tech_alpha'), isFalse);
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, stressDate, teamMemberId: 'tech_beta'), isTrue);
      expect(repo2.availabilityBlocks.length, equals(1));
      expect(repo2.availabilityBlocks.first.teamMemberId, equals('tech_beta'));

      repo2.dispose();
    });

    test('CAL-STRESS-3: Studio-wide day block superimposed on multi-tech blocks preserves individual tech blocks when studio block is lifted', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);
      final targetDate = DateTime(2026, 12, 18);

      repo1.addTeamMember(const TeamMember(id: 'tech_x', name: 'Tech X', roleTitle: 'Specialist', avatarUrl: ''));
      repo1.addTeamMember(const TeamMember(id: 'tech_y', name: 'Tech Y', roleTitle: 'Specialist', avatarUrl: ''));

      // Tech X has an individual block on targetDate
      repo1.addAvailabilityBlock(CalendarAvailabilityBlock(
        id: 'block_tech_x_individual',
        detailerId: repo1.currentUser.id,
        teamMemberId: 'tech_x',
        date: targetDate,
        isAllDay: true,
        reason: 'Tech X vacation day',
        createdAt: DateTime.now(),
      ));

      // Entire studio is now blocked (e.g. Blizzard / shop closure)
      repo1.toggleBlockDay(targetDate, reason: 'Winter Blizzard Studio Closure');

      // Both studio and Tech X are blocked
      expect(repo1.isDateFullyBlocked(repo1.currentUser.id, targetDate), isTrue);

      // Studio re-opens (toggle studio block off)
      repo1.toggleBlockDay(targetDate);

      // Studio as a whole is no longer blocked
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate), isFalse);

      // But Tech X vacation block was NOT destroyed!
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate, teamMemberId: 'tech_x'), isTrue);
      expect(repo1.isDateExplicitlyBlocked(repo1.currentUser.id, targetDate, teamMemberId: 'tech_y'), isFalse);

      // Simulate refresh
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, targetDate, teamMemberId: 'tech_x'), isTrue);
      expect(repo2.isDateExplicitlyBlocked(repo2.currentUser.id, targetDate, teamMemberId: 'tech_y'), isFalse);

      repo2.dispose();
    });
  });
}
