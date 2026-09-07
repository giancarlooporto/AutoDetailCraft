import 'package:flutter/foundation.dart';
import '../models/detail_job.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../models/user_vehicle.dart';
import 'mock_data_service.dart';
import 'local_storage_service.dart';
import 'supabase_auth_service.dart';
import 'supabase_db_service.dart';

class JobRepository extends ChangeNotifier {
  List<DetailJob> _jobs = [];
  List<BookingAppointment> _bookings = [];
  List<UserProfile> _publicDetailers = [];
  UserProfile _currentUser = MockDataService.youUser; // Default fallback

  String _selectedServiceType = 'All Services';
  String _selectedLocationCity = 'All Locations';
  String _searchQuery = '';
  int _activeTabIndex = 0;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  JobRepository() {
    init();
  }

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
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
      // Background refresh profile from Supabase Database if online
      _refreshProfileFromCloud(savedUser.id);
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
      _refreshProfileFromCloud(authUser.id);
    } else {
      _isLoggedIn = false;
    }

    // 3. Load persistent bookings if logged in
    final savedBookings = await LocalStorageService.loadBookings();
    if (savedBookings != null) {
      _bookings = savedBookings;
    }

    // 4. Load persistent likes & bookmarks
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

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _refreshProfileFromCloud(String userId) async {
    try {
      final cloudProfile = await SupabaseDbService.fetchUserProfile(userId);
      if (cloudProfile != null) {
        _currentUser = cloudProfile;
        _persistUser();
        notifyListeners();
      }
    } catch (_) {}
  }

  void loginUser(UserProfile user) {
    _currentUser = user;
    _isLoggedIn = true;
    LocalStorageService.saveIsGuest(false);
    _persistUser();
    // Try to fetch latest cloud state
    _refreshProfileFromCloud(user.id);
    notifyListeners();
  }

  Future<void> logoutUser() async {
    await SupabaseAuthService.signOut();
    await LocalStorageService.logoutSession();
    _isLoggedIn = false;
    _currentUser = MockDataService.youUser;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
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

  void _persistInteractions() {
    final liked = _jobs.where((j) => j.isLiked).map((j) => j.id).toSet();
    final saved = _jobs.where((j) => j.isSaved).map((j) => j.id).toSet();
    LocalStorageService.saveInteractionState(likedJobIds: liked, savedJobIds: saved);
  }

  // Getters
  List<DetailJob> get jobs => _jobs;
  List<BookingAppointment> get bookings => _bookings;
  
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
    return _jobs.where((job) {
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
  }

  // Filtered detailers list for Explore search
  List<UserProfile> get filteredDetailers {
    return publicDetailers.where((detailer) {
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

  // Turo-Style Host Promotion / Mode Toggle
  void toggleHostMode() {
    final isNowHost = _currentUser.role == UserRole.client;
    _currentUser = _currentUser.copyWith(
      role: isNowHost ? UserRole.detailer : UserRole.client,
      isVerifiedHost: isNowHost,
    );
    _persistUser();
    notifyListeners();
  }

  // Update subscription tier (free, pro, enterprise)
  void updateSubscriptionTier(SubscriptionTier tier) {
    _currentUser = _currentUser.copyWith(subscriptionTier: tier);
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
    if (_currentUser.id == newJob.author.id) {
      _currentUser = _currentUser.copyWith(
        totalJobsCount: _currentUser.totalJobsCount + 1,
      );
      _persistUser();
    }
    notifyListeners();
  }

  void addBooking(BookingAppointment booking) {
    _bookings.insert(0, booking);
    _persistBookings();
    notifyListeners();
  }

  void updateBookingStatus(String bookingId, BookingStatus newStatus) {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final b = _bookings[idx];
      _bookings[idx] = BookingAppointment(
        id: b.id,
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
      notifyListeners();
    }
  }
}
