import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M4: Feed, Comments & Likes Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1: Custom uploaded job persists to storage and survives browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final customJob = DetailJob(
        id: 'job_custom_m4_test',
        author: repo1.currentUser,
        createdAt: DateTime.now(),
        title: 'M4 Custom Transformation Test',
        description: 'Multi-stage paint correction and ceramic shield.',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: '911 GT3 RS',
        paintColorName: 'Guards Red',
        paintCode: 'G1',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 130.0,
        finalPaintThicknessMicrons: 125.0,
        defectSeverity: 2,
        defectStage: DefectStage.stage2,
        correctionPercentage: 90,
        serviceType: '2-Stage Multi-Cut Polish',
        recipeStages: const [],
        beforeImageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600',
        afterImageUrl: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?w=600',
        beforePhotos: const ['https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600'],
        afterPhotos: const ['https://images.unsplash.com/photo-1617788138017-80ad40651399?w=600'],
        mediaZones: const [],
        durationHours: 8.0,
        quotedPrice: 1200.0,
        likesCount: 5,
        isLiked: false,
        savesCount: 2,
        isSaved: false,
        comments: const [],
      );

      repo1.addJob(customJob);
      expect(repo1.allJobs.any((j) => j.id == 'job_custom_m4_test'), isTrue);

      // Verify immediate local storage persistence
      final savedJobs = await LocalStorageService.loadCustomJobs();
      expect(savedJobs.any((j) => j.id == 'job_custom_m4_test'), isTrue);

      // Simulate browser refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.allJobs.any((j) => j.id == 'job_custom_m4_test'), isTrue);
      final reloaded = repo2.allJobs.firstWhere((j) => j.id == 'job_custom_m4_test');
      expect(reloaded.vehicleMake, equals('Porsche'));
      expect(reloaded.vehicleModel, equals('911 GT3 RS'));
      expect(reloaded.title, equals('M4 Custom Transformation Test'));
      expect(reloaded.quotedPrice, equals(1200.0));
    });

    test('T2: Discussion comments added to mock and custom jobs survive reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true, seedSampleJob: true);

      // 1. Add comment to mock job
      final mockJobId = repo1.allJobs.first.id;
      final mockComment = JobComment(
        id: 'comment_m4_mock_1',
        authorName: 'Pro Detailer Dave',
        authorAvatar: '',
        text: 'Incredible finish on the hood clear coat!',
        createdAt: DateTime.now(),
        isVerifiedPro: true,
      );

      await repo1.addComment(mockJobId, mockComment);

      // Verify comment present in repo1 and local storage
      final mockComments1 = repo1.getCommentsForJob(mockJobId);
      expect(mockComments1.any((c) => c.id == 'comment_m4_mock_1'), isTrue);
      final storedMockComments = await LocalStorageService.loadJobComments(mockJobId);
      expect(storedMockComments != null && storedMockComments.any((c) => c.id == 'comment_m4_mock_1'), isTrue);

      // 2. Add custom job and add comment to it
      final customJob = DetailJob(
        id: 'job_custom_m4_comments',
        author: repo1.currentUser,
        createdAt: DateTime.now(),
        title: 'M4 Custom Transformation with Comments',
        description: 'Single-stage polish and sealant.',
        vehicleYear: 2023,
        vehicleMake: 'BMW',
        vehicleModel: 'M2 Competition',
        paintColorName: 'Alpine White',
        paintCode: '300',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 120.0,
        finalPaintThicknessMicrons: 118.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 80,
        serviceType: 'Gloss Enhancement Polish',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 4.0,
        quotedPrice: 650.0,
        likesCount: 1,
        isLiked: false,
        savesCount: 0,
        isSaved: false,
        comments: const [],
      );
      repo1.addJob(customJob);

      final customComment = JobComment(
        id: 'comment_m4_custom_1',
        authorName: 'Marcus Vance',
        authorAvatar: '',
        text: 'What pad and compound combo did you use for the piano black trim?',
        createdAt: DateTime.now().add(const Duration(minutes: 5)),
        isVerifiedPro: false,
      );
      await repo1.addComment(customJob.id, customComment);

      // 3. Simulate browser reload
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);

      // Verify mock job comment survived
      final mockComments2 = repo2.getCommentsForJob(mockJobId);
      expect(mockComments2.any((c) => c.id == 'comment_m4_mock_1'), isTrue);
      expect(mockComments2.firstWhere((c) => c.id == 'comment_m4_mock_1').text,
          equals('Incredible finish on the hood clear coat!'));

      // Verify custom job comment survived
      final customComments2 = repo2.getCommentsForJob(customJob.id);
      expect(customComments2.any((c) => c.id == 'comment_m4_custom_1'), isTrue);
      expect(customComments2.firstWhere((c) => c.id == 'comment_m4_custom_1').text,
          equals('What pad and compound combo did you use for the piano black trim?'));
    });

    test('T3: Toggling like on job persists like state and count across reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true, seedSampleJob: true);
      final jobId = repo1.allJobs.first.id;
      final initialLikes = repo1.allJobs.first.likesCount;

      // Toggle like ON
      repo1.toggleJobLike(jobId);
      expect(repo1.allJobs.first.isLiked, isTrue);
      expect(repo1.allJobs.first.likesCount, equals(initialLikes + 1));

      // Simulate browser refresh
      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      final reloadedJob = repo2.allJobs.firstWhere((j) => j.id == jobId);
      expect(reloadedJob.isLiked, isTrue);
      expect(reloadedJob.likesCount, equals(initialLikes + 1));

      // Toggle like OFF
      repo2.toggleJobLike(jobId);
      expect(repo2.allJobs.firstWhere((j) => j.id == jobId).isLiked, isFalse);
      expect(repo2.allJobs.firstWhere((j) => j.id == jobId).likesCount, equals(initialLikes));

      // Simulate second browser refresh
      final repo3 = await TestHarness.simulateBrowserRefresh(repo2);
      final reloadedJob3 = repo3.allJobs.firstWhere((j) => j.id == jobId);
      expect(reloadedJob3.isLiked, isFalse);
      expect(reloadedJob3.likesCount, equals(initialLikes));
    });

    test('T4: Custom job deletion cleans up local storage and survives reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      final customJob = DetailJob(
        id: 'job_to_delete_test',
        author: repo1.currentUser,
        createdAt: DateTime.now(),
        title: 'Job To Be Deleted',
        description: 'Temporary job test',
        vehicleYear: 2020,
        vehicleMake: 'Ford',
        vehicleModel: 'Mustang',
        paintColorName: 'Shadow Black',
        paintCode: 'G1',
        paintHardness: PaintHardness.soft,
        initialPaintThicknessMicrons: 110.0,
        finalPaintThicknessMicrons: 108.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 75,
        serviceType: 'Wash & Wax',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 2.0,
        quotedPrice: 200.0,
        likesCount: 0,
        isLiked: false,
        savesCount: 0,
        isSaved: false,
        comments: const [],
      );

      repo1.addJob(customJob);
      expect(repo1.allJobs.any((j) => j.id == 'job_to_delete_test'), isTrue);

      repo1.deleteJob('job_to_delete_test');
      expect(repo1.allJobs.any((j) => j.id == 'job_to_delete_test'), isFalse);

      final saved = await LocalStorageService.loadCustomJobs();
      expect(saved.any((j) => j.id == 'job_to_delete_test'), isFalse);

      final repo2 = await TestHarness.simulateBrowserRefresh(repo1);
      expect(repo2.allJobs.any((j) => j.id == 'job_to_delete_test'), isFalse);
    });
  });
}
