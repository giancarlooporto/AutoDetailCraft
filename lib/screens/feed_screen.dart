import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../widgets/job_recipe_card.dart';
import 'booking_flow_screen.dart';
import 'public_studio_screen.dart';

class FeedScreen extends StatefulWidget {
  final JobRepository repository;

  const FeedScreen({super.key, required this.repository});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openBookingForDetailer(BuildContext context, UserProfile detailer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          detailer: detailer,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _openPublicStudio(BuildContext context, UserProfile detailer) {
    print('DEBUG: _openPublicStudio called for ${detailer.displayName}!');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicStudioScreen(
          detailer: detailer,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final jobs = widget.repository.filteredJobs;
        final detailers = widget.repository.filteredDetailers;
        final activeCities = widget.repository.activeCitiesWithDetailers;
        final selectedCity = widget.repository.selectedLocationCity;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;

            return Scaffold(
              appBar: isDesktop
                  ? null
                  : AppBar(
                      title: _isSearching
                          ? TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Search city, detailer name, ceramic...',
                                border: InputBorder.none,
                              ),
                              onChanged: (v) => widget.repository.setSearchQuery(v),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'AutoDetailCraft',
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                      actions: [
                        IconButton(
                          icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
                          onPressed: () {
                            setState(() {
                              _isSearching = !_isSearching;
                              if (!_isSearching) {
                                _searchCtrl.clear();
                                widget.repository.setSearchQuery('');
                              }
                            });
                          },
                        ),
                      ],
                    ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Desktop Turo-style Search & Filter Pill (Centered)
                        if (isDesktop) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 580),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Search transformations, studios, cities...',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (v) => widget.repository.setSearchQuery(v),
                                        ),
                                      ),
                                      if (_searchCtrl.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            widget.repository.setSearchQuery('');
                                            setState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // 1. Dynamic Active Cities Filter (Includes your registered location!)
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 14),
                      children: activeCities.map((loc) {
                        final isSelected = selectedCity == loc;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(
                              loc == 'All Locations' ? Icons.travel_explore_rounded : Icons.location_on_rounded,
                              size: 14,
                              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            label: Text(loc),
                            selected: isSelected,
                            onSelected: (_) => widget.repository.setLocationFilter(loc),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // 2. Service Category Filter Bar
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 14),
                      children: AppConstants.serviceTypes.map((service) {
                        final isSelected = widget.repository.selectedServiceType == service;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(service, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (_) => widget.repository.setServiceFilter(service),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // 3. Highlighted Detailers in Selected City (Shows your studio card!)
                  if (detailers.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              selectedCity == 'All Locations'
                                  ? 'Featured Detailers & Studios'
                                  : 'Verified Detailers in $selectedCity',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${detailers.length} Studios',
                            style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 126,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 14, vertical: 4),
                        itemCount: detailers.length,
                        itemBuilder: (context, idx) {
                          final d = detailers[idx];
                          final isYou = widget.repository.isLoggedIn && d.id == widget.repository.currentUser.id;

                          return GestureDetector(
                            key: Key('detailer_card_${d.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openPublicStudio(context, d),
                            child: Container(
                              width: 250,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isYou ? AppTheme.primary : AppTheme.border,
                                  width: isYou ? 1.5 : 1,
                                ),
                                boxShadow: isYou
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withAlpha(20),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: d.localAvatarBytes != null
                                          ? MemoryImage(d.localAvatarBytes!) as ImageProvider
                                          : NetworkImage(d.avatarUrl),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  d.businessName.isNotEmpty ? d.businessName : d.displayName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isYou) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primary.withAlpha(30),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                                ),
                                              ] else if (d.subscriptionTier != SubscriptionTier.free) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: d.subscriptionTier == SubscriptionTier.enterprise
                                                        ? Colors.purpleAccent.withAlpha(40)
                                                        : AppTheme.primary.withAlpha(40),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    d.subscriptionTier == SubscriptionTier.enterprise ? 'SHOP' : 'PRO',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: d.subscriptionTier == SubscriptionTier.enterprise ? Colors.purpleAccent : AppTheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ] else if (d.isVerifiedHost) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified_rounded, size: 13, color: AppTheme.primary),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(d.location, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                          const SizedBox(width: 3),
                                          Text('${d.averageRating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '• ${d.serviceRadius}',
                                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isYou ? AppTheme.surfaceLight : AppTheme.primary,
                                        foregroundColor: isYou ? AppTheme.primary : Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(60, 28),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _openBookingForDetailer(context, d),
                                      child: Text(isYou ? 'My Studio' : 'Book', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      ),
                    ),
                    const Divider(color: AppTheme.border, height: 16),
                  ],

                  // 4. Paint Correction & Ceramic Coating Transformation Feed
                  Expanded(
                    child: jobs.isEmpty && detailers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_city_rounded, size: 54, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No detailers or posts found in "$selectedCity"',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Register as a detailer under My Studio to appear here!',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    widget.repository.clearFilters();
                                  },
                                  label: const Text('Reset All Filters', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                            onRefresh: () async {
                              await Future.delayed(const Duration(milliseconds: 600));
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isDesktop = constraints.maxWidth >= 720;
                                final isWide = constraints.maxWidth >= 1024;
                                final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

                                return !isDesktop
                                    ? ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        itemCount: jobs.length,
                                        itemBuilder: (context, idx) {
                                          final job = jobs[idx];
                                          return JobRecipeCard(
                                            job: job,
                                            repository: widget.repository,
                                            onLike: () => widget.repository.toggleLike(job.id),
                                            onSave: () => widget.repository.toggleSave(job.id),
                                          );
                                        },
                                      )
                                    : SingleChildScrollView(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            for (int col = 0; col < crossAxisCount; col++) ...[
                                              if (col > 0) const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    for (int i = col; i < jobs.length; i += crossAxisCount)
                                                      JobRecipeCard(
                                                        job: jobs[i],
                                                        repository: widget.repository,
                                                        onLike: () => widget.repository.toggleLike(jobs[i].id),
                                                        onSave: () => widget.repository.toggleSave(jobs[i].id),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
      },
    );
  }
}
