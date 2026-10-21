import 'dart:async';
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
import '../models/shift_request.dart';
import 'owner_pin_security.dart';

const Set<String> _legacyMockJobIds = {
  'job_01', 'job_02', 'job_03', 'job_04', 'job_05', 'job_06', 'job_07'
};
const Set<String> _legacyMockInvIds = {
  'inv_hw_01', 'inv_hw_02', 'inv_hw_03', 'inv_hw_04', 'inv_hw_05',
  'inv_chem_01', 'inv_chem_02', 'inv_chem_03', 'inv_chem_04', 'inv_chem_05',
  'inv_rcp_01', 'inv_rcp_02'
};
const Set<String> _legacyMockBookingIds = {
  'bk_01', 'bk_02', 'bk_03', 'bk_04'
};

class JobRepository extends ChangeNotifier {
  List<DetailJob> _jobs = [];
  List<BookingAppointment> _bookings = [];
  List<UserProfile> _publicDetailers = [];
  UserProfile _currentUser = MockDataService.youUser; // Default fallback
  List<StudioRecipePreset> _customPresets = [];
  List<InventoryItem> _inventoryItems = [];
  List<CalendarAvailabilityBlock> _availabilityBlocks = [];
  DetailerCalendarPreferences _calendarPreferences = DetailerCalendarPreferences.defaults();
  final Map<String, DetailerCalendarPreferences> _detailerPreferencesMap = {};
  List<ShiftRequest> _shiftRequests = [];
  String? _activeTeamMemberId; // null or 'founder' = shop owner (Founder)
  bool _isStaffSession = false; // true = authenticated via staff PIN or staff credentials directly
  String? _ownerPinHash; // salted PBKDF2 hash; null = owner has not created a PIN yet
  bool _serverHasOwnerPin = false;
  int _ownerPinFails = 0;
  DateTime? _ownerPinLockedUntil;
  static const int _maxOwnerPinAttempts = 5;
  static const Duration _ownerPinLockDuration = Duration(minutes: 15);
  bool _isOwnerLocked = false;
  int _ownerAutoLockMinutes = 5;
  bool? _workingWithTeamOverride;

  String _selectedServiceType = 'All Services';
  String _selectedLocationCity = 'All Locations';
  String _searchQuery = '';
  int _activeTabIndex = 0;
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  Completer<void>? _initCompleter;

  // Messaging state
  List<Conversation> _conversations = [];
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _jobsChannel;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _interactionsChannel;
  RealtimeChannel? _profilesChannel;

  JobRepository();

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  // ignore: unnecessary_getters_setters
  bool get isLoggedIn => _isLoggedIn;
  // ignore: unnecessary_getters_setters
  set isLoggedIn(bool value) => _isLoggedIn = value;
  bool get isGuestMode => !_isLoggedIn;
  int get activeTabIndex => _activeTabIndex;

  bool get isDetailerWorkbenchMode => _currentUser.role == UserRole.detailer;
  set isDetailerWorkbenchMode(bool value) {
    if (value) {
      _currentUser = _currentUser.copyWith(role: UserRole.detailer, isVerifiedHost: true);
      LocalStorageService.saveWorkbenchMode('studio');
    } else {
      _currentUser = _currentUser.copyWith(role: UserRole.client);
      LocalStorageService.saveWorkbenchMode('garage');
    }
    notifyListeners();
  }
  String get workbenchMode => _currentUser.role == UserRole.detailer ? 'studio' : 'garage';

  List<ShiftRequest> get shiftRequests => List.unmodifiable(_shiftRequests);
  List<ShiftRequest> get pendingShiftRequests =>
      _shiftRequests.where((r) => r.isPending && (r.detailerId.isEmpty || r.detailerId == _currentUser.id)).toList();

  String? get activeTeamMemberId => _activeTeamMemberId;
  bool get isStaffSession => _isStaffSession;
  bool get isViewingAsTeamMember => _activeTeamMemberId != null && _activeTeamMemberId != 'founder';
  TeamMember? get activeTeamMember =>
      isViewingAsTeamMember ? _currentUser.teamMembers.where((m) => m.id == _activeTeamMemberId).firstOrNull : null;

  bool get hasOwnerPin => _ownerPinHash != null || _serverHasOwnerPin;
  bool get hasCustomOwnerPin => hasOwnerPin;
  bool get isOwnerPinLockedOut =>
      _ownerPinLockedUntil != null && _ownerPinLockedUntil!.isAfter(DateTime.now());
  DateTime? get ownerPinLockedUntil => _ownerPinLockedUntil;
  bool get isOwnerLocked => _isOwnerLocked;
  int get ownerAutoLockMinutes => _ownerAutoLockMinutes;

  /// Whether "Working with a Team?" is enabled in Settings > Shop.
  /// For new users with no team members, defaults to false (solo).
  /// Once a user enables it or has team members, it stays on across logins and devices.
  bool get workingWithTeam => _workingWithTeamOverride ?? (_currentUser.teamMembers.isNotEmpty);
  set workingWithTeamOverride(bool? val) {
    _workingWithTeamOverride = val;
    notifyListeners();
  }

  Future<void> setWorkingWithTeam(bool value) async {
    _workingWithTeamOverride = value;
    await LocalStorageService.saveWorkingWithTeam(value);
    if (!value) {
      _isOwnerLocked = false;
      await LocalStorageService.saveIsOwnerLocked(false);
    }
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      if (_initCompleter != null) {
        await _initCompleter!.future;
      }
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      _jobs = [];
      _bookings = [];
      _publicDetailers = [];

      // 1. Load active tab index
      _activeTabIndex = await LocalStorageService.loadActiveTab();

      // 2. Check auth state (Supabase or stored session)
      final isGuest = await LocalStorageService.loadIsGuest();
      final savedUser = await LocalStorageService.loadCurrentUser();
      final savedWorkbenchMode = await LocalStorageService.loadWorkbenchMode();
      final isStaffSession = await LocalStorageService.loadIsStaffSession();
      final activeStaffId = await LocalStorageService.loadActiveTeamMemberId();

      if (isStaffSession && activeStaffId != null) {
        // Staff direct session
        _isStaffSession = true;
        _activeTeamMemberId = activeStaffId;
        _currentUser = savedUser ?? MockDataService.youUser;
        _currentUser = _currentUser.copyWith(role: UserRole.detailer);
        _isLoggedIn = true;
      } else if (SupabaseAuthService.isLoggedIn) {
        // Supabase persistent session found
        final authUser = SupabaseAuthService.currentAuthUser!;
        _currentUser = savedUser ?? UserProfile(
          id: authUser.id,
          username: authUser.email?.split('@').first ?? 'user',
          displayName: (authUser.userMetadata?['display_name'] as String?) ?? 'Vehicle Owner',
          businessName: '',
          avatarUrl: '',
          coverUrl: '',
          location: '',
          serviceRadius: '',
          bio: '',
        );
        _isLoggedIn = true;
        await LocalStorageService.saveIsGuest(false);
      } else if (!isGuest && savedUser != null) {
        _currentUser = savedUser;
        _isLoggedIn = true;
      } else {
        // Strict guest visitor mode
        _isLoggedIn = false;
        _currentUser = MockDataService.youUser.copyWith(role: UserRole.client);
        await LocalStorageService.saveIsGuest(true);
      }

      // Apply explicit workbench mode if logged in ('studio' vs 'garage')
      if (_isLoggedIn) {
        if (savedWorkbenchMode == 'studio') {
          _currentUser = _currentUser.copyWith(
            role: UserRole.detailer,
            isVerifiedHost: true,
          );
        } else if (savedWorkbenchMode == 'garage') {
          _currentUser = _currentUser.copyWith(
            role: UserRole.client,
          );
        }
      } else {
        _currentUser = _currentUser.copyWith(role: UserRole.client);
      }

      // 2b. Hydrate dedicated service packages from local storage first
      final dedicatedPackages = await LocalStorageService.loadServicePackages();
      List<ServicePackage> initialPackages;
      if (dedicatedPackages.isNotEmpty) {
        initialPackages = dedicatedPackages;
      } else if (_currentUser.servicePackages.isNotEmpty) {
        initialPackages = _currentUser.servicePackages;
        await LocalStorageService.saveServicePackages(initialPackages);
      } else {
        initialPackages = [];
        await LocalStorageService.saveServicePackages(initialPackages);
      }
      _currentUser = _currentUser.copyWith(servicePackages: initialPackages);

      // 2c. Hydrate dedicated garage vehicles from local storage first
      final dedicatedGarage = await LocalStorageService.loadGarageVehicles();
      List<UserVehicle> initialGarage;
      if (dedicatedGarage.isNotEmpty) {
        initialGarage = dedicatedGarage;
      } else if (_currentUser.myGarage.isNotEmpty) {
        initialGarage = _currentUser.myGarage;
        await LocalStorageService.saveGarageVehicles(initialGarage);
      } else {
        initialGarage = [];
      }
      _currentUser = _currentUser.copyWith(myGarage: initialGarage);

      // 2d. Hydrate dedicated team members from local storage first
      final dedicatedTeam = await LocalStorageService.loadTeamMembers();
      List<TeamMember> initialTeam;
      if (dedicatedTeam.isNotEmpty) {
        initialTeam = dedicatedTeam;
      } else if (_currentUser.teamMembers.isNotEmpty) {
        initialTeam = _currentUser.teamMembers;
        await LocalStorageService.saveTeamMembers(initialTeam);
      } else {
        initialTeam = [];
        await LocalStorageService.saveTeamMembers(initialTeam);
      }
      _currentUser = _currentUser.copyWith(teamMembers: initialTeam);

      // 2e. Hydrate dedicated inventory items from local storage first
      final dedicatedInventory = await LocalStorageService.loadInventoryItems();
      if (dedicatedInventory != null) {
        _inventoryItems = dedicatedInventory.where((i) => !_legacyMockInvIds.contains(i.id)).toList();
      } else {
        _inventoryItems = [];
        await LocalStorageService.saveInventoryItems(_inventoryItems);
      }

      // 2f. Hydrate dedicated calendar blocks and preferences from local storage first
      final dedicatedBlocks = await LocalStorageService.loadCalendarBlocks();
      if (dedicatedBlocks.isNotEmpty) {
        _availabilityBlocks = List.from(dedicatedBlocks);
      } else {
        final legacyBlocks = await LocalStorageService.loadAvailabilityBlocks();
        if (legacyBlocks != null && legacyBlocks.isNotEmpty) {
          _availabilityBlocks = List.from(legacyBlocks);
          await LocalStorageService.saveCalendarBlocks(_availabilityBlocks);
        }
      }

      final dedicatedPrefs = await LocalStorageService.loadDetailerCalendarPreferences(detailerId: _currentUser.id);
      if (dedicatedPrefs != null) {
        _calendarPreferences = dedicatedPrefs;
        _detailerPreferencesMap[_currentUser.id] = dedicatedPrefs;
      } else {
        final legacyPrefs = await LocalStorageService.loadCalendarPreferences();
        if (legacyPrefs != null) {
          _calendarPreferences = legacyPrefs;
          _detailerPreferencesMap[_currentUser.id] = legacyPrefs;
          await LocalStorageService.saveDetailerCalendarPreferences(legacyPrefs, detailerId: _currentUser.id);
        } else {
          _calendarPreferences = DetailerCalendarPreferences.defaults();
          _detailerPreferencesMap[_currentUser.id] = _calendarPreferences;
          await LocalStorageService.saveDetailerCalendarPreferences(_calendarPreferences, detailerId: _currentUser.id);
          await LocalStorageService.saveCalendarPreferences(_calendarPreferences);
        }
      }

      // 2g. Hydrate dedicated booking appointments from local storage first
      final dedicatedBookings = await LocalStorageService.loadBookings();
      if (dedicatedBookings != null) {
        _bookings = dedicatedBookings.where((b) => !_legacyMockBookingIds.contains(b.id)).toList();
      } else {
        _bookings = [];
        await LocalStorageService.saveBookings(_bookings);
      }

      // 2h. Hydrate dedicated custom transformation jobs from local storage first
      final customJobs = await LocalStorageService.loadCustomJobs();
      _jobs = customJobs.where((j) => !_legacyMockJobIds.contains(j.id)).toList();

      // 2i. Hydrate dedicated comment overrides across all jobs (both mock and custom)
      final commentOverrides = await LocalStorageService.loadJobCommentsOverrides();
      if (commentOverrides.isNotEmpty) {
        _jobs = _jobs.map((job) {
          final overrides = commentOverrides[job.id];
          if (overrides != null && overrides.isNotEmpty) {
            return job.copyWith(comments: overrides);
          }
          return job;
        }).toList();
      }

      // 2j. Hydrate dedicated shift requests and active team member session
      _shiftRequests = await LocalStorageService.loadShiftRequests();
      _activeTeamMemberId = await LocalStorageService.loadActiveTeamMemberId();
      _isStaffSession = await LocalStorageService.loadIsStaffSession();
      if (_isStaffSession && _activeTeamMemberId != null) {
        _isLoggedIn = true;
        _currentUser = _currentUser.copyWith(role: UserRole.detailer);
      }

      // 2k. Hydrate owner PIN hash, brute-force lockout, and lock state
      _ownerPinHash = await LocalStorageService.loadOwnerPinHash() ?? _currentUser.ownerPinHash;
      final lockout = await LocalStorageService.loadOwnerPinLockout();
      _ownerPinFails = lockout.$1;
      _ownerPinLockedUntil = lockout.$2;
      _ownerAutoLockMinutes = await LocalStorageService.loadOwnerAutoLockMinutes();
      _workingWithTeamOverride = await LocalStorageService.loadWorkingWithTeam();
      _isOwnerLocked = await LocalStorageService.loadIsOwnerLocked();
      if (!hasOwnerPin) _isOwnerLocked = false; // can't be locked without a PIN
      unawaited(refreshOwnerPinStatus());

      // 4. Load custom recipe presets from local cache
      _customPresets = await LocalStorageService.loadCustomPresets();

      // 5. Load persistent likes, bookmarks & exact like counts from local cache
      final interaction = await LocalStorageService.loadInteractionState();
      final likeCounts = await LocalStorageService.loadJobLikeCounts();
      if (interaction.likedJobIds.isNotEmpty || interaction.savedJobIds.isNotEmpty || likeCounts.isNotEmpty) {
        _jobs = _jobs.map((job) {
          final isLiked = interaction.likedJobIds.contains(job.id);
          final isSaved = interaction.savedJobIds.contains(job.id);
          int likes = job.likesCount;
          if (likeCounts.containsKey(job.id)) {
            likes = likeCounts[job.id]!;
          } else if (isLiked && !job.isLiked) {
            likes = job.likesCount + 1;
          }
          return job.copyWith(
            isLiked: isLiked,
            isSaved: isSaved,
            likesCount: likes,
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
            refreshOwnerPinStatus(),
            _refreshJobsFromCloud(),
            _refreshBookingsFromCloud(_currentUser.id),
            _refreshInteractionsFromCloud(_currentUser.id),
            _refreshPublicDetailersFromCloud(),
          ]).timeout(const Duration(seconds: 4));
        } catch (_) {
          // Fallback to local cache if offline or slow network
        }
      } else {
        // For guest visitors, refresh community jobs and detailers in the background
        _refreshJobsFromCloud();
        _refreshPublicDetailersFromCloud();
      }

      // 7. Load persistent messages & conversations
      loadConversations();

      // 8. Subscribe to realtime channels if logged in
      if (_isLoggedIn) {
        _subscribeToRealtime();
      }

      _isInitialized = true;
      notifyListeners();
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
      _initCompleter = null;
    }
  }

  Future<void> _refreshProfileFromCloud(String userId) async {
    try {
      final cloudProfile = await SupabaseDbService.fetchUserProfile(userId);
      if (cloudProfile != null) {
        // Non-destructive union merge for service packages: union by ID, preserving local custom packages and additions
        List<ServicePackage> resolvedPackages;
        if (cloudProfile.servicePackages.isNotEmpty) {
          final packageMap = <String, ServicePackage>{
            for (final p in _currentUser.servicePackages) p.id: p,
          };
          for (final cp in cloudProfile.servicePackages) {
            final local = packageMap[cp.id];
            if (local == null) {
              packageMap[cp.id] = cp;
            }
          }
          resolvedPackages = packageMap.values.toList();
        } else {
          resolvedPackages = _currentUser.servicePackages.isNotEmpty
              ? _currentUser.servicePackages
              : await LocalStorageService.loadServicePackages();
        }

        // Non-destructive union merge for garage vehicles: union by ID, preserving local custom vehicles and data
        List<UserVehicle> resolvedGarage;
        if (cloudProfile.myGarage.isNotEmpty) {
          final vehicleMap = <String, UserVehicle>{
            for (final v in _currentUser.myGarage) v.id: v,
          };
          for (final cv in cloudProfile.myGarage) {
            final local = vehicleMap[cv.id];
            if (local != null) {
              vehicleMap[cv.id] = cv.copyWith(
                localImageBytes: cv.localImageBytes ?? local.localImageBytes,
                lastDetailService: cv.lastDetailService ?? local.lastDetailService,
                lastDetailDate: cv.lastDetailDate ?? local.lastDetailDate,
              );
            } else {
              vehicleMap[cv.id] = cv;
            }
          }
          resolvedGarage = vehicleMap.values.toList();
        } else {
          resolvedGarage = _currentUser.myGarage.isNotEmpty
              ? _currentUser.myGarage
              : await LocalStorageService.loadGarageVehicles();
        }

        // Non-destructive union merge for team members: union by ID across local storage, in-memory profile, and cloud
        final storedLocalTeam = await LocalStorageService.loadTeamMembers();
        final storedLocalUser = await LocalStorageService.loadUserById(userId);
        List<TeamMember> resolvedTeam;
        if (cloudProfile.teamMembers.isNotEmpty) {
          final teamMap = <String, TeamMember>{
            if (storedLocalUser != null)
              for (final m in storedLocalUser.teamMembers) m.id: m,
            for (final m in storedLocalTeam) m.id: m,
            for (final m in _currentUser.teamMembers) m.id: m,
          };
          for (final cm in cloudProfile.teamMembers) {
            final local = teamMap[cm.id];
            if (local != null) {
              teamMap[cm.id] = cm.copyWith(
                pin: (cm.pin != null && cm.pin!.isNotEmpty) ? cm.pin : local.pin,
                email: (cm.email != null && cm.email!.isNotEmpty) ? cm.email : local.email,
                allowedHubSections: cm.allowedHubSections ?? local.allowedHubSections,
                customWeeklySchedule: cm.customWeeklySchedule ?? local.customWeeklySchedule,
                localAvatarBytes: cm.localAvatarBytes ?? local.localAvatarBytes,
                isFounder: cm.isFounder || local.isFounder,
              );
            } else {
              teamMap[cm.id] = cm;
            }
          }
          resolvedTeam = teamMap.values.toList();
        } else {
          final teamMap = <String, TeamMember>{
            if (storedLocalUser != null)
              for (final m in storedLocalUser.teamMembers) m.id: m,
            for (final m in storedLocalTeam) m.id: m,
            for (final m in _currentUser.teamMembers) m.id: m,
          };
          resolvedTeam = teamMap.values.toList();
        }

        // Resolve ownerPinHash across cloud, local storage, and current in-memory state
        final localPinHash = await LocalStorageService.loadOwnerPinHash() ??
            storedLocalUser?.ownerPinHash ??
            _currentUser.ownerPinHash ??
            _ownerPinHash;
        final resolvedPinHash = (cloudProfile.ownerPinHash != null && cloudProfile.ownerPinHash!.isNotEmpty)
            ? cloudProfile.ownerPinHash
            : localPinHash;
        if (resolvedPinHash != null && resolvedPinHash.isNotEmpty) {
          _ownerPinHash = resolvedPinHash;
          await LocalStorageService.saveOwnerPinHash(resolvedPinHash);
        }

        final mode = await LocalStorageService.loadWorkbenchMode();
        var merged = cloudProfile.copyWith(
          servicePackages: resolvedPackages,
          myGarage: resolvedGarage,
          teamMembers: resolvedTeam,
          ownerPinHash: resolvedPinHash,
        );

        if (mode == 'studio') {
          merged = merged.copyWith(
            role: UserRole.detailer,
            isVerifiedHost: true,
          );
        } else if (mode == 'garage') {
          merged = merged.copyWith(
            role: UserRole.client,
          );
        }

        _currentUser = merged;
        await LocalStorageService.saveCurrentUser(_currentUser);
        if (resolvedPackages.isNotEmpty) {
          await LocalStorageService.saveServicePackages(resolvedPackages);
        }
        if (resolvedGarage.isNotEmpty) {
          await LocalStorageService.saveGarageVehicles(resolvedGarage);
        }
        if (resolvedTeam.isNotEmpty) {
          await LocalStorageService.saveTeamMembers(resolvedTeam);
        }
        if (userId != 'usr_you') {
          final needsProfileSync = resolvedPackages.length > cloudProfile.servicePackages.length ||
              resolvedTeam.length > cloudProfile.teamMembers.length ||
              ((cloudProfile.ownerPinHash == null || cloudProfile.ownerPinHash!.isEmpty) &&
                  resolvedPinHash != null &&
                  resolvedPinHash.isNotEmpty);
          if (needsProfileSync) {
            SupabaseDbService.saveUserProfile(merged);
          }
          // Push any locally added team members that were missing from Supabase up to the cloud
          final cloudTeamIds = cloudProfile.teamMembers.map((m) => m.id).toSet();
          for (final member in resolvedTeam) {
            if (!cloudTeamIds.contains(member.id)) {
              SupabaseDbService.saveTeamMember(userId, member);
            }
          }
        }

        // Non-destructive union merge for inventory items: union by ID, preserving local custom items and fill levels
        try {
          final cloudInventory = await SupabaseDbService.fetchInventoryItems(userId);
          if (cloudInventory.isNotEmpty) {
            final invMap = <String, InventoryItem>{
              for (final item in _inventoryItems) item.id: item,
            };
            for (final ci in cloudInventory) {
              final local = invMap[ci.id];
              if (local != null) {
                invMap[ci.id] = ci.copyWith(
                  status: local.status,
                  location: local.location.isNotEmpty ? local.location : ci.location,
                  notes: local.notes ?? ci.notes,
                );
              } else {
                invMap[ci.id] = ci;
              }
            }
            _inventoryItems = invMap.values.toList();
            await LocalStorageService.saveInventoryItems(_inventoryItems);
          }
        } catch (_) {}

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
        // 2. Cloud jobs non-destructively merge with local state
        for (final cJob in cloudJobs) {
          final existing = jobMap[cJob.id];
          if (existing != null) {
            // Non-destructive comments merge: combine local and cloud comments without dropping either
            final commentMap = <String, JobComment>{};
            for (final c in cJob.comments) {
              commentMap[c.id] = c;
            }
            for (final c in existing.comments) {
              commentMap[c.id] = c;
            }
            final mergedComments = commentMap.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

            jobMap[cJob.id] = cJob.copyWith(
              isLiked: existing.isLiked,
              isSaved: existing.isSaved,
              likesCount: existing.likesCount > cJob.likesCount ? existing.likesCount : cJob.likesCount,
              comments: mergedComments,
            );
          } else {
            // If the job belongs to the current user (e.g. published on another device),
            // attribute it directly to _currentUser so it appears in My Studio portfolio immediately
            if (cJob.author.id == _currentUser.id || cJob.author.username == _currentUser.username) {
              jobMap[cJob.id] = cJob.copyWith(author: _currentUser);
            } else {
              jobMap[cJob.id] = cJob;
            }
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
    if (user.ownerPinHash != null && user.ownerPinHash!.isNotEmpty) {
      _ownerPinHash = user.ownerPinHash;
      await LocalStorageService.saveOwnerPinHash(_ownerPinHash);
    }
    await LocalStorageService.saveIsGuest(false);

    // 1. Fetch latest profile state and PIN status from cloud FIRST
    // This ensures cloud garage, team, bio, packages, and Admin PIN are loaded onto this device
    await Future.wait([
      _refreshProfileFromCloud(user.id),
      refreshOwnerPinStatus(),
    ]);

    if (_currentUser.ownerPinHash != null && _currentUser.ownerPinHash!.isNotEmpty) {
      _ownerPinHash = _currentUser.ownerPinHash;
      await LocalStorageService.saveOwnerPinHash(_ownerPinHash);
    }

    // Keep detailer or superAdmin in studio workbench mode
    final isDetailerOrAdmin = _currentUser.role == UserRole.detailer || _currentUser.role == UserRole.superAdmin;
    if (isDetailerOrAdmin) {
      _currentUser = _currentUser.copyWith(role: UserRole.detailer, isVerifiedHost: true);
      await LocalStorageService.saveWorkbenchMode('studio');
    } else {
      _currentUser = _currentUser.copyWith(role: UserRole.client);
      await LocalStorageService.saveWorkbenchMode('garage');
    }

    await LocalStorageService.saveCurrentUser(_currentUser);

    // 2. Refresh jobs and public detailers from cloud
    await Future.wait([
      _refreshJobsFromCloud(),
      _refreshPublicDetailersFromCloud(),
    ]);

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
    _isStaffSession = false;
    _activeTeamMemberId = null;
    await LocalStorageService.saveIsStaffSession(false);
    await LocalStorageService.saveActiveTeamMemberId(null);
    await LocalStorageService.logoutSession();
    await LocalStorageService.saveWorkbenchMode('garage');
    _isLoggedIn = false;
    _currentUser = MockDataService.youUser;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _unsubscribeFromRealtime();
    final userId = _currentUser.id;

    // 1. Permanently purge user profile, garage, team, and auth from Supabase while authenticated
    if (_isLoggedIn) {
      await SupabaseDbService.deleteAccountFromCloud(userId);
    }

    // 2. Sign out auth session
    await SupabaseAuthService.signOut();

    // 3. Purge local device storage & all browser caches
    _isStaffSession = false;
    _activeTeamMemberId = null;
    await LocalStorageService.saveIsStaffSession(false);
    await LocalStorageService.saveActiveTeamMemberId(null);
    await LocalStorageService.deleteAccountData(userId);
    await LocalStorageService.saveWorkbenchMode('garage');

    // 4. Reset all in-memory repository collections to fresh blank state
    _jobs = [];
    _bookings = [];
    _conversations = [];
    _customPresets = [];
    _inventoryItems = [];
    _availabilityBlocks = [];
    _shiftRequests = [];
    _ownerPinHash = null;
    _isOwnerLocked = false;
    _workingWithTeamOverride = null;
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
    // 1. Always save to local storage for fast offline cache and refresh persistence
    LocalStorageService.saveCurrentUser(_currentUser);
    LocalStorageService.saveServicePackages(_currentUser.servicePackages);
    LocalStorageService.saveGarageVehicles(_currentUser.myGarage);
    LocalStorageService.saveTeamMembers(_currentUser.teamMembers);
    LocalStorageService.saveInventoryItems(_inventoryItems);
    if (_isLoggedIn) {
      // 2. Sync to Supabase Database
      SupabaseDbService.saveUserProfile(_currentUser);
    }
  }

  Future<void> _refreshPublicDetailersFromCloud() async {
    try {
      final detailers = await SupabaseDbService.fetchPublicDetailers();
      _publicDetailers = detailers;
      notifyListeners();
    } catch (_) {}
  }

  void _persistBookings() {
    LocalStorageService.saveBookings(_bookings);
  }

  void _persistCustomJobs() {
    // Only persist jobs that are custom user jobs (not legacy mock ids)
    final customJobs = _jobs.where((j) => !_legacyMockJobIds.contains(j.id)).toList();
    LocalStorageService.saveCustomJobs(customJobs);
  }

  void _persistLikeCounts() {
    final counts = {for (final j in _jobs) j.id: j.likesCount};
    LocalStorageService.saveJobLikeCounts(counts);
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
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.saveInventoryItem(_currentUser.id, item);
    }
    notifyListeners();
  }

  void updateInventoryItem(InventoryItem updated) {
    final idx = _inventoryItems.indexWhere((i) => i.id == updated.id);
    if (idx != -1) {
      _inventoryItems[idx] = updated;
      LocalStorageService.saveInventoryItems(_inventoryItems);
      _persistUser();
      if (_isLoggedIn) {
        SupabaseDbService.saveInventoryItem(_currentUser.id, updated);
      }
      notifyListeners();
    }
  }

  void removeInventoryItem(String itemId) {
    _inventoryItems.removeWhere((i) => i.id == itemId);
    LocalStorageService.saveInventoryItems(_inventoryItems);
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.deleteInventoryItem(itemId);
    }
    notifyListeners();
  }

  void updateChemicalFillStatus(String itemId, String newFillStatus) {
    final idx = _inventoryItems.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      final current = _inventoryItems[idx];
      final updated = current.copyWith(status: newFillStatus);
      _inventoryItems[idx] = updated;
      LocalStorageService.saveInventoryItems(_inventoryItems);
      _persistUser();
      if (_isLoggedIn) {
        SupabaseDbService.saveInventoryItem(_currentUser.id, updated);
      }
      notifyListeners();
    }
  }

  // Getters
  List<DetailJob> get jobs => _jobs;
  List<DetailJob> get allJobs => _jobs;
  List<BookingAppointment> get bookings => _bookings;

  // Studio Bookings: Only bookings placed by clients for this detailer's studio
  List<BookingAppointment> get studioBookings =>
      _bookings.where((b) => b.detailerId == _currentUser.id).toList();

  // Client Bookings: Only personal bookings made by this user as a customer
  List<BookingAppointment> get clientBookings =>
      _bookings.where((b) => b.clientId == _currentUser.id).toList();

  List<CalendarAvailabilityBlock> get availabilityBlocks => List.unmodifiable(_availabilityBlocks);
  DetailerCalendarPreferences get calendarPreferences => _calendarPreferences;
  
  // All public detailers including the current user when registered/logged in as studio!
  List<UserProfile> get publicDetailers {
    final list = List<UserProfile>.from(_publicDetailers);
    final isStudio = _currentUser.role == UserRole.detailer || _currentUser.role == UserRole.superAdmin;
    if (_isLoggedIn && isStudio && _currentUser.location.isNotEmpty) {
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
  void toggleHostMode({UserRole? targetRole}) {
    final newRole = targetRole ?? (_currentUser.role == UserRole.detailer ? UserRole.client : UserRole.detailer);
    final isNowHost = newRole == UserRole.detailer;
    _currentUser = _currentUser.copyWith(
      role: newRole,
      isVerifiedHost: isNowHost,
    );
    LocalStorageService.saveWorkbenchMode(isNowHost ? 'studio' : 'garage');
    if (isNowHost) {
      _isLoggedIn = true;
      LocalStorageService.saveIsGuest(false);
    }
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
    final updatedList = [..._currentUser.myGarage, vehicle];
    _currentUser = _currentUser.copyWith(
      myGarage: updatedList,
    );
    LocalStorageService.saveGarageVehicles(updatedList);
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
      LocalStorageService.saveGarageVehicles(list);
      _persistUser();
      if (_isLoggedIn) {
        SupabaseDbService.saveVehicle(_currentUser.id, updated);
      }
      notifyListeners();
    }
  }

  void removeVehicleFromGarage(String vehicleId) {
    final updatedList = _currentUser.myGarage.where((v) => v.id != vehicleId).toList();
    _currentUser = _currentUser.copyWith(
      myGarage: updatedList,
    );
    LocalStorageService.saveGarageVehicles(updatedList);
    _persistUser();
    if (_isLoggedIn) {
      SupabaseDbService.deleteVehicle(vehicleId);
    }
    notifyListeners();
  }

  // Add a hired team member under your company profile (Detailer mode - Persisted)
  void addTeamMember(TeamMember member) {
    final updatedMembers = [..._currentUser.teamMembers, member];
    _currentUser = _currentUser.copyWith(
      teamMembers: updatedMembers,
    );
    LocalStorageService.saveTeamMembers(updatedMembers);
    _persistUser();
    final studioId = _currentUser.id != 'usr_you'
        ? _currentUser.id
        : (SupabaseAuthService.currentAuthUser?.id ?? _currentUser.id);
    if ((_isLoggedIn || SupabaseAuthService.isLoggedIn) && studioId != 'usr_you') {
      SupabaseDbService.saveTeamMember(studioId, member);
    }
    if (member.email != null &&
        member.email!.trim().isNotEmpty &&
        member.inviteStatus == 'pending') {
      final token = (member.inviteToken != null && member.inviteToken!.trim().isNotEmpty)
          ? member.inviteToken!
          : member.id;
      SupabaseAuthService.sendStaffInvitationEmail(
        email: member.email!.trim(),
        staffName: member.name,
        studioName: _currentUser.businessName.isNotEmpty
            ? _currentUser.businessName
            : _currentUser.displayName,
        inviteToken: token,
        inviteUrl: member.getInviteLink(studioId: studioId),
      );
    }
    notifyListeners();
  }

  void removeTeamMember(String memberId) {
    final updatedMembers = _currentUser.teamMembers.where((m) => m.id != memberId).toList();
    _currentUser = _currentUser.copyWith(
      teamMembers: updatedMembers,
    );
    LocalStorageService.saveTeamMembers(updatedMembers);
    _persistUser();
    if (_isLoggedIn || SupabaseAuthService.isLoggedIn) {
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
      LocalStorageService.saveTeamMembers(list);
      _persistUser();
      final studioId = _currentUser.id != 'usr_you'
          ? _currentUser.id
          : (SupabaseAuthService.currentAuthUser?.id ?? _currentUser.id);
      if ((_isLoggedIn || SupabaseAuthService.isLoggedIn) && studioId != 'usr_you') {
        SupabaseDbService.saveTeamMember(studioId, updated);
      }
      notifyListeners();
    }
  }

  // Add / Edit / Remove Service Package (Persisted immediately to dedicated storage)
  void addServicePackage(ServicePackage package) {
    final updatedList = [..._currentUser.servicePackages, package];
    _currentUser = _currentUser.copyWith(
      servicePackages: updatedList,
    );
    LocalStorageService.saveServicePackages(updatedList);
    _persistUser();
    notifyListeners();
  }

  void updateServicePackage(ServicePackage updated) {
    final idx = _currentUser.servicePackages.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      final list = List<ServicePackage>.from(_currentUser.servicePackages);
      list[idx] = updated;
      _currentUser = _currentUser.copyWith(servicePackages: list);
      LocalStorageService.saveServicePackages(list);
      _persistUser();
      notifyListeners();
    }
  }

  void removeServicePackage(String packageId) {
    final updatedList = _currentUser.servicePackages.where((p) => p.id != packageId).toList();
    _currentUser = _currentUser.copyWith(
      servicePackages: updatedList,
    );
    LocalStorageService.saveServicePackages(updatedList);
    _persistUser();
    notifyListeners();
  }

  /// Toggles like state and persists liked IDs + like counts across all jobs
  void toggleJobLike(String jobId) => toggleLike(jobId);

  void toggleLike(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      final job = _jobs[idx];
      final newIsLiked = !job.isLiked;
      final newLikesCount = newIsLiked
          ? job.likesCount + 1
          : (job.likesCount > 0 ? job.likesCount - 1 : 0);

      _jobs[idx] = job.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikesCount,
      );
      _persistInteractions();
      _persistLikeCounts();
      _persistCustomJobs();
      notifyListeners();
    }
  }

  void toggleSave(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      final job = _jobs[idx];
      final newIsSaved = !job.isSaved;
      final newSavesCount = newIsSaved
          ? job.savesCount + 1
          : (job.savesCount > 0 ? job.savesCount - 1 : 0);

      _jobs[idx] = job.copyWith(
        isSaved: newIsSaved,
        savesCount: newSavesCount,
      );
      _persistInteractions();
      _persistCustomJobs();
      notifyListeners();
    }
  }

  /// Aliases matching contract
  void addCustomJob(DetailJob newJob) => addJob(newJob);
  void uploadJob(DetailJob newJob) => addJob(newJob);

  void addJob(DetailJob newJob) {
    final existingIdx = _jobs.indexWhere((j) => j.id == newJob.id);
    if (existingIdx != -1) {
      _jobs[existingIdx] = newJob;
    } else {
      _jobs.insert(0, newJob);
    }
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
      LocalStorageService.saveJobCommentsOverride(updatedJob.id, updatedJob.comments);
      if (_isLoggedIn) {
        SupabaseDbService.saveJob(updatedJob);
      }
      notifyListeners();
    }
  }

  /// Retrieves comments for a job (from memory or overrides)
  List<JobComment> getCommentsForJob(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      return _jobs[idx].comments;
    }
    return [];
  }

  /// Appends a comment to any job (custom OR mock) and persists to both local storage overrides and cloud.
  Future<void> addComment(String jobId, JobComment comment) async {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final updatedComments = [..._jobs[idx].comments, comment];
    final updatedJob = _jobs[idx].copyWith(
      comments: updatedComments,
    );
    _jobs[idx] = updatedJob;

    // 1. Immediately persist comment override so it survives reload even on mock jobs
    await LocalStorageService.saveJobCommentsOverride(jobId, updatedComments);

    // 2. Persist custom jobs if custom job
    _persistCustomJobs();

    // 3. Persist to Supabase if logged in
    if (_isLoggedIn) {
      SupabaseDbService.saveJobComment(jobId, comment, currentJob: updatedJob);
    }

    notifyListeners();
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

  bool addBooking(BookingAppointment booking, {bool allowOverbooking = false}) {
    // 1. Guard against duplicate booking insertions (idempotency)
    final existingIdx = _bookings.indexWhere((b) => b.id == booking.id);
    if (existingIdx != -1) {
      _bookings[existingIdx] = booking;
      _persistBookings();
      if (_isLoggedIn) {
        SupabaseDbService.saveBooking(booking);
      }
      notifyListeners();
      return true;
    }

    // 2. Race condition guard: verify slot capacity has not been exhausted
    if (!allowOverbooking &&
        isSlotConflictedByBooking(
          booking.scheduledDate,
          booking.scheduledTimeSlot,
          detailerId: booking.detailerId,
          teamMemberId: booking.assignedTeamMemberId,
        )) {
      if (kDebugMode) {
        print('[JobRepository] addBooking rejected: Slot ${booking.scheduledTimeSlot} on ${booking.scheduledDate} is already conflicted or fully booked.');
      }
      return false;
    }

    _bookings.insert(0, booking);
    _persistBookings();
    if (_isLoggedIn) {
      SupabaseDbService.saveBooking(booking);
    }
    notifyListeners();
    return true;
  }

  void updateBookingStatus(String bookingId, BookingStatus newStatus) {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(status: newStatus);
      _persistBookings();
      if (_isLoggedIn) {
        SupabaseDbService.updateBookingStatus(bookingId, newStatus);
      }
      notifyListeners();
    }
  }

  void cancelBooking(String bookingId) {
    updateBookingStatus(bookingId, BookingStatus.cancelled);
  }

  bool rescheduleBooking(String bookingId, DateTime newDate, String newSlot) {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(
        scheduledDate: newDate,
        scheduledTimeSlot: newSlot,
      );
      _persistBookings();
      if (_isLoggedIn) {
        SupabaseDbService.saveBooking(_bookings[idx]);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // ─── CALENDAR & AVAILABILITY ────────────────────────────────────────────────

  Future<void> saveDetailerCalendarPreferences(DetailerCalendarPreferences preferences, {String? detailerId}) async {
    updateCalendarPreferences(preferences, detailerId: detailerId);
    final targetId = detailerId ?? _currentUser.id;
    await LocalStorageService.saveDetailerCalendarPreferences(preferences, detailerId: targetId);
    await LocalStorageService.saveCalendarPreferences(preferences);
    if (_isLoggedIn) {
      await SupabaseDbService.saveCalendarPreferences(targetId, preferences);
    }
  }

  void updateCalendarPreferences(DetailerCalendarPreferences preferences, {String? detailerId}) {
    _calendarPreferences = preferences;
    final targetId = detailerId ?? _currentUser.id;
    _detailerPreferencesMap[targetId] = preferences;
    _detailerPreferencesMap[_currentUser.id] = preferences;
    LocalStorageService.saveCalendarPreferences(preferences);
    LocalStorageService.saveDetailerCalendarPreferences(preferences, detailerId: targetId);
    if (_isLoggedIn) {
      SupabaseDbService.saveCalendarPreferences(targetId, preferences);
    }
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
              b.date.day == block.date.day &&
              b.teamMemberId == block.teamMemberId),
    );
    _availabilityBlocks.add(block);
    LocalStorageService.saveCalendarBlocks(_availabilityBlocks);
    if (_isLoggedIn) {
      SupabaseDbService.saveAvailabilityBlock(block);
    }
    notifyListeners();
  }

  void removeAvailabilityBlock(String blockId) {
    _availabilityBlocks.removeWhere((b) => b.id == blockId);
    LocalStorageService.saveCalendarBlocks(_availabilityBlocks);
    if (_isLoggedIn) {
      SupabaseDbService.deleteAvailabilityBlock(blockId);
    }
    notifyListeners();
  }

  void toggleBlockDay(
    DateTime date, {
    String? reason,
    String? detailerId,
    String? teamMemberId,
    List<String>? targetTeamMemberIds,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);

    if (targetTeamMemberIds != null && targetTeamMemberIds.isNotEmpty) {
      for (final mId in targetTeamMemberIds) {
        final idx = _availabilityBlocks.indexWhere(
          (b) => b.detailerId == targetDetailerId &&
                 b.date.year == normDate.year &&
                 b.date.month == normDate.month &&
                 b.date.day == normDate.day &&
                 b.isAllDay &&
                 b.teamMemberId == mId,
        );
        if (idx != -1) {
          _availabilityBlocks.removeAt(idx);
        } else {
          _availabilityBlocks.add(
            CalendarAvailabilityBlock(
              id: 'block_${DateTime.now().millisecondsSinceEpoch}_$mId',
              detailerId: targetDetailerId,
              teamMemberId: mId,
              date: normDate,
              isAllDay: true,
              reason: reason,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      LocalStorageService.saveCalendarBlocks(_availabilityBlocks);
      notifyListeners();
      return;
    }

    final isSpecificMember = teamMemberId != null && teamMemberId != 'all';
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             b.isAllDay &&
             (isSpecificMember
                 ? b.teamMemberId == teamMemberId
                 : (b.teamMemberId == null || b.teamMemberId == 'all')),
    );

    if (idx != -1) {
      final existing = _availabilityBlocks[idx];
      if (existing.hasCustomSlotsOverride || existing.customSlots.isNotEmpty) {
        _availabilityBlocks[idx] = existing.copyWith(isAllDay: false);
      } else {
        _availabilityBlocks.removeAt(idx);
      }
    } else {
      _availabilityBlocks.add(
        CalendarAvailabilityBlock(
          id: 'block_${DateTime.now().millisecondsSinceEpoch}',
          detailerId: targetDetailerId,
          teamMemberId: isSpecificMember ? teamMemberId : null,
          date: normDate,
          isAllDay: true,
          reason: reason,
          createdAt: DateTime.now(),
        ),
      );
    }
    LocalStorageService.saveCalendarBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void toggleBlockSlot(
    DateTime date,
    String slot, {
    String? reason,
    String? detailerId,
    String? teamMemberId,
    List<String>? targetTeamMemberIds,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);

    if (targetTeamMemberIds != null && targetTeamMemberIds.isNotEmpty) {
      for (final mId in targetTeamMemberIds) {
        _toggleBlockSlotSingle(normDate, slot, targetDetailerId, mId, reason, date);
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
      notifyListeners();
      return;
    }

    final mId = (teamMemberId != null && teamMemberId != 'all') ? teamMemberId : null;
    _toggleBlockSlotSingle(normDate, slot, targetDetailerId, mId, reason, date);
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  void _toggleBlockSlotSingle(DateTime normDate, String slot, String targetDetailerId, String? mId, String? reason, DateTime date) {
    final idx = _availabilityBlocks.indexWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             (mId == null
                 ? (b.teamMemberId == null || b.teamMemberId == 'all')
                 : b.teamMemberId == mId),
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
          id: 'block_${DateTime.now().millisecondsSinceEpoch}_${mId ?? "all"}',
          detailerId: targetDetailerId,
          teamMemberId: mId,
          date: normDate,
          isAllDay: false,
          blockedSlots: [slot],
          reason: reason,
          createdAt: DateTime.now(),
        ),
      );
    }
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
    bool allowPartialTrailingSlot = false,
  }) {
    final openMin = timeStringToMinutes(openTime);
    final closeMin = timeStringToMinutes(closeTime);
    if (closeMin <= openMin) return [];

    final stepMin = (slotDurationHours <= 0 ? 3 : slotDurationHours) * 60;
    final List<String> result = [];
    int cur = openMin;

    while (cur < closeMin) {
      final end = cur + stepMin;
      if (end <= closeMin) {
        result.add('${formatMinutesToTime(cur)} - ${formatMinutesToTime(end)}');
      } else if (allowPartialTrailingSlot) {
        result.add('${formatMinutesToTime(cur)} - ${formatMinutesToTime(closeMin)}');
      }
      cur += stepMin;
    }

    // Fallback: If operating window is shorter than duration, generate one slot for the full window
    if (result.isEmpty && closeMin > openMin) {
      result.add('${formatMinutesToTime(openMin)} - ${formatMinutesToTime(closeMin)}');
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

      // Filter slots that fall within operating hours
      final inHours = slots.where((s) => isSlotWithinOperatingHours(date, s, detailerId: targetDetailerId)).toList();
      final earliestSlotMin = inHours.isEmpty
          ? -1
          : inHours.map(timeStringToMinutes).reduce((a, b) => a < b ? a : b);

      if (inHours.isNotEmpty && earliestSlotMin == openMin) {
        slots = inHours;
      } else {
        // If configured slots don't cleanly align with this day's hours (e.g. Saturday 9am vs Monday 8am),
        // cleanly auto-generate slots for this day using the configured slotDurationHours!
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
    bool allowPartialTrailingSlot = false,
    DateTime? specificDate,
    String? detailerId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final generated = generateSlotsForHours(
      openTime: openTime,
      closeTime: closeTime,
      slotDurationHours: slotDurationHours,
      allowPartialTrailingSlot: allowPartialTrailingSlot,
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

      // When auto-generating across all operating days, clear date overrides
      // so all calendar dates adopt the new duration and slot template immediately!
      for (int i = 0; i < _availabilityBlocks.length; i++) {
        final b = _availabilityBlocks[i];
        if (b.detailerId == targetDetailerId) {
          _availabilityBlocks[i] = b.copyWith(
            customSlots: [],
            hasCustomSlotsOverride: false,
          );
        }
      }
      LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
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

  void clearBlockedSlotsForDate(DateTime date, {String? detailerId, String? teamMemberId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final normDate = DateTime(date.year, date.month, date.day);
    _availabilityBlocks.removeWhere(
      (b) => b.detailerId == targetDetailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             !b.hasCustomSlotsOverride &&
             b.customSlots.isEmpty &&
             (teamMemberId == null || teamMemberId == 'all' || b.teamMemberId == teamMemberId),
    );
    for (int i = 0; i < _availabilityBlocks.length; i++) {
      final b = _availabilityBlocks[i];
      if (b.detailerId == targetDetailerId &&
          b.date.year == normDate.year &&
          b.date.month == normDate.month &&
          b.date.day == normDate.day &&
          (teamMemberId == null || teamMemberId == 'all' || b.teamMemberId == teamMemberId)) {
        _availabilityBlocks[i] = b.copyWith(
          blockedSlots: const [],
          isAllDay: false,
        );
      }
    }
    LocalStorageService.saveAvailabilityBlocks(_availabilityBlocks);
    notifyListeners();
  }

  /// Returns complete studio staff roster (Founder + registered team members).
  List<TeamMember> getStudioStaff({String? detailerId}) {
    final targetId = detailerId ?? _currentUser.id;
    final user = (targetId != _currentUser.id)
        ? (publicDetailers.firstWhere((u) => u.id == targetId, orElse: () => _currentUser))
        : _currentUser;

    final founder = TeamMember(
      id: 'founder',
      name: '${user.displayName} (Founder)',
      roleTitle: 'Shop Owner / Lead Detailer',
      avatarUrl: user.avatarUrl,
      localAvatarBytes: user.localAvatarBytes,
      rating: user.averageRating,
      completedJobsCount: user.totalJobsCount,
      isAvailable: true,
      isFounder: true,
    );

    return [founder, ...user.teamMembers];
  }

  bool isMemberRecurringDayOff(String memberId, DateTime date, {String? detailerId}) {
    final targetId = detailerId ?? _currentUser.id;
    final user = (targetId != _currentUser.id)
        ? (publicDetailers.firstWhere((u) => u.id == targetId, orElse: () => _currentUser))
        : _currentUser;

    if (memberId == 'founder' || memberId == user.id) {
      return isDateRecurringDayOff(date, detailerId: targetId);
    }

    final member = user.teamMembers.where((m) => m.id == memberId).firstOrNull;
    if (member != null && member.customWeeklySchedule != null && member.customWeeklySchedule!.isNotEmpty) {
      final dayHours = member.customWeeklySchedule!.firstWhere(
        (h) => h.weekday == date.weekday,
        orElse: () => DayBusinessHours(weekday: date.weekday, isOpen: true),
      );
      return !dayHours.isOpen;
    }

    return isDateRecurringDayOff(date, detailerId: targetId);
  }

  bool isDateRecurringDayOff(DateTime date, {String? detailerId}) {
    final prefs = getCalendarPreferences(detailerId: detailerId);
    return !prefs.getHoursForWeekday(date.weekday).isOpen;
  }

  bool isDateExplicitlyBlocked(String detailerId, DateTime date, {String? teamMemberId}) {
    final normDate = DateTime(date.year, date.month, date.day);
    return _availabilityBlocks.any(
      (b) => b.detailerId == detailerId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             b.isAllDay &&
             (teamMemberId == null
                 ? (b.teamMemberId == null || b.teamMemberId == 'all')
                 : (b.teamMemberId == null || b.teamMemberId == 'all' || b.teamMemberId == teamMemberId)),
    );
  }

  bool isMemberOnDutyOnDate(String memberId, DateTime date, {String? detailerId}) {
    final targetId = detailerId ?? _currentUser.id;
    // 1. If entire studio is blocked all day
    if (isDateExplicitlyBlocked(targetId, date)) return false;
    // 2. If studio operating hours are closed
    final hours = getHoursForDate(date, detailerId: targetId);
    if (!hours.isOpen) return false;
    // 3. If member has recurring day off
    if (isMemberRecurringDayOff(memberId, date, detailerId: targetId)) return false;
    // 4. If member is explicitly blocked for this date
    final normDate = DateTime(date.year, date.month, date.day);
    final memberBlocked = _availabilityBlocks.any(
      (b) => b.detailerId == targetId &&
             b.date.year == normDate.year &&
             b.date.month == normDate.month &&
             b.date.day == normDate.day &&
             b.isAllDay &&
             (b.teamMemberId == memberId || b.teamMemberId == null || b.teamMemberId == 'all'),
    );
    if (memberBlocked) return false;
    return true;
  }

  bool isDateFullyBlocked(String detailerId, DateTime date) {
    if (isDateRecurringDayOff(date, detailerId: detailerId)) return true;
    final hours = getHoursForDate(date, detailerId: detailerId);
    if (!hours.isOpen) return true;
    if (isDateExplicitlyBlocked(detailerId, date)) return true;

    // Check if ALL studio staff are off or blocked on this date
    final staff = getStudioStaff(detailerId: detailerId);
    if (staff.isNotEmpty && !staff.any((s) => isMemberOnDutyOnDate(s.id, date, detailerId: detailerId))) {
      return true;
    }

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

  bool isSlotExplicitlyBlocked(String detailerId, DateTime date, String slot, {String? teamMemberId}) {
    return _availabilityBlocks.any(
      (b) => b.detailerId == detailerId &&
             b.date.year == date.year &&
             b.date.month == date.month &&
             b.date.day == date.day &&
             (teamMemberId == null
                 ? (b.teamMemberId == null || b.teamMemberId == 'all')
                 : (b.teamMemberId == null || b.teamMemberId == 'all' || b.teamMemberId == teamMemberId)) &&
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

  /// Calculates staffing breakdown and remaining client booking capacity for a time slot.
  SlotStaffingStatus getSlotStaffingStatus(DateTime date, String slot, {String? detailerId}) {
    final targetId = detailerId ?? _currentUser.id;
    final staff = getStudioStaff(detailerId: targetId);
    final totalStaff = staff.length;

    final studioBlocked = isDateExplicitlyBlocked(targetId, date) || isDateRecurringDayOff(date, detailerId: targetId);
    final withinHours = isSlotWithinOperatingHours(date, slot, detailerId: targetId);

    if (studioBlocked || !withinHours) {
      return SlotStaffingStatus(
        totalStaff: totalStaff,
        onDutyCount: 0,
        onDutyMemberIds: const [],
        offMemberIds: staff.map((s) => s.id).toList(),
        availableCapacity: 0,
        activeBookingsCount: 0,
        isFullyBooked: false,
        isBlocked: true,
      );
    }

    final onDutyIds = <String>[];
    final offIds = <String>[];
    for (final m in staff) {
      if (isMemberOnDutyOnDate(m.id, date, detailerId: targetId) &&
          !isSlotExplicitlyBlocked(targetId, date, slot, teamMemberId: m.id)) {
        onDutyIds.add(m.id);
      } else {
        offIds.add(m.id);
      }
    }

    final onDutyCount = onDutyIds.length;
    if (onDutyCount == 0) {
      return SlotStaffingStatus(
        totalStaff: totalStaff,
        onDutyCount: 0,
        onDutyMemberIds: const [],
        offMemberIds: offIds,
        availableCapacity: 0,
        activeBookingsCount: 0,
        isFullyBooked: false,
        isBlocked: true,
      );
    }

    final bookingsOnDate = getBookingsForDate(date, detailerId: targetId);
    final conflictingBookings = bookingsOnDate.where((b) => isBookingConflictingWithSlot(b, date, slot)).toList();
    final activeBookingsCount = conflictingBookings.length;

    final availableCapacity = (onDutyCount - activeBookingsCount).clamp(0, onDutyCount);
    final isFullyBooked = activeBookingsCount >= onDutyCount;

    return SlotStaffingStatus(
      totalStaff: totalStaff,
      onDutyCount: onDutyCount,
      onDutyMemberIds: onDutyIds,
      offMemberIds: offIds,
      availableCapacity: availableCapacity,
      activeBookingsCount: activeBookingsCount,
      isFullyBooked: isFullyBooked,
      isBlocked: false,
    );
  }

  bool isSlotBlocked(String detailerId, DateTime date, String slot) {
    if (isDateFullyBlocked(detailerId, date)) return true;
    final status = getSlotStaffingStatus(date, slot, detailerId: detailerId);
    return status.isBlocked;
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

  /// Checks if a specific team member is booked for [slot] on [date].
  bool isMemberBookedForSlot(String memberId, DateTime date, String slot, {String? detailerId}) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    final staff = getStudioStaff(detailerId: targetDetailerId);
    final bookingsOnDate = getBookingsForDate(date, detailerId: targetDetailerId);
    final conflictingBookings = bookingsOnDate.where((b) => isBookingConflictingWithSlot(b, date, slot)).toList();
    if (conflictingBookings.isEmpty) return false;

    // 1. If this member is explicitly assigned to any conflicting booking
    if (conflictingBookings.any((b) => b.assignedTeamMemberId == memberId)) {
      return true;
    }

    // 2. If studio has only 1 staff member (e.g. solo founder), any booking blocks them
    if (staff.length <= 1) {
      return true;
    }

    // 3. For unassigned bookings, check if remaining capacity is exhausted
    final status = getSlotStaffingStatus(date, slot, detailerId: targetDetailerId);
    return status.isFullyBooked;
  }

  /// Returns the first non-cancelled booking conflicting with [slot] on [date] for [detailerId].
  BookingAppointment? getConflictingBookingForSlot(
    DateTime date,
    String slot, {
    String? detailerId,
    String? teamMemberId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    for (final b in _bookings) {
      if (b.detailerId == targetDetailerId && isBookingConflictingWithSlot(b, date, slot)) {
        if (teamMemberId == null || teamMemberId == 'all' || b.assignedTeamMemberId == teamMemberId) {
          return b;
        }
      }
    }
    return null;
  }

  /// Checks if [slot] on [date] is booked or overlaps with any booked appointment.
  /// When [teamMemberId] is specified, checks availability of that specific technician.
  /// When null or 'all', returns true only if the slot is fully booked across all on-duty technicians.
  bool isSlotConflictedByBooking(
    DateTime date,
    String slot, {
    String? detailerId,
    String? teamMemberId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    if (teamMemberId != null && teamMemberId != 'all') {
      return isMemberBookedForSlot(teamMemberId, date, slot, detailerId: targetDetailerId);
    }
    final status = getSlotStaffingStatus(date, slot, detailerId: targetDetailerId);
    return status.isFullyBooked;
  }

  /// Checks if all slots on [date] are filled by bookings or conflicted.
  bool isDateFullyBooked(
    DateTime date, {
    String? detailerId,
    String? teamMemberId,
  }) {
    final targetDetailerId = detailerId ?? _currentUser.id;
    if (isDateRecurringDayOff(date, detailerId: targetDetailerId)) return true;
    final hours = getHoursForDate(date, detailerId: targetDetailerId);
    if (!hours.isOpen) return true;
    if (isDateExplicitlyBlocked(targetDetailerId, date, teamMemberId: teamMemberId)) return true;
    final slots = getTimeSlotsForDate(date, detailerId: targetDetailerId);
    if (slots.isEmpty) return false;
    final bookings = getBookingsForDate(date, detailerId: targetDetailerId);
    if (bookings.isEmpty) return false;
    return slots.every((s) {
      if (teamMemberId != null && teamMemberId != 'all') {
        return isSlotExplicitlyBlocked(targetDetailerId, date, s, teamMemberId: teamMemberId) ||
               isMemberBookedForSlot(teamMemberId, date, s, detailerId: targetDetailerId) ||
               !isSlotWithinOperatingHours(date, s, detailerId: targetDetailerId);
      }
      final status = getSlotStaffingStatus(date, s, detailerId: targetDetailerId);
      return status.isFullyBooked || status.isBlocked;
    });
  }

  void assignBookingTechnician(String bookingId, String memberId, String memberName) {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(
        assignedTeamMemberId: memberId,
        assignedTeamMemberName: memberName,
      );
      _persistBookings();
      if (_isLoggedIn) {
        SupabaseDbService.saveBooking(_bookings[idx]);
      }
      notifyListeners();
    }
  }

  void updateTeamMemberWeeklySchedule(String memberId, List<DayBusinessHours> schedule) {
    final updatedMembers = _currentUser.teamMembers.map((m) {
      if (m.id == memberId) {
        return m.copyWith(customWeeklySchedule: schedule);
      }
      return m;
    }).toList();
    _currentUser = _currentUser.copyWith(teamMembers: updatedMembers);
    LocalStorageService.saveTeamMembers(updatedMembers);
    _persistUser();
    if (_isLoggedIn) {
      final updatedMember = updatedMembers.where((m) => m.id == memberId).firstOrNull;
      if (updatedMember != null) {
        SupabaseDbService.saveTeamMember(_currentUser.id, updatedMember);
      }
    }
    notifyListeners();
  }

  void setActiveTeamMember(String? memberId) {
    if (_isStaffSession && memberId != _activeTeamMemberId) {
      // Direct employee sessions cannot switch accounts or elevate privileges
      return;
    }
    _activeTeamMemberId = (memberId == null || memberId.isEmpty || memberId == 'founder') ? null : memberId;
    if (_activeTeamMemberId != null) {
      _isOwnerLocked = false;
      LocalStorageService.saveIsOwnerLocked(false);
    }
    LocalStorageService.saveActiveTeamMemberId(_activeTeamMemberId);
    notifyListeners();
  }

  /// Fetches whether a PIN exists on the server (authoritative when signed in).
  Future<void> refreshOwnerPinStatus() async {
    final res = await SupabaseDbService.ownerPinStatus();
    if (res == null) return;
    final had = hasOwnerPin;
    _serverHasOwnerPin = res['has_pin'] == true;
    final until = res['locked_until'];
    if (until is String) _ownerPinLockedUntil = DateTime.tryParse(until)?.toLocal();
    if (had != hasOwnerPin) notifyListeners();
  }

  /// Offline check against the locally cached salted hash (no lockout accounting).
  bool verifyOwnerPin(String pin) => OwnerPinSecurity.verify(pin, _ownerPinHash);

  Future<void> _cacheOwnerPinHash(String pin) async {
    _ownerPinHash = OwnerPinSecurity.hashPin(pin);
    _currentUser = _currentUser.copyWith(ownerPinHash: _ownerPinHash);
    await LocalStorageService.saveOwnerPinHash(_ownerPinHash);
    _persistUser();
    if (_isLoggedIn) {
      await SupabaseDbService.saveUserProfile(_currentUser);
    }
  }

  Future<void> _registerPinFailure({DateTime? serverLockedUntil}) async {
    if (serverLockedUntil != null) {
      _ownerPinLockedUntil = serverLockedUntil;
      _ownerPinFails = 0;
    } else {
      _ownerPinFails++;
      if (_ownerPinFails >= _maxOwnerPinAttempts) {
        _ownerPinLockedUntil = DateTime.now().add(_ownerPinLockDuration);
        _ownerPinFails = 0;
      }
    }
    await LocalStorageService.saveOwnerPinLockout(_ownerPinFails, _ownerPinLockedUntil);
  }

  Future<void> _resetPinFailures() async {
    _ownerPinFails = 0;
    _ownerPinLockedUntil = null;
    await LocalStorageService.saveOwnerPinLockout(0, null);
  }

  OwnerPinResult _lockedResult() =>
      OwnerPinResult(ok: false, error: 'locked', lockedUntil: _ownerPinLockedUntil);

  /// First-time PIN creation: PIN entered twice, no "current PIN".
  Future<OwnerPinResult> createOwnerPin({required String pin, required String confirm}) async {
    final p = pin.trim();
    if (!OwnerPinSecurity.isValidFormat(p)) {
      return const OwnerPinResult(ok: false, error: 'invalid_format');
    }
    if (p != confirm.trim()) return const OwnerPinResult(ok: false, error: 'mismatch');
    if (hasOwnerPin) return const OwnerPinResult(ok: false, error: 'already_set');

    final res = await SupabaseDbService.setOwnerPin(newPin: p);
    if (res != null && res['ok'] != true) {
      if (res['error'] == 'wrong_pin') {
        // A PIN already exists server-side (e.g. created on another device).
        _serverHasOwnerPin = true;
        notifyListeners();
        return const OwnerPinResult(ok: false, error: 'already_set');
      }
      return OwnerPinResult(ok: false, error: res['error'] as String?);
    }
    if (res != null) _serverHasOwnerPin = true;
    await _cacheOwnerPinHash(p);
    await _resetPinFailures();
    notifyListeners();
    return const OwnerPinResult(ok: true);
  }

  /// Verifies a PIN with brute-force protection. Server is authoritative when available.
  Future<OwnerPinResult> attemptOwnerPin(String pin) async {
    if (!hasOwnerPin) return const OwnerPinResult(ok: false, error: 'no_pin');
    if (isOwnerPinLockedOut) return _lockedResult();

    final res = await SupabaseDbService.verifyOwnerPin(pin.trim());
    if (res != null && res['error'] != 'no_pin') {
      if (res['ok'] == true) {
        await _resetPinFailures();
        // Refresh local hash cache so offline verification stays in sync.
        if (!verifyOwnerPin(pin)) await _cacheOwnerPinHash(pin.trim());
        return const OwnerPinResult(ok: true);
      }
      if (res['error'] == 'locked') {
        final until = DateTime.tryParse('${res['locked_until']}')?.toLocal() ??
            DateTime.now().add(_ownerPinLockDuration);
        await _registerPinFailure(serverLockedUntil: until);
        notifyListeners();
        return _lockedResult();
      }
      final remaining = (res['remaining'] as num?)?.toInt();
      _ownerPinFails = _maxOwnerPinAttempts - (remaining ?? _maxOwnerPinAttempts);
      await LocalStorageService.saveOwnerPinLockout(_ownerPinFails, _ownerPinLockedUntil);
      return OwnerPinResult(ok: false, error: 'wrong_pin', remaining: remaining);
    }

    // Offline / not signed in: verify against the local salted hash.
    if (verifyOwnerPin(pin)) {
      await _resetPinFailures();
      return const OwnerPinResult(ok: true);
    }
    await _registerPinFailure();
    notifyListeners();
    if (isOwnerPinLockedOut) return _lockedResult();
    return OwnerPinResult(
      ok: false,
      error: 'wrong_pin',
      remaining: _maxOwnerPinAttempts - _ownerPinFails,
    );
  }

  /// Change an existing PIN (requires current PIN). Returns false on failure.
  Future<bool> setOwnerPin({required String currentPin, required String newPin}) async {
    final result = await changeOwnerPin(currentPin: currentPin, newPin: newPin);
    return result.ok;
  }

  Future<OwnerPinResult> changeOwnerPin({required String currentPin, required String newPin}) async {
    final cleanNew = newPin.trim();
    if (!OwnerPinSecurity.isValidFormat(cleanNew)) {
      return const OwnerPinResult(ok: false, error: 'invalid_format');
    }
    final check = await attemptOwnerPin(currentPin);
    if (!check.ok) return check;

    final res = await SupabaseDbService.setOwnerPin(currentPin: currentPin.trim(), newPin: cleanNew);
    if (res != null && res['ok'] != true) {
      return OwnerPinResult(ok: false, error: res['error'] as String?);
    }
    await _cacheOwnerPinHash(cleanNew);
    notifyListeners();
    return const OwnerPinResult(ok: true);
  }

  void lockOwnerView() {
    if (!hasOwnerPin) return; // Nothing to unlock with — UI prompts PIN creation first.
    _isOwnerLocked = true;
    LocalStorageService.saveIsOwnerLocked(true);
    notifyListeners();
  }

  Future<OwnerPinResult> unlockOwnerView(String pin) async {
    final result = await attemptOwnerPin(pin);
    if (result.ok) {
      _isOwnerLocked = false;
      LocalStorageService.saveIsOwnerLocked(false);
      notifyListeners();
    }
    return result;
  }

  Future<OwnerPinResult> unlockOwnerModeWithPin(String pin) async {
    final result = await attemptOwnerPin(pin);
    if (result.ok) {
      _isOwnerLocked = false;
      _activeTeamMemberId = null;
      LocalStorageService.saveIsOwnerLocked(false);
      LocalStorageService.saveActiveTeamMemberId(null);
      notifyListeners();
    }
    return result;
  }

  /// Verifies a team member's 4-digit PIN from the workstation lock modal and unlocks into their restricted view.
  bool unlockAsTeamMemberWithPin(String memberId, String pin) {
    final cleanPin = pin.trim();
    if (cleanPin.length != 4) return false;
    final member = _currentUser.teamMembers.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return false;
    final expectedPin = member.pin?.trim() ?? '';
    if (expectedPin.isEmpty || expectedPin != cleanPin) {
      return false;
    }
    _isOwnerLocked = false;
    _activeTeamMemberId = member.id;
    LocalStorageService.saveIsOwnerLocked(false);
    LocalStorageService.saveActiveTeamMemberId(member.id);
    notifyListeners();
    return true;
  }

  /// Verifies a team member's 4-digit PIN locally first, then falls back to server-side RPC (`verify_staff_pin_rpc`)
  /// so staff PINs work on secondary devices even when `pin` is only stored in `staff_security` online.
  Future<bool> unlockAsTeamMemberWithPinAsync(String memberId, String pin) async {
    if (unlockAsTeamMemberWithPin(memberId, pin)) {
      return true;
    }
    final cleanPin = pin.trim();
    if (cleanPin.length != 4) return false;
    final cloudRes = await SupabaseDbService.findStaffMember(
      memberId: memberId,
      pin: cleanPin,
    );
    if (cloudRes != null) {
      // Cache the verified PIN locally on this device so subsequent unlocks are instant
      final idx = _currentUser.teamMembers.indexWhere((m) => m.id == memberId);
      if (idx != -1) {
        final updatedList = List<TeamMember>.from(_currentUser.teamMembers);
        updatedList[idx] = updatedList[idx].copyWith(pin: cleanPin);
        _currentUser = _currentUser.copyWith(teamMembers: updatedList);
        await LocalStorageService.saveTeamMembers(updatedList);
        await LocalStorageService.saveCurrentUser(_currentUser);
      }
      _isOwnerLocked = false;
      _activeTeamMemberId = memberId;
      await LocalStorageService.saveIsOwnerLocked(false);
      await LocalStorageService.saveActiveTeamMemberId(memberId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setOwnerAutoLockMinutes(int minutes) async {
    _ownerAutoLockMinutes = minutes;
    await LocalStorageService.saveOwnerAutoLockMinutes(minutes);
    notifyListeners();
  }

  Future<void> logoutStaffMember() async {
    _unsubscribeFromRealtime();
    _isStaffSession = false;
    _activeTeamMemberId = null;
    await LocalStorageService.saveIsStaffSession(false);
    await LocalStorageService.saveActiveTeamMemberId(null);
    await LocalStorageService.logoutSession();
    await LocalStorageService.saveWorkbenchMode('garage');
    _isLoggedIn = false;
    _currentUser = MockDataService.youUser;
    notifyListeners();
  }

  Future<({bool success, String? error, TeamMember? member})> loginStaffMember({
    String? pin,
    String? email,
    String? password,
  }) async {
    final cleanPin = pin?.trim();
    final cleanEmail = email?.trim();
    final cleanPass = password?.trim();

    if ((cleanPin == null || cleanPin.isEmpty) &&
        (cleanEmail == null || cleanEmail.isEmpty)) {
      return (
        success: false,
        error: 'Please enter your 4-digit PIN or staff email.',
        member: null,
      );
    }

    // 1. Search locally in _currentUser.teamMembers
    TeamMember? matchedMember;
    for (final m in _currentUser.teamMembers) {
      if (cleanPin != null && cleanPin.isNotEmpty && m.authenticateWithPin(cleanPin)) {
        matchedMember = m;
        break;
      }
      if (cleanEmail != null &&
          cleanEmail.isNotEmpty &&
          m.authenticateWithPassword(cleanEmail, cleanPass ?? cleanPin ?? '')) {
        matchedMember = m;
        break;
      }
    }

    // 2. If not found in _currentUser, search in cached local storage team members
    if (matchedMember == null) {
      final cachedMembers = await LocalStorageService.loadTeamMembers();
      for (final m in cachedMembers) {
        if (cleanPin != null && cleanPin.isNotEmpty && m.authenticateWithPin(cleanPin)) {
          matchedMember = m;
          break;
        }
        if (cleanEmail != null &&
            cleanEmail.isNotEmpty &&
            m.authenticateWithPassword(cleanEmail, cleanPass ?? cleanPin ?? '')) {
          matchedMember = m;
          break;
        }
      }
      if (matchedMember != null) {
        final exists = _currentUser.teamMembers.any((m) => m.id == matchedMember!.id);
        if (!exists) {
          _currentUser = _currentUser.copyWith(teamMembers: [..._currentUser.teamMembers, matchedMember]);
        }
      }
    }

    // 3. If still not found, search Supabase cloud team members
    if (matchedMember == null) {
      try {
        final cloudRes = await SupabaseDbService.findStaffMember(
          pin: cleanPin,
          email: cleanEmail,
          password: cleanPass,
        );
        if (cloudRes != null) {
          matchedMember = cloudRes.member;
          final studioProfile = await SupabaseDbService.fetchUserProfile(cloudRes.studioId);
          if (studioProfile != null) {
            _currentUser = studioProfile;
          } else {
            _currentUser = _currentUser.copyWith(
              id: cloudRes.studioId,
              role: UserRole.detailer,
              teamMembers: [matchedMember],
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('[JobRepository] Cloud staff lookup error: $e');
      }
    }

    if (matchedMember == null) {
      return (
        success: false,
        error: 'Invalid Staff PIN or email credentials. Please check with your shop owner.',
        member: null,
      );
    }

    // Successful staff authentication
    _activeTeamMemberId = matchedMember.id;
    _isStaffSession = true;
    _isOwnerLocked = false;
    _isLoggedIn = true;
    _currentUser = _currentUser.copyWith(role: UserRole.detailer);

    await LocalStorageService.saveIsStaffSession(true);
    await LocalStorageService.saveActiveTeamMemberId(matchedMember.id);
    await LocalStorageService.saveWorkbenchMode('studio');
    await LocalStorageService.saveIsGuest(false);
    _persistUser();

    notifyListeners();
    return (success: true, error: null, member: matchedMember);
  }

  Future<({bool success, String? error})> sendStaffInvite(TeamMember member) async {
    final token = (member.inviteToken != null && member.inviteToken!.trim().isNotEmpty)
        ? member.inviteToken!
        : 'inv_${DateTime.now().millisecondsSinceEpoch}_${member.name.replaceAll(RegExp(r'\s+'), '').toLowerCase()}';
    final updated = member.copyWith(
      inviteToken: token,
      inviteStatus: 'pending',
      inviteSentAt: DateTime.now(),
    );
    updateTeamMember(updated);

    if (updated.email != null && updated.email!.trim().isNotEmpty) {
      return await SupabaseAuthService.sendStaffInvitationEmail(
        email: updated.email!.trim(),
        staffName: updated.name,
        studioName: _currentUser.businessName.isNotEmpty
            ? _currentUser.businessName
            : _currentUser.displayName,
        inviteToken: token,
        inviteUrl: updated.getInviteLink(studioId: _currentUser.id),
      );
    }
    return (success: true, error: null);
  }

  TeamMember? findMemberByInviteToken(String token) {
    final clean = token.trim();
    if (clean.isEmpty) return null;
    return _currentUser.teamMembers
        .where((m) => m.inviteToken == clean || m.id == clean)
        .firstOrNull;
  }

  Future<({bool success, String? error, TeamMember? member})> acceptStaffInvite({
    required String token,
    required String password,
  }) async {
    var cleanToken = token.trim();
    final cleanPass = password.trim();

    // If user pasted the full invite URL into the input box, extract only the `token` parameter
    if (cleanToken.contains('http://') || cleanToken.contains('https://') || cleanToken.contains('token=')) {
      final uri = Uri.tryParse(cleanToken);
      if (uri != null) {
        cleanToken = uri.queryParameters['token'] ?? uri.queryParameters['invite'] ?? cleanToken;
      }
    }

    if (cleanToken.isEmpty) {
      return (success: false, error: 'Invitation token is missing or invalid.', member: null);
    }
    if (cleanPass.length < 6) {
      return (success: false, error: 'Password must be at least 6 characters.', member: null);
    }

    TeamMember? matchedMember;

    // 1. Server-authoritative verification via Supabase SECURITY DEFINER RPC (accept_staff_invite_rpc)
    try {
      final cloudRes = await SupabaseDbService.acceptStaffInviteOnServer(
        token: cleanToken,
        newPassword: cleanPass,
      );
      if (cloudRes != null) {
        matchedMember = cloudRes.member;
        final studioProfile = await SupabaseDbService.fetchUserProfile(cloudRes.studioId);
        if (studioProfile != null) {
          final hasMember = studioProfile.teamMembers.any((m) => m.id == matchedMember!.id);
          _currentUser = hasMember
              ? studioProfile
              : studioProfile.copyWith(teamMembers: [...studioProfile.teamMembers, matchedMember]);
        } else {
          _currentUser = _currentUser.copyWith(
            id: cloudRes.studioId,
            role: UserRole.detailer,
            teamMembers: [matchedMember],
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('[JobRepository] Server invite verification error: $e');
    }

    // 2. Same-device local state check (when owner/staff test on the same device or offline)
    matchedMember ??= _currentUser.teamMembers
        .where((m) => m.inviteToken == cleanToken || m.id == cleanToken)
        .firstOrNull;

    if (matchedMember == null) {
      final cachedMembers = await LocalStorageService.loadTeamMembers();
      matchedMember = cachedMembers
          .where((m) => m.inviteToken == cleanToken || m.id == cleanToken)
          .firstOrNull;
      if (matchedMember != null) {
        final exists = _currentUser.teamMembers.any((m) => m.id == matchedMember!.id);
        if (!exists) {
          _currentUser = _currentUser.copyWith(teamMembers: [..._currentUser.teamMembers, matchedMember]);
        }
      }
    }

    if (matchedMember == null) {
      return (
        success: false,
        error: 'Invalid or expired invitation link. Please request a new invite from your shop owner.',
        member: null,
      );
    }

    // If authenticated via Supabase magic link, also set their Supabase Auth password
    if (SupabaseAuthService.isLoggedIn) {
      await SupabaseAuthService.updateUserPassword(cleanPass);
    }

    // Update member status to accepted (clear one-time inviteToken locally)
    final updatedMember = matchedMember.copyWith(
      password: cleanPass,
      inviteStatus: 'accepted',
    );
    updateTeamMember(updatedMember);

    // Automatically log in as the staff member into My Studio
    _activeTeamMemberId = updatedMember.id;
    _isStaffSession = true;
    _isOwnerLocked = false;
    _isLoggedIn = true;
    _currentUser = _currentUser.copyWith(role: UserRole.detailer);

    await LocalStorageService.saveIsStaffSession(true);
    await LocalStorageService.saveActiveTeamMemberId(updatedMember.id);
    await LocalStorageService.saveWorkbenchMode('studio');
    await LocalStorageService.saveIsGuest(false);
    _persistUser();

    notifyListeners();
    return (success: true, error: null, member: updatedMember);
  }

  Future<void> submitShiftRequest(ShiftRequest req) async {
    _shiftRequests.removeWhere((r) => r.teamMemberId == req.teamMemberId && r.isPending);
    _shiftRequests.insert(0, req);
    await LocalStorageService.saveShiftRequests(_shiftRequests);
    if (_isLoggedIn) {
      SupabaseDbService.saveShiftRequest(req);
    }
    notifyListeners();
  }

  Future<void> approveShiftRequest(String requestId, {String? reviewerNotes}) async {
    final idx = _shiftRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _shiftRequests[idx];
      final updatedReq = req.copyWith(
        status: ShiftRequestStatus.approved,
        reviewedAt: DateTime.now(),
        reviewerNotes: reviewerNotes,
      );
      _shiftRequests[idx] = updatedReq;
      await LocalStorageService.saveShiftRequests(_shiftRequests);
      if (_isLoggedIn) {
        SupabaseDbService.updateShiftRequestStatus(
          requestId,
          'approved',
          reviewedAt: updatedReq.reviewedAt,
          reviewerNotes: reviewerNotes,
        );
      }
      updateTeamMemberWeeklySchedule(req.teamMemberId, req.requestedSchedule);
    }
  }

  Future<void> rejectShiftRequest(String requestId, {String? notes}) async {
    final idx = _shiftRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _shiftRequests[idx];
      final updatedReq = req.copyWith(
        status: ShiftRequestStatus.rejected,
        reviewedAt: DateTime.now(),
        reviewerNotes: notes,
      );
      _shiftRequests[idx] = updatedReq;
      await LocalStorageService.saveShiftRequests(_shiftRequests);
      if (_isLoggedIn) {
        SupabaseDbService.updateShiftRequestStatus(
          requestId,
          'rejected',
          reviewedAt: updatedReq.reviewedAt,
          reviewerNotes: notes,
        );
      }
      notifyListeners();
    }
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

  // Studio Conversations: Client inquiries & chats addressed to this studio
  List<Conversation> get studioConversations {
    return _conversations.where((c) {
      final otherId = c.participantA == _currentUser.id ? c.participantB : c.participantA;
      final isOtherDetailer = _publicDetailers.any((d) => d.id == otherId && d.id != _currentUser.id);
      return !isOtherDetailer;
    }).toList();
  }

  // Client Conversations: Chats where this user contacted other detailers/shops
  List<Conversation> get clientConversations {
    return _conversations.where((c) {
      final otherId = c.participantA == _currentUser.id ? c.participantB : c.participantA;
      final isOtherDetailer = _publicDetailers.any((d) => d.id == otherId && d.id != _currentUser.id);
      return isOtherDetailer;
    }).toList();
  }

  int get studioUnreadMessages =>
      studioConversations.fold(0, (sum, c) => sum + c.unreadCount);

  int get clientUnreadMessages =>
      clientConversations.fold(0, (sum, c) => sum + c.unreadCount);

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

    // 5. Profiles realtime channel (for public studio discovery sync)
    _profilesChannel = client
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) {
            _refreshPublicDetailersFromCloud();
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
    _profilesChannel?.unsubscribe();
    _profilesChannel = null;
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }
}

