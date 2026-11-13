import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_models.dart';
import '../models/detail_job.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/map_launcher_service.dart';
import '../widgets/client_garage_gate.dart';
import '../widgets/job_recipe_card.dart';
import '../widgets/studio_share_dialog.dart';
import 'auth_modal.dart';
import 'booking_flow_screen.dart';
import 'chat_screen.dart';

class PublicStudioScreen extends StatefulWidget {
  final UserProfile detailer;
  final JobRepository repository;

  const PublicStudioScreen({
    super.key,
    required this.detailer,
    required this.repository,
  });

  @override
  State<PublicStudioScreen> createState() => _PublicStudioScreenState();
}

class _PublicStudioScreenState extends State<PublicStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPortfolioFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBookingFlow({ServicePackage? initialPackage}) {
    if (!widget.repository.isLoggedIn) {
      AuthModal.show(
        context,
        repository: widget.repository,
        onSuccess: () {
          if (mounted) _openBookingFlow(initialPackage: initialPackage);
        },
      );
      return;
    }

    if (widget.repository.currentUser.myGarage.isEmpty) {
      final name = widget.detailer.businessName.isNotEmpty
          ? widget.detailer.businessName
          : widget.detailer.displayName;
      ClientGarageGate.ensureHasVehicle(
        context: context,
        repository: widget.repository,
        detailerName: name,
        onProceedToBooking: () {
          if (mounted) _openBookingFlow(initialPackage: initialPackage);
        },
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          detailer: widget.detailer,
          repository: widget.repository,
          initialPackage: initialPackage,
        ),
      ),
    );
  }

  Future<void> _openChatWithDetailer() async {
    final repo = widget.repository;
    if (repo.isGuestMode) {
      AuthModal.show(
        context,
        repository: repo,
        onSuccess: () {
          if (mounted) _openChatWithDetailer();
        },
      );
      return;
    }
    final convId = await repo.openOrCreateConversation(widget.detailer.id);
    if (convId != null && mounted) {
      ChatScreen.open(
        context,
        conversationId: convId,
        otherUserName: widget.detailer.businessName.isNotEmpty
            ? widget.detailer.businessName
            : widget.detailer.displayName,
        otherUserAvatar: widget.detailer.avatarUrl,
        repository: repo,
      );
    }
  }

  String _formattedStudioAddress(UserProfile detailer) {
    final parts = <String>[
      if (detailer.studioStreetAddress.trim().isNotEmpty)
        detailer.studioStreetAddress.trim(),
      if (detailer.studioCity.trim().isNotEmpty) detailer.studioCity.trim(),
      if (detailer.studioState.trim().isNotEmpty) detailer.studioState.trim(),
      if (detailer.studioPostalCode.trim().isNotEmpty)
        detailer.studioPostalCode.trim(),
    ];
    return parts.join(', ');
  }

  bool _hasStudioDirections(UserProfile detailer) {
    final addr = _formattedStudioAddress(detailer);
    final hasCoords = detailer.effectiveStudioLatitude != null &&
        detailer.effectiveStudioLongitude != null;
    return addr.isNotEmpty || hasCoords;
  }

  Future<void> _launchDirections(UserProfile detailer) async {
    final addr = _formattedStudioAddress(detailer);
    await MapLauncherService.launchNavigation(
      latitude: detailer.effectiveStudioLatitude,
      longitude: detailer.effectiveStudioLongitude,
      address: addr.isNotEmpty ? addr : detailer.location,
      unitOrApt: detailer.studioUnitOrApt,
    );
  }

  double? _lowestStartingPrice(UserProfile detailer) {
    if (detailer.servicePackages.isNotEmpty) {
      final prices = detailer.servicePackages.map((p) => p.basePrice).toList()
        ..sort();
      return prices.first;
    }
    if (detailer.startingPrice > 0) {
      return detailer.startingPrice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final constrainedWidth = screenWidth > 1280 ? 1280.0 : screenWidth;
    final dynamicBannerHeight = (constrainedWidth / 3.2).clamp(180.0, 340.0);
    final detailer = widget.detailer;
    final studioJobs =
        widget.repository.jobs.where((j) => j.author.id == detailer.id).toList();
    final packages = detailer.servicePackages;
    final studioName = detailer.businessName.isNotEmpty
        ? detailer.businessName
        : detailer.displayName;
    final hasDirections = _hasStudioDirections(detailer);
    final startingPrice = _lowestStartingPrice(detailer);
    final completedJobs =
        detailer.totalJobsCount > 0 ? detailer.totalJobsCount : studioJobs.length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: dynamicBannerHeight,
              pinned: true,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: Colors.white, size: 18),
                    tooltip: 'Share Studio Website & QR',
                    onPressed: () {
                      StudioShareDialog.show(
                        context,
                        detailer: widget.detailer,
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    detailer.coverUrl.trim().isNotEmpty
                        ? Image.network(
                            detailer.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: AppTheme.surfaceLight),
                          )
                        : Container(color: AppTheme.surfaceLight),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(color: Colors.black.withAlpha(100)),
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: detailer.localCoverBytes != null
                              ? Image.memory(detailer.localCoverBytes!,
                                  fit: BoxFit.cover)
                              : (detailer.coverUrl.trim().isNotEmpty
                                  ? Image.network(
                                      detailer.coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox(),
                                    )
                                  : const SizedBox()),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withAlpha(40),
                            Colors.black.withAlpha(130),
                            AppTheme.background,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Luxury Hero & Trust Header
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.primary, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(140),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: AppTheme.surfaceLight,
                                backgroundImage: detailer.localAvatarBytes != null
                                    ? MemoryImage(detailer.localAvatarBytes!)
                                        as ImageProvider
                                    : (detailer.avatarUrl.trim().isNotEmpty
                                        ? NetworkImage(
                                            detailer.avatarUrl.trim())
                                        : null),
                                child: (detailer.localAvatarBytes == null &&
                                        detailer.avatarUrl.trim().isEmpty)
                                    ? Text(
                                        studioName.isNotEmpty
                                            ? studioName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studioName,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              size: 16, color: Colors.amber),
                                          const SizedBox(width: 3),
                                          Text(
                                            detailer.averageRating
                                                .toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${detailer.reviewCount} reviews)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '• $completedJobs jobs completed',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (detailer.location.trim().isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.location_on_outlined,
                                                size: 14,
                                                color: AppTheme.textMuted),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                detailer.location,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (detailer.serviceRadius
                                          .trim()
                                          .isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(25),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            detailer.serviceRadius,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (hasDirections)
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: const BorderSide(
                                                color: AppTheme.primary),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _launchDirections(detailer),
                                          icon: const Icon(
                                              Icons.directions_rounded,
                                              size: 14),
                                          label: const Text(
                                            'Directions',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (detailer.isVerifiedHost ||
                            detailer.isIdaCertified ||
                            detailer.isInsuranceVerified) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (detailer.isVerifiedHost)
                                _buildAuthorityBadge(
                                  icon: Icons.verified_rounded,
                                  label: 'Verified Pro',
                                ),
                              if (detailer.isIdaCertified)
                                _buildAuthorityBadge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: 'IDA Certified',
                                ),
                              if (detailer.isInsuranceVerified)
                                _buildAuthorityBadge(
                                  icon: Icons.shield_rounded,
                                  label: 'Insured',
                                ),
                            ],
                          ),
                        ],
                        if (detailer.bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            detailer.bio,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: screenWidth < 420,
                  tabAlignment:
                      screenWidth < 420 ? TabAlignment.start : TabAlignment.fill,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Services'),
                    Tab(text: 'Portfolio'),
                    Tab(text: 'Reviews'),
                    Tab(text: 'About & Studio'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildServicesTab(packages),
            _buildPortfolioTab(studioJobs),
            _buildReviewsTab(detailer, completedJobs),
            _buildAboutTab(detailer, hasDirections),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(detailer, startingPrice),
    );
  }

  Widget _buildAuthorityBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab(List<ServicePackage> packages) {
    if (packages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No service packages listed yet.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;
        final isWide = constraints.maxWidth >= 1024;
        final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

        if (!isDesktop) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final pkg = packages[index];
              final isFeatured =
                  pkg.isPopular || (packages.length > 1 && index == 0 && !packages.any((p) => p.isPopular));
              return _buildServicePackageCard(pkg, isFeatured: isFeatured);
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (int i = 0; i < packages.length; i++)
                    Builder(
                      builder: (context) {
                        final pkg = packages[i];
                        final isFeatured = pkg.isPopular ||
                            (packages.length > 1 &&
                                i == 0 &&
                                !packages.any((p) => p.isPopular));
                        final availableWidth =
                            constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                        final itemWidth =
                            (availableWidth - 32 - (crossAxisCount - 1) * 16) /
                                crossAxisCount;
                        return SizedBox(
                          width: itemWidth - 0.1,
                          child: _buildServicePackageCard(pkg, isFeatured: isFeatured),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioTab(List<DetailJob> studioJobs) {
    if (studioJobs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text(
                'No Transformations Published Yet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.detailer.displayName} has not published 50/50 transformation recipes yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final serviceTypes = <String>{
      'All',
      ...studioJobs
          .map((j) => j.serviceType.trim())
          .where((s) => s.isNotEmpty),
    }.toList();

    final filteredJobs = _selectedPortfolioFilter == 'All'
        ? studioJobs
        : studioJobs
            .where((j) => j.serviceType.trim() == _selectedPortfolioFilter)
            .toList();

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: serviceTypes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = serviceTypes[index];
              final selected = _selectedPortfolioFilter == type;
              return ChoiceChip(
                label: Text(type),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedPortfolioFilter = type;
                  });
                },
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : AppTheme.textPrimary,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.border,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              final isWide = constraints.maxWidth >= 1024;
              final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

              if (!isDesktop) {
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    return JobRecipeCard(
                      job: job,
                      repository: widget.repository,
                      onLike: () => widget.repository.toggleLike(job.id),
                      onSave: () => widget.repository.toggleSave(job.id),
                    );
                  },
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int col = 0; col < crossAxisCount; col++) ...[
                      if (col > 0) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            for (int i = col;
                                i < filteredJobs.length;
                                i += crossAxisCount)
                              JobRecipeCard(
                                job: filteredJobs[i],
                                repository: widget.repository,
                                onLike: () => widget.repository
                                    .toggleLike(filteredJobs[i].id),
                                onSave: () => widget.repository
                                    .toggleSave(filteredJobs[i].id),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(UserProfile detailer, int completedJobs) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 400;
                  final ratingBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detailer.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 28),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${detailer.reviewCount} verified reviews',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );

                  final statsBlock = Column(
                    crossAxisAlignment: isNarrow
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$completedJobs',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Text(
                        'Verified Bookings',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ratingBlock,
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: 12),
                        statsBlock,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ratingBlock,
                      statsBlock,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: const [
                  Icon(Icons.rate_review_outlined,
                      size: 40, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Verified Client Reviews',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Only clients who complete a booked studio service can leave a verified review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(UserProfile detailer, bool hasDirections) {
    final studioAddr = _formattedStudioAddress(detailer);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (detailer.bio.trim().isNotEmpty) ...[
              _buildInfoSection(
                title: 'About the Studio',
                icon: Icons.storefront_rounded,
                children: [
                  Text(
                    detailer.bio,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _buildInfoSection(
              title: 'Studio Location & Directions',
              icon: Icons.location_on_rounded,
              children: [
                if (studioAddr.isNotEmpty) ...[
                  Text(studioAddr, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                ] else if (detailer.location.trim().isNotEmpty) ...[
                  Text('Base City: ${detailer.location}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                ],
                if (detailer.serviceRadius.trim().isNotEmpty) ...[
                  Text(
                    'Service Radius: ${detailer.serviceRadius}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasDirections)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _launchDirections(detailer),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text(
                      'Get Directions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoSection(
              title: 'Professional Certifications',
              icon: Icons.verified_user_rounded,
              children: detailer.certifications.isEmpty
                  ? [
                      const Text(
                        'No public certifications uploaded yet.',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      )
                    ]
                  : detailer.certifications.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_rounded,
                                color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Text(c.issuer,
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
            if (detailer.teamMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                title: 'Studio Team',
                icon: Icons.groups_rounded,
                children: detailer.teamMembers.map((member) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.surfaceLight,
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              if (member.roleTitle.isNotEmpty)
                                Text(member.roleTitle,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (detailer.phone.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                title: 'Contact',
                icon: Icons.phone_outlined,
                children: [
                  Text(
                    'Phone: ${detailer.phone}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(UserProfile detailer, double? startingPrice) {
    final priceLabel = startingPrice != null
        ? 'From \$${startingPrice.toStringAsFixed(0)}'
        : 'Custom Quote';

    return Container(
      color: AppTheme.surface,
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(top: BorderSide(color: AppTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          priceLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Colors.amber),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                detailer.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Message',
                    constraints:
                        const BoxConstraints(minWidth: 38, minHeight: 38),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                    onPressed: _openChatWithDetailer,
                    icon: const Icon(Icons.chat_rounded, size: 17),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openBookingFlow(),
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: const Text(
                      'Book Appointment',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicePackageCard(ServicePackage pkg, {bool isFeatured = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFeatured ? AppTheme.primary.withAlpha(160) : AppTheme.border,
          width: isFeatured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFeatured) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Most Popular',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pkg.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${pkg.basePrice.toStringAsFixed(0)}+',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pkg.estimatedDuration,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          ...pkg.includes.map((feat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFeatured ? AppTheme.primary : AppTheme.surfaceLight,
                foregroundColor: isFeatured ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openBookingFlow(initialPackage: pkg),
              child: const Text(
                'Book This Service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
