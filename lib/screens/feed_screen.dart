import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../widgets/job_recipe_card.dart';
import 'booking_flow_screen.dart';
import 'public_studio_screen.dart';
import '../widgets/dilution_dialog.dart';

class FeedScreen extends StatefulWidget {
  final JobRepository repository;

  const FeedScreen({super.key, required this.repository});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  bool? _isFeaturedExpandedOverride;

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicStudioScreen(
          detailer: detailer,
          repository: widget.repository,
        ),
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'Ceramic Coating':
        return Icons.shield_rounded;
      case 'Paint Correction':
        return Icons.auto_fix_high_rounded;
      case 'Gloss & Decon Wash':
        return Icons.water_drop_rounded;
      case 'Interior Deep Clean':
        return Icons.airline_seat_recline_extra_rounded;
      case 'PPF & Clear Bra':
        return Icons.security_rounded;
      default:
        return Icons.tune_rounded;
    }
  }

  Widget _buildLocationDropdown(
    BuildContext context,
    List<String> activeCities,
    String selectedCity, {
    bool isEmbedded = false,
  }) {
    final isFiltered = selectedCity != 'All Locations';
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: AppTheme.primary.withAlpha(25),
        splashColor: AppTheme.primary.withAlpha(15),
      ),
      child: PopupMenuButton<String>(
        key: const Key('location_dropdown_btn'),
        tooltip: 'Filter by Location',
        offset: const Offset(0, 42),
        constraints: const BoxConstraints(minWidth: 185, maxWidth: 260),
        color: AppTheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isFiltered ? AppTheme.primary.withAlpha(140) : AppTheme.border,
            width: 1,
          ),
        ),
        initialValue: selectedCity,
        onSelected: (loc) => widget.repository.setLocationFilter(loc),
        itemBuilder: (context) => activeCities.map((loc) {
          final isSelected = selectedCity == loc;
          return PopupMenuItem<String>(
            value: loc,
            height: 40,
            child: Row(
              children: [
                Icon(
                  loc == 'All Locations'
                      ? Icons.travel_explore_rounded
                      : Icons.location_on_rounded,
                  size: 15,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_rounded, size: 16, color: AppTheme.primary),
              ],
            ),
          );
        }).toList(),
        child: isEmbedded
            ? Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: isFiltered
                    ? BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selectedCity == 'All Locations'
                          ? Icons.travel_explore_rounded
                          : Icons.location_on_rounded,
                      size: 15,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        selectedCity,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                          color: isFiltered ? AppTheme.primary : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ],
                ),
              )
            : Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isFiltered ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFiltered ? AppTheme.primary : AppTheme.border,
                    width: isFiltered ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedCity == 'All Locations'
                          ? Icons.travel_explore_rounded
                          : Icons.location_on_rounded,
                      size: 14,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        selectedCity,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                          color: isFiltered ? AppTheme.primary : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildServiceDropdown(
    BuildContext context,
    List<String> serviceTypes,
    String selectedService, {
    bool isEmbedded = false,
  }) {
    final isFiltered = selectedService != 'All Services';
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: AppTheme.primary.withAlpha(25),
        splashColor: AppTheme.primary.withAlpha(15),
      ),
      child: PopupMenuButton<String>(
        key: const Key('service_dropdown_btn'),
        tooltip: 'Filter by Service',
        offset: const Offset(0, 42),
        constraints: const BoxConstraints(minWidth: 185, maxWidth: 260),
        color: AppTheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isFiltered ? AppTheme.primary.withAlpha(140) : AppTheme.border,
            width: 1,
          ),
        ),
        initialValue: selectedService,
        onSelected: (service) => widget.repository.setServiceFilter(service),
        itemBuilder: (context) => serviceTypes.map((service) {
          final isSelected = selectedService == service;
          return PopupMenuItem<String>(
            value: service,
            height: 40,
            child: Row(
              children: [
                Icon(
                  _getServiceIcon(service),
                  size: 15,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_rounded, size: 16, color: AppTheme.primary),
              ],
            ),
          );
        }).toList(),
        child: isEmbedded
            ? Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: isFiltered
                    ? BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getServiceIcon(selectedService),
                      size: 15,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        selectedService,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                          color: isFiltered ? AppTheme.primary : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ],
                ),
              )
            : Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isFiltered ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFiltered ? AppTheme.primary : AppTheme.border,
                    width: isFiltered ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getServiceIcon(selectedService),
                      size: 14,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        selectedService,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
                          color: isFiltered ? AppTheme.primary : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: isFiltered ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeaturedDetailersSection(
    BuildContext context,
    List<UserProfile> detailers,
    String selectedCity,
    bool isFeaturedExpanded,
    bool isDesktop,
  ) {
    if (detailers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 14, 2, isDesktop ? 24 : 14, 4),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: InkWell(
                key: const Key('toggle_featured_detailers_btn'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isFeaturedExpandedOverride = !isFeaturedExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, size: 13, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          selectedCity == 'All Locations'
                              ? 'Featured Detailers & Studios'
                              : 'Verified Studios in $selectedCity',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${detailers.length} Studios',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isFeaturedExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isFeaturedExpanded) ...[
          SizedBox(
            height: 124,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 14, vertical: 2),
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
          const SizedBox(height: 4),
        ],
      ],
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
            final isFeaturedExpanded = _isFeaturedExpandedOverride ?? isDesktop;

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
                          icon: const Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 20),
                          tooltip: 'Chemical Dilution Calculator',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const DilutionDialog(),
                            );
                          },
                        ),
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
                        // Desktop: Single Unified Turo-style Search & Filter Pill (Unlayered)
                        // Mobile: Clean Side-by-Side Location & Service Dropdown Bar
                        if (isDesktop) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: (selectedCity != 'All Locations' ||
                                              widget.repository.selectedServiceType != 'All Services' ||
                                              _searchCtrl.text.isNotEmpty)
                                          ? AppTheme.primary.withAlpha(120)
                                          : AppTheme.border,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(30),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Search Input Section
                                      Expanded(
                                        flex: 5,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 14),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  controller: _searchCtrl,
                                                  decoration: const InputDecoration(
                                                    hintText: 'Search transformations, studios, cities...',
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                  onChanged: (v) => widget.repository.setSearchQuery(v),
                                                ),
                                              ),
                                              if (_searchCtrl.text.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

                                      // Vertical Divider
                                      Container(
                                        height: 24,
                                        width: 1,
                                        color: AppTheme.border.withAlpha(120),
                                      ),

                                      // Location Dropdown (Embedded)
                                      Flexible(
                                        flex: 3,
                                        child: _buildLocationDropdown(
                                          context,
                                          activeCities,
                                          selectedCity,
                                          isEmbedded: true,
                                        ),
                                      ),

                                      // Vertical Divider
                                      Container(
                                        height: 24,
                                        width: 1,
                                        color: AppTheme.border.withAlpha(120),
                                      ),

                                      // Service Dropdown (Embedded)
                                      Flexible(
                                        flex: 3,
                                        child: _buildServiceDropdown(
                                          context,
                                          AppConstants.serviceTypes,
                                          widget.repository.selectedServiceType,
                                          isEmbedded: true,
                                        ),
                                      ),

                                      // Quick Reset Button
                                      if (selectedCity != 'All Locations' ||
                                          widget.repository.selectedServiceType != 'All Services' ||
                                          _searchCtrl.text.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8, left: 4),
                                          child: Tooltip(
                                            message: 'Reset Filters',
                                            child: InkWell(
                                              key: const Key('reset_filters_btn'),
                                              onTap: () {
                                                _searchCtrl.clear();
                                                widget.repository.clearFilters();
                                                setState(() {});
                                              },
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                height: 32,
                                                width: 32,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.surfaceLight,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppTheme.primary.withAlpha(80)),
                                                ),
                                                child: const Icon(
                                                  Icons.filter_alt_off_rounded,
                                                  size: 15,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else
                                        const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Mobile: Clean Side-by-Side Location & Service Dropdown Filter Bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 680),
                                child: Row(
                                  children: [
                                    // All Locations Dropdown
                                    Expanded(
                                      child: _buildLocationDropdown(
                                        context,
                                        activeCities,
                                        selectedCity,
                                        isEmbedded: false,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // All Services Dropdown
                                    Expanded(
                                      child: _buildServiceDropdown(
                                        context,
                                        AppConstants.serviceTypes,
                                        widget.repository.selectedServiceType,
                                        isEmbedded: false,
                                      ),
                                    ),
                                    // Quick Reset button if filters active
                                    if (selectedCity != 'All Locations' ||
                                        widget.repository.selectedServiceType != 'All Services') ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        key: const Key('reset_filters_btn'),
                                        onTap: () {
                                          widget.repository.setLocationFilter('All Locations');
                                          widget.repository.setServiceFilter('All Services');
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 38,
                                          width: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surface,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: const Icon(
                                            Icons.filter_alt_off_rounded,
                                            size: 16,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        // 2. Feed Content (Featured Detailers scrolls naturally with feed so it doesn't block screen on mobile!)
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

                                      if (!isDesktop) {
                                        final hasDetailers = detailers.isNotEmpty;
                                        final totalItems = (hasDetailers ? 1 : 0) + (jobs.isEmpty ? 1 : jobs.length);

                                        return ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          itemCount: totalItems,
                                          itemBuilder: (context, idx) {
                                            if (hasDetailers && idx == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: _buildFeaturedDetailersSection(
                                                  context,
                                                  detailers,
                                                  selectedCity,
                                                  isFeaturedExpanded,
                                                  isDesktop,
                                                ),
                                              );
                                            }

                                            final jobIdx = hasDetailers ? idx - 1 : idx;
                                            if (jobs.isEmpty) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 24),
                                                child: Center(
                                                  child: Text(
                                                    'No transformation posts found for this filter.',
                                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                                  ),
                                                ),
                                              );
                                            }

                                            final job = jobs[jobIdx];
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
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (detailers.isNotEmpty) ...[
                                              _buildFeaturedDetailersSection(
                                                context,
                                                detailers,
                                                selectedCity,
                                                isFeaturedExpanded,
                                                isDesktop,
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                            if (jobs.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 48),
                                                child: Center(
                                                  child: Text(
                                                    'No transformation posts found for this filter.',
                                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                                                  ),
                                                ),
                                              )
                                            else
                                              Row(
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
