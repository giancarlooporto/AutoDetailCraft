import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/inventory_item.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import 'package:detail_craft/widgets/inventory_item_editor_dialog.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3: Inventory & Chemical Fill Status Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1: Add inventory items (Hardware, Chemical, Recipe) persists immediately to dedicated storage and survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final hardware = InventoryItem(
        id: 'inv_hw_custom_polisher',
        name: 'Flex XFE 7-15 150',
        category: InventoryCategory.hardware,
        brand: 'Flex',
        subCategory: 'Dual Action Polisher',
        status: 'Optimal',
        location: 'Bay 1 Cabinet A',
        specs: const {'Stroke': '15mm', 'Backing Plate': '5 inch'},
      );

      final chemical = InventoryItem(
        id: 'inv_chem_custom_compound',
        name: 'Menzerna 400 Heavy Cut',
        category: InventoryCategory.chemicals,
        brand: 'Menzerna',
        subCategory: 'Heavy Cut Compound',
        status: 'Full',
        location: 'Chemical Rack 2',
        dilutionSpecs: 'Use neat with wool pad',
      );

      final recipe = InventoryItem(
        id: 'inv_rec_custom_rotary',
        name: 'Super Heavy Wool Rotary Cut',
        category: InventoryCategory.recipe,
        brand: '',
        subCategory: 'Recipe',
        status: 'Active',
        location: '',
        recipeStages: const [
          RecipeStage(
            stageName: 'Stage 1: Wool Heavy Cut',
            machine: 'Flex PE 14-2 150 Rotary',
            chemical: 'Menzerna 400',
            pad: 'Twisted Wool 6 inch',
            technique: '1200 RPM 3 crosshatch passes',
            dilution: 'Neat',
          ),
          RecipeStage(
            stageName: 'Stage 2: DA Refine',
            machine: 'Rupes LHR15 Mark III',
            chemical: 'Sonax Perfect Finish',
            pad: 'Yellow Foam Pad',
            technique: 'Speed 4 4 passes',
            dilution: 'Neat',
          ),
        ],
      );

      repo1.addInventoryItem(hardware);
      repo1.addInventoryItem(chemical);
      repo1.addInventoryItem(recipe);

      // Verify immediate dedicated storage persistence
      final savedItems = await LocalStorageService.loadInventoryItems();
      expect(savedItems, isNotNull);
      expect(savedItems!.any((i) => i.id == 'inv_hw_custom_polisher'), isTrue);
      expect(savedItems.any((i) => i.id == 'inv_chem_custom_compound'), isTrue);
      expect(savedItems.any((i) => i.id == 'inv_rec_custom_rotary'), isTrue);

      final savedChem = savedItems.firstWhere((i) => i.id == 'inv_chem_custom_compound');
      expect(savedChem.fillStatus, equals('Full'));
      expect(savedChem.status, equals('Full'));
      expect(savedChem.dilutionSpecs, equals('Use neat with wool pad'));

      final savedRec = savedItems.firstWhere((i) => i.id == 'inv_rec_custom_rotary');
      expect(savedRec.recipeStages.length, equals(2));
      expect(savedRec.recipeStages[0].dilution, equals('Neat'));

      // Simulate browser refresh (Cmd+R)
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);

      expect(repo2.inventoryItems.any((i) => i.id == 'inv_hw_custom_polisher'), isTrue);
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_chem_custom_compound'), isTrue);
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_rec_custom_rotary'), isTrue);

      final reloadedChem = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_custom_compound');
      expect(reloadedChem.fillStatus, equals('Full'));
      expect(reloadedChem.status, equals('Full'));
    });

    test('T2: updateChemicalFillStatus toggles fill status (Full -> Half -> Empty) and survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final chemical = InventoryItem(
        id: 'inv_chem_fill_toggle_test',
        name: 'Gyeon Q2 CanCoat EVO',
        category: InventoryCategory.chemicals,
        brand: 'Gyeon',
        subCategory: 'Ceramic Sealant',
        status: 'Full',
      );
      repo1.addInventoryItem(chemical);
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test').fillStatus, equals('Full'));

      // Toggle to Half
      repo1.updateChemicalFillStatus('inv_chem_fill_toggle_test', 'Half');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test').fillStatus, equals('Half'));
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test').status, equals('Half'));

      // Verify dedicated storage
      var saved = await LocalStorageService.loadInventoryItems();
      expect(saved!.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test').fillStatus, equals('Half'));

      // Toggle to Empty
      repo1.updateChemicalFillStatus('inv_chem_fill_toggle_test', 'Empty');
      expect(repo1.inventoryItems.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test').fillStatus, equals('Empty'));

      // Simulate browser refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      final restored = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_chem_fill_toggle_test');
      expect(restored.fillStatus, equals('Empty'));
      expect(restored.status, equals('Empty'));
    });

    test('T3: Update inventory item metadata and recipe stages persists and survives reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final item = InventoryItem(
        id: 'inv_hw_update_test',
        name: 'Rupes iBrid Nano',
        category: InventoryCategory.hardware,
        brand: 'Rupes',
        subCategory: 'Micro Polisher',
        status: 'In Service',
        location: 'Bay 1 Cabinet',
        notes: 'Initial battery charge test',
      );
      repo1.addInventoryItem(item);

      final updated = item.copyWith(
        status: 'Optimal',
        location: 'Precision Tool Cart',
        notes: 'Equipped with 30mm rotary backing plate and extension shaft',
        specs: const {'Battery': 'Li-Ion 10.8V', 'Neck': 'Long Neck'},
      );
      repo1.updateInventoryItem(updated);

      // Simulate refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      final restored = repo2.inventoryItems.firstWhere((i) => i.id == 'inv_hw_update_test');
      expect(restored.status, equals('Optimal'));
      expect(restored.location, equals('Precision Tool Cart'));
      expect(restored.notes, equals('Equipped with 30mm rotary backing plate and extension shaft'));
      expect(restored.specs['Neck'], equals('Long Neck'));
    });

    test('T4: Remove inventory item updates dedicated storage and survives refresh', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final item = InventoryItem(
        id: 'inv_item_to_delete',
        name: 'Disposable Nitrile Gloves XL',
        category: InventoryCategory.hardware,
        brand: 'Adenna',
      );
      repo1.addInventoryItem(item);
      expect(repo1.inventoryItems.any((i) => i.id == 'inv_item_to_delete'), isTrue);

      repo1.removeInventoryItem('inv_item_to_delete');
      expect(repo1.inventoryItems.any((i) => i.id == 'inv_item_to_delete'), isFalse);

      final dedicated = await LocalStorageService.loadInventoryItems();
      expect(dedicated!.any((i) => i.id == 'inv_item_to_delete'), isFalse);

      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.inventoryItems.any((i) => i.id == 'inv_item_to_delete'), isFalse);
    });

    test('T5: Initial run initializes clean inventory and immediately seeds storage key', () async {
      // Clear all initial values
      SharedPreferences.setMockInitialValues({});

      final repo = JobRepository();
      await repo.init();

      expect(repo.inventoryItems, isEmpty);

      // Verify that step 2e immediately seeded adc_inventory_items_v1
      final prefs = await SharedPreferences.getInstance();
      final hasStored = prefs.containsKey('adc_inventory_items_v1');
      expect(hasStored, isTrue);

      final loaded = await LocalStorageService.loadInventoryItems();
      expect(loaded, isNotNull);
      expect(loaded!.length, equals(repo.inventoryItems.length));
    });

    testWidgets('T6: InventoryItemEditorDialog allows inputting chemical dilution specs', (WidgetTester tester) async {
      InventoryItem? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  InventoryItemEditorDialog.show(
                    ctx,
                    initialCategory: InventoryCategory.chemicals,
                    onSave: (item) => savedResult = item,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Dialog opens
      expect(find.text('Add New CHEMICALS'), findsOneWidget);

      // Enter Name
      await tester.enterText(find.widgetWithText(TextFormField, 'Chemical / Product Name *'), 'P&S Brake Buster');
      // Enter Brand
      await tester.enterText(find.widgetWithText(TextFormField, 'Brand / Manufacturer'), 'P&S');
      // Enter Dilution Specs
      await tester.enterText(find.widgetWithText(TextFormField, 'Dilution Specs / Instructions'), '1:5 for light cleaning, 1:1 in foam cannon');

      // Tap Save (Add to Inventory)
      await tester.tap(find.text('Add to Inventory'));
      await tester.pumpAndSettle();

      expect(savedResult, isNotNull);
      expect(savedResult!.name, equals('P&S Brake Buster'));
      expect(savedResult!.brand, equals('P&S'));
      expect(savedResult!.dilutionSpecs, equals('1:5 for light cleaning, 1:1 in foam cannon'));
      expect(savedResult!.fillStatus, equals('Full'));
    });
  });
}
