import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:detail_craft/models/detail_job.dart';
import 'package:detail_craft/services/job_repository.dart';
import 'package:detail_craft/services/local_storage_service.dart';
import '../core/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M4 Challenger 1: Empirical Adversarial Stress Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('STRESS-1: Rapid consecutive comments on mock and custom jobs survive browser reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // 1. Target mock job: job_01
      const mockJobId = 'job_01';
      final initialMockJob = repo1.allJobs.firstWhere(
        (j) => j.id == mockJobId,
        orElse: () => repo1.allJobs.first,
      );
      final actualMockJobId = initialMockJob.id;
      final initialMockCommentCount = initialMockJob.comments.length;

      // 2. Add 5 comments in rapid succession to mock job
      final mockComments = List.generate(5, (i) {
        return JobComment(
          id: 'comment_mock_burst_$i',
          authorName: 'Mock Detailer $i',
          authorAvatar: 'https://images.unsplash.com/avatar_$i.jpg',
          text: 'Rapid stress comment $i on mock job with special chars: 💎 #paintcorrection [level $i]',
          createdAt: DateTime.utc(2026, 10, 16, 11, i, 0),
          isVerifiedPro: i.isEven,
        );
      });

      for (final comment in mockComments) {
        await repo1.addComment(actualMockJobId, comment);
      }

      // Verify in repo1 memory
      final inMemoryMockComments = repo1.getCommentsForJob(actualMockJobId);
      expect(inMemoryMockComments.length, equals(initialMockCommentCount + 5));

      // 3. Create and add a newly uploaded custom job
      final customJob = DetailJob(
        id: 'job_custom_rapid_comments_stress',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 10, 0, 0),
        title: 'Challenger 1 Rapid Comments Stress Rig',
        description: 'Adversarial validation of rapid comment bursts across sessions.',
        vehicleYear: 2025,
        vehicleMake: 'Ferrari',
        vehicleModel: '296 GTB Assetto Fiorano',
        paintColorName: 'Rosso Corsa',
        paintCode: '322',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 135.0,
        finalPaintThicknessMicrons: 130.0,
        defectSeverity: 2,
        defectStage: DefectStage.stage2,
        correctionPercentage: 92,
        serviceType: 'Multi-Stage Paint Correction',
        recipeStages: const [],
        beforeImageUrl: 'https://images.unsplash.com/photo-ferrari-before.jpg',
        afterImageUrl: 'https://images.unsplash.com/photo-ferrari-after.jpg',
        beforePhotos: const ['https://images.unsplash.com/photo-ferrari-before.jpg'],
        afterPhotos: const ['https://images.unsplash.com/photo-ferrari-after.jpg'],
        mediaZones: const [],
        durationHours: 12.0,
        quotedPrice: 1850.0,
        likesCount: 14,
        isLiked: false,
        savesCount: 3,
        isSaved: false,
        comments: const [],
      );
      repo1.addJob(customJob);
      expect(repo1.allJobs.any((j) => j.id == customJob.id), isTrue);

      // 4. Add 5 comments in rapid succession to the custom job
      final customComments = List.generate(5, (i) {
        return JobComment(
          id: 'comment_custom_burst_$i',
          authorName: 'Master Artisan $i',
          authorAvatar: 'https://images.unsplash.com/artisan_$i.jpg',
          text: 'Custom job rapid reply $i: Microfiber cutting pad with DA polisher at 4500 OPM 🔥',
          createdAt: DateTime.utc(2026, 10, 16, 11, 30 + i, 0),
          isVerifiedPro: true,
        );
      });

      for (final comment in customComments) {
        await repo1.addComment(customJob.id, comment);
      }

      // Verify in repo1 memory for custom job
      final inMemoryCustomComments = repo1.getCommentsForJob(customJob.id);
      expect(inMemoryCustomComments.length, equals(5));

      // 5. Simulate browser reload
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      // 6. Verify all 10 comments survive intact with correct authors, timestamps, and job associations
      final reloadedMockComments = repo2.getCommentsForJob(actualMockJobId);
      expect(reloadedMockComments.length, equals(initialMockCommentCount + 5));
      for (int i = 0; i < 5; i++) {
        final expected = mockComments[i];
        final matched = reloadedMockComments.firstWhere(
          (c) => c.id == expected.id,
          orElse: () => throw StateError('Mock comment ${expected.id} missing after reload!'),
        );
        expect(matched.authorName, equals(expected.authorName));
        expect(matched.text, equals(expected.text));
        expect(matched.createdAt, equals(expected.createdAt));
        expect(matched.isVerifiedPro, equals(expected.isVerifiedPro));
      }

      final reloadedCustomComments = repo2.getCommentsForJob(customJob.id);
      expect(reloadedCustomComments.length, equals(5));
      for (int i = 0; i < 5; i++) {
        final expected = customComments[i];
        final matched = reloadedCustomComments.firstWhere(
          (c) => c.id == expected.id,
          orElse: () => throw StateError('Custom comment ${expected.id} missing after reload!'),
        );
        expect(matched.authorName, equals(expected.authorName));
        expect(matched.text, equals(expected.text));
        expect(matched.createdAt, equals(expected.createdAt));
        expect(matched.isVerifiedPro, equals(expected.isVerifiedPro));
      }

      // 7. Verify strict job association isolation
      for (final mc in mockComments) {
        expect(reloadedCustomComments.any((c) => c.id == mc.id), isFalse,
            reason: 'Mock comment leaked into custom job comments!');
      }
      for (final cc in customComments) {
        expect(reloadedMockComments.any((c) => c.id == cc.id), isFalse,
            reason: 'Custom comment leaked into mock job comments!');
      }

      repo2.dispose();
    });

    test('STRESS-2: Rapid like/unlike bursts on 5 jobs toggle 10 times consecutively and survive reload', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // Ensure at least 5 jobs exist by uploading 2 custom jobs alongside the 3 initial mock jobs
      final customBurstJob1 = DetailJob(
        id: 'job_burst_custom_01',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 8, 0, 0),
        title: 'Custom Burst Job 1',
        description: 'Burst test job 1',
        vehicleYear: 2024,
        vehicleMake: 'BMW',
        vehicleModel: 'M3 Touring',
        paintColorName: 'Isle of Man Green',
        paintCode: 'C4G',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 120.0,
        finalPaintThicknessMicrons: 118.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 88,
        serviceType: 'Enhancement Polish',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 5.0,
        quotedPrice: 750.0,
        likesCount: 10,
        isLiked: false,
        savesCount: 2,
        isSaved: false,
        comments: const [],
      );

      final customBurstJob2 = DetailJob(
        id: 'job_burst_custom_02',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 8, 30, 0),
        title: 'Custom Burst Job 2',
        description: 'Burst test job 2',
        vehicleYear: 2023,
        vehicleMake: 'Audi',
        vehicleModel: 'RS3 Sedan',
        paintColorName: 'Kyalami Green',
        paintCode: 'LZ6A',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 130.0,
        finalPaintThicknessMicrons: 128.0,
        defectSeverity: 2,
        defectStage: DefectStage.stage2,
        correctionPercentage: 90,
        serviceType: 'Ceramic Coating',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 7.0,
        quotedPrice: 1100.0,
        likesCount: 25,
        isLiked: false,
        savesCount: 5,
        isSaved: false,
        comments: const [],
      );

      repo1.addJob(customBurstJob1);
      repo1.addJob(customBurstJob2);

      // Select 5 distinct jobs (3 mock jobs + 2 custom jobs)
      expect(repo1.allJobs.length, greaterThanOrEqualTo(5));
      final targetJobs = repo1.allJobs.take(5).toList();
      final targetJobIds = targetJobs.map((j) => j.id).toList();

      final initialLikedStates = {for (final j in targetJobs) j.id: j.isLiked};
      final initialLikeCounts = {for (final j in targetJobs) j.id: j.likesCount};

      // 1. Toggle like on 5 jobs 10 times consecutively (10 is even -> returns to initial state)
      for (final jobId in targetJobIds) {
        for (int t = 0; t < 10; t++) {
          repo1.toggleLike(jobId);
        }
      }

      // Verify in-memory state after 10 toggles
      for (final jobId in targetJobIds) {
        final job = repo1.allJobs.firstWhere((j) => j.id == jobId);
        expect(job.isLiked, equals(initialLikedStates[jobId]),
            reason: 'Job $jobId isLiked should return to initial state after 10 toggles');
        expect(job.likesCount, equals(initialLikeCounts[jobId]),
            reason: 'Job $jobId likesCount should return to initial count after 10 toggles');
      }

      // 2. Simulate browser reload
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      // Verify reloaded state matches exactly
      for (final jobId in targetJobIds) {
        final reloadedJob = repo2.allJobs.firstWhere((j) => j.id == jobId);
        expect(reloadedJob.isLiked, equals(initialLikedStates[jobId]),
            reason: 'Reloaded job $jobId isLiked mismatch after 10 toggles');
        expect(reloadedJob.likesCount, equals(initialLikeCounts[jobId]),
            reason: 'Reloaded job $jobId likesCount mismatch after 10 toggles');
      }

      // 3. Now toggle like an ODD number of times (7 toggles) on the first 3 jobs
      // Odd toggles must flip the like state and increment/decrement like count accordingly
      final oddTargetIds = targetJobIds.take(3).toList();
      final preOddStates = {for (final id in oddTargetIds) id: repo2.allJobs.firstWhere((j) => j.id == id).isLiked};
      final preOddCounts = {for (final id in oddTargetIds) id: repo2.allJobs.firstWhere((j) => j.id == id).likesCount};

      for (final jobId in oddTargetIds) {
        for (int t = 0; t < 7; t++) {
          repo2.toggleLike(jobId);
        }
      }

      for (final jobId in oddTargetIds) {
        final job = repo2.allJobs.firstWhere((j) => j.id == jobId);
        final expectedLiked = !preOddStates[jobId]!;
        final expectedCount = expectedLiked ? preOddCounts[jobId]! + 1 : preOddCounts[jobId]! - 1;
        expect(job.isLiked, equals(expectedLiked));
        expect(job.likesCount, equals(expectedCount));
      }

      // 4. Reload second time and verify odd toggle survival
      repo2.dispose();
      final repo3 = JobRepository();
      await repo3.init();

      for (final jobId in oddTargetIds) {
        final reloadedJob = repo3.allJobs.firstWhere((j) => j.id == jobId);
        final expectedLiked = !preOddStates[jobId]!;
        final expectedCount = expectedLiked ? preOddCounts[jobId]! + 1 : preOddCounts[jobId]! - 1;
        expect(reloadedJob.isLiked, equals(expectedLiked),
            reason: 'Reloaded job $jobId odd toggle isLiked mismatch');
        expect(reloadedJob.likesCount, equals(expectedCount),
            reason: 'Reloaded job $jobId odd toggle likesCount mismatch');
      }

      repo3.dispose();
    });

    test('STRESS-3: Custom Job Full Life-Cycle Survival (add, edit, comment, multi-reload, delete without resurrection)', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // 1. Add 3 distinct custom jobs
      final jobA = DetailJob(
        id: 'job_custom_lifecycle_alpha',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 9, 0, 0),
        title: 'Alpha Ceramic Coating',
        description: 'Original Alpha Description',
        vehicleYear: 2024,
        vehicleMake: 'McLaren',
        vehicleModel: '750S',
        paintColorName: 'Papaya Spark',
        paintCode: 'MSO-01',
        paintHardness: PaintHardness.soft,
        initialPaintThicknessMicrons: 110.0,
        finalPaintThicknessMicrons: 108.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 85,
        serviceType: '1-Stage Polish & Ceramic',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 6.0,
        quotedPrice: 1500.0,
        likesCount: 2,
        isLiked: false,
        savesCount: 1,
        isSaved: false,
        comments: const [],
      );

      final jobB = DetailJob(
        id: 'job_custom_lifecycle_beta',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 9, 30, 0),
        title: 'Beta Heavy Defect Removal',
        description: 'Original Beta Description',
        vehicleYear: 2023,
        vehicleMake: 'Aston Martin',
        vehicleModel: 'DBS Superleggera',
        paintColorName: 'Xenon Grey',
        paintCode: 'AST-509',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 140.0,
        finalPaintThicknessMicrons: 133.0,
        defectSeverity: 3,
        defectStage: DefectStage.stage3,
        correctionPercentage: 95,
        serviceType: 'Wet Sand & 3-Stage Cut',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 16.0,
        quotedPrice: 2800.0,
        likesCount: 7,
        isLiked: false,
        savesCount: 4,
        isSaved: false,
        comments: const [],
      );

      final jobC = DetailJob(
        id: 'job_custom_lifecycle_gamma',
        author: repo1.currentUser,
        createdAt: DateTime.utc(2026, 10, 16, 10, 0, 0),
        title: 'Gamma Maintenance Detail',
        description: 'Original Gamma Description',
        vehicleYear: 2022,
        vehicleMake: 'Audi',
        vehicleModel: 'RS6 Avant',
        paintColorName: 'Nardo Grey',
        paintCode: 'LY7C',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 125.0,
        finalPaintThicknessMicrons: 124.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 80,
        serviceType: 'Decon Wash & Light Polish',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 3.5,
        quotedPrice: 450.0,
        likesCount: 0,
        isLiked: false,
        savesCount: 0,
        isSaved: false,
        comments: const [],
      );

      repo1.addJob(jobA);
      repo1.addJob(jobB);
      repo1.addJob(jobC);

      // Verify all 3 added
      expect(repo1.allJobs.any((j) => j.id == jobA.id), isTrue);
      expect(repo1.allJobs.any((j) => j.id == jobB.id), isTrue);
      expect(repo1.allJobs.any((j) => j.id == jobC.id), isTrue);

      // 2. First browser reload: verify all 3 survive
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      expect(repo2.allJobs.any((j) => j.id == jobA.id), isTrue);
      expect(repo2.allJobs.any((j) => j.id == jobB.id), isTrue);
      expect(repo2.allJobs.any((j) => j.id == jobC.id), isTrue);

      // 3. Edit jobA: modify title, description, price, vehicleModel
      final retrievedA = repo2.allJobs.firstWhere((j) => j.id == jobA.id);
      final updatedA = retrievedA.copyWith(
        title: 'Alpha Ceramic Coating [PRO MODIFIED]',
        description: 'Updated description with 5-year Gtechniq Crystal Serum Ultra warranty.',
        quotedPrice: 1950.0,
        vehicleModel: '750S Spider',
      );
      repo2.updateJob(updatedA);

      // 4. Add comments to jobA (3 comments) and jobB (2 comments)
      final commentsForA = List.generate(3, (i) => JobComment(
        id: 'comment_alpha_$i',
        authorName: 'Commenter Alpha $i',
        authorAvatar: '',
        text: 'Alpha discussion comment #$i',
        createdAt: DateTime.utc(2026, 10, 16, 11, i, 0),
        isVerifiedPro: true,
      ));
      for (final c in commentsForA) {
        await repo2.addComment(jobA.id, c);
      }

      final commentsForB = List.generate(2, (i) => JobComment(
        id: 'comment_beta_$i',
        authorName: 'Commenter Beta $i',
        authorAvatar: '',
        text: 'Beta discussion comment #$i',
        createdAt: DateTime.utc(2026, 10, 16, 11, 20 + i, 0),
        isVerifiedPro: false,
      ));
      for (final c in commentsForB) {
        await repo2.addComment(jobB.id, c);
      }

      // 5. Toggle like on jobA, toggle save on jobB
      repo2.toggleLike(jobA.id);
      repo2.toggleSave(jobB.id);

      // 6. Second browser reload: verify edit, comments, like, and save all survive
      repo2.dispose();
      final repo3 = JobRepository();
      await repo3.init();

      final reloadedA = repo3.allJobs.firstWhere((j) => j.id == jobA.id);
      expect(reloadedA.title, equals('Alpha Ceramic Coating [PRO MODIFIED]'));
      expect(reloadedA.description, contains('5-year Gtechniq Crystal Serum Ultra warranty'));
      expect(reloadedA.quotedPrice, equals(1950.0));
      expect(reloadedA.vehicleModel, equals('750S Spider'));
      expect(reloadedA.isLiked, isTrue);
      expect(reloadedA.comments.length, equals(3));
      expect(reloadedA.comments.first.text, equals('Alpha discussion comment #0'));

      final reloadedB = repo3.allJobs.firstWhere((j) => j.id == jobB.id);
      expect(reloadedB.isSaved, isTrue);
      expect(reloadedB.comments.length, equals(2));
      expect(reloadedB.comments.first.text, equals('Beta discussion comment #0'));

      expect(repo3.allJobs.any((j) => j.id == jobC.id), isTrue);

      // 7. Delete jobB: verify immediate deletion
      repo3.deleteJob(jobB.id);
      expect(repo3.allJobs.any((j) => j.id == jobB.id), isFalse);

      // Verify custom jobs storage no longer contains jobB
      final customJobsStorage = await LocalStorageService.loadCustomJobs();
      expect(customJobsStorage.any((j) => j.id == jobB.id), isFalse);

      // 8. Third browser reload: verify jobB does NOT resurrect
      repo3.dispose();
      final repo4 = JobRepository();
      await repo4.init();

      expect(repo4.allJobs.any((j) => j.id == jobB.id), isFalse,
          reason: 'Deleted jobB resurrected after 3rd reload!');
      expect(repo4.allJobs.any((j) => j.id == jobA.id), isTrue);
      expect(repo4.allJobs.any((j) => j.id == jobC.id), isTrue);

      // 9. Fourth browser reload: verify permanent absence of jobB
      repo4.dispose();
      final repo5 = JobRepository();
      await repo5.init();

      expect(repo5.allJobs.any((j) => j.id == jobB.id), isFalse,
          reason: 'Deleted jobB resurrected after 4th reload!');
      final finalA = repo5.allJobs.firstWhere((j) => j.id == jobA.id);
      expect(finalA.title, equals('Alpha Ceramic Coating [PRO MODIFIED]'));
      expect(finalA.comments.length, equals(3));
      expect(repo5.allJobs.any((j) => j.id == jobC.id), isTrue);

      repo5.dispose();
    });

    test('STRESS-4: Non-existent job operations and boundary safety', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // 1. Adding comment to non-existent job does not throw
      final phantomComment = JobComment(
        id: 'comment_phantom',
        authorName: 'Ghost',
        authorAvatar: '',
        text: 'I do not exist',
        createdAt: DateTime.now(),
        isVerifiedPro: false,
      );
      await repo.addComment('job_non_existent_9999', phantomComment);
      expect(repo.getCommentsForJob('job_non_existent_9999'), isEmpty);

      // 2. Deleting non-existent job does not throw
      expect(() => repo.deleteJob('job_non_existent_9999'), returnsNormally);

      // 3. Toggling like on non-existent job does not throw
      expect(() => repo.toggleLike('job_non_existent_9999'), returnsNormally);
      expect(() => repo.toggleJobLike('job_non_existent_9999'), returnsNormally);

      // 4. Toggling save on non-existent job does not throw
      expect(() => repo.toggleSave('job_non_existent_9999'), returnsNormally);

      repo.dispose();
    });

    test('STRESS-5: Concurrent comment writes across multiple jobs and reload verification', () async {
      final repo1 = await TestHarness.createSession(isLoggedIn: true);

      // Create two distinct jobs
      final jobX = DetailJob(
        id: 'job_concurrent_x',
        author: repo1.currentUser,
        createdAt: DateTime.now(),
        title: 'Concurrent Job X',
        description: 'Testing concurrent writes',
        vehicleYear: 2024,
        vehicleMake: 'Porsche',
        vehicleModel: 'Cayman GT4',
        paintColorName: 'Shark Blue',
        paintCode: 'D5C',
        paintHardness: PaintHardness.medium,
        initialPaintThicknessMicrons: 120.0,
        finalPaintThicknessMicrons: 118.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 90,
        serviceType: 'Polish',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 4.0,
        quotedPrice: 600.0,
        likesCount: 5,
        isLiked: false,
        savesCount: 1,
        isSaved: false,
        comments: const [],
      );

      final jobY = DetailJob(
        id: 'job_concurrent_y',
        author: repo1.currentUser,
        createdAt: DateTime.now(),
        title: 'Concurrent Job Y',
        description: 'Testing concurrent writes',
        vehicleYear: 2023,
        vehicleMake: 'BMW',
        vehicleModel: 'M4 CSL',
        paintColorName: 'Frozen Brooklyn Grey',
        paintCode: 'C4P',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 130.0,
        finalPaintThicknessMicrons: 127.0,
        defectSeverity: 2,
        defectStage: DefectStage.stage2,
        correctionPercentage: 92,
        serviceType: 'Correction',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 6.0,
        quotedPrice: 950.0,
        likesCount: 8,
        isLiked: false,
        savesCount: 2,
        isSaved: false,
        comments: const [],
      );

      repo1.addJob(jobX);
      repo1.addJob(jobY);

      // Dispatch comments to jobX and jobY in interleaved / concurrent fashion
      final commentsX = List.generate(3, (i) => JobComment(
        id: 'comment_cx_$i',
        authorName: 'Concurrent User X$i',
        authorAvatar: '',
        text: 'Interleaved comment X #$i',
        createdAt: DateTime.utc(2026, 10, 16, 12, i, 0),
        isVerifiedPro: true,
      ));

      final commentsY = List.generate(3, (i) => JobComment(
        id: 'comment_cy_$i',
        authorName: 'Concurrent User Y$i',
        authorAvatar: '',
        text: 'Interleaved comment Y #$i',
        createdAt: DateTime.utc(2026, 10, 16, 12, 10 + i, 0),
        isVerifiedPro: false,
      ));

      // Interleave calls sequentially to stress sequential pipeline
      for (int i = 0; i < 3; i++) {
        await repo1.addComment(jobX.id, commentsX[i]);
        await repo1.addComment(jobY.id, commentsY[i]);
      }

      // Simulate browser reload
      repo1.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      final reloadedX = repo2.allJobs.firstWhere((j) => j.id == jobX.id);
      final reloadedY = repo2.allJobs.firstWhere((j) => j.id == jobY.id);

      expect(reloadedX.comments.length, equals(3));
      expect(reloadedY.comments.length, equals(3));

      for (int i = 0; i < 3; i++) {
        expect(reloadedX.comments.any((c) => c.id == commentsX[i].id), isTrue);
        expect(reloadedY.comments.any((c) => c.id == commentsY[i].id), isTrue);
      }

      repo2.dispose();
    });

    test('STRESS-6: Like and save count underflow protection and boundary check', () async {
      final repo = await TestHarness.createSession(isLoggedIn: true);

      // Custom job with 0 likes and 0 saves
      final zeroJob = DetailJob(
        id: 'job_zero_counts',
        author: repo.currentUser,
        createdAt: DateTime.now(),
        title: 'Zero Counts Job',
        description: 'Testing lower bound clamping',
        vehicleYear: 2021,
        vehicleMake: 'Tesla',
        vehicleModel: 'Model 3 Performance',
        paintColorName: 'Pearl White',
        paintCode: 'PPSW',
        paintHardness: PaintHardness.soft,
        initialPaintThicknessMicrons: 100.0,
        finalPaintThicknessMicrons: 98.0,
        defectSeverity: 1,
        defectStage: DefectStage.stage1,
        correctionPercentage: 85,
        serviceType: '1-Step Polish',
        recipeStages: const [],
        beforeImageUrl: '',
        afterImageUrl: '',
        beforePhotos: const [],
        afterPhotos: const [],
        mediaZones: const [],
        durationHours: 3.0,
        quotedPrice: 350.0,
        likesCount: 0,
        isLiked: false,
        savesCount: 0,
        isSaved: false,
        comments: const [],
      );

      repo.addJob(zeroJob);
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).likesCount, equals(0));
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).savesCount, equals(0));

      // Toggle like ON then OFF: likesCount should be 1 then 0, never negative
      repo.toggleLike(zeroJob.id);
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).likesCount, equals(1));
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).isLiked, isTrue);

      repo.toggleLike(zeroJob.id);
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).likesCount, equals(0));
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).isLiked, isFalse);

      // Toggle save ON then OFF: savesCount should be 1 then 0, never negative
      repo.toggleSave(zeroJob.id);
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).savesCount, equals(1));
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).isSaved, isTrue);

      repo.toggleSave(zeroJob.id);
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).savesCount, equals(0));
      expect(repo.allJobs.firstWhere((j) => j.id == zeroJob.id).isSaved, isFalse);

      // Reload and verify 0 counts persist cleanly
      repo.dispose();
      final repo2 = JobRepository();
      await repo2.init();

      final reloadedZero = repo2.allJobs.firstWhere((j) => j.id == zeroJob.id);
      expect(reloadedZero.likesCount, equals(0));
      expect(reloadedZero.isLiked, isFalse);
      expect(reloadedZero.savesCount, equals(0));
      expect(reloadedZero.isSaved, isFalse);

      repo2.dispose();
    });
  });
}
