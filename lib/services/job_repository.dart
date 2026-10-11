import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detail_job.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../models/user_vehicle.dart';
import '../models/message_model.dart';
import '../models/inventory_item.dart';
import '../core/constants/detailing_presets.dart';
import 'mock_data_service.dart';
import 'local_storage_service.dart';
import 'supabase_auth_service.dart';
import 'supabase_db_service.dart';
import 'supabase_service.dart';
import 'r2_storage_service.dart';
import '../models/calendar_availability_block.dart';

class JobRepository extends ChangeNotifier {
  List<DetailJob> _jobs = MockDataService.getInitialJobs();
  List<BookingAppointment> _bookings = [];
  List<UserProfile> _publicDetailers = List.from(MockDataService.publicDetailers);
  UserProfile _currentUser = MockDataService.youUser; // Default fallback
  List<StudioRecipePreset> _customPresets = [];
  List<InventoryItem> _inventoryItems = MockDataService.getInitialInventory();
  List<CalendarAvailabilityBlock> _availabilityBlocks = [];
  DetailerCalendarPreferences _calendarPreferences = DetailerCalendarPreferences.defaults();
  final Map<String, DetailerCalendarPreferences> _detailerPreferencesMap = {};

  String _selectedServiceType = 'All Services';
  String _selectedLocationCity = 'All Locations';
  String _searchQuery = '';
  int _activeTabIndex = 0;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  // Messaging state
  List<Conversation> _conversations = [];
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _jobsChannel;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _interactionsChannel;

  JobRepository() {
    init();
  }

  bool get isInitialized => _isInitialized;
  // ignore: unnecessary_getters_setters
  bool get isLoggedIn => _isLoggedIn;
  // ignore: unnecessary_getters_setters
  set isLoggedIn(bool value) => _isLoggedIn = value;
  bool get isGuestMode => !_isLoggedIn;
  int get activeTabIndex => _activeTabIndex;

  Future<void> init() async {
    if (_isInitialized) return;

    _jobs = MockDataService.getInitialJobs();
    _bookings = MockDataService.getInitialBookings();
    _publicDetailers = List.from(MockDataService.publicDetailers);

    // 1. Load active tab index
    _activeTabIndex = await LocalStorageService.loadActiveTab();

    // 2. Check auth state (Supabase or stored session)
    final isGuest = await LocalStorageService.loadIsGuest();
    final savedUser = await LocalStorageService.loadCurrentUser();

    if (!isGuest && savedUser != null) {
      _currentUser = savedUser;
      _isLoggedIn = true;
    } else if (SupabaseAuthService.isLoggedIn) {
      // Supabase persistent session found
      final authUser = SupabaseAuthService.currentAuthUser!;
      _currentUser = savedUser ?? UserProfile(
        id: authUser.id,
        username: authUser.email?.split('@').first ?? 'user',
        displayName: (authUser.userMetadata?['display_name'] as String?) ?? 'Vehicle Owner',
        businessName: 'My Detailing Studio',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
        location: 'Austin, Texas',
        bio: 'Car enthusiast & detailing craft connoisseur.',
      );
      _isLoggedIn = true;
      await LocalStorageService.saveIsGuest(false);
    } else {
      _isLoggedIn = false;
    }

    // 3. Load persistent custom transformation jobs from local cache first
    final customJobs = await LocalStorageService.loadCustomJobs();
    if (customJobs.isNotEmpty) {
      final existingIds = customJobs.map((j) => j.id).toSet();
      _jobs = [
        ...customJobs,
        ...MockDataService.getInitialJobs().where((j) => !existingIds.contains(j.id)),
      ];
    } else {
      _jobs = MockDataService.getInitialJobs();
    }

    // 4. Load persistent bookings from local cache
    final savedBookings = await LocalStorageService.loadBookings();
    if (savedBookings != null) {
      _bookings = savedBookings;
    }

    // 4b. Load custom recipe presets from local cache
    _customPresets = await LocalStorageService.loadCustomPresets();

    // 4c. Load inventory items from local cache
    final savedInventory = await LocalStorageService.loadInventoryItems();
    if (savedInventory != null) {
      _inventoryItems = savedInventory;
    } else {
      _inventoryItems = MockDataService.getInitialInventory();
    }

    // 4d. Load calendar availability blocks and preferences
    final savedBlocks = await LocalStorageService.loadAvailabilityBlocks();
    if (savedBlocks != null) {
      _availabilityBlocks = savedBlocks;
    }
    final savedPrefs = await LocalStorageService.loadCalendarPreferences();
    if (savedPrefs != null) {
      _calendarPreferences = savedPrefs;
    }

    // 5. Load persistent likes & bookmarks from local cache
    final interaction = await LocalStorageService.loadInteractionState();
    if (interaction.likedJobIds.isNotEmpty || interaction.savedJobIds.isNotEmpty) {
      _jobs = _jobs.map((job) {
        final isLiked = interaction.likedJobIds.contains(job.id);
        final isSaved = interaction.savedJobIds.contains(job.id);
        return job.copyWith(
          isLiked: isLiked,
          isSaved: isSaved,
        );
      }).toList();
    }

    // 6. Synchronous hydration from Supabase Cloud:
    // Await cloud hydration before marking initialization complete so a secondary device
    // immediately displays all synced profile info, custom published jobs, bookings, and likes/saves.
    if (_isLoggedIn) {
      try {
        await Future.wait([
          _refreshProfileFromCloud(_currentUser.id),
          _refreshJobsFromCloud(),
          _refreshBookingsFromCloud(_currentUser.id),
          _refreshInteractionsFromCloud(_currentUser.id),
        ]).timeout(const Duration(seconds: 4));
      } catch (_) {
        // Fallback to local cache if offline or slow network
      }
    } else {
      // For guest visitors, refresh community jobs in the background
      _refreshJobsFromCloud();
    }

    // 7. Load persistent messages & conversations
    loadConversations();

    // 8. Subscribe to realtime channels if logged in
    if (_isLoggedIn) {
      _subscribeToRealtime();
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _refreshProfileFromCloud(String userId) async {
    try {
      final cloudProfile = await SupabaseDbService.fetchUserProfile(userId);
      if (cloudProfile != null) {
        _currentUser = cloudProfile;
        await LocalStorageService.saveCurrentUser(cloudProfile);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _refreshJobsFromCloud() async {
    try {
      final cloudJobs = await SupabaseDbService.fetchJobs();
      if (cloudJobs.isNotEmpty) {
        final Map<String, DetailJob> jobMap = {};
        // 1. Existing local jobs
        for (final job in _jobs) {
          jobMap[job.id] = job;
        }
        // 2. Cloud jobs overwrite stale local copies
        for (final cJob in cloudJobs) {
          final existing = jobMap[cJob.id];
          if (existing != null) {
            jobMap[cJob.id] = cJob.copyWith(
              isLiked: existing.isLiked,
              isSaved: existing.isSaved,
            );
          } else {
            jobMap[cJob.id] = cJob;
          }
        }
        _jobs = jobMap.values.toList();
        _jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _persistCustomJobs();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _refreshBookingsFromCloud(String userId) async {
    try {
      final cloudBookings = await SupabaseDbService.fetchBookings(userId);
      if (cloudBookings.isNotEmpty) {
        final Map<String, BookingAppointment> map = {
          for (final b in _bookings) b.id: b,
        };
        for (final cb in cloudBookings) {
          map[cb.id] = cb;
        }
        _bookings = map.values.toList()
          ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        LocalStorageService.saveBookings(_bookings);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _refreshInteractionsFromCloud(String userId) async {
    try {
      final interactions = await SupabaseDbService.fetchUserInteractions(userId);
      if (interactions != null) {
        final liked = interactions.likedJobIds;
        final saved = interactions.savedJobIds;
        _jobs = _jobs.map((job) {
          final isLiked = liked.contains(job.id);
          final isSaved = saved.contains(job.id);
          return job.copyWith(
            isLiked: isLiked,
            isSaved: isSaved,
          );
        }).toList();
        await LocalStorageService.saveInteractionState(likedJobIds: liked, savedJobIds: saved);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loginUser(UserProfile user) async {
    _currentUser = user;
    _isLoggedIn = true;
    await LocalStorageService.saveIsGuest(false);

    // 1. Fetch latest profile state from cloud FIRST
    // This ensures cloud garage, team, bio, packages are loaded onto this device
    await _refreshProfileFromCloud(user.id);
    await LocalStorageService.saveCurrentUser(_currentUser);

    // 2. Refresh jobs from cloud
    await _refreshJobsFromCloud();

    // 3. Refresh conversations
    await loadConversations();

    // 4. Refresh bookings and interactions from cloud
    await _refreshBookingsFromCloud(user.id);
    await _refreshInteractionsFromCloud(user.id);

    // 5. Subscribe to realtime channels
    _subscribeToRealtime();

    notifyListeners();
  }

  Future<void> logoutUser() async {
    _unsubscribeFromRealtime();
    await SupabaseAuthService.signOut();
    await LocalStorageService.logoutSession();
    _isLoggedIn = false;
    _currentUser = MockDataService.youUser;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _unsubscribeFromRealtime();
    final userId = _currentUser.id;
    await SupabaseAuthService.signOut();
    await LocalStorageService.deleteAccountData(userId);
    _isLoggedIn = false;
    _currentUser = MockDataService.youUser;
    notifyListeners();
  }

  void setActiveTab(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      LocalStorageService.saveActiveTab(index);
      notifyListeners();
    }
  }

  void _persistUser() {
    if (_isLoggedIn) {
      // 1. Save to local storage for fast offline cache
      LocalStorageService.saveCurrentUser(_currentUser);
      // 2. Sync to Supabase Database
      SupabaseDbService.saveUserProfile(_currentUser);
    }
  }

  void _persistBookings() {
    LocalStorageService.saveBookings(_bookings);
  }

  void _persistCustomJobs() {
    // Only persist jobs that are custom user jobs (not initial mock ids or created by current user)
    final mockIds = MockDataService.getInitialJobs().map((j) => j.id).toSet();
    final customJobs = _jobs.where((j) => !mockIds.contains(j.id)).toList();
    LocalStorageService.saveCustomJobs(customJobs);
  }

  void _persistInteractions() {
    final liked = _jobs.where((j) => j.isLiked).map((j) => j.id).toSet();
    final saved = _jobs.where((j) => j.isSaved).map((j) => j.id).toSet();
    LocalStorageService.saveInteractionState(likedJobIds: liked, savedJobIds: saved);
    if (_isLoggedIn) {
      SupabaseDbService.saveUserInteractions(
        userId: _currentUser.id,
        likedJobIds: liked,
        savedJobIds: saved,
      );
    }
  }

  // Studio Recipe Presets (System presets + User custom presets)
  List<StudioRecipePreset> get allRecipePresets => [
    ...DetailingPresets.recipePresets,
    ..._customPresets,
  ];

  List<StudioRecipePreset> get customPresets => List.unmodifiable(_customPresets);

  void saveRecipePreset(StudioRecipePreset preset) {
    final existingIdx = _customPresets.indexWhere((p) => p.id == preset.id);
    if (existingIdx != -1) {
      _customPresets[existingIdx] = preset;
    } else {
      _customPresets.add(preset);
    }
    LocalStorageService.saveCustomPresets(_customPresets);
    notifyListeners();
  }

  void deleteRecipePreset(String presetId) {
    _customPresets.removeWhere((p) => p.id == presetId);
    LocalStorageService.saveCustomPresets(_customPresets);
    notifyListeners();
  }

  // Inventory Getters & Actions (Hardware, Chemicals, Recipes)
  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);
  List<InventoryItem> get hardwareItems => _inventoryItems.where((i) => i.category == InventoryCategory.hardware).toList();
  List<InventoryItem> get chemicalItems => _inventoryItems.where((i) => i.category == InventoryCategory.chemicals).toList();
  List<InventoryItem> get recipeItems => _inventoryItems.where((i) => i.category == InventoryCategory.recipe).toList();

  void addInventoryItem(InventoryItem item) {
    _inventoryItems.insert(0, item);
    LocalStorageService.saveInventoryItems(_inventoryItems);
    notifyListeners();
  }

  void updateInventoryItem(InventoryItem updated) {
    final idx = _inventoryItems.indexWhere((i) => i.id == updated.id);
    if (idx != -1) {
      _inventoryItems[idx] = updated;
      LocalStorageService.saveInventoryItems(_inventoryItems);
      notifyListeners();
    }
  }

  void removeInventoryItem(String itemId) {
    _inventoryItems.removeWhere((i) => i.id == itemId);
    LocalStorageService.saveInventoryItems(_inventoryItems);
    notifyListeners();
  }

  // Getters
  List<DetailJob> get jobs => _jobs;
  List<BookingAppointment> get bookings => _bookings;
  List<CalendarAvailabilityBlock> get availabilityBlocks => List.unmodifiable(_availabilityBlocks);
  DetailerCalendarPreferences get calendarPreferences => _calendarPreferences;
  
  // All public detailers including the current user when registered/logged in!
  List<UserProfile> get publicDetailers {
    final list = List<UserProfile>.from(_publicDetailers);
    if (_isLoggedIn && _currentUser.location.isNotEmpty) {
      final existingIndex = list.indexWhere((p) => p.id == _currentUser.id);
      if (existingIndex != -1) {
        list[existingIndex] = _currentUser;
      } else {
        list.insert(0, _currentUser);
      }
    }
    return list;
  }

  UserProfile get currentUser => _currentUser;

  String get selectedServiceType => _selectedServiceType;
  String get selectedLocationCity => _selectedLocationCity;
  String get searchQuery => _searchQuery;

  // Active cities with detailers & users (Always includes registered user's location!)
  List<String> get activeCitiesWithDetailers {
    final cities = <String>{'All Locations'};
    for (final d in _publicDetailers) {
      if (d.location.isNotEmpty) cities.add(d.location);
    }
    if (_currentUser.location.isNotEmpty) {
      cities.add(_currentUser.location);
    }
    return cities.toList();
  }

  List<DetailJob> get filteredJobs {
    final list = _jobs.where((job) {
      if (_selectedServiceType != 'All Services' &&
          !job.serviceType.toLowerCase().contains(_selectedServiceType.toLowerCase())) {
        return false;
      }

      if (_selectedLocationCity != 'All Locations' &&
          !job.author.location.toLowerCase().contains(_selectedLocationCity.toLowerCase())) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchVehicle = job.vehicleFullName.toLowerCase().contains(q);
        final matchColor = job.paintColorName.toLowerCase().contains(q);
        final matchTitle = job.title.toLowerCase().contains(q);
        final matchAuthor = job.author.displayName.toLowerCase().contains(q);
        final matchBusiness = job.author.businessName.toLowerCase().contains(q);
        final matchLocation = job.author.location.toLowerCase().contains(q);

        if (!matchVehicle && !matchColor && !matchTitle && !matchAuthor && !matchBusiness && !matchLocation) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort jobs by recency combined with detailer composite rank weight
    list.sort((a, b) {
      final scoreA = a.createdAt.millisecondsSinceEpoch + (calculateDetailerCompositeScore(a.author) * 86400000);
      final scoreB = b.createdAt.millisecondsSinceEpoch + (calculateDetailerCompositeScore(b.author) * 86400000);
      return scoreB.compareTo(scoreA);
    });

    return list;
  }

  /// Calculates a detailer's Weighted Composite Rank Score for Explore Feed ranking.
  /// Combines: Rating (45%), Activity/Recency (25%), Verification (20%), Certifications (10%).
  double calculateDetailerCompositeScore(UserProfile detailer) {
    double score = 0.0;

    // 1. Rating & Review Volume (0 - 8.0 pts)
    score += (detailer.averageRating.clamp(0.0, 5.0)) * 1.4;
    if (detailer.reviewCount > 0) {
      score += (detailer.reviewCount.clamp(0, 100) / 10.0);
    }

    // 2. Verified Host Status (+2.0 pts)
    if (detailer.isVerifiedHost) {
      score += 2.0;
    }

    // 3. Certifications (+0.5 pts per cert, max +2.0 pts)
    score += (detailer.certifications.length * 0.5).clamp(0.0, 2.0);

    // 4. Recency & Activity (+0.5 pts per job, +2.5 pts if posted in last 7 days)
    final detailerJobs = _jobs.where((j) => j.author.id == detailer.id).toList();
    score += (detailerJobs.length * 0.5).clamp(0.0, 3.0);
    if (detailerJobs.isNotEmpty) {
      detailerJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final daysAgo = DateTime.now().difference(detailerJobs.first.createdAt).inDays;
      if (daysAgo <= 7) {
        score += 2.5;
      } else if (daysAgo <= 30) {
        score += 1.0;
      }
    }

    return score;
  }

  // Filtered detailers list for Explore search, sorted descending by Composite Rank Score
  List<UserProfile> get filteredDetailers {
    final list = publicDetailers.where((detailer) {
      if (_selectedLocationCity != 'All Locations' &&
          !detailer.location.toLowerCase().contains(_selectedLocationCity.toLowerCase())) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = detailer.displayName.toLowerCase().contains(q);
        final matchBusiness = detailer.businessName.toLowerCase().contains(q);
        final matchLocation = detailer.location.toLowerCase().contains(q);
        final matchBio = detailer.bio.toLowerCase().contains(q);

        if (!matchName && !matchBusiness && !matchLocation && !matchBio) {
          return false;
        }
      }

      return true;
    }).toList();

    // Rank detailers descending by Composite Score
    list.sort((a, b) => calculateDetailerCompositeScore(b).compareTo(calculateDetailerCompositeScore(a)));
    return list;
  }

  List<DetailJob> get savedJobs => _jobs.where((j) => j.isSaved).toList();

  List<DetailJob> getJobsByDetailer(String detailerId) {
    return _jobs.where((j) => j.author.id == detailerId).toList();
  }

  // Actions
  void setServiceFilter(String serviceType) {
    _selectedServiceType = serviceType;
    notifyListeners();
  }

  void setLocationFilter(String city) {
    _selectedLocationCity = city;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedServiceType = 'All Services';
    _selectedLocationCity = 'All Locations';
    _searchQuery = '';
    notifyListeners();
  }

  // Verification queue for Back Office admins
  List<VerificationRequest> _verificationRequests = [
    VerificationRequest(
      id: 'ver_sample_01',
      userId: 'usr_diego',
      detailerName: 'Diego Morales',
      businessName: 'Morales Elite Mobile Detail',
      docType: 'insurance',
      docUrl: 'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=800&auto=format&fit=crop&q=80',
      policyOrCertNumber: 'HISCOX-GK-99210-TX',
      status: VerificationStatus.pending,
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    VerificationRequest(
      id: 'ver_sample_02',
      userId: 'usr_marcus',
      detailerName: 'Marcus Vance',
      businessName: 'Apex Gloss Lab & Mobile',
      docType: 'ida_certification',
      docUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&auto=format&fit=crop&q=80',
      policyOrCertNumber: 'IDA-CDSV-2024-88',
      status: VerificationStatus.approved,
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      reviewedAt: DateTime.now().subtract(const Duration(days: 1)),
      reviewerNotes: 'Official IDA credential validated with registry.',
    ),
  ];

  List<VerificationRequest> get verificationRequests => _verificationRequests;

  Future<void> loadVerificationRequests() async {
    if (_isLoggedIn) {
      final cloudList = await SupabaseDbService.fetchVerificationRequests();
      if (cloudList.isNotEmpty) {
        _verificationRequests = cloudList;
        notifyListeners();
      }
    }
  }

  Future<void> submitDetailerVerification({
    required String docType,
    required String docUrl,
    required String policyOrCertNumber,
  }) async {
    final req = VerificationRequest(
      id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
      userId: _currentUser.id,
      detailerName: _currentUser.displayName,
      businessName: _currentUser.businessName,
      docType: docType,
      docUrl: docUrl,
      policyOrCertNumber: policyOrCertNumber,
      status: VerificationStatus.pending,
      submittedAt: DateTime.now(),
    );

    _verificationRequests.insert(0, req);
    if (_isLoggedIn) {
      await SupabaseDbService.submitVerificationRequest(req);
    }
    notifyListeners();
  }

  Future<void> reviewVerification({
    required String requestId,
    required String detailerUserId,
    required String docType,
    required VerificationStatus newStatus,
    required String notes,
  }) async {
    final idx = _verificationRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final old = _verificationRequests[idx];
      _verificationRequests[idx] = VerificationRequest(
        id: old.id,
        userId: old.userId,
        detailerName: old.detailerName,
        businessName: old.businessName,
        docType: old.docType,
        docUrl: old.docUrl,
        policyOrCertNumber: old.policyOrCertNumber,
        status: newStatus,
        reviewerNotes: notes,
        submittedAt: old.submittedAt,
        reviewedAt: DateTime.now(),
      );

      // If approved, update in-memory detailer profile badges
      if (newStatus == VerificationStatus.approved) {
        if (_currentUser.id == detailerUserId) {
          _currentUser = _currentUser.copyWith(
            isInsuranceVerified: docType == 'insurance' ? true : _currentUser.isInsuranceVerified,
            isIdaCertified: docType == 'ida_certification' ? true : _currentUser.isIdaCertified,
          );
          _persistUser();
        }

        final pIdx = _publicDetailers.indexWhere((p) => p.id == detailerUserId);
        if (pIdx != -1) {
          _publicDetailers[pIdx] = _publicDetailers[pIdx].copyWith(
            isInsuranceVerified: docType == 'insurance' ? true : _publicDetailers[pIdx].isInsuranceVerified,
            isIdaCertified: docType == 'ida_certification' ? true : _publicDetailers[pIdx].isIdaCertified,
          );
        }
      }

      if (_isLoggedIn) {
        await SupabaseDbService.reviewVerificationRequest(
          requestId: requestId,
          detailerUserId: detailerUserId,
          docType: docType,
          newStatus: newStatus,
          reviewerNotes: notes,
        );
      }
      notifyListeners();
    }
  }

  // Detailer / Host Promotion / Mode Toggle
  void toggleHostMode() {
    final isNowHost = _currentUser.role == UserRole.client;
    _currentUser = _currentUser.copyWith(
      role: isNowHost ? UserRole.detailer : UserRole.client,
      isVerifiedHost: isNowHost,
    );
    _persistUser();
    notifyListeners();
  }

  // Update profile details (bio, business name, phone, etc.)
  void updateCurrentUser(UserProfile updated) {
    _currentUser = updated;
    _persistUser();
    notifyListeners();
  }

  // Add / Edit / Remove vehicle in user's garage (Persisted)
  void addVehicleToGarage(UserVehicle vehicle) {
    _currentUser = _currentUser.copyWith(
      myGarage: [..._currentUser.myGarage, vehicle],
    );
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.saveVehicle(_currentUser.id, vehicle);
    }
    notifyListeners();
  }

  void updateVehicleInGarage(UserVehicle updated) {
    final idx = _currentUser.myGarage.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      final list = List<UserVehicle>.from(_currentUser.myGarage);
      list[idx] = updated;
      _currentUser = _currentUser.copyWith(myGarage: list);
      _persistUser();
      if (_isLoggedIn) {
        SupabaseDbService.saveVehicle(_currentUser.id, updated);
      }
      notifyListeners();
    }
  }

  void removeVehicleFromGarage(String vehicleId) {
    _currentUser = _currentUser.copyWith(
      myGarage: _currentUser.myGarage.where((v) => v.id != vehicleId).toList(),
    );
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.deleteVehicle(vehicleId);
    }
    notifyListeners();
  }

  // Add a hired team member under your company profile (Detailer mode - Persisted)
  void addTeamMember(TeamMember member) {
    _currentUser = _currentUser.copyWith(
      teamMembers: [..._currentUser.teamMembers, member],
    );
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.saveTeamMember(_currentUser.id, member);
    }
    notifyListeners();
  }

  void removeTeamMember(String memberId) {
    _currentUser = _currentUser.copyWith(
      teamMembers: _currentUser.teamMembers.where((m) => m.id != memberId).toList(),
    );
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.deleteTeamMember(memberId);
    }
    notifyListeners();
  }

  void updateTeamMember(TeamMember updated) {
    final idx = _currentUser.teamMembers.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      final list = List<TeamMember>.from(_currentUser.teamMembers);
      list[idx] = updated;
      _currentUser = _currentUser.copyWith(teamMembers: list);
      _persistUser();
      if (_isLoggedIn) {
        SupabaseDbService.saveTeamMember(_currentUser.id, updated);
      }
      notifyListeners();
    }
  }

  // Add / Edit / Remove Service Package (Persisted)
  void addServicePackage(ServicePackage package) {
    _currentUser = _currentUser.copyWith(
      servicePackages: [..._currentUser.servicePackages, package],
    );
    _persistUser();
    notifyListeners();
  }

  void updateServicePackage(ServicePackage updated) {
    final idx = _currentUser.servicePackages.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      final list = List<ServicePackage>.from(_currentUser.servicePackages);
      list[idx] = updated;
      _currentUser = _currentUser.copyWith(servicePackages: list);
      _persistUser();
      notifyListeners();
    }
  }

  void removeServicePackage(String packageId) {
    _currentUser = _currentUser.copyWith(
      servicePackages: _currentUser.servicePackages.where((p) => p.id != packageId).toList(),
    );
    _persistUser();
    notifyListeners();
  }

  void toggleLike(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      final job = _jobs[idx];
      _jobs[idx] = job.copyWith(
        isLiked: !job.isLiked,
        likesCount: job.isLiked ? job.likesCount - 1 : job.likesCount + 1,
      );
      _persistInteractions();
      notifyListeners();
    }
  }

  void toggleSave(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      final job = _jobs[idx];
      _jobs[idx] = job.copyWith(
        isSaved: !job.isSaved,
        savesCount: job.isSaved ? job.savesCount - 1 : job.savesCount + 1,
      );
      _persistInteractions();
      notifyListeners();
    }
  }

  void addJob(DetailJob newJob) {
    _jobs.insert(0, newJob);
    _persistCustomJobs();
    if (_isLoggedIn) {
      SupabaseDbService.saveJob(newJob);
    }
    if (_currentUser.id == newJob.author.id) {
      _currentUser = _currentUser.copyWith(
        totalJobsCount: _currentUser.totalJobsCount + 1,
      );
      _persistUser();
    }
    notifyListeners();
  }

  void updateJob(DetailJob updatedJob) {
    final idx = _jobs.indexWhere((j) => j.id == updatedJob.id);
    if (idx != -1) {
      _jobs[idx] = updatedJob;
      _persistCustomJobs();
      if (_isLoggedIn) {
        SupabaseDbService.saveJob(updatedJob);
      }
      notifyListeners();
    }
  }

  /// Appends a comment to a job and persists to Supabase.
  void addComment(String jobId, JobComment comment) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;
    final updatedJob = _jobs[idx].copyWith(
      comments: [..._jobs[idx].comments, comment],
    );
    updateJob(updatedJob);
  }

  void deleteJob(String jobId) {
    final jobMatches = _jobs.where((j) => j.id == jobId);
    final DetailJob? jobToDelete = jobMatches.isNotEmpty ? jobMatches.first : null;

    _jobs.removeWhere((j) => j.id == jobId);
    _persistCustomJobs();

    if (_isLoggedIn) {
      SupabaseDbService.deleteJob(jobId);
    }

    // Permanently purge all associated images from Cloudflare R2
    if (jobToDelete != null) {
      final List<String> imageUrlsToPurge = [];
      if (jobToDelete.beforeImageUrl.isNotEmpty) imageUrlsToPurge.add(jobToDelete.beforeImageUrl);
      if (jobToDelete.afterImageUrl.isNotEmpty) imageUrlsToPurge.add(jobToDelete.afterImageUrl);
      imageUrlsToPurge.addAll(jobToDelete.beforePhotos);
      imageUrlsToPurge.addAll(jobToDelete.afterPhotos);
      for (final zone in jobToDelete.mediaZones) {
        if (zone.beforeImageUrl.isNotEmpty) imageUrlsToPurge.add(zone.beforeImageUrl);
        if (zone.afterImageUrl.isNotEmpty) imageUrlsToPurge.add(zone.afterImageUrl);
      }

      if (imageUrlsToPurge.isNotEmpty) {
        R2StorageService.deleteImages(imageUrlsToPurge);
      }
    }

    if (jobToDelete != null && _currentUser.id == jobToDelete.author.id && _currentUser.totalJobsCount > 0) {
      _currentUser = _currentUser.copyWith(
        totalJobsCount: _currentUser.totalJobsCount - 1,
      );
      _persistUser();
    }
    notifyListeners();
  }

  void addBooking(BookingAppointment booking) {
    _bookings.insert(0, booking);
    _persistBookings();
    if (_isLoggedIn) {
      SupabaseDbService.saveBooking(booking);
    }
    notifyListeners();
  }

  void updateBookingStatus(String bookingId, BookingStatus newStatus) {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final b = _bookings[idx];
      _bookings[idx] = BookingAppointment(
        id: b.id,
        clientId: b.clientId,
        detailerId: b.detailerId,
        detailerName: b.detailerName,
        detailerBusinessName: b.detailerBusinessName,
        detailerAvatar: b.detailerAvatar,
        clientName: b.clientName,
        clientPhone: b.clientPhone,
        clientEmail: b.clientEmail,
        vehicleYearMakeModel: b.vehicleYearMakeModel,
        vehicleSize: b.vehicleSize,
        package: b.package,
        locationType: b.locationType,
        clientAddress: b.clientAddress,
        scheduledDate: b.scheduledDate,
        scheduledTimeSlot: b.scheduledTimeSlot,
        totalPrice: b.totalPrice,
        depositAmount: b.depositAmount,
        status: newStatus,
        clientNotes: b.clientNotes,
        preInspectionSummary: b.preInspectionSummary,
        warrantyPassportId: b.warrantyPassportId,
      );
      _persistBookings();
      if (_isLoggedIn) {
        SupabaseDbService.updateBookingStatus(bookingId, newStatus);
      }
      notifyListeners();
    }
  }

  // ─── CALENDAR & AVAILABILITY ────────────────────────────────────────────────

  void updateCalendarPreferences(DetailerCalendarPreferences preferences, {String? detailerId}) {
    _calendarPreferences = preferences;
    if (detailerId != null) {
      _detailerPreferencesMap[detailerId] = preferences;
    }
    _detailerPreferencesMap[_currentUser.id] = preferences;
    LocalStorageService.saveCalendarPreferences(preferences);
    notifyListeners();
  }

  DetailerCalendarPreferences getCalendarPreferences({String? detailerId}) {
    if (detailerId != null && _detailerPreferencesMap.containsKey(detailerId)) {
      return _detailerPreferencesMap[detailerId]!;
    }
    return _calendarPreferences;
  }

  void addAvailabilityBlock(CalendarAvailabilityBlock block) {
    _availabilityBlocks.removeWhere(
      (b) => b.id == block.id ||
             (b.detailerId == block.detailerId &&
              b.date.year == block.date.year &&
              b.date.month == block.date.month &&
              b.date.day == block.date.day),
    );
    _availabilityBlocks.add(block);
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void removeAvailabilityBlock(String blockId) {
    _availabilityBlocks.removeWhere((b) => b.id == blockId);
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void toggleBlockDay(DateTime date, {String? reason, String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             b.isAllDay,
    );
    if (idx != -1) {
      final existing = _availabilityBlocks[idx];
      if (existing.hasCustomSlotsOverride || existing.customSlots.isNotEmpty) {
        _availabilityBlocks[idx] = existing.copyWith(isAllDay: false);
      } else {
        _availabilityBlocks.removeAt(idx);
      }
    } else {
      final existingIdx = _availabilityBlocks.indexWhere(
        (b) => b.detailerId == targetDetailerId &&
               b.date.year == normDate.year &&
               b.date.month == normDate.month &&
               b.date.day == normDate.day,
      );
      if (existingIdx != -1) {
        _availabilityBlocks[existingIdx] = _availabilityBlocks[existingIdx].copyWith(
          isAllDay: true,
          reason: reason,
        );
      } else {
        _availabilityBlocks.add(
          CalendarAvailabilityBlock(
            id: 'block_${DateTime.now().millisecondsSinceEpoch}',
            detailerId: targetDetailerId,
            date: normDate,
            isAllDay: true,
            reason: reason,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void toggleBlockSlot(DateTime date, String slot, {String? reason, String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day,
    );
    if (idx != -1) {
      final existing = _availabilityBlocks[idx];
      if (existing.isAllDay) {
        final currentSlots = getTimeSlotsForDate(date, detailerId: targetDetailerId);
        final remaining = currentSlots.where((s) => s != slot).toList();
        _availabilityBlocks[idx] = existing.copyWith(
          isAllDay: false,
          blockedSlots: remaining,
        );
      } else {
        final currentSlots = List<String>.from(existing.blockedSlots);
        if (currentSlots.contains(slot)) {
          currentSlots.remove(slot);
        } else {
          currentSlots.add(slot);
        }
        if (currentSlots.isEmpty && !existing.hasCustomSlotsOverride && existing.customSlots.isEmpty) {
          _availabilityBlocks.removeAt(idx);
        } else {
          _availabilityBlocks[idx] = existing.copyWith(
            blockedSlots: currentSlots,
            reason: reason ?? existing.reason,
          );
        }
      }
    } else {
      _availabilityBlocks.add(
        CalendarAvailabilityBlock(
          id: 'block_${DateTime.now().millisecondsSinceEpoch}',
          detailerId: targetDetailerId,
          date: normDate,
          isAllDay: false,
          blockedSlots: [slot],
          reason: reason,
          createdAt: DateTime.now(),
        ),
      );
    }
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  static String formatMinutesToTime(int totalMinutes) {
    int hour = (totalMinutes ~/ 60) % 24;
    int min = totalMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    final minStr = min == 0 ? '00' : (min < 10 ? '0$min' : '$min');
    return '$displayHour:$minStr $period';
  }

  static List<String> generateSlotsForHours({
    required String openTime,
    required String closeTime,
    int slotDurationHours = 3,
  }) {
    final openMin = timeStringToMinutes(openTime);
    final closeMin = timeStringToMinutes(closeTime);
    if (closeMin <= openMin) return [];

    final stepMin = (slotDurationHours <= 0 ? 3 : slotDurationHours) * 60;
    final List<String> result = [];
    int cur = openMin;

    while (cur < closeMin) {
      final end = (cur + stepMin <= closeMin) ? cur + stepMin : closeMin;
      result.add('${formatMinutesToTime(cur)} - ${formatMinutesToTime(end)}');
      cur += stepMin;
    }
    return result;
  }

  List<String> getTimeSlotsForDate(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final prefs = getCalendarPreferences(detailerId: targetDetailerId);
    final dayHours = getHoursForDate(date, detailerId: targetDetailerId);
    final normDate = DateTime(date.year, date.month, date.day);

    // 1. Check if date-specific custom slots override exists
    final specificBlockIdx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             (b.hasCustomSlotsOverride || b.customSlots.isNotEmpty),
    );
    if (specificBlockIdx != -1) {
      final specificBlock = _availabilityBlocks[specificBlockIdx];
      // Detailer explicitly configured slots for this specific date (even if empty)
      return List<String>.from(specificBlock.customSlots);
    }

    // 2. Base slots from preferences
    List<String> slots = List<String>.from(prefs.customTimeSlots);
    if (slots.isEmpty) {
      slots = List<String>.from(DetailerCalendarPreferences.defaultTimeSlots);
    }

    // 3. If open, ensure operating hours match
    if (dayHours.isOpen) {
      final openMin = timeStringToMinutes(dayHours.openTime);
      final closeMin = timeStringToMinutes(dayHours.closeTime);

      // If open time is earlier than the earliest slot, prepend morning slot(s)
      final earliestSlotMin = slots.isEmpty
          ? 1440
          : slots.map(timeStringToMinutes).reduce((a, b) => a < b ? a : b);
      if (openMin < earliestSlotMin) {
        int cur = openMin;
        final step = (prefs.slotDurationHours <= 0 ? 3 : prefs.slotDurationHours) * 60;
        final extra = <String>[];
        while (cur < earliestSlotMin) {
          final end = (cur + step <= closeMin) ? cur + step : closeMin;
          extra.add('${formatMinutesToTime(cur)} - ${formatMinutesToTime(end)}');
          cur += step;
        }
        slots = [...extra, ...slots];
      }

      // Filter slots that fall within operating hours
      final inHours = slots.where((s) => isSlotWithinOperatingHours(date, s, detailerId: targetDetailerId)).toList();
      if (inHours.isNotEmpty) {
        slots = inHours;
      } else {
        // If none of the configured slots fit, auto-generate for the hours
        slots = generateSlotsForHours(
          openTime: dayHours.openTime,
          closeTime: dayHours.closeTime,
          slotDurationHours: prefs.slotDurationHours,
        );
      }
    }

    // Deduplicate and sort chronologically
    final unique = slots.toSet().toList();
    unique.sort((a, b) => timeStringToMinutes(a).compareTo(timeStringToMinutes(b)));
    return unique;
  }

  void addCustomTimeSlot(String slot, {DateTime? specificDate, String? detailerId}) {
    final cleanSlot = slot.trim();
    if (cleanSlot.isEmpty) return;
    final targetDetailerId = detailerId ?? _currentUser.id;

    if (specificDate != null) {
      final normDate = DateTime(specificDate.year, specificDate.month, specificDate.day);
      final currentSlots = getTimeSlotsForDate(specificDate, detailerId: targetDetailerId);
      final list = List<String>.from(currentSlots);
      if (!list.contains(cleanSlot)) {
        list.add(cleanSlot);
        list.sort((a, b) => timeStringToMinutes(a).compareTo(timeStringToMinutes(b)));
      }

      final idx = _availabilityBlocks.indexWhere(
        (b) => b.detailerId == targetDetailerId &&
               b.date.year == normDate.year &&
               b.date.month == normDate.month &&
               b.date.day == normDate.day,
      );
      if (idx != -1) {
        final existing = _availabilityBlocks[idx];
        _availabilityBlocks[idx] = existing.copyWith(
          customSlots: list,
          hasCustomSlotsOverride: true,
        );
      } else {
        _availabilityBlocks.add(
          CalendarAvailabilityBlock(
            id: 'block_${DateTime.now().millisecondsSinceEpoch}',
            detailerId: targetDetailerId,
            date: normDate,
            isAllDay: false,
            customSlots: list,
            hasCustomSlotsOverride: true,
            createdAt: DateTime.now(),
          ),
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    } else {
      final prefs = getCalendarPreferences(detailerId: targetDetailerId);
      final list = List<String>.from(prefs.customTimeSlots);
      if (!list.contains(cleanSlot)) {
        list.add(cleanSlot);
        list.sort((a, b) => timeStringToMinutes(a).compareTo(timeStringToMinutes(b)));
        final updated = prefs.copyWith(customTimeSlots: list);
        updateCalendarPreferences(updated, detailerId: targetDetailerId);
      }
    }
    notifyListeners();
  }

  void updateCustomTimeSlot(String oldSlot, String newSlot, {DateTime? specificDate, String? detailerId}) {
    final cleanNew = newSlot.trim();
    if (cleanNew.isEmpty) return;
    final targetDetailerId = detailerId ?? _currentUser.id;

    if (specificDate != null) {
      final normDate = DateTime(specificDate.year, specificDate.month, specificDate.day);
      final currentSlots = getTimeSlotsForDate(specificDate, detailerId: targetDetailerId);
      final list = List<String>.from(currentSlots);
      final pos = list.indexOf(oldSlot);
      if (pos != -1) {
        list[pos] = cleanNew;
      } else {
        list.add(cleanNew);
      }
      list.sort((a, b) => timeStringToMinutes(a).compareTo(timeStringToMinutes(b)));

      final idx = _availabilityBlocks.indexWhere(
        (b) => b.detailerId == targetDetailerId &&
               b.date.year == normDate.year &&
               b.date.month == normDate.month &&
               b.date.day == normDate.day,
      );
      if (idx != -1) {
        final existing = _availabilityBlocks[idx];
        _availabilityBlocks[idx] = existing.copyWith(
          customSlots: list,
          hasCustomSlotsOverride: true,
        );
      } else {
        _availabilityBlocks.add(
          CalendarAvailabilityBlock(
            id: 'block_${DateTime.now().millisecondsSinceEpoch}',
            detailerId: targetDetailerId,
            date: normDate,
            isAllDay: false,
            customSlots: list,
            hasCustomSlotsOverride: true,
            createdAt: DateTime.now(),
          ),
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    } else {
      final prefs = getCalendarPreferences(detailerId: targetDetailerId);
      final list = List<String>.from(prefs.customTimeSlots);
      final pos = list.indexOf(oldSlot);
      if (pos != -1) {
        list[pos] = cleanNew;
      } else {
        list.add(cleanNew);
      }
      list.sort((a, b) => timeStringToMinutes(a).compareTo(timeStringToMinutes(b)));
      final updated = prefs.copyWith(customTimeSlots: list);
      updateCalendarPreferences(updated, detailerId: targetDetailerId);
    }
    notifyListeners();
  }

  void removeCustomTimeSlot(
    String slot, {
    DateTime? specificDate,
    bool applyAllDays = false,
    String? detailerId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;

    if (applyAllDays || specificDate == null) {
      final prefs = getCalendarPreferences(detailerId: targetDetailerId);
      List<String> list = List<String>.from(prefs.customTimeSlots);
      if (list.isEmpty) {
        list = List<String>.from(DetailerCalendarPreferences.defaultTimeSlots);
      }
      list.remove(slot);
      final updated = prefs.copyWith(customTimeSlots: list);
      updateCalendarPreferences(updated, detailerId: targetDetailerId);

      // Also remove from date-specific custom slots overrides if present
      for (int i = 0; i < _availabilityBlocks.length; i++) {
        final b = _availabilityBlocks[i];
        if (b.detailerId == targetDetailerId && b.customSlots.contains(slot)) {
          final updatedCustom = List<String>.from(b.customSlots)..remove(slot);
          _availabilityBlocks[i] = b.copyWith(customSlots: updatedCustom);
        }
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    } else {
      final normDate = DateTime(specificDate.year, specificDate.month, specificDate.day);
      final currentSlots = getTimeSlotsForDate(specificDate, detailerId: targetDetailerId);
      final remainingSlots = List<String>.from(currentSlots)..remove(slot);

      final idx = _availabilityBlocks.indexWhere(
        (b) => b.detailerId == targetDetailerId &&
               b.date.year == normDate.year &&
               b.date.month == normDate.month &&
               b.date.day == normDate.day,
      );
      if (idx != -1) {
        final existing = _availabilityBlocks[idx];
        _availabilityBlocks[idx] = existing.copyWith(
          customSlots: remainingSlots,
          hasCustomSlotsOverride: true,
        );
      } else {
        _availabilityBlocks.add(
          CalendarAvailabilityBlock(
            id: 'block_${DateTime.now().millisecondsSinceEpoch}',
            detailerId: targetDetailerId,
            date: normDate,
            isAllDay: false,
            customSlots: remainingSlots,
            hasCustomSlotsOverride: true,
            createdAt: DateTime.now(),
          ),
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    }
    notifyListeners();
  }

  void autoGenerateTimeSlots({
    required String openTime,
    required String closeTime,
    int slotDurationHours = 3,
    DateTime? specificDate,
    String? detailerId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final generated = generateSlotsForHours(
      openTime: openTime,
      closeTime: closeTime,
      slotDurationHours: slotDurationHours,
    );
    if (generated.isEmpty) return;

    if (specificDate != null) {
      final normDate = DateTime(specificDate.year, specificDate.month, specificDate.day);
      final idx = _availabilityBlocks.indexWhere(
        (b) => b.detailerId == targetDetailerId &&
               b.date.year == normDate.year &&
               b.date.month == normDate.month &&
               b.date.day == normDate.day,
      );
      if (idx != -1) {
        _availabilityBlocks[idx] = _availabilityBlocks[idx].copyWith(
          customSlots: generated,
          hasCustomSlotsOverride: true,
        );
      } else {
        _availabilityBlocks.add(
          CalendarAvailabilityBlock(
            id: 'block_${DateTime.now().millisecondsSinceEpoch}',
            detailerId: targetDetailerId,
            date: normDate,
            isAllDay: false,
            customSlots: generated,
            hasCustomSlotsOverride: true,
            createdAt: DateTime.now(),
          ),
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    } else {
      final prefs = getCalendarPreferences(detailerId: targetDetailerId);
      final updated = prefs.copyWith(
        customTimeSlots: generated,
        slotDurationHours: slotDurationHours,
      );
      updateCalendarPreferences(updated, detailerId: targetDetailerId);
    }
    notifyListeners();
  }

  void clearTimeSlotsForDate(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day,
    );
    if (idx != -1) {
      _availabilityBlocks[idx] = _availabilityBlocks[idx].copyWith(
        customSlots: [],
        hasCustomSlotsOverride: true,
      );
    } else {
      _availabilityBlocks.add(
        CalendarAvailabilityBlock(
          id: 'block_${DateTime.now().millisecondsSinceEpoch}',
          detailerId: targetDetailerId,
          date: normDate,
          isAllDay: false,
          customSlots: [],
          hasCustomSlotsOverride: true,
          createdAt: DateTime.now(),
        ),
      );
    }
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void resetTimeSlotsForDateToDefaults(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day,
    );
    if (idx != -1) {
      final existing = _availabilityBlocks[idx];
      if (existing.blockedSlots.isEmpty && !existing.isAllDay) {
        _availabilityBlocks.removeAt(idx);
      } else {
        _availabilityBlocks[idx] = existing.copyWith(
          customSlots: [],
          hasCustomSlotsOverride: false,
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
      notifyListeners();
    }
  }

  void clearBlockedSlotsForDate(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day,
    );
    if (idx != -1) {
      final existing = _availabilityBlocks[idx];
      if (!existing.hasCustomSlotsOverride && existing.customSlots.isEmpty) {
        _availabilityBlocks.removeAt(idx);
      } else {
        _availabilityBlocks[idx] = existing.copyWith(
          isAllDay: false,
          blockedSlots: [],
        );
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
      notifyListeners();
    }
  }

  bool isDateRecurringDayOff(DateTime date, {String? detailerId}) {
    final prefs = getCalendarPreferences(detailerId: detailerId);
    return !prefs.getHoursForWeekday(date.weekday).isOpen;
  }

  bool isDateExplicitlyBlocked(String detailerId, DateTime date) {
    final normDate = DateTime(date.year, date.month, date.day);
    return _availabilityBlocks.any(
      (b) => b.detailerId == detailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             b.isAllDay,
    );
  }

  bool isDateFullyBlocked(String detailerId, DateTime date) {
    if (isDateRecurringDayOff(date, detailerId: detailerId)) return true;
    if (isDateExplicitlyBlocked(detailerId, date)) return true;
    final normDate = DateTime(date.year, date.month, date.day);
    // Check if covered by multi-day booking
    final coveredByMultiDay = _bookings.any((b) {
      if (b.status == BookingStatus.cancelled || b.detailerId != detailerId) return false;
      final apptDate = DateTime(b.scheduledDate.year, b.scheduledDate.month, b.scheduledDate.day);
      final dayDiff = normDate.difference(apptDate).inDays;
      final durationStr = b.package.estimatedDuration.toLowerCase();
      if (durationStr.contains('day')) {
        final match = RegExp(r'\d+').firstMatch(durationStr);
        final days = match != null ? int.parse(match.group(0)!) : 1;
        return dayDiff > 0 && dayDiff < days;
      }
      return false;
    });
    return coveredByMultiDay;
  }

  bool isSlotExplicitlyBlocked(String detailerId, DateTime date, String slot) {
    return _availabilityBlocks.any(
      (b) => b.detailerId == detailerId &&
             b.date.year == date.year &&
             b.date.month == date.month &&
             b.date.day == date.day &&
             (b.isAllDay ||
              b.blockedSlots.contains(slot) ||
              b.blockedSlots.any((bs) {
                final cleanBs = bs.trim().toLowerCase();
                final cleanSlot = slot.trim().toLowerCase();
                return cleanBs == cleanSlot ||
                       cleanBs.contains(cleanSlot) ||
                       cleanSlot.contains(cleanBs);
              })),
    );
  }

  bool isSlotBlocked(String detailerId, DateTime date, String slot) {
    if (isDateFullyBlocked(detailerId, date)) return true;
    return isSlotExplicitlyBlocked(detailerId, date, slot);
  }

  static int timeStringToMinutes(String timeStr) {
    String clean = timeStr.trim();
    if (clean.contains('-')) {
      clean = clean.split('-').first.trim();
    }
    final upper = clean.toUpperCase();
    final isPm = upper.contains('PM');
    final digitsOnly = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = digitsOnly.split(':');
    int hour = int.tryParse(parts[0].trim()) ?? 0;
    int min = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return hour * 60 + min;
  }

  /// Parses a time slot string into start and end minutes since midnight.
  static (int startMin, int endMin) parseSlotRange(String slot, {int defaultDurationHours = 3}) {
    final clean = slot.trim();
    if (clean.contains('-')) {
      final parts = clean.split('-');
      final start = timeStringToMinutes(parts[0]);
      final end = timeStringToMinutes(parts[1]);
      return (start, end);
    }
    final start = timeStringToMinutes(clean);
    final end = start + (defaultDurationHours * 60);
    return (start, end);
  }

  /// Parses estimated duration string (e.g., "2-3 hrs", "4 hours", "90 mins", "1 day") to minutes.
  static int parseDurationToMinutes(String durationStr, {int defaultMinutes = 180}) {
    final clean = durationStr.toLowerCase().trim();
    if (clean.contains('day')) {
      final match = RegExp(r'\d+').firstMatch(clean);
      final days = match != null ? int.parse(match.group(0)!) : 1;
      return days * 24 * 60;
    }
    if (clean.contains('hour') || clean.contains('hr')) {
      final matches = RegExp(r'\d+').allMatches(clean).map((m) => int.parse(m.group(0)!)).toList();
      if (matches.isNotEmpty) {
        final hours = matches.reduce((a, b) => a > b ? a : b);
        return hours * 60;
      }
    }
    if (clean.contains('min')) {
      final match = RegExp(r'\d+').firstMatch(clean);
      if (match != null) {
        return int.parse(match.group(0)!);
      }
    }
    return defaultMinutes;
  }

  /// Calculates appointment start and end minutes, including package duration and turnaround buffer.
  static (int startMin, int endMin) getAppointmentTimeInterval(
    BookingAppointment appointment, {
    int bufferMinutes = 0,
  }) {
    final slotRange = parseSlotRange(appointment.scheduledTimeSlot);
    final slotSpan = slotRange.$2 > slotRange.$1 ? slotRange.$2 - slotRange.$1 : 180;
    final durationMin = parseDurationToMinutes(
      appointment.package.estimatedDuration,
      defaultMinutes: slotSpan,
    );
    final effectiveDuration = durationMin > slotSpan ? durationMin : slotSpan;
    final startMin = slotRange.$1;
    final endMin = startMin + effectiveDuration + bufferMinutes;
    return (startMin, endMin);
  }

  /// Determines whether an appointment conflicts with a requested time slot on [date].
  bool isBookingConflictingWithSlot(BookingAppointment b, DateTime date, String slot) {
    if (b.status == BookingStatus.cancelled) return false;

    final normDate = DateTime(date.year, date.month, date.day);
    final apptDate = DateTime(b.scheduledDate.year, b.scheduledDate.month, b.scheduledDate.day);
    final dayDiff = normDate.difference(apptDate).inDays;

    // Multi-day booking handling
    final durationStr = b.package.estimatedDuration.toLowerCase();
    if (durationStr.contains('day')) {
      final match = RegExp(r'\d+').firstMatch(durationStr);
      final days = match != null ? int.parse(match.group(0)!) : 1;
      if (dayDiff >= 0 && dayDiff < days) {
        if (dayDiff > 0) return true; // Entire day blocked on subsequent days
        final slotRange = parseSlotRange(slot);
        final apptStart = parseSlotRange(b.scheduledTimeSlot).$1;
        return slotRange.$2 > apptStart;
      }
      return false;
    }

    if (dayDiff != 0) return false;

    // Direct slot string match
    if (b.scheduledTimeSlot.trim().toLowerCase() == slot.trim().toLowerCase()) {
      return true;
    }

    // Interval overlap calculation with turnaround buffer
    final prefs = getCalendarPreferences(detailerId: b.detailerId);
    final buffer = prefs.bufferMinutesBetweenJobs;
    final apptInterval = getAppointmentTimeInterval(b, bufferMinutes: buffer);
    final slotInterval = parseSlotRange(slot);

    final overlapStart = slotInterval.$1 > apptInterval.$1 ? slotInterval.$1 : apptInterval.$1;
    final overlapEnd = slotInterval.$2 < apptInterval.$2 ? slotInterval.$2 : apptInterval.$2;

    return overlapStart < overlapEnd;
  }

  /// Returns the first non-cancelled booking conflicting with [slot] on [date] for [detailerId].
  BookingAppointment? getConflictingBookingForSlot(DateTime date, String slot, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    for (final b in _bookings) {
      if (b.detailerId == targetDetailerId && isBookingConflictingWithSlot(b, date, slot)) {
        return b;
      }
    }
    return null;
  }

  /// Checks if [slot] on [date] is booked or overlaps with any booked appointment.
  bool isSlotConflictedByBooking(DateTime date, String slot, {String? detailerId}) {
    return getConflictingBookingForSlot(date, slot, detailerId: detailerId) != null;
  }

  /// Checks if all slots on [date] are filled by bookings or conflicted.
  bool isDateFullyBooked(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    if (isDateRecurringDayOff(date, detailerId: targetDetailerId)) return false;
    final hours = getHoursForDate(date, detailerId: targetDetailerId);
    if (!hours.isOpen) return false;
    if (isDateExplicitlyBlocked(targetDetailerId, date)) return false;
    final slots = getTimeSlotsForDate(date, detailerId: targetDetailerId);
    if (slots.isEmpty) return false;
    final bookings = getBookingsForDate(date, detailerId: targetDetailerId);
    if (bookings.isEmpty) return false;
    return slots.every((s) =>
      isSlotExplicitlyBlocked(targetDetailerId, date, s) ||
      isSlotConflictedByBooking(date, s, detailerId: targetDetailerId) ||
      !isSlotWithinOperatingHours(date, s, detailerId: targetDetailerId),
    );
  }

  bool isSlotWithinOperatingHours(DateTime date, String slot, {String? detailerId}) {
    final prefs = getCalendarPreferences(detailerId: detailerId);
    final dayHours = prefs.getHoursForWeekday(date.weekday);
    if (!dayHours.isOpen) return false;
    final slotMin = timeStringToMinutes(slot);
    final openMin = timeStringToMinutes(dayHours.openTime);
    final closeMin = timeStringToMinutes(dayHours.closeTime);
    if (slotMin < openMin || slotMin >= closeMin) return false;
    if (slot.contains('-')) {
      final endMin = timeStringToMinutes(slot.split('-').last);
      if (endMin > closeMin) return false;
    }
    return true;
  }

  bool isSlotWithinLeadTime(DateTime date, String slot, {String? detailerId}) {
    final prefs = getCalendarPreferences(detailerId: detailerId);
    final leadHours = prefs.advanceNoticeHours;
    if (leadHours <= 0) return true;
    final slotMin = timeStringToMinutes(slot);
    final slotDate = DateTime(date.year, date.month, date.day, slotMin ~/ 60, slotMin % 60);
    return slotDate.difference(DateTime.now()).inMinutes >= leadHours * 60;
  }

  DayBusinessHours getHoursForDate(DateTime date, {String? detailerId}) {
    final prefs = getCalendarPreferences(detailerId: detailerId);
    return prefs.getHoursForWeekday(date.weekday);
  }

  List<CalendarAvailabilityBlock> getBlocksForDate(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    return _availabilityBlocks.where(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == date.year &&
             b.date.month == date.month &&
             b.date.day == date.day,
    ).toList();
  }

  List<BookingAppointment> getBookingsForDate(DateTime date, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    return _bookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (b.detailerId != targetDetailerId) return false;

      final apptDate = DateTime(b.scheduledDate.year, b.scheduledDate.month, b.scheduledDate.day);
      final dayDiff = normDate.difference(apptDate).inDays;

      final durationStr = b.package.estimatedDuration.toLowerCase();
      if (durationStr.contains('day')) {
        final match = RegExp(r'\d+').firstMatch(durationStr);
        final days = match != null ? int.parse(match.group(0)!) : 1;
        return dayDiff >= 0 && dayDiff < days;
      }

      return dayDiff == 0;
    }).toList();
  }

  // ─── MESSAGING ────────────────────────────────────────────────────────────

  List<Conversation> get conversations => _conversations;

  int get totalUnreadMessages =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Loads conversations from local storage and Supabase, subscribing to realtime updates.
  Future<void> loadConversations() async {
    try {
      // 1. Instant load from local cache
      final localConvs = await LocalStorageService.loadConversations();
      if (localConvs.isNotEmpty) {
        _conversations = localConvs;
        _enrichConversationProfiles();
        notifyListeners();
      }

      // 2. Sync from Supabase if logged in
      if (_isLoggedIn) {
        final remoteConvs = await SupabaseDbService.fetchConversations(_currentUser.id);
        if (remoteConvs.isNotEmpty) {
          final Map<String, Conversation> convMap = {
            for (final c in _conversations) c.id: c,
          };
          for (final rc in remoteConvs) {
            convMap[rc.id] = rc;
          }
          _conversations = convMap.values.toList();
        }
        _subscribeToRealtime();
      }

      _enrichConversationProfiles();
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await LocalStorageService.saveConversations(_conversations);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[JobRepository] loadConversations error: $e');
    }
  }

  void _enrichConversationProfiles() {
    for (int i = 0; i < _conversations.length; i++) {
      final c = _conversations[i];
      if (c.otherUserName.isEmpty || c.otherUserName == 'User' || c.otherUserName == 'Unknown User') {
        final otherId = c.participantA == _currentUser.id ? c.participantB : c.participantA;
        final match = _publicDetailers.where((d) => d.id == otherId);
        if (match.isNotEmpty) {
          final detailer = match.first;
          _conversations[i] = c.copyWith(
            otherUserName: detailer.businessName.isNotEmpty ? detailer.businessName : detailer.displayName,
            otherUserAvatar: detailer.avatarUrl,
          );
        }
      }
    }
  }

  /// Opens (or creates) a DM conversation and returns the conversationId.
  Future<String?> openOrCreateConversation(String otherUserId) async {
    String? convId;

    // 1. Try Supabase cloud conversation if logged in
    if (_isLoggedIn) {
      try {
        convId = await SupabaseDbService.createOrGetConversation(_currentUser.id, otherUserId);
      } catch (_) {}
    }

    // 2. Reliable local/offline conversation ID fallback
    if (convId == null || convId.isEmpty) {
      convId = 'conv_${_currentUser.id}_$otherUserId';
    }

    // 3. Ensure conversation exists in local list
    final existingIdx = _conversations.indexWhere((c) => c.id == convId);
    if (existingIdx == -1) {
      String name = 'Detailer';
      String avatar = '';
      final match = _publicDetailers.where((d) => d.id == otherUserId);
      if (match.isNotEmpty) {
        final d = match.first;
        name = d.businessName.isNotEmpty ? d.businessName : d.displayName;
        avatar = d.avatarUrl;
      }
      final newConv = Conversation(
        id: convId,
        participantA: _currentUser.id,
        participantB: otherUserId,
        updatedAt: DateTime.now(),
        otherUserName: name,
        otherUserAvatar: avatar,
      );
      _conversations.insert(0, newConv);
      await LocalStorageService.saveConversations(_conversations);
      notifyListeners();
    }

    return convId;
  }

  /// Fetches messages for a given conversation.
  Future<List<DirectMessage>> fetchMessages(String conversationId) async {
    final localMsgs = await LocalStorageService.loadMessages(conversationId);
    List<DirectMessage> remoteMsgs = [];

    if (_isLoggedIn) {
      try {
        remoteMsgs = await SupabaseDbService.fetchMessages(conversationId);
        SupabaseDbService.markMessagesAsRead(conversationId, _currentUser.id);
      } catch (_) {}
    }

    // Merge and deduplicate by id
    final Map<String, DirectMessage> map = {};
    for (final m in localMsgs) {
      map[m.id] = m;
    }
    for (final m in remoteMsgs) {
      map[m.id] = m;
    }

    final merged = map.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Update unread badge
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      LocalStorageService.saveConversations(_conversations);
      notifyListeners();
    }
    return merged;
  }

  /// Sends a DM message in a conversation.
  Future<DirectMessage?> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final localMsg = DirectMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: _currentUser.id,
      text: trimmed,
      createdAt: DateTime.now(),
      isRead: false,
    );

    // 1. Immediately store in local messages cache
    final msgs = await LocalStorageService.loadMessages(conversationId);
    msgs.add(localMsg);
    await LocalStorageService.saveMessages(conversationId, msgs);

    // 2. Update conversation preview and move to top
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final updated = _conversations[idx].copyWith(
        lastMessage: localMsg,
        updatedAt: DateTime.now(),
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated);
      await LocalStorageService.saveConversations(_conversations);
      notifyListeners();
    }

    // 3. Sync to Supabase in background
    if (_isLoggedIn) {
      SupabaseDbService.sendMessage(
        conversationId: conversationId,
        senderId: _currentUser.id,
        text: trimmed,
      ).catchError((e) {
        if (kDebugMode) print('[JobRepository] Supabase sendMessage background error: $e');
        return null;
      });
    }

    return localMsg;
  }

  /// Subscribes to all Supabase Realtime channels (messages, jobs, bookings, user_interactions)
  void _subscribeToRealtime() {
    final client = SupabaseService.client;
    if (client == null) return;

    _unsubscribeFromRealtime();

    // 1. Messages realtime channel
    _messagesChannel = client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            loadConversations();
          },
        )
        .subscribe();

    // 2. Jobs realtime channel
    _jobsChannel = client
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          callback: (_) {
            _refreshJobsFromCloud();
          },
        )
        .subscribe();

    // 3. Bookings realtime channel
    _bookingsChannel = client
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) {
            if (_isLoggedIn) {
              _refreshBookingsFromCloud(_currentUser.id);
            }
          },
        )
        .subscribe();

    // 4. User interactions realtime channel
    _interactionsChannel = client
        .channel('public:user_interactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_interactions',
          callback: (_) {
            if (_isLoggedIn) {
              _refreshInteractionsFromCloud(_currentUser.id);
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeFromRealtime() {
    _messagesChannel?.unsubscribe();
    _messagesChannel = null;
    _jobsChannel?.unsubscribe();
    _jobsChannel = null;
    _bookingsChannel?.unsubscribe();
    _bookingsChannel = null;
    _interactionsChannel?.unsubscribe();
    _interactionsChannel = null;
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }
}

