import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/detail_job.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../models/user_vehicle.dart';
import '../services/job_repository.dart';
import 'job_detail_screen.dart';
import 'booking_flow_screen.dart';
import 'vehicle_editor_dialog.dart';
import 'auth_modal.dart';
import 'edit_profile_dialog.dart';
import 'add_team_member_dialog.dart';
import '../widgets/job_recipe_card.dart';

class ProfileScreen extends StatefulWidget {
  final JobRepository repository;

  const ProfileScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openVehicleEditor(BuildContext context, [UserVehicle? vehicle]) {
    if (!widget.repository.isLoggedIn) {
      AuthModal.show(
        context,
        repository: widget.repository,
        initialIsSignUp: false,
        onSuccess: () => _openVehicleEditor(context, vehicle),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => VehicleEditorDialog(
        repository: widget.repository,
        vehicleToEdit: vehicle,
      ),
    );
  }

  void _showAddTeamMemberDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Lead Paint Correction Specialist');
    final avatarCtrl = TextEditingController(
      text: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Text('Add Team Specialist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Specialty / Role Title',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Photo URL',
                    prefixIcon: Icon(Icons.photo_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final newMember = TeamMember(
                    id: 'team_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    roleTitle: roleCtrl.text.trim(),
                    avatarUrl: avatarCtrl.text.trim(),
                    completedJobsCount: 0,
                    rating: 5.0,
                  );
                  widget.repository.addTeamMember(newMember);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add to Company', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                  title: const Text('Edit Profile & Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Change display name, avatar, bio, location', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    EditProfileDialog.show(context, repository: widget.repository);
                  },
                ),
                const Divider(color: AppTheme.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.orangeAccent),
                  title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Return to guest browsing mode', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await widget.repository.logoutUser();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You have been logged out.'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    }
                  },
                ),
                const Divider(color: AppTheme.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Permanently remove your garage and studio data', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteAccount(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? All registered vehicles, profile info, and local settings will be permanently cleared.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.repository.deleteAccount();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account data has been deleted.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withAlpha(60), width: 2),
              ),
              child: const Icon(Icons.directions_car_filled_rounded, size: 54, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to AutoDetailCraft',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in or create an account to manage your personal garage, store paint correction recipes, or start your own detailing business host profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In to My Studio / Garage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => AuthModal.show(context, repository: widget.repository, initialIsSignUp: false),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Create New Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => AuthModal.show(context, repository: widget.repository, initialIsSignUp: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final isLoggedIn = widget.repository.isLoggedIn;
        if (!isLoggedIn) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Studio & Garage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: AppTheme.background,
              elevation: 0,
            ),
            body: _buildGuestView(),
          );
        }

        final user = widget.repository.currentUser;
        final isDetailer = user.role == UserRole.detailer;
        final myJobs = widget.repository.getJobsByDetailer(user.id);
        final packages = user.servicePackages;
        final team = user.teamMembers;
        final garage = user.myGarage;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: AppTheme.background,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      tooltip: 'Account Settings',
                      onPressed: () => _showAccountMenu(context),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        user.localCoverBytes != null
                            ? Image.memory(
                                user.localCoverBytes!,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                user.coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceLight),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.background.withAlpha(200),
                                AppTheme.background,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => EditProfileDialog.show(context, repository: widget.repository),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.primary, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(150),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 36,
                                        backgroundImage: user.localAvatarBytes != null
                                            ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                                            : NetworkImage(user.avatarUrl),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isDetailer ? user.businessName : user.displayName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (user.isVerifiedHost)
                                          const Icon(Icons.verified_rounded, size: 18, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => EditProfileDialog.show(context, repository: widget.repository),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(100),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            child: const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.location,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (isDetailer) ...[
                                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${user.averageRating} (${user.reviewCount} reviews)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isDetailer ? 'Detailer Host' : 'Vehicle Owner',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Detailer / Regular User Mode Switch Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isDetailer ? Icons.storefront_rounded : Icons.person_rounded,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDetailer ? 'Detailer Mode Active' : 'Regular User Mode Active',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      isDetailer
                                          ? 'Showing Storefront, Services & Pricing, and Portfolio'
                                          : 'Showing Garage, My Vehicles, and Care History',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDetailer ? AppTheme.surfaceLight : AppTheme.primary,
                                  foregroundColor: isDetailer ? AppTheme.primary : Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => widget.repository.toggleHostMode(),
                                child: Text(
                                  isDetailer ? 'Switch to Client' : 'Switch to Detailer',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bio
                        Text(user.bio, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                        const SizedBox(height: 10),

                        // Detailer Contact & Certifications Info
                        if (isDetailer) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 13, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text(user.phone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, size: 13, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text(user.instagramHandle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Text(user.serviceRadius, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),

                // Detailer Mode Tabs (Portfolio / Services / Team)
                if (isDetailer)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                        tabs: const [
                          Tab(text: 'Portfolio'),
                          Tab(text: 'Services & Pricing'),
                          Tab(text: 'My Team (Hires)'),
                        ],
                      ),
                    ),
                  ),
              ];
            },
            body: isDetailer
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Detailer Portfolio
                      myJobs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No Portfolio Recipes Yet',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Use the Post (+) tab in the bottom bar to publish your 50/50 paint correction recipes.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: myJobs.length,
                              itemBuilder: (context, index) {
                                final job = myJobs[index];
                                return JobRecipeCard(
                                  job: job,
                                  repository: widget.repository,
                                  onLike: () => widget.repository.toggleLike(job.id),
                                  onSave: () => widget.repository.toggleSave(job.id),
                                );
                              },
                            ),

                      // TAB 2: Services & Pricing
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: packages.length,
                        itemBuilder: (context, index) {
                          final pkg = packages[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: pkg.isPopular ? AppTheme.primary.withAlpha(150) : AppTheme.border,
                                width: pkg.isPopular ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pkg.title,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      '\$${pkg.basePrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(pkg.estimatedDuration, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(pkg.description, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                const SizedBox(height: 12),
                                ...pkg.includes.map((inc) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(inc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          );
                        },
                      ),

                      // TAB 3: My Team (Hired Staff)
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. OWNER / FOUNDER CARD AT THE TOP
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primary, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundImage: user.localAvatarBytes != null
                                          ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                                          : NetworkImage(user.avatarUrl),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.black),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.displayName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withAlpha(30),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.primary.withAlpha(120)),
                                            ),
                                            child: const Text(
                                              'Founder & Lead Master',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        user.businessName,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text('${user.averageRating} Rating', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Text('• ${user.totalJobsCount} jobs completed', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                                  tooltip: 'Edit Profile',
                                  onPressed: () => EditProfileDialog.show(context, repository: widget.repository),
                                ),
                              ],
                            ),
                          ),

                          // 2. ADD STAFF BUTTON
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              foregroundColor: AppTheme.primary,
                              minimumSize: const Size(double.infinity, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Add Hired Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => AddTeamMemberDialog.show(context, repository: widget.repository),
                          ),
                          const SizedBox(height: 14),

                          // 3. HIRED STAFF MEMBERS LIST
                          if (team.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No additional staff hired yet.\nWhen you expand your business, add hired specialists here so clients can select them when booking!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                                ),
                              ),
                            )
                          else
                            ...team.map((member) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: member.localAvatarBytes != null
                                          ? MemoryImage(member.localAvatarBytes!) as ImageProvider
                                          : NetworkImage(member.avatarUrl),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(member.roleTitle, style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                              const SizedBox(width: 4),
                                              Text('${member.rating} Rating', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                              const SizedBox(width: 8),
                                              Text('• ${member.completedJobsCount} jobs done', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                                      tooltip: 'Remove from team',
                                      onPressed: () => widget.repository.removeTeamMember(member.id),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ],
                  )
                // REGULAR USER VIEW: My Garage & Registered Vehicles with Edit & Upload Options
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                          foregroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Vehicle to My Garage', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _openVehicleEditor(context),
                      ),
                      const SizedBox(height: 14),
                      if (garage.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No vehicles added yet.\nAdd your car to store your paint color and track digital detail warranty passports!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                            ),
                          ),
                        )
                      else
                        ...garage.map((veh) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: veh.localImageBytes != null
                                      ? Image.memory(
                                          veh.localImageBytes!,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          veh.imageUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              veh.fullName,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Edit Button
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                                            tooltip: 'Edit Vehicle & Photo',
                                            onPressed: () => _openVehicleEditor(context, veh),
                                          ),
                                          // Delete Button
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 18),
                                            tooltip: 'Remove from Garage',
                                            onPressed: () => widget.repository.removeVehicleFromGarage(veh.id),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.palette_outlined, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Paint Color: ${veh.colorName}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      if (veh.lastDetailService != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.primary.withAlpha(50)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Active Care: ${veh.lastDetailService}',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
