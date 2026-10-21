import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/models/user_profile.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/core/theme/app_theme.dart';
import 'package:detail_craft/screens/feed_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explore Service Search and Studio Cards', () {
    late JobRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = JobRepository();
      await repo.init();
    });

    test('filteredDetailers matches on servicePackages title, description, and includes', () {
      const customPackage = ServicePackage(
        id: 'pkg_ceramic_pro',
        title: 'Ceramic Coating 9H Diamond',
        description: 'Multi-stage paint correction with hydrophobic quartz finish',
        basePrice: 450.0,
        estimatedDuration: '6 hours',
        includes: ['Decontamination wash', 'Clay bar treatment', 'Graphene topper'],
        isPopular: true,
      );

      repo.toggleHostMode(targetRole: UserRole.detailer);
      repo.updateCurrentUser(repo.currentUser.copyWith(
        displayName: 'Gloss Lab Studio',
        businessName: 'Gloss Lab Texas',
        location: 'Austin, TX',
        serviceRadius: '30 miles',
        servicePackages: [customPackage],
      ));

      final myStudioId = repo.currentUser.id;

      // Verify studio is present in publicDetailers
      expect(repo.publicDetailers.any((d) => d.id == myStudioId), isTrue);

      // 1. Search by exact package title keyword
      repo.setSearchQuery('Diamond');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);

      // 2. Search by package description keyword
      repo.setSearchQuery('hydrophobic');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);

      // 3. Search by package includes item keyword
      repo.setSearchQuery('Graphene topper');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);

      // 4. Search by non-matching query
      repo.setSearchQuery('NonExistentServiceXYZ');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isFalse);

      repo.clearFilters();
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);
    });

    test('refreshExploreFeed reloads and notifies listeners', () async {
      int notifyCount = 0;
      repo.addListener(() {
        notifyCount++;
      });

      await repo.refreshExploreFeed();
      expect(notifyCount, greaterThan(0));
    });

    testWidgets('Studio card renders starting price and service count (plural) on Explore card face', (tester) async {
      const customPackage1 = ServicePackage(
        id: 'pkg_1',
        title: 'Express Wash & Seal',
        description: 'Foam bath and spray sealant',
        basePrice: 150.0,
        estimatedDuration: '2 hours',
        includes: ['Hand wash'],
      );
      const customPackage2 = ServicePackage(
        id: 'pkg_2',
        title: 'Paint Correction',
        description: 'Two stage machine polish',
        basePrice: 350.0,
        estimatedDuration: '5 hours',
        includes: ['Cutting compound', 'Finish polish'],
      );

      repo.toggleHostMode(targetRole: UserRole.detailer);
      repo.updateCurrentUser(repo.currentUser.copyWith(
        displayName: 'Austin Pro Detail',
        businessName: 'Austin Pro Detail Studio',
        location: 'Austin, TX',
        serviceRadius: '25 miles',
        servicePackages: [customPackage1, customPackage2],
      ));

      final myStudioId = repo.currentUser.id;

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

      expect(find.byKey(const Key('toggle_featured_detailers_btn')), findsOneWidget);
      expect(find.byKey(Key('detailer_card_$myStudioId')), findsOneWidget);

      final servicesFinder = find.byKey(Key('detailer_card_services_$myStudioId'));
      expect(servicesFinder, findsOneWidget);

      final Text servicesWidget = tester.widget(servicesFinder);
      expect(servicesWidget.data, 'From \$150 • 2 services');
    });

    testWidgets('Studio card renders singular service count when only 1 service is configured', (tester) async {
      const singlePackage = ServicePackage(
        id: 'pkg_single',
        title: 'Full Exterior Wash',
        description: 'Foam wash and dry',
        basePrice: 99.0,
        estimatedDuration: '1 hour',
        includes: ['Hand wash'],
      );

      repo.toggleHostMode(targetRole: UserRole.detailer);
      repo.updateCurrentUser(repo.currentUser.copyWith(
        displayName: 'Solo Pro Detail',
        businessName: 'Solo Pro Detailing',
        location: 'Dallas, TX',
        serviceRadius: '15 miles',
        servicePackages: [singlePackage],
      ));

      final myStudioId = repo.currentUser.id;

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

      final servicesFinder = find.byKey(Key('detailer_card_services_$myStudioId'));
      expect(servicesFinder, findsOneWidget);

      final Text servicesWidget = tester.widget(servicesFinder);
      expect(servicesWidget.data, 'From \$99 • 1 service');
    });

    test('search handles leading/trailing whitespace correctly', () {
      const customPackage = ServicePackage(
        id: 'pkg_gloss',
        title: 'High Gloss Ceramic',
        description: 'Single-stage paint polish',
        basePrice: 200.0,
        estimatedDuration: '3 hours',
        includes: ['Decon', 'Sealant'],
      );

      repo.toggleHostMode(targetRole: UserRole.detailer);
      repo.updateCurrentUser(repo.currentUser.copyWith(
        displayName: 'Gloss Studio',
        businessName: 'Gloss Studio TX',
        location: 'Austin, TX',
        servicePackages: [customPackage],
      ));

      final myStudioId = repo.currentUser.id;

      // With leading/trailing whitespace
      repo.setSearchQuery('  Ceramic  ');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);

      // Whitespace only should not filter out
      repo.setSearchQuery('   ');
      expect(repo.filteredDetailers.any((d) => d.id == myStudioId), isTrue);
    });

    test('addServicePackage immediately reflects in publicDetailers and filteredDetailers', () {
      const customPackage = ServicePackage(
        id: 'pkg_boost_added',
        title: 'Titanium Ceramic Boost',
        description: 'Extreme hydrophobicity',
        basePrice: 275.0,
        estimatedDuration: '4 hours',
        includes: ['Prep', 'Coating'],
      );

      repo.addServicePackage(customPackage);

      expect(repo.currentUser.servicePackages.any((p) => p.id == 'pkg_boost_added'), isTrue);
      expect(repo.currentUser.startingPrice, 275.0);
      expect(repo.publicDetailers.any((d) => d.id == repo.currentUser.id), isTrue);

      repo.setSearchQuery('Titanium');
      expect(repo.filteredDetailers.any((d) => d.id == repo.currentUser.id), isTrue);
    });

    testWidgets('Pull to refresh invokes repository.refreshExploreFeed', (tester) async {
      int refreshCalls = 0;
      repo.addListener(() {
        refreshCalls++;
      });

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

      // Trigger pull to refresh gesture on the RefreshIndicator
      final refreshIndicatorFinder = find.byType(RefreshIndicator);
      expect(refreshIndicatorFinder, findsOneWidget);

      await tester.fling(refreshIndicatorFinder, const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCalls, greaterThan(0));
    });
  });
}
