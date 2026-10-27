import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/models/user_vehicle.dart';
import 'package:detail_craft/screens/public_studio_screen.dart';
import 'package:detail_craft/screens/booking_flow_screen.dart';
import 'package:detail_craft/screens/vehicle_editor_dialog.dart';
import 'package:detail_craft/screens/service_package_editor_dialog.dart';
import 'package:detail_craft/screens/detailer_workbench_view.dart';
import 'package:detail_craft/services/mock_data_service.dart';
import 'package:detail_craft/screens/feed_screen.dart';
import 'package:detail_craft/screens/job_detail_screen.dart';
import 'package:detail_craft/widgets/job_recipe_card.dart';
import '../core/mock_http_client.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserVehicle & VehicleBodyType Model Tests', () {
    test('Default vehicleType is Sedan and resolvedVehicleSize maps correctly', () {
      const vDefault = UserVehicle(
        id: 'v_default',
        make: 'Honda',
        model: 'Civic',
        year: 2022,
        colorName: 'Modern Steel',
        imageUrl: '',
      );
      expect(vDefault.vehicleType, equals(VehicleBodyType.sedan));
      expect(vDefault.resolvedVehicleSize, equals(VehicleSize.coupeSedan));

      const vCoupe = UserVehicle(
        id: 'v_coupe',
        make: 'Ford',
        model: 'Mustang',
        year: 2020,
        colorName: 'Race Red',
        imageUrl: '',
        vehicleType: VehicleBodyType.coupe,
      );
      expect(vCoupe.resolvedVehicleSize, equals(VehicleSize.coupeSedan));

      const vSuv = UserVehicle(
        id: 'v_suv',
        make: 'Tesla',
        model: 'Model Y',
        year: 2023,
        colorName: 'Pearl White',
        imageUrl: '',
        vehicleType: VehicleBodyType.suv,
      );
      expect(vSuv.resolvedVehicleSize, equals(VehicleSize.suvCrossover));

      const vTruck = UserVehicle(
        id: 'v_truck',
        make: 'Ford',
        model: 'F-150',
        year: 2021,
        colorName: 'Oxford White',
        imageUrl: '',
        vehicleType: VehicleBodyType.truck,
      );
      expect(vTruck.resolvedVehicleSize, equals(VehicleSize.truckVan));

      const vVan = UserVehicle(
        id: 'v_van',
        make: 'Toyota',
        model: 'Sienna',
        year: 2024,
        colorName: 'Celestial Silver',
        imageUrl: '',
        vehicleType: VehicleBodyType.minivan,
      );
      expect(vVan.resolvedVehicleSize, equals(VehicleSize.truckVan));
    });

    test('UserVehicle JSON roundtrip and backwards compatibility', () {
      final v = const UserVehicle(
        id: 'v_test',
        make: 'Porsche',
        model: 'Cayenne',
        year: 2024,
        colorName: 'Jet Black Metallic',
        imageUrl: '',
        vehicleType: VehicleBodyType.suv,
      );

      final json = v.toJson();
      expect(json['vehicleType'], equals(VehicleBodyType.suv));

      final restored = UserVehicle.fromJson(json);
      expect(restored.vehicleType, equals(VehicleBodyType.suv));

      // Test backwards-compatible key parsing: vehicle_type, bodyType, body_type
      final legacy1 = UserVehicle.fromJson({
        'id': 'leg_1',
        'make': 'Chevy',
        'model': 'Silverado',
        'year': 2021,
        'colorName': 'Summit White',
        'imageUrl': '',
        'vehicle_type': 'Truck',
      });
      expect(legacy1.vehicleType, equals(VehicleBodyType.truck));

      final legacy2 = UserVehicle.fromJson({
        'id': 'leg_2',
        'make': 'Toyota',
        'model': 'Sienna',
        'year': 2020,
        'colorName': 'Blizzard Pearl',
        'imageUrl': '',
        'body_type': 'Minivan / Van',
      });
      expect(legacy2.vehicleType, equals(VehicleBodyType.minivan));
    });

    test('VehicleBodyType helpers and icons return valid metadata', () {
      expect(VehicleBodyType.all.length, equals(5));
      expect(VehicleBodyType.getIcon(VehicleBodyType.coupe), isNotNull);
      expect(VehicleBodyType.getIcon(VehicleBodyType.suv), isNotNull);
      expect(VehicleBodyType.getIcon(VehicleBodyType.truck), isNotNull);
      expect(VehicleBodyType.toVehicleSize(VehicleBodyType.suv), equals(VehicleSize.suvCrossover));
      expect(VehicleBodyType.toVehicleSize(VehicleBodyType.truck), equals(VehicleSize.truckVan));
    });

    test('UserVehicle implements operator == and hashCode based on id for dropdown stability', () {
      const v1 = UserVehicle(
        id: 'v_equal_test',
        make: 'Porsche',
        model: '911 GT3',
        year: 2024,
        colorName: 'Shark Blue',
        imageUrl: '',
        vehicleType: 'Coupe',
      );
      const v2 = UserVehicle(
        id: 'v_equal_test',
        make: 'Porsche',
        model: '911 GT3 RS',
        year: 2024,
        colorName: 'Shark Blue',
        imageUrl: '',
        vehicleType: 'Coupe',
      );
      const v3 = UserVehicle(
        id: 'v_different_test',
        make: 'Porsche',
        model: '911 GT3',
        year: 2024,
        colorName: 'Shark Blue',
        imageUrl: '',
        vehicleType: 'Coupe',
      );

      expect(v1 == v2, isTrue);
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1 == v3, isFalse);
    });
  });

  group('ServicePackage Pricing & Vehicle Surcharge Tests', () {
    test('calculatePriceForVehicleType with custom surcharges and fallback multipliers', () {
      // 1. Package with custom dollar surcharges
      final packageCustom = ServicePackage(
        id: 'pkg_1',
        title: 'Paint Correction',
        description: 'Multi-stage polish',
        basePrice: 500.0,
        estimatedDuration: '4 hours',
        includes: const ['Wash', 'Correction', 'Sealant'],
        vehicleSurcharges: const {
          'SUV / Crossover': 75.0,
          'Truck': 120.0,
          'Minivan / Van': 100.0,
        },
      );

      expect(packageCustom.getSurchargeForVehicleType('Sedan'), equals(0.0));
      expect(packageCustom.calculatePriceForVehicleType('Sedan'), equals(500.0));
      expect(packageCustom.calculatePriceForVehicleType('Coupe'), equals(500.0));
      expect(packageCustom.calculatePriceForVehicleType('SUV / Crossover'), equals(575.0));
      expect(packageCustom.calculatePriceForVehicleType('Truck'), equals(620.0));
      expect(packageCustom.calculatePriceForVehicleType('Minivan / Van'), equals(600.0));

      // calculatePriceForVehicle helper
      const suvVehicle = UserVehicle(
        id: 'v_suv',
        make: 'Audi',
        model: 'Q7',
        year: 2023,
        colorName: 'Mythos Black',
        imageUrl: '',
        vehicleType: 'SUV / Crossover',
      );
      expect(packageCustom.calculatePriceForVehicle(suvVehicle), equals(575.0));

      // 2. Package without custom surcharges (uses default multiplier: 1.0, 1.25, 1.45)
      final packageDefault = ServicePackage(
        id: 'pkg_2',
        title: 'Basic Detail',
        description: 'Standard wash',
        basePrice: 100.0,
        estimatedDuration: '1 hour',
        includes: const ['Hand Wash'],
      );

      expect(packageDefault.calculatePriceForVehicleType('Sedan'), equals(100.0));
      expect(packageDefault.calculatePriceForVehicleType('SUV / Crossover'), equals(125.0));
      expect(packageDefault.calculatePriceForVehicleType('Truck'), equals(145.0));

      // Serialization roundtrip
      final json = packageCustom.toJson();
      expect(json['vehicleSurcharges'], isA<Map>());
      final restored = ServicePackage.fromJson(json);
      expect(restored.vehicleSurcharges['SUV / Crossover'], equals(75.0));
    });
  });

  group('Booking Gate & Empty Garage Tests', () {
    testWidgets('PublicStudioScreen prompts to add vehicle when garage is empty', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = await TestHarness.createSession(isLoggedIn: true);
        await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

        final detailer = MockDataService.youUser.copyWith(
          id: 'usr_detailer_studio_01',
          displayName: 'Apex Detailing Studio',
          servicePackages: MockDataService.standardPackages,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: PublicStudioScreen(
              detailer: detailer,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Book Studio Service button in the header
        final bookButton = find.text('Book Studio Service');
        expect(bookButton, findsOneWidget);
        await tester.tap(bookButton);
        await tester.pumpAndSettle();

        // Verify Empty Garage Gate Alert Dialog appears
        expect(find.text('Add a Vehicle First'), findsOneWidget);
        expect(find.textContaining('please add your vehicle to My Garage first'), findsOneWidget);
        expect(find.text('Add Vehicle to Garage'), findsOneWidget);

        // Tap Add Vehicle to Garage
        await tester.tap(find.text('Add Vehicle to Garage'));
        await tester.pumpAndSettle();

        // Verify VehicleEditorDialog is displayed
        expect(find.byType(VehicleEditorDialog), findsOneWidget);
        expect(find.text('4. Vehicle Body Style & Size Classification'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('VehicleEditorDialog allows selecting vehicle type and auto-detects from model', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: true);
      await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: VehicleEditorDialog(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to manual text typing mode
      await tester.tap(find.text('+ Type manually'));
      await tester.pumpAndSettle();

      // Enter Make
      final makeField = find.widgetWithText(TextField, 'Make (e.g. Lucid, Koenigsegg, Pagani, Lotus)');
      await tester.enterText(makeField, 'Ford');

      // Enter Model - F-150 Raptor should auto-detect Truck body style
      final modelField = find.widgetWithText(TextField, 'Model (e.g. Air Sapphire, Emira, Custom GT)');
      await tester.enterText(modelField, 'F-150 Raptor');
      await tester.pumpAndSettle();

      // Scroll down to reveal color input
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Enter Color
      final colorField = find.widgetWithText(TextField, 'Custom Paint / Vinyl Wrap Color');
      await tester.enterText(colorField, 'Oxford White');
      await tester.pumpAndSettle();

      // Tap Save Vehicle
      final saveBtn = find.text('Add to Garage');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify vehicle was added to repository's myGarage with Truck vehicleType
      expect(repo.currentUser.myGarage.length, equals(1));
      final savedVeh = repo.currentUser.myGarage.first;
      expect(savedVeh.make, equals('Ford'));
      expect(savedVeh.model, equals('F-150 Raptor'));
      expect(savedVeh.vehicleType, equals(VehicleBodyType.truck));
      expect(savedVeh.resolvedVehicleSize, equals(VehicleSize.truckVan));
    });
  });

  group('BookingFlowScreen Garage Vehicle Selection & Real-Time Dynamic Pricing', () {
    testWidgets('Dropdown selects vehicle from garage and dynamically updates package surcharge price', (tester) async {
      tester.view.physicalSize = const Size(900, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: true);

      // Add two vehicles to client garage: Sedan and SUV
      const sedan = UserVehicle(
        id: 'veh_sedan_01',
        make: 'BMW',
        model: 'M3 Competition',
        year: 2022,
        colorName: 'Isle of Man Green',
        imageUrl: '',
        vehicleType: VehicleBodyType.sedan,
      );
      const suv = UserVehicle(
        id: 'veh_suv_01',
        make: 'Porsche',
        model: 'Cayenne GTS',
        year: 2024,
        colorName: 'Carmine Red',
        imageUrl: '',
        vehicleType: VehicleBodyType.suv,
      );
      await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: [sedan, suv]));

      // Create detailer service package with specific vehicle surcharges
      final package = ServicePackage(
        id: 'pkg_custom_test',
        title: 'Paint Correction & Ceramic Coating',
        description: 'Complete multi-stage detail',
        basePrice: 500.0,
        estimatedDuration: '4 hours',
        includes: const ['Full Wash', 'Paint Correction', '9H Ceramic'],
        vehicleSurcharges: const {
          'SUV / Crossover': 120.0,
          'Truck': 160.0,
          'Minivan / Van': 140.0,
        },
      );

      final detailer = MockDataService.youUser.copyWith(
        id: 'usr_detailer_studio_02',
        servicePackages: [package],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BookingFlowScreen(
              detailer: detailer,
              repository: repo,
              initialPackage: package,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0: Select a Detailing Package -> Continue
      expect(find.text('Select a Detailing Package'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 1: Vehicle & Schedule
      expect(find.text('Vehicle to Detail'), findsOneWidget);
      expect(find.text('Select Vehicle from My Garage'), findsOneWidget);

      // Initially sedan is selected -> Base price $500, standard pricing note
      expect(find.text('\$500'), findsWidgets);
      expect(find.text('Standard vehicle size pricing applied'), findsOneWidget);

      // Open dropdown and select the SUV
      final dropdown = find.byType(DropdownButtonFormField<UserVehicle>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap on Porsche Cayenne GTS
      await tester.tap(find.text('2024 Porsche Cayenne GTS').last);
      await tester.pumpAndSettle();

      // Price should update dynamically: $500 + $120 = $620
      expect(find.text('\$620'), findsWidgets);
      expect(find.textContaining('+ \$120 SUV / Crossover fee'), findsOneWidget);

      // Advance to Step 2: Checkout / Review & Confirm
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Fill in contact info
      final nameField = find.widgetWithText(TextField, 'Full Name');
      await tester.enterText(nameField, 'Jane Doe');
      final phoneField = find.widgetWithText(TextField, 'Mobile Phone (For SMS updates)');
      await tester.enterText(phoneField, '555-123-4567');
      final emailField = find.widgetWithText(TextField, 'Email Address (For Warranty Receipt)');
      await tester.enterText(emailField, 'janedoe@example.com');
      await tester.pumpAndSettle();

      // Confirm Booking via "Reserve & Book"
      await tester.tap(find.text('Reserve & Book'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog shows "Booking Reserved!", vehicle receipt, and "View in My Bookings"
      expect(find.text('Booking Reserved!'), findsOneWidget);
      expect(find.text('2024 Porsche Cayenne GTS'), findsOneWidget);
      expect(find.text('\$620'), findsWidgets);
      expect(find.text('View in My Bookings'), findsOneWidget);

      // Tapping "View in My Bookings" switches active tab to 1
      await tester.tap(find.text('View in My Bookings'));
      await tester.pumpAndSettle();

      expect(repo.activeTabIndex, equals(1));
    });
  });

  group('Detailer Workbench & ServicePackageEditorDialog Surcharge Configuration', () {
    testWidgets('DetailerWorkbenchView displays vehicle type price surcharges in package inspector', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = await TestHarness.createSession(isLoggedIn: true);

        final packageWithSurcharges = ServicePackage(
          id: 'pkg_surcharge_demo',
          title: 'Premium Multi-Stage Polish',
          description: 'Flawless swirl removal',
          basePrice: 400.0,
          estimatedDuration: '3 hours',
          includes: const ['Decontamination', '2-stage correction'],
          vehicleSurcharges: const {
            'SUV / Crossover': 80.0,
            'Truck': 150.0,
            'Minivan / Van': 120.0,
          },
        );

        await repo.updateCurrentUser(repo.currentUser.copyWith(
          servicePackages: [packageWithSurcharges],
        ));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DetailerWorkbenchView(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Services tab
        await tester.tap(find.text('Services'));
        await tester.pumpAndSettle();

        // Select the package card from the list in Pane 2
        await tester.tap(find.text('Premium Multi-Stage Polish').first);
        await tester.pumpAndSettle();

        // Verify "PRICING BY VEHICLE TYPE" chip grid is rendered in package inspector
        expect(find.text('PRICING BY VEHICLE TYPE'), findsOneWidget);
        expect(find.textContaining('Coupe / Sedan'), findsOneWidget);
        expect(find.textContaining('SUV'), findsWidgets);
        expect(find.textContaining('Truck'), findsWidgets);
        expect(find.textContaining('Minivan'), findsWidgets);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('ServicePackageEditorDialog allows detailer to customize and save vehicle surcharges', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ServicePackage? savedPackage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ServicePackageEditorDialog(
              onSave: (pkg) => savedPackage = pkg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter Title & Price
      final titleField = find.widgetWithText(TextFormField, 'e.g. 2-Stage Paint Correction & Ceramic Seal');
      await tester.enterText(titleField, 'Express Maintenance Wash');

      final priceField = find.widgetWithText(TextFormField, '150');
      await tester.enterText(priceField, '100');

      // Scroll down to Vehicle Type Pricing Surcharges section
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Type Pricing Surcharges'), findsOneWidget);

      // Customize SUV surcharge to 30
      final suvCtrl = find.descendant(of: find.byKey(const Key('surcharge_field_suv')), matching: find.byType(TextFormField));
      await tester.enterText(suvCtrl, '30');

      // Customize Truck surcharge to 50
      final truckCtrl = find.descendant(of: find.byKey(const Key('surcharge_field_truck')), matching: find.byType(TextFormField));
      await tester.enterText(truckCtrl, '50');

      // Customize Minivan surcharge to 40
      final minivanCtrl = find.descendant(of: find.byKey(const Key('surcharge_field_minivan')), matching: find.byType(TextFormField));
      await tester.enterText(minivanCtrl, '40');

      // Tap Create Package
      await tester.tap(find.text('Create Package'));
      await tester.pumpAndSettle();

      expect(savedPackage, isNotNull);
      expect(savedPackage!.basePrice, equals(100.0));
      expect(savedPackage!.vehicleSurcharges['SUV / Crossover'], equals(30.0));
      expect(savedPackage!.vehicleSurcharges['Truck'], equals(50.0));
      expect(savedPackage!.vehicleSurcharges['Minivan / Van'], equals(40.0));
      expect(savedPackage!.calculatePriceForVehicleType('SUV / Crossover'), equals(130.0));
      expect(savedPackage!.calculatePriceForVehicleType('Truck'), equals(150.0));
      expect(savedPackage!.calculatePriceForVehicleType('Minivan / Van'), equals(140.0));
    });

    testWidgets('ServicePackageEditorDialog clamps negative/invalid surcharge input to 0', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ServicePackage? savedPackage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ServicePackageEditorDialog(
              onSave: (pkg) => savedPackage = pkg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(TextFormField, 'e.g. 2-Stage Paint Correction & Ceramic Seal');
      await tester.enterText(titleField, 'Clamping Test Package');

      final priceField = find.widgetWithText(TextFormField, '150');
      await tester.enterText(priceField, '200');

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final suvCtrl = find.descendant(of: find.byKey(const Key('surcharge_field_suv')), matching: find.byType(TextFormField));
      await tester.enterText(suvCtrl, '-50');

      final truckCtrl = find.descendant(of: find.byKey(const Key('surcharge_field_truck')), matching: find.byType(TextFormField));
      await tester.enterText(truckCtrl, 'invalid_text');

      await tester.tap(find.text('Create Package'));
      await tester.pumpAndSettle();

      expect(savedPackage, isNotNull);
      expect(savedPackage!.vehicleSurcharges['SUV / Crossover'], equals(0.0));
      expect(savedPackage!.vehicleSurcharges['Truck'], equals(0.0));
    });
  });

  group('Booking Entry Point Gate Tests across All Surfaces', () {
    testWidgets('BookingFlowScreen blocks advancing to step 2 when garage is empty', (tester) async {
      tester.view.physicalSize = const Size(900, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await TestHarness.createSession(isLoggedIn: true);
      await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

      final package = MockDataService.standardPackages.first;
      final detailer = MockDataService.youUser.copyWith(
        id: 'usr_detailer_gate_test',
        servicePackages: [package],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BookingFlowScreen(
              detailer: detailer,
              repository: repo,
              initialPackage: package,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0: Package -> Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 1: Empty garage banner should be visible
      expect(find.byKey(const Key('empty_garage_banner')), findsOneWidget);
      expect(find.text('No Vehicle in My Garage'), findsOneWidget);

      // Attempt to advance to step 2 without vehicle -> must be blocked
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify warning snackbar is triggered and VehicleEditorDialog is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Please add a vehicle to My Garage first before proceeding'), findsOneWidget);
      expect(find.byType(VehicleEditorDialog), findsOneWidget);
    });

    testWidgets('FeedScreen triggers garage gate dialog when booking with empty garage', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = await TestHarness.createSession(isLoggedIn: true);
        await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

        final testDetailer = MockDataService.youUser.copyWith(
          id: 'usr_feed_detailer_01',
          role: UserRole.detailer,
          displayName: 'Velocity Detail Studio',
          businessName: 'Velocity Auto Detailing',
          servicePackages: MockDataService.standardPackages,
        );
        repo.setPublicDetailersForTesting([testDetailer]);
        final job = createTestJob(id: 'job_feed_test_01').copyWith(author: testDetailer);
        repo.addJob(job);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: FeedScreen(repository: repo),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final bookButton = find.text('Book').first;
        await tester.tap(bookButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Add a Vehicle First'), findsOneWidget);
        expect(find.textContaining('please add your vehicle to My Garage first'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('JobDetailScreen triggers garage gate dialog when booking with empty garage', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = await TestHarness.createSession(isLoggedIn: true);
        await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

        final testDetailer = MockDataService.youUser.copyWith(
          id: 'usr_detail_detailer_01',
          businessName: 'Prestige Detail Studio',
        );
        final sampleJob = createTestJob(id: 'job_detail_test_01').copyWith(author: testDetailer);
        repo.addJob(sampleJob);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: JobDetailScreen(
                job: sampleJob,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bookBtn = find.text('Book Service');
        expect(bookBtn, findsOneWidget);
        await tester.tap(bookBtn);
        await tester.pumpAndSettle();
        expect(find.text('Add a Vehicle First'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });

    testWidgets('JobRecipeCard triggers garage gate dialog when booking with empty garage', (tester) async {
      setupMockImageHttpClient();
      try {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = await TestHarness.createSession(isLoggedIn: true);
        await repo.updateCurrentUser(repo.currentUser.copyWith(myGarage: const []));

        final testDetailer = MockDataService.youUser.copyWith(
          id: 'usr_card_detailer_01',
          businessName: 'Apex Studio Works',
        );
        final sampleJob = createTestJob(id: 'job_card_test_01').copyWith(author: testDetailer);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: JobRecipeCard(
                  job: sampleJob,
                  repository: repo,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final bookBtn = find.text('Book Here');
        expect(bookBtn, findsOneWidget);
        await tester.tap(bookBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Add a Vehicle First'), findsOneWidget);
      } finally {
        tearDownMockImageHttpClient();
      }
    });
  });
}
