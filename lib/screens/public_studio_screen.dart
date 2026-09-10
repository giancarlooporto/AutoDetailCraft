import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../services/job_repository.dart';
import '../widgets/job_recipe_card.dart';
import 'booking_flow_screen.dart';

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

class _PublicStudioScreenState extends State<PublicStudioScreen> with SingleTickerProviderStateMixin {
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

  void _openBookingFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          detailer: widget.detailer,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailer = widget.detailer;
    final studioJobs = widget.repository.jobs.where((j) => j.author.id == detailer.id).toList();
    final packages = detailer.servicePackages;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
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
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Storefront link copied for ${detailer.businessName.isNotEmpty ? detailer.businessName : detailer.displayName}'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Blurred Full-Width Background
                    Image.network(
                      detailer.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surfaceLight),
                    ),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(color: Colors.black.withAlpha(100)),
                      ),
                    ),
                    // 2. Crisp Centered Foreground Image
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: detailer.localCoverBytes != null
                              ? Image.memory(detailer.localCoverBytes!, fit: BoxFit.cover)
                              : Image.network(
                                  detailer.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withAlpha(50),
                            Colors.black.withAlpha(140),
                            AppTheme.background,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(150),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundImage: detailer.localAvatarBytes != null
                                  ? MemoryImage(detailer.localAvatarBytes!) as ImageProvider
                                  : NetworkImage(detailer.avatarUrl),
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
                                        detailer.businessName.isNotEmpty ? detailer.businessName : detailer.displayName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (detailer.isVerifiedHost) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 18),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detailer.location,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${detailer.averageRating} (${detailer.reviewCount} reviews)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        detailer.serviceRadius,
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
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (detailer.bio.isNotEmpty) ...[
                      Text(
                        detailer.bio,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Quick stats badges
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.auto_awesome_motion_rounded,
                          label: 'Transformations',
                          value: '${studioJobs.isNotEmpty ? studioJobs.length : detailer.totalJobsCount}',
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          icon: Icons.shield_outlined,
                          label: 'Certifications',
                          value: '${detailer.certifications.length} Pro',
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          icon: Icons.timelapse_rounded,
                          label: 'Response Time',
                          value: '< 1 hr',
                        ),
                      ],
                    ),
                    if (detailer.certifications.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: detailer.certifications.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primary.withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_outlined, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  '${c.title} • ${c.issuer}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Transformations'),
                    Tab(text: 'Services & Pricing'),
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
            // TAB 1: Transformations
            studioJobs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No Transformations Published Yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${detailer.displayName} has not published 50/50 transformation recipes yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 720;
                      final isWide = constraints.maxWidth >= 1024;
                      final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

                      return !isDesktop
                          ? ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: studioJobs.length,
                              itemBuilder: (context, index) {
                                final job = studioJobs[index];
                                return JobRecipeCard(
                                  job: job,
                                  repository: widget.repository,
                                  onLike: () => widget.repository.toggleLike(job.id),
                                  onSave: () => widget.repository.toggleSave(job.id),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int col = 0; col < crossAxisCount; col++) ...[
                                    if (col > 0) const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          for (int i = col; i < studioJobs.length; i += crossAxisCount)
                                            JobRecipeCard(
                                              job: studioJobs[i],
                                              repository: widget.repository,
                                              onLike: () => widget.repository.toggleLike(studioJobs[i].id),
                                              onSave: () => widget.repository.toggleSave(studioJobs[i].id),
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

            // TAB 2: Services & Pricing
            packages.isEmpty
                ? const Center(
                    child: Text('No service packages listed yet.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 720;
                      final isWide = constraints.maxWidth >= 1024;
                      final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

                      return !isDesktop
                          ? ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: packages.length,
                              itemBuilder: (context, index) {
                                return _buildServicePackageCard(packages[index]);
                              },
                            )
                                                    : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: packages.map((pkg) {
                                  final availableWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                                  final itemWidth = (availableWidth - 32 - (crossAxisCount - 1) * 16) / crossAxisCount;
                                  return SizedBox(
                                    width: itemWidth - 0.1,
                                    child: _buildServicePackageCard(pkg),
                                  );
                                }).toList(),
                              ),
                            );
                    },
                  ),

            // TAB 3: About & Studio Info
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoSection(
                      title: 'Studio Location & Service Coverage',
                      icon: Icons.location_on_rounded,
                      children: [
                        Text('Base City: ${detailer.location}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Service Radius: ${detailer.serviceRadius}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        const Text('Studio Facility: Climate-controlled clean bay with multi-spectrum color-match LED lighting.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      title: 'Professional Certifications',
                      icon: Icons.verified_user_rounded,
                      children: detailer.certifications.isEmpty
                          ? [const Text('No public certifications uploaded yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))]
                          : detailer.certifications.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(c.issuer, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      title: 'Equipment & Precision Standards',
                      icon: Icons.precision_manufacturing_rounded,
                      children: const [
                        Text('• RUPES BigFoot & FLEX Cordless Rotary Polishing Units', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('• DeFelsko PosiTector 200 Ultrasonic Paint Depth Gauge (Pre & Post micron audit)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('• Scangrip 3-Color High CRI+ SunMatch Inspection Lamps', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('• 100% DI Pure Deionized Spot-Free Water Filtration System', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppTheme.surface,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Next Available Slot', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          const Text('This Week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _openBookingFlow,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: const Text(
                        'Book Studio Service',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicePackageCard(ServicePackage pkg) {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pkg.description,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${pkg.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  Text(
                    pkg.estimatedDuration,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
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
                backgroundColor: pkg.isPopular ? AppTheme.primary : AppTheme.surfaceLight,
                foregroundColor: pkg.isPopular ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openBookingFlow,
              child: Text(
                'Book ${pkg.title}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
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
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
