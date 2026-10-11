import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../models/inventory_item.dart';
import '../services/job_repository.dart';
import '../widgets/job_recipe_card.dart';
import '../widgets/dilution_dialog.dart';
import '../widgets/inventory_item_editor_dialog.dart';
import 'service_package_editor_dialog.dart';
import 'add_team_member_dialog.dart';
import 'create_job_screen.dart';
import 'edit_profile_dialog.dart';
import 'public_studio_screen.dart';
import 'calendar_preferences_dialog.dart';
import '../models/calendar_availability_block.dart';

enum StudioHubSection {
  calendar('Calendar', 'CALENDAR', 'Bookings & host schedule', Icons.calendar_month_rounded),
  portfolio('Portfolio', 'PORTFOLIO', 'Showcase builds & media', Icons.photo_library_rounded),
  services('Services', 'SERVICES', 'Packages & pricing menus', Icons.design_services_rounded),
  inventory('Inventory', 'INVENTORY', 'Hardware, chemicals, recipe', Icons.inventory_2_rounded),
  teams('My Teams', 'MY TEAMS', 'Staff roles & technicians', Icons.groups_rounded),
  savedRecipes('Saved Recipes', 'SAVED RECIPES', 'Technical playbook', Icons.bookmark_rounded);

  final String title;
  final String tag;
  final String subtitle;
  final IconData icon;
  const StudioHubSection(this.title, this.tag, this.subtitle, this.icon);
}

class DetailerWorkbenchView extends StatefulWidget {
  final JobRepository repository;
  final DateTime? initialCalendarDate;

  const DetailerWorkbenchView({
    super.key,
    required this.repository,
    this.initialCalendarDate,
  });

  @override
  State<DetailerWorkbenchView> createState() => _DetailerWorkbenchViewState();
}

class _DetailerWorkbenchViewState extends State<DetailerWorkbenchView> {
  StudioHubSection _selectedHub = StudioHubSection.portfolio;
  String _inventoryCategoryFilter = 'HARDWARE'; // HARDWARE, CHEMICALS, RECIPE

  // Selected item IDs or indices
  String? _selectedInventoryId;
  String? _selectedTeamMemberId;
  String? _selectedServicePackageId;
  String? _selectedPortfolioJobId;
  String? _selectedSavedJobId;
  String? _returnToServicePackageId;
  String? _returnToServicePackageTitle;

  // Calendar state
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _calendarDisplayMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Responsive state
  bool _isFocusMode = false;
  int _mobileStep = 0; // 0 = Hub (Pane 1), 1 = List (Pane 2), 2 = Inspector (Pane 3)

  @override
  void initState() {
    super.initState();
    if (widget.initialCalendarDate != null) {
      _selectedCalendarDate = widget.initialCalendarDate!;
      _calendarDisplayMonth = DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, 1);
    }
    widget.repository.addListener(_onRepoChanged);
    _ensureSelection();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {
        _ensureSelection();
      });
    }
  }

  void _ensureSelection() {
    final user = widget.repository.currentUser;
    final myJobs = widget.repository.getJobsByDetailer(user.id);
    final savedJobs = widget.repository.savedJobs;
    final inventory = widget.repository.inventoryItems;

    if (_selectedPortfolioJobId == null || !myJobs.any((j) => j.id == _selectedPortfolioJobId)) {
      _selectedPortfolioJobId = myJobs.isNotEmpty ? myJobs.first.id : null;
    }
    if (_selectedSavedJobId == null || !savedJobs.any((j) => j.id == _selectedSavedJobId)) {
      _selectedSavedJobId = savedJobs.isNotEmpty ? savedJobs.first.id : null;
    }
    if (_selectedServicePackageId == null || !user.servicePackages.any((p) => p.id == _selectedServicePackageId)) {
      _selectedServicePackageId = user.servicePackages.isNotEmpty ? user.servicePackages.first.id : null;
    }

    List<InventoryItem> filteredInventory = inventory;
    if (_inventoryCategoryFilter == 'HARDWARE') {
      filteredInventory = inventory.where((i) => i.category == InventoryCategory.hardware).toList();
    } else if (_inventoryCategoryFilter == 'CHEMICALS') {
      filteredInventory = inventory.where((i) => i.category == InventoryCategory.chemicals).toList();
    } else if (_inventoryCategoryFilter == 'RECIPE') {
      filteredInventory = inventory.where((i) => i.category == InventoryCategory.recipe).toList();
    }
    if (_selectedInventoryId == null || !filteredInventory.any((i) => i.id == _selectedInventoryId)) {
      _selectedInventoryId = filteredInventory.isNotEmpty
          ? filteredInventory.first.id
          : (inventory.isNotEmpty ? inventory.first.id : null);
    }

    if (_selectedTeamMemberId != 'founder' && !user.teamMembers.any((m) => m.id == _selectedTeamMemberId)) {
      _selectedTeamMemberId = 'founder';
    }
  }

  void _selectHub(StudioHubSection section, {bool isMobile = false}) {
    setState(() {
      _selectedHub = section;
      if (section != StudioHubSection.inventory) {
        _returnToServicePackageId = null;
        _returnToServicePackageTitle = null;
      }
      _ensureSelection();
      if (isMobile) {
        _mobileStep = 1;
      }
    });
  }

  bool _hasActiveItemToInspect() {
    final user = widget.repository.currentUser;
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        return true;
      case StudioHubSection.inventory:
        return widget.repository.inventoryItems.isNotEmpty;
      case StudioHubSection.teams:
        return true;
      case StudioHubSection.portfolio:
        return widget.repository.getJobsByDetailer(user.id).isNotEmpty;
      case StudioHubSection.services:
        return user.servicePackages.isNotEmpty;
      case StudioHubSection.savedRecipes:
        return widget.repository.savedJobs.isNotEmpty;
    }
  }

  // --- ACTIONS ---

  void _openAdd({bool isMobile = false}) {
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        CalendarPreferencesDialog.show(context, repository: widget.repository);
        break;
      case StudioHubSection.inventory:
        InventoryCategory cat = InventoryCategory.hardware;
        if (_inventoryCategoryFilter == 'CHEMICALS') cat = InventoryCategory.chemicals;
        if (_inventoryCategoryFilter == 'RECIPE') cat = InventoryCategory.recipe;
        final hardwareOptions = widget.repository.inventoryItems
            .where((i) => i.category == InventoryCategory.hardware)
            .map((i) => i.name)
            .toList();
        final chemicalOptions = widget.repository.inventoryItems
            .where((i) => i.category == InventoryCategory.chemicals)
            .map((i) => i.name)
            .toList();
        InventoryItemEditorDialog.show(
          context,
          initialCategory: cat,
          hardwareOptions: hardwareOptions,
          chemicalOptions: chemicalOptions,
          onSave: (newItem) {
            widget.repository.addInventoryItem(newItem);
            setState(() {
              _selectedInventoryId = newItem.id;
              if (isMobile) _mobileStep = 2;
            });
          },
        );
        break;
      case StudioHubSection.teams:
        AddTeamMemberDialog.show(context, repository: widget.repository);
        break;
      case StudioHubSection.portfolio:
        CreateJobScreen.show(
          context,
          repository: widget.repository,
          onJobCreated: () {
            setState(() {
              final myJobs = widget.repository.getJobsByDetailer(widget.repository.currentUser.id);
              if (myJobs.isNotEmpty) {
                _selectedPortfolioJobId = myJobs.first.id;
                if (isMobile) _mobileStep = 2;
              }
            });
          },
        );
        break;
      case StudioHubSection.services:
        ServicePackageEditorDialog.show(
          context,
          availableRecipes: widget.repository.recipeItems,
          onSave: (pkg) {
            widget.repository.addServicePackage(pkg);
            setState(() {
              _selectedServicePackageId = pkg.id;
              if (isMobile) _mobileStep = 2;
            });
          },
        );
        break;
      case StudioHubSection.savedRecipes:
        widget.repository.setActiveTab(0);
        break;
    }
  }

  void _editActiveItem() {
    final user = widget.repository.currentUser;
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        CalendarPreferencesDialog.show(context, repository: widget.repository);
        break;
      case StudioHubSection.inventory:
        final inventory = widget.repository.inventoryItems;
        if (inventory.isEmpty) return;
        final item = inventory.firstWhere(
          (i) => i.id == _selectedInventoryId,
          orElse: () => inventory.first,
        );
        final hardwareOptions = widget.repository.inventoryItems
            .where((i) => i.category == InventoryCategory.hardware)
            .map((i) => i.name)
            .toList();
        final chemicalOptions = widget.repository.inventoryItems
            .where((i) => i.category == InventoryCategory.chemicals)
            .map((i) => i.name)
            .toList();
        InventoryItemEditorDialog.show(
          context,
          itemToEdit: item,
          hardwareOptions: hardwareOptions,
          chemicalOptions: chemicalOptions,
          onSave: (updated) => widget.repository.updateInventoryItem(updated),
          onDelete: () {
            widget.repository.removeInventoryItem(item.id);
            if (_mobileStep == 2) setState(() => _mobileStep = 1);
          },
        );
        break;
      case StudioHubSection.services:
        final pkgs = user.servicePackages;
        if (pkgs.isEmpty) return;
        final pkg = pkgs.firstWhere(
          (p) => p.id == _selectedServicePackageId,
          orElse: () => pkgs.first,
        );
        ServicePackageEditorDialog.show(
          context,
          package: pkg,
          availableRecipes: widget.repository.recipeItems,
          onSave: (up) => widget.repository.updateServicePackage(up),
          onDelete: () {
            widget.repository.removeServicePackage(pkg.id);
            if (_mobileStep == 2) setState(() => _mobileStep = 1);
          },
        );
        break;
      case StudioHubSection.teams:
        if (_selectedTeamMemberId == 'founder' || _selectedTeamMemberId == null) {
          EditProfileDialog.show(context, repository: widget.repository);
          return;
        }
        final staff = user.teamMembers;
        if (staff.isEmpty) return;
        final member = staff.firstWhere(
          (m) => m.id == _selectedTeamMemberId,
          orElse: () => staff.first,
        );
        _showEditTeamMemberDialog(member);
        break;
      case StudioHubSection.portfolio:
        final myJobs = widget.repository.getJobsByDetailer(user.id);
        if (myJobs.isEmpty) return;
        final job = myJobs.firstWhere(
          (j) => j.id == _selectedPortfolioJobId,
          orElse: () => myJobs.first,
        );
        CreateJobScreen.show(
          context,
          repository: widget.repository,
          jobToEdit: job,
          onJobCreated: () => setState(() {}),
        );
        break;
      case StudioHubSection.savedRecipes:
        break;
    }
  }

  void _confirmDeleteActiveItem() {
    final user = widget.repository.currentUser;
    String itemTitle = '';
    VoidCallback? deleteAction;

    switch (_selectedHub) {
      case StudioHubSection.calendar:
        return;
      case StudioHubSection.inventory:
        final inventory = widget.repository.inventoryItems;
        if (inventory.isEmpty) return;
        final item = inventory.firstWhere(
          (i) => i.id == _selectedInventoryId,
          orElse: () => inventory.first,
        );
        itemTitle = item.name;
        deleteAction = () => widget.repository.removeInventoryItem(item.id);
        break;
      case StudioHubSection.services:
        final pkgs = user.servicePackages;
        if (pkgs.isEmpty) return;
        final pkg = pkgs.firstWhere(
          (p) => p.id == _selectedServicePackageId,
          orElse: () => pkgs.first,
        );
        itemTitle = pkg.title;
        deleteAction = () => widget.repository.removeServicePackage(pkg.id);
        break;
      case StudioHubSection.teams:
        if (_selectedTeamMemberId == 'founder' || _selectedTeamMemberId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove shop founder.')),
          );
          return;
        }
        final staff = user.teamMembers;
        if (staff.isEmpty) return;
        final member = staff.firstWhere(
          (m) => m.id == _selectedTeamMemberId,
          orElse: () => staff.first,
        );
        itemTitle = member.name;
        deleteAction = () => widget.repository.removeTeamMember(member.id);
        break;
      case StudioHubSection.portfolio:
        final myJobs = widget.repository.getJobsByDetailer(user.id);
        if (myJobs.isEmpty) return;
        final job = myJobs.firstWhere(
          (j) => j.id == _selectedPortfolioJobId,
          orElse: () => myJobs.first,
        );
        itemTitle = job.vehicleFullName;
        deleteAction = () => widget.repository.deleteJob(job.id);
        break;
      case StudioHubSection.savedRecipes:
        return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirm Deletion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$itemTitle"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              deleteAction?.call();
              if (_mobileStep == 2) {
                setState(() => _mobileStep = 1);
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTeamMemberDialog(TeamMember member) {
    final nameCtrl = TextEditingController(text: member.name);
    final roleCtrl = TextEditingController(text: member.roleTitle);
    bool available = member.isAvailable;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Team Specialist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Specialist Role / Title'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Available for Bookings', style: TextStyle(fontSize: 13)),
                value: available,
                onChanged: (val) => setDlgState(() => available = val),
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.repository.removeTeamMember(member.id);
              },
              child: const Text('Remove'),
            ),
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
                final updated = member.copyWith(
                  name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : member.name,
                  roleTitle: roleCtrl.text.trim().isNotEmpty ? roleCtrl.text.trim() : member.roleTitle,
                  isAvailable: available,
                );
                widget.repository.updateTeamMember(updated);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PANE 1: STUDIO HUB
  // ==========================================
  Widget _buildPane1(BuildContext context, {bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final myJobs = widget.repository.getJobsByDetailer(user.id);
    final savedJobs = widget.repository.savedJobs;
    final inventory = widget.repository.inventoryItems;

    return Material(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Studio Profile Header Card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withAlpha(120),
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: user.localAvatarBytes != null
                          ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                          : NetworkImage(user.avatarUrl),
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
                                  user.businessName.isNotEmpty ? user.businessName : user.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isVerifiedHost) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 14, color: AppTheme.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.location.isNotEmpty ? user.location : 'Studio OS',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Mode Switch & Storefront Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.directions_car_rounded, size: 14),
                        label: const Text('Switch to Client Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => widget.repository.toggleHostMode(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary),
                      tooltip: 'View Public Storefront',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicStudioScreen(
                              detailer: user,
                              repository: widget.repository,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                      tooltip: 'Edit Profile & Settings',
                      onPressed: () => EditProfileDialog.show(context, repository: widget.repository),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Studio Hub Section Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Text(
                    'STUDIO WORKBENCH HUB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final section in StudioHubSection.values) ...[
                  _buildHubTile(
                    section: section,
                    isSelected: _selectedHub == section,
                    count: _getCountForHub(section, myJobs.length, savedJobs.length, user, inventory.length),
                    isMobile: isMobile,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 10),

                // Quick Utilities in Hub
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.calculate_outlined, size: 18, color: AppTheme.primary),
                          title: const Text('Dilution Calculator', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textMuted),
                          onTap: () => showDialog(context: context, builder: (_) => const DilutionDialog()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCountForHub(StudioHubSection section, int myJobs, int saved, UserProfile user, int invCount) {
    switch (section) {
      case StudioHubSection.calendar:
        return widget.repository.bookings.where((b) {
          return b.detailerId == user.id &&
                 b.scheduledDate.year == _calendarDisplayMonth.year &&
                 b.scheduledDate.month == _calendarDisplayMonth.month &&
                 b.status != BookingStatus.cancelled;
        }).length;
      case StudioHubSection.portfolio:
        return myJobs;
      case StudioHubSection.savedRecipes:
        return saved;
      case StudioHubSection.services:
        return user.servicePackages.length;
      case StudioHubSection.teams:
        return user.teamMembers.length + 1; // Founder + staff
      case StudioHubSection.inventory:
        return invCount;
    }
  }

  Widget _buildHubTile({
    required StudioHubSection section,
    required bool isSelected,
    required int count,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppTheme.primary.withAlpha(120) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              section.icon,
              color: isSelected ? Colors.black : AppTheme.textSecondary,
              size: 16,
            ),
          ),
          title: Text(
            section.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            section.subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : AppTheme.textMuted,
              ),
            ),
          ),
          onTap: () => _selectHub(section, isMobile: isMobile),
        ),
      ),
    );
  }

  // ==========================================
  // PANE 2: SUBCATEGORY / ITEM LIST
  // ==========================================
  Widget _buildPane2(BuildContext context, {bool isMobile = false}) {
    return Material(
      color: AppTheme.background,
      child: Column(
        children: [
          // Pane 2 Header with [ + ADD ] button
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _mobileStep = 0),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedHub.title.toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      Text(
                        _getPane2Subtitle(),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Selector (When INVENTORY selected: HARDWARE, CHEMICALS, RECIPE)
          if (_selectedHub == StudioHubSection.inventory) ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildInventoryCategoryRow(
                    category: 'HARDWARE',
                    label: 'HARDWARE',
                    subtitle: 'General equipment, mitts, buckets, polishers',
                    icon: Icons.handyman_rounded,
                    count: widget.repository.hardwareItems.length,
                    isSelected: _inventoryCategoryFilter == 'HARDWARE',
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 10),
                  _buildInventoryCategoryRow(
                    category: 'CHEMICALS',
                    label: 'CHEMICALS',
                    subtitle: 'Compounds, coatings, prep sprays, APC',
                    icon: Icons.science_rounded,
                    count: widget.repository.chemicalItems.length,
                    isSelected: _inventoryCategoryFilter == 'CHEMICALS',
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 10),
                  _buildInventoryCategoryRow(
                    category: 'RECIPE',
                    label: 'RECIPE',
                    subtitle: 'Correction formulas & build steps',
                    icon: Icons.auto_stories_rounded,
                    count: widget.repository.recipeItems.length,
                    isSelected: _inventoryCategoryFilter == 'RECIPE',
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Item List Body for other hub sections
            Expanded(
              child: _buildPane2Content(context, isMobile: isMobile),
            ),
          ],

          // Bottom: [ + ADD ] button to add new team, portfolio, or service (Inventory add button transferred to Pane 3, Calendar has settings)
          if (_selectedHub != StudioHubSection.savedRecipes && _selectedHub != StudioHubSection.inventory && _selectedHub != StudioHubSection.calendar) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('[ + ADD ]', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  onPressed: () => _openAdd(isMobile: isMobile),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPane2Subtitle() {
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        return 'Monthly availability & bookings';
      case StudioHubSection.inventory:
        return 'Polishers, chemicals, formulas';
      case StudioHubSection.teams:
        return 'Technicians & specialists';
      case StudioHubSection.portfolio:
        return 'Published build transformations';
      case StudioHubSection.services:
        return 'Active studio service menus';
      case StudioHubSection.savedRecipes:
        return 'Bookmarked community builds';
    }
  }

  Widget _buildInventoryCategoryRow({
    required String category,
    required String label,
    required String subtitle,
    required IconData icon,
    required int count,
    required bool isSelected,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _inventoryCategoryFilter = category;
              if (isMobile) {
                _mobileStep = 2;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : AppTheme.textMuted,
                    ),
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPane2Content(BuildContext context, {bool isMobile = false}) {
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        return _buildCalendarMonthPane2(context, isMobile: isMobile);
      case StudioHubSection.inventory:
        return const SizedBox.shrink();
      case StudioHubSection.teams:
        return _buildTeamsList(isMobile: isMobile);
      case StudioHubSection.portfolio:
        return _buildPortfolioList(isMobile: isMobile);
      case StudioHubSection.services:
        return _buildServicesList(isMobile: isMobile);
      case StudioHubSection.savedRecipes:
        return _buildSavedRecipesList(isMobile: isMobile);
    }
  }

  // --- TEAMS LIST ---
  Widget _buildTeamsList({bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final staff = user.teamMembers;

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        // Founder / Shop Owner Card
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _selectedTeamMemberId == 'founder' || _selectedTeamMemberId == null
                ? AppTheme.primary.withAlpha(20)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selectedTeamMemberId == 'founder' || _selectedTeamMemberId == null
                  ? AppTheme.primary
                  : AppTheme.primary.withAlpha(120),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundImage: user.localAvatarBytes != null
                    ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                    : NetworkImage(user.avatarUrl),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('FOUNDER', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(user.businessName, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('${user.averageRating} (${user.reviewCount} reviews)', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedTeamMemberId = 'founder';
                  if (isMobile) _mobileStep = 2;
                });
              },
            ),
          ),
        ),

        for (final member in staff) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: member.id == _selectedTeamMemberId ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: member.id == _selectedTeamMemberId ? AppTheme.primary : AppTheme.border,
                width: member.id == _selectedTeamMemberId ? 1.5 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundImage: member.localAvatarBytes != null
                      ? MemoryImage(member.localAvatarBytes!) as ImageProvider
                      : NetworkImage(member.avatarUrl),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: member.isAvailable ? Colors.greenAccent.withAlpha(25) : Colors.orangeAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        member.statusLabel,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: member.isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(member.roleTitle, style: const TextStyle(fontSize: 10.5, color: AppTheme.primary)),
                    const SizedBox(height: 2),
                    Text('• ${member.completedJobsCount} jobs completed', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedTeamMemberId = member.id;
                    if (isMobile) _mobileStep = 2;
                  });
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- PORTFOLIO LIST ---
  Widget _buildPortfolioList({bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final myJobs = widget.repository.getJobsByDetailer(user.id);

    if (myJobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare_arrows_rounded, size: 36, color: AppTheme.textMuted),
              SizedBox(height: 10),
              Text('No Published Builds Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 6),
              Text('Document and upload your before & after paint correction transformations using "[ + ADD ]" below.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: myJobs.length,
      itemBuilder: (context, index) {
        final job = myJobs[index];
        final isSelected = job.id == _selectedPortfolioJobId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.network(
                    job.afterImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surfaceLight),
                  ),
                ),
              ),
              title: Text(
                job.vehicleFullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${job.paintColorName} • ${job.serviceType}',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.orangeAccent.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text(job.defectStage.shortLabel, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.greenAccent.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text('${job.correctionPercentage}% Cut', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedPortfolioJobId = job.id;
                  if (isMobile) _mobileStep = 2;
                });
              },
            ),
          ),
        );
      },
    );
  }

  // --- SERVICES LIST ---
  Widget _buildServicesList({bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final pkgs = user.servicePackages;

    if (pkgs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.miscellaneous_services_outlined, size: 36, color: AppTheme.textMuted),
              SizedBox(height: 10),
              Text('No Service Packages Configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 6),
              Text('Create service menus with starting prices and treatment checklists using "[ + ADD ]" below.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: pkgs.length,
      itemBuilder: (context, index) {
        final pkg = pkgs[index];
        final isSelected = pkg.id == _selectedServicePackageId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sell_outlined, size: 16, color: AppTheme.primary),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      pkg.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${pkg.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${pkg.estimatedDuration} • ${pkg.includes.length} treatments included',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                  if (pkg.isPopular) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.amber.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                      child: const Text('POPULAR CHOICE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ),
                  ],
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedServicePackageId = pkg.id;
                  if (isMobile) _mobileStep = 2;
                });
              },
            ),
          ),
        );
      },
    );
  }

  // --- SAVED RECIPES LIST ---
  Widget _buildSavedRecipesList({bool isMobile = false}) {
    final savedJobs = widget.repository.savedJobs;

    if (savedJobs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withAlpha(60)),
                ),
                child: const Icon(Icons.bookmark_border_rounded, size: 36, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Saved Recipes Yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bookmark recipes from the community feed to build your technical paint correction playbook.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: savedJobs.length,
      itemBuilder: (context, index) {
        final job = savedJobs[index];
        final isSelected = job.id == _selectedSavedJobId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.network(
                    job.afterImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surfaceLight),
                  ),
                ),
              ),
              title: Text(
                job.vehicleFullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'by ${job.author.displayName} • ${job.paintColorName}',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text('${job.recipeStages.length} Stages', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.greenAccent.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                        child: Text('${job.correctionPercentage}% Cut', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedSavedJobId = job.id;
                  if (isMobile) _mobileStep = 2;
                });
              },
            ),
          ),
        );
      },
    );
  }

  // --- CALENDAR MONTH VIEW (PANE 2) ---
  Widget _buildCalendarMonthPane2(BuildContext context, {bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final year = _calendarDisplayMonth.year;
    final month = _calendarDisplayMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOfMonth = DateTime(year, month, 1);
    final leadingBlanks = (firstDayOfMonth.weekday - 1);

    final monthName = DateFormat('MMMM yyyy').format(_calendarDisplayMonth);
    final today = DateUtils.dateOnly(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Month Selector Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous Month',
                onPressed: () {
                  setState(() {
                    _calendarDisplayMonth = DateTime(year, month - 1, 1);
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Center(
                  child: Text(
                    monthName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Next Month',
                onPressed: () {
                  setState(() {
                    _calendarDisplayMonth = DateTime(year, month + 1, 1);
                  });
                },
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() {
                    final now = DateTime.now();
                    _calendarDisplayMonth = DateTime(now.year, now.month, 1);
                    _selectedCalendarDate = now;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Day of Week Header
        Row(
          children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Monthly Grid (7 columns)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 0.8,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) {
              return const SizedBox.shrink();
            }
            final day = index - leadingBlanks + 1;
            final cellDate = DateTime(year, month, day);
            final isSelected = DateUtils.isSameDay(cellDate, _selectedCalendarDate);
            final isToday = DateUtils.isSameDay(cellDate, today);
            final isRecurringOff = widget.repository.isDateRecurringDayOff(cellDate, detailerId: user.id);
            final isExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(user.id, cellDate);
            final isFullyBlocked = widget.repository.isDateFullyBlocked(user.id, cellDate);
            final dayBlocks = widget.repository.getBlocksForDate(cellDate, detailerId: user.id);
            final isPartiallyBlocked = !isExplicitlyBlocked && dayBlocks.any((b) => b.blockedSlots.isNotEmpty);
            final dayBookings = widget.repository.getBookingsForDate(cellDate, detailerId: user.id);
            final isFullyBooked = !isFullyBlocked && !isRecurringOff && widget.repository.isDateFullyBooked(cellDate, detailerId: user.id);

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _selectedCalendarDate = cellDate;
                  if (isMobile) _mobileStep = 2;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withAlpha(35)
                      : (isExplicitlyBlocked
                          ? Colors.redAccent.withAlpha(20)
                          : (isRecurringOff
                              ? AppTheme.surfaceLight.withAlpha(50)
                              : AppTheme.surface)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : (isExplicitlyBlocked
                            ? Colors.redAccent.withAlpha(100)
                            : (isToday ? AppTheme.primary.withAlpha(80) : AppTheme.border)),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Day number + today dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isRecurringOff ? AppTheme.textMuted : Colors.white),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 2),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Status Indicator Badges / Dots
                      if (dayBookings.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: isFullyBooked ? Colors.amber.withAlpha(40) : Colors.greenAccent.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isFullyBooked ? 'FULL' : '${dayBookings.length}bk',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isFullyBooked ? Colors.amber : Colors.greenAccent,
                            ),
                          ),
                        ),
                      ] else if (isExplicitlyBlocked) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BLK',
                            style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ),
                      ] else if (isPartiallyBlocked) ...[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else if (isRecurringOff) ...[
                        const Text(
                          'OFF',
                          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 12),

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildLegendItem(Colors.greenAccent, 'Booked Job'),
            _buildLegendItem(Colors.redAccent, 'Full Day Blocked'),
            _buildLegendItem(Colors.amber, 'Hourly Slots Blocked'),
            _buildLegendItem(AppTheme.textMuted, 'Recurring Day Off'),
          ],
        ),

        const SizedBox(height: 16),

        // Schedule & Preferences Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Operating Hours & Preferences', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            onPressed: () => CalendarPreferencesDialog.show(context, repository: widget.repository),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  // ==========================================
  // PANE 3: WORKSPACE CANVAS / INSPECTOR
  // ==========================================
  Widget _buildPane3(BuildContext context, {bool isMobile = false}) {
    return Material(
      color: AppTheme.surfaceLight,
      child: Column(
        children: [
          // Inspector Top Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _mobileStep = 1),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _selectedHub == StudioHubSection.inventory
                        ? '$_inventoryCategoryFilter INVENTORY'
                        : '${_selectedHub.tag} INSPECTOR',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Top Right: Focus Mode Toggle Button (Large screen)
                if (!isMobile) ...[
                  Tooltip(
                    message: _isFocusMode ? 'Exit Full Screen Focus Mode' : 'Toggle 100% Full Screen Focus Mode',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isFocusMode ? Colors.black : AppTheme.primary,
                        backgroundColor: _isFocusMode ? AppTheme.primary : Colors.transparent,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(_isFocusMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 16),
                      label: Text(
                        _isFocusMode ? 'Exit Focus' : 'Focus Mode',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => setState(() => _isFocusMode = !_isFocusMode),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Action controls for Inventory vs Calendar vs other hubs
                if (_selectedHub == StudioHubSection.inventory) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('[ + ADD ]', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    onPressed: () => _openAdd(isMobile: isMobile),
                  ),
                ] else if (_selectedHub == StudioHubSection.calendar) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Operating Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: () => CalendarPreferencesDialog.show(context, repository: widget.repository),
                  ),
                ] else if (_hasActiveItemToInspect() && _selectedHub != StudioHubSection.savedRecipes) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
                    label: const Text('[EDIT]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onPressed: _editActiveItem,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Delete Item',
                    onPressed: _confirmDeleteActiveItem,
                  ),
                ],
              ],
            ),
          ),

          // Inspector Canvas Body
          Expanded(
            child: _selectedHub == StudioHubSection.inventory
                ? _buildInventoryItemsPane3(isMobile: isMobile)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildInspectorBody(context, isMobile: isMobile),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorBody(BuildContext context, {bool isMobile = false}) {
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        return _buildCalendarDayInspector(context, isMobile: isMobile);
      case StudioHubSection.inventory:
        return const SizedBox.shrink();
      case StudioHubSection.teams:
        return _buildTeamInspector(context);
      case StudioHubSection.portfolio:
        return _buildPortfolioInspector(context);
      case StudioHubSection.services:
        return _buildServiceInspector(context, isMobile: isMobile);
      case StudioHubSection.savedRecipes:
        return _buildSavedRecipesInspector(context);
    }
  }

  // --- INVENTORY ITEMS (PANE 3) ---
  Widget _buildInventoryItemsPane3({bool isMobile = false}) {
    List<InventoryItem> items = widget.repository.inventoryItems;
    if (_inventoryCategoryFilter == 'HARDWARE') {
      items = items.where((i) => i.category == InventoryCategory.hardware).toList();
    } else if (_inventoryCategoryFilter == 'CHEMICALS') {
      items = items.where((i) => i.category == InventoryCategory.chemicals).toList();
    } else if (_inventoryCategoryFilter == 'RECIPE') {
      items = items.where((i) => i.category == InventoryCategory.recipe).toList();
    }

    Widget contentWidget;
    if (items.isEmpty) {
      contentWidget = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _inventoryCategoryFilter == 'HARDWARE'
                    ? Icons.handyman_outlined
                    : _inventoryCategoryFilter == 'CHEMICALS'
                        ? Icons.science_outlined
                        : Icons.auto_stories_outlined,
                size: 40,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No $_inventoryCategoryFilter Items Recorded',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Use "[ + ADD ]" to record new $_inventoryCategoryFilter for your studio.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('[ + ADD ]', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openAdd(isMobile: isMobile),
              ),
            ],
          ),
        ),
      );
    } else {
      contentWidget = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildInventoryItemRow(item, isMobile: isMobile);
        },
      );
    }

    if (_returnToServicePackageId != null) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Viewing recipe linked to ',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      children: [
                        TextSpan(
                          text: _returnToServicePackageTitle ?? 'Service Package',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedHub = StudioHubSection.services;
                      _selectedServicePackageId = _returnToServicePackageId;
                      _returnToServicePackageId = null;
                      _returnToServicePackageTitle = null;
                      if (isMobile) _mobileStep = 2;
                    });
                  },
                  child: const Text('Back to Package', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                  tooltip: 'Dismiss',
                  onPressed: () {
                    setState(() {
                      _returnToServicePackageId = null;
                      _returnToServicePackageTitle = null;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(child: contentWidget),
        ],
      );
    }

    return contentWidget;
  }

  Widget _buildInventoryItemRow(InventoryItem item, {bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          final contentWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.category == InventoryCategory.hardware
                      ? Colors.blueAccent.withAlpha(30)
                      : item.category == InventoryCategory.chemicals
                          ? Colors.tealAccent.withAlpha(30)
                          : Colors.purpleAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.category == InventoryCategory.hardware
                      ? Icons.handyman_rounded
                      : item.category == InventoryCategory.chemicals
                          ? Icons.science_rounded
                          : Icons.auto_stories_rounded,
                  size: 18,
                  color: item.category == InventoryCategory.hardware
                      ? Colors.blueAccent
                      : item.category == InventoryCategory.chemicals
                          ? Colors.tealAccent
                          : Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                        ),
                        if (item.location.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blueAccent.withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 10, color: Colors.blueAccent),
                                const SizedBox(width: 3),
                                Text(
                                  item.location,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (item.category != InventoryCategory.recipe) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${item.brand.isNotEmpty ? "${item.brand} • " : ""}${item.subCategory}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (item.category == InventoryCategory.hardware && item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.notes!,
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ] else if (item.category == InventoryCategory.chemicals && item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.notes!,
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ] else if (item.category == InventoryCategory.recipe) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${item.recipeStages.length} Formula Steps',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                      if (item.recipeStages.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (int i = 0; i < item.recipeStages.length; i++) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  '#${i + 1} ${item.recipeStages[i].stageName}: ${item.recipeStages[i].chemical}${item.recipeStages[i].machine.isNotEmpty ? " + ${item.recipeStages[i].machine}" : ""}',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.notes!,
                          style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );

          final controlsWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.category != InventoryCategory.recipe) ...[
                _buildStatusDropdown(item),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceLight,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                label: const Text('[EDIT]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () => _openEditInventoryItem(item),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Delete Item',
                onPressed: () => _confirmDeleteInventoryItem(item),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                contentWidget,
                const SizedBox(height: 10),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.category != InventoryCategory.recipe)
                      _buildStatusDropdown(item)
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                          label: const Text('[EDIT]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () => _openEditInventoryItem(item),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Item',
                          onPressed: () => _confirmDeleteInventoryItem(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: contentWidget),
              const SizedBox(width: 12),
              controlsWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusDropdown(InventoryItem item) {
    if (item.category == InventoryCategory.recipe) {
      return const SizedBox.shrink();
    }

    if (item.category == InventoryCategory.chemicals) {
      final currentStatus = const ['Full', 'Half', 'Empty'].contains(item.status)
          ? item.status
          : 'Full';

      Color getChemicalStatusColor(String status) {
        switch (status) {
          case 'Full':
            return Colors.greenAccent;
          case 'Half':
            return Colors.orangeAccent;
          case 'Empty':
            return Colors.redAccent;
          default:
            return AppTheme.textMuted;
        }
      }

      final color = getChemicalStatusColor(currentStatus);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(120), width: 1),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentStatus,
            isDense: true,
            dropdownColor: AppTheme.surface,
            icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            onChanged: (newStatus) {
              if (newStatus != null && newStatus != item.status) {
                final updated = item.copyWith(status: newStatus);
                widget.repository.updateInventoryItem(updated);
                setState(() {});
              }
            },
            items: const [
              DropdownMenuItem(
                value: 'Full',
                child: Text('Full', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              DropdownMenuItem(
                value: 'Half',
                child: Text('Half', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              DropdownMenuItem(
                value: 'Empty',
                child: Text('Empty', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    // Hardware status: In Service, Repair, Optimal, Retired
    final currentStatus = const ['In Service', 'Repair', 'Optimal', 'Retired'].contains(item.status)
        ? item.status
        : 'In Service';

    Color getStatusColor(String status) {
      switch (status) {
        case 'In Service':
          return AppTheme.primary;
        case 'Repair':
          return Colors.orangeAccent;
        case 'Optimal':
          return Colors.greenAccent;
        case 'Retired':
        default:
          return AppTheme.textMuted;
      }
    }

    final color = getStatusColor(currentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isDense: true,
          dropdownColor: AppTheme.surface,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != item.status) {
              final updated = item.copyWith(status: newStatus);
              widget.repository.updateInventoryItem(updated);
              setState(() {});
            }
          },
          items: const [
            DropdownMenuItem(
              value: 'In Service',
              child: Text('In Service', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            DropdownMenuItem(
              value: 'Repair',
              child: Text('Repair', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            DropdownMenuItem(
              value: 'Optimal',
              child: Text('Optimal', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            DropdownMenuItem(
              value: 'Retired',
              child: Text('Retired', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditInventoryItem(InventoryItem item) {
    final hardwareOptions = widget.repository.inventoryItems
        .where((i) => i.category == InventoryCategory.hardware)
        .map((i) => i.name)
        .toList();
    final chemicalOptions = widget.repository.inventoryItems
        .where((i) => i.category == InventoryCategory.chemicals)
        .map((i) => i.name)
        .toList();
    InventoryItemEditorDialog.show(
      context,
      itemToEdit: item,
      hardwareOptions: hardwareOptions,
      chemicalOptions: chemicalOptions,
      onSave: (updated) => widget.repository.updateInventoryItem(updated),
      onDelete: () => widget.repository.removeInventoryItem(item.id),
    );
  }

  void _confirmDeleteInventoryItem(InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirm Deletion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${item.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.repository.removeInventoryItem(item.id);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TEAM MEMBER INSPECTOR ---
  Widget _buildTeamInspector(BuildContext context) {
    final user = widget.repository.currentUser;
    final isFounder = _selectedTeamMemberId == 'founder' || _selectedTeamMemberId == null || user.teamMembers.isEmpty;

    if (isFounder) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: user.localAvatarBytes != null
                    ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                    : NetworkImage(user.avatarUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(user.businessName, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _badge('Founder & Lead Master', AppTheme.primary),
                        if (user.isVerifiedHost) _badge('Verified Pro Host', Colors.blueAccent),
                        _badge('${user.averageRating} Rating', Colors.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 14),
          _buildInfoSection(title: 'BIO & OPERATING ETHOS', content: user.bio, icon: Icons.badge_outlined),
          const SizedBox(height: 14),
          _buildInfoSection(title: 'SERVICE RADIUS & LOCATIONS', content: '${user.location} • ${user.serviceRadius}', icon: Icons.location_on_outlined),
          const SizedBox(height: 14),
          _buildInfoSection(title: 'CONTACT & SOCIAL', content: 'Phone: ${user.phone.isNotEmpty ? user.phone : "Not provided"} • IG: ${user.instagramHandle}', icon: Icons.phone_outlined),
        ],
      );
    }

    final member = user.teamMembers.firstWhere(
      (m) => m.id == _selectedTeamMemberId,
      orElse: () => user.teamMembers.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundImage: member.localAvatarBytes != null
                  ? MemoryImage(member.localAvatarBytes!) as ImageProvider
                  : NetworkImage(member.avatarUrl),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(member.roleTitle, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _badge(member.statusLabel, member.isAvailable ? Colors.greenAccent : Colors.orangeAccent),
                      _badge('${member.completedJobsCount} Jobs Completed', Colors.blueAccent),
                      _badge('${member.rating} Stars', Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 14),
        _buildInfoSection(
          title: 'ASSIGNED RESPONSIBILITIES',
          content: 'Responsible for ${member.roleTitle.toLowerCase()} workflows, paint gauge mapping, and multi-stage correction.',
          icon: Icons.work_outline_rounded,
        ),
      ],
    );
  }

  // --- PORTFOLIO INSPECTOR ---
  Widget _buildPortfolioInspector(BuildContext context) {
    final user = widget.repository.currentUser;
    final myJobs = widget.repository.getJobsByDetailer(user.id);
    if (myJobs.isEmpty) {
      return const Center(child: Text('No transformations published yet.'));
    }

    final job = myJobs.firstWhere(
      (j) => j.id == _selectedPortfolioJobId,
      orElse: () => myJobs.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              job.afterImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surface),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(job.vehicleFullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text('${job.paintColorName} • ${job.serviceType}', style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            _badge(job.defectStage.label, Colors.orangeAccent),
            _badge('${job.correctionPercentage}% Correction Achieved', Colors.greenAccent),
            _badge('${job.initialPaintThicknessMicrons.toStringAsFixed(0)}µm → ${job.finalPaintThicknessMicrons.toStringAsFixed(0)}µm', Colors.cyanAccent),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 12),
        _buildInfoSection(title: 'DESCRIPTION', content: job.description, icon: Icons.notes_rounded),
      ],
    );
  }

  // --- SERVICE INSPECTOR ---
  Widget _buildServiceInspector(BuildContext context, {bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final pkgs = user.servicePackages;
    if (pkgs.isEmpty) {
      return const Center(child: Text('No service packages defined yet.'));
    }

    final pkg = pkgs.firstWhere(
      (p) => p.id == _selectedServicePackageId,
      orElse: () => pkgs.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(pkg.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Text('\$${pkg.basePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Estimated Duration: ${pkg.estimatedDuration}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 16),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 12),
        _buildInfoSection(title: 'SERVICE DESCRIPTION', content: pkg.description, icon: Icons.description_outlined),
        if (pkg.recipeName != null && pkg.recipeName!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withAlpha(70)),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LINKED STUDIO RECIPE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                      ),
                      Text(
                        pkg.recipeName!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primary,
                  ),
                  onPressed: () {
                    final recipe = widget.repository.inventoryItems.firstWhere(
                      (i) => (pkg.recipeId != null && i.id == pkg.recipeId) ||
                             (i.category == InventoryCategory.recipe && i.name == pkg.recipeName),
                      orElse: () => InventoryItem(
                        id: pkg.recipeId ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}',
                        name: pkg.recipeName ?? 'Studio Recipe',
                        category: InventoryCategory.recipe,
                      ),
                    );
                    _showRecipePreviewModal(context, recipe, pkg, isMobile: isMobile);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View Recipe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(width: 2),
                      Icon(Icons.visibility_outlined, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('TREATMENTS & STEPS INCLUDED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        const SizedBox(height: 8),
        for (final item in pkg.includes) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13, color: Colors.white))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- SAVED RECIPES INSPECTOR ---
  Widget _buildSavedRecipesInspector(BuildContext context) {
    final savedJobs = widget.repository.savedJobs;
    if (savedJobs.isEmpty) {
      return const Center(child: Text('Select and save recipes from the community feed to view here.'));
    }

    final job = savedJobs.firstWhere(
      (j) => j.id == _selectedSavedJobId,
      orElse: () => savedJobs.first,
    );

    return JobRecipeCard(
      job: job,
      repository: widget.repository,
      onJobChanged: () => setState(() {}),
      onLike: () => widget.repository.toggleLike(job.id),
      onSave: () => widget.repository.toggleSave(job.id),
    );
  }

  void _showRecipePreviewModal(
    BuildContext context,
    InventoryItem recipe,
    ServicePackage pkg, {
    bool isMobile = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.science_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Linked to "${pkg.title}" Package',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 12),

                // Stages count badge & Recipe subcategory (if any)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withAlpha(60)),
                      ),
                      child: Text(
                        '${recipe.recipeStages.length} Formula Stages',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    if (recipe.subCategory.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        recipe.subCategory,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Stages List
                Expanded(
                  child: recipe.recipeStages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 36, color: AppTheme.textMuted),
                                const SizedBox(height: 10),
                                Text(
                                  'No detailed stages recorded yet for "${recipe.name}".',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: recipe.recipeStages.length,
                          itemBuilder: (context, i) {
                            final stage = recipe.recipeStages[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: AppTheme.primary.withAlpha(40),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          stage.stageName.isNotEmpty ? stage.stageName : 'Step ${i + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (stage.machine.isNotEmpty ||
                                      stage.chemical.isNotEmpty ||
                                      stage.pad.isNotEmpty ||
                                      stage.technique.isNotEmpty ||
                                      (stage.dilution != null && stage.dilution!.isNotEmpty)) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (stage.machine.isNotEmpty)
                                          _modalStageChip(Icons.handyman_outlined, stage.machine, Colors.blueAccent),
                                        if (stage.chemical.isNotEmpty)
                                          _modalStageChip(Icons.science_outlined, stage.chemical, Colors.tealAccent),
                                        if (stage.pad.isNotEmpty)
                                          _modalStageChip(Icons.radio_button_checked_rounded, stage.pad, Colors.amberAccent),
                                        if (stage.technique.isNotEmpty)
                                          _modalStageChip(Icons.speed_rounded, stage.technique, Colors.purpleAccent),
                                        if (stage.dilution != null && stage.dilution!.isNotEmpty)
                                          _modalStageChip(Icons.water_drop_outlined, stage.dilution!, Colors.cyanAccent),
                                      ],
                                    ),
                                  ],
                                  if (stage.notes != null && stage.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      stage.notes!,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),

                if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withAlpha(60),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recipe.notes!,
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 14),

                // Modal Footer Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceLight,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 15),
                        label: const Text('Back to Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Open in Workbench', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _selectedHub = StudioHubSection.inventory;
                            _inventoryCategoryFilter = 'RECIPE';
                            _selectedInventoryId = recipe.id;
                            _returnToServicePackageId = pkg.id;
                            _returnToServicePackageTitle = pkg.title;
                            if (isMobile) _mobileStep = 2;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modalStageChip(IconData icon, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
    Color color = AppTheme.primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4)),
        ],
      ),
    );
  }

  // --- CALENDAR DAY INSPECTOR (PANE 3) ---
  Widget _buildCalendarDayInspector(BuildContext context, {bool isMobile = false}) {
    final user = widget.repository.currentUser;
    final date = _selectedCalendarDate;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final isRecurringOff = widget.repository.isDateRecurringDayOff(date, detailerId: user.id);
    final isExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(user.id, date);
    final hours = widget.repository.getHoursForDate(date, detailerId: user.id);
    final dayBookings = widget.repository.getBookingsForDate(date, detailerId: user.id);
    final dayBlocks = widget.repository.getBlocksForDate(date, detailerId: user.id);
    final prefs = widget.repository.getCalendarPreferences(detailerId: user.id);

    final daySlots = widget.repository.getTimeSlotsForDate(date, detailerId: user.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExplicitlyBlocked ? Colors.redAccent.withAlpha(100) : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isExplicitlyBlocked
                          ? Colors.redAccent.withAlpha(30)
                          : (isRecurringOff ? AppTheme.surfaceLight : AppTheme.primary.withAlpha(30)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isExplicitlyBlocked
                          ? Icons.block_rounded
                          : (isRecurringOff ? Icons.nightlife_rounded : Icons.calendar_today_rounded),
                      color: isExplicitlyBlocked
                          ? Colors.redAccent
                          : (isRecurringOff ? AppTheme.textMuted : AppTheme.primary),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isExplicitlyBlocked
                                    ? Colors.redAccent.withAlpha(30)
                                    : (isRecurringOff
                                        ? Colors.amber.withAlpha(30)
                                        : Colors.greenAccent.withAlpha(30)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExplicitlyBlocked
                                    ? 'DAY BLOCKED'
                                    : (isRecurringOff ? 'RECURRING DAY OFF' : 'OPEN FOR BOOKINGS'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isExplicitlyBlocked
                                      ? Colors.redAccent
                                      : (isRecurringOff ? Colors.amber : Colors.greenAccent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hours.isOpen ? '${hours.openTime} - ${hours.closeTime}' : 'Studio Closed',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Action Bar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExplicitlyBlocked ? Colors.green : Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(isExplicitlyBlocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16),
                      label: Text(
                        isExplicitlyBlocked ? 'Unblock Full Day' : 'Block Full Day',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        widget.repository.toggleBlockDay(date, detailerId: user.id);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => CalendarPreferencesDialog.show(context, repository: widget.repository),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section 1: Turo-Style Slot Availability
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOURLY SLOT AVAILABILITY',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap any window to block/open, or edit and add custom slots.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Add Slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddSlotDialog(context, date),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 13),
              label: const Text('Auto-Gen', style: TextStyle(fontSize: 11)),
              onPressed: () => _showAutoGenerateSlotsDialog(context, date, hours),
            ),
            if (daySlots.isNotEmpty) ...[
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 13),
                label: const Text('Clear Slots', style: TextStyle(fontSize: 11)),
                onPressed: () => _confirmClearAllSlots(context, date),
              ),
            ],
            if (dayBlocks.any((b) => b.blockedSlots.isNotEmpty || b.isAllDay)) ...[
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: BorderSide(color: Colors.greenAccent.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 13),
                label: const Text('Unblock All', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  widget.repository.clearBlockedSlotsForDate(date, detailerId: user.id);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unblocked all slots for ${DateFormat('MMM d').format(date)}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        if (daySlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 28, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  const Text('No slots defined for this day.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Add Time Slot'),
                        onPressed: () => _showAddSlotDialog(context, date),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 13),
                        label: const Text('Auto-Gen Slots'),
                        onPressed: () => _showAutoGenerateSlotsDialog(context, date, hours),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 13),
                        label: const Text('Reset to Schedule Defaults'),
                        onPressed: () {
                          widget.repository.resetTimeSlotsForDateToDefaults(date, detailerId: user.id);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reset ${DateFormat('MMM d').format(date)} to operating hours slots'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          // Slot Matrix
          ...daySlots.map((slot) {
            final conflictingAppt = widget.repository.getConflictingBookingForSlot(date, slot, detailerId: user.id);
            final isBooked = conflictingAppt != null;
            final isExactMatch = isBooked && conflictingAppt.scheduledTimeSlot.trim().toLowerCase() == slot.trim().toLowerCase();
            final isDayOff = !hours.isOpen || isRecurringOff;
            final isDayExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(user.id, date);
            final isSlotExplicitlyBlocked = widget.repository.isSlotExplicitlyBlocked(user.id, date, slot);
            final inOperatingHours = widget.repository.isSlotWithinOperatingHours(date, slot, detailerId: user.id);

            Color borderColor = AppTheme.border;
            Color bgColor = AppTheme.surface;
            String statusTitle = 'Available for Booking';
            Color statusColor = Colors.greenAccent;
            IconData iconData = Icons.check_circle_outline_rounded;
            bool isStruck = false;

            if (isBooked) {
              final hasDayConflict = isDayOff || isDayExplicitlyBlocked;
              borderColor = hasDayConflict ? Colors.amber.withAlpha(140) : Colors.green.withAlpha(120);
              bgColor = hasDayConflict ? Colors.amber.withAlpha(20) : Colors.green.withAlpha(20);
              statusTitle = isExactMatch
                  ? (hasDayConflict
                      ? 'Booked by ${conflictingAppt.clientName} (Conflict: Day Closed/Blocked)'
                      : 'Booked by ${conflictingAppt.clientName}')
                  : (hasDayConflict
                      ? 'Reserved • Overlaps with ${conflictingAppt.clientName} (Day Closed/Blocked)'
                      : 'Reserved • Overlaps with ${conflictingAppt.clientName} (${conflictingAppt.scheduledTimeSlot})');
              statusColor = hasDayConflict ? Colors.amber : Colors.greenAccent;
              iconData = hasDayConflict ? Icons.warning_amber_rounded : Icons.directions_car_rounded;
              isStruck = false;
            } else if (isDayExplicitlyBlocked) {
              borderColor = Colors.redAccent.withAlpha(100);
              bgColor = Colors.redAccent.withAlpha(15);
              statusTitle = 'Day Blocked by Detailer';
              statusColor = Colors.redAccent;
              iconData = Icons.block_rounded;
              isStruck = true;
            } else if (isDayOff) {
              borderColor = AppTheme.border;
              bgColor = AppTheme.surfaceLight.withAlpha(45);
              statusTitle = 'Studio Closed (Day Off)';
              statusColor = AppTheme.textMuted;
              iconData = Icons.nightlife_rounded;
              isStruck = true;
            } else if (isSlotExplicitlyBlocked) {
              borderColor = Colors.redAccent.withAlpha(100);
              bgColor = Colors.redAccent.withAlpha(15);
              statusTitle = 'Blocked by Detailer';
              statusColor = Colors.redAccent;
              iconData = Icons.block_rounded;
              isStruck = true;
            } else if (!inOperatingHours && hours.isOpen) {
              borderColor = AppTheme.border;
              bgColor = AppTheme.surfaceLight.withAlpha(60);
              statusTitle = 'Outside Operating Hours';
              statusColor = AppTheme.textMuted;
              iconData = Icons.access_time_rounded;
              isStruck = true;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(iconData, size: 18, color: statusColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isStruck ? Colors.grey.shade400 : Colors.white,
                            decoration: isStruck ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusTitle,
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                        ),
                        if (isBooked) ...[
                          const SizedBox(height: 2),
                          Text(
                            isExactMatch
                                ? ((isDayOff || isDayExplicitlyBlocked)
                                    ? '⚠️ Day is closed/blocked • ${conflictingAppt.vehicleYearMakeModel}'
                                    : '${conflictingAppt.vehicleYearMakeModel} • ${conflictingAppt.package.title}')
                                : 'Conflict shield: ${conflictingAppt.package.title} (${conflictingAppt.package.estimatedDuration})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: (isDayOff || isDayExplicitlyBlocked) ? Colors.amber : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isBooked) ...[
                    if (isDayOff && !isDayExplicitlyBlocked && !isSlotExplicitlyBlocked) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMuted,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => CalendarPreferencesDialog.show(context, repository: widget.repository),
                        child: const Text('Day Off', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: (isDayExplicitlyBlocked || isSlotExplicitlyBlocked) ? Colors.greenAccent : Colors.redAccent,
                          side: BorderSide(
                            color: (isDayExplicitlyBlocked || isSlotExplicitlyBlocked)
                                ? Colors.greenAccent.withAlpha(120)
                                : Colors.redAccent.withAlpha(100),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          widget.repository.toggleBlockSlot(date, slot, detailerId: user.id);
                        },
                        child: Text(
                          (isDayExplicitlyBlocked || isSlotExplicitlyBlocked) ? 'Reopen' : 'Block Slot',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Edit Slot',
                      onPressed: () => _showEditSlotDialog(context, date, slot),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Delete Slot',
                      onPressed: () => _confirmDeleteTimeSlot(context, date, slot),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '\$${conflictingAppt.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

        const SizedBox(height: 20),

        // Section 2: Confirmed Bookings List
        Text(
          'CONFIRMED APPOINTMENTS (${dayBookings.length})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        if (dayBookings.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_available_rounded, size: 20, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No client bookings scheduled for this date.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...dayBookings.map((b) => _buildBookingAppointmentCard(b)),
        ],

        const SizedBox(height: 20),

        // Section 3: Detailer Calendar Settings Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text('CALENDAR SHIELD PREFERENCES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                    ],
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    onPressed: () => CalendarPreferencesDialog.show(context, repository: widget.repository),
                    child: const Text('Edit Preferences', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPrefRow(Icons.timer_outlined, 'Advance Notice:', '${prefs.advanceNoticeHours} hours lead time required'),
              const SizedBox(height: 4),
              _buildPrefRow(Icons.hourglass_empty_rounded, 'Turnaround Buffer:', '${prefs.bufferMinutesBetweenJobs} min buffer between jobs'),
              const SizedBox(height: 4),
              _buildPrefRow(Icons.calendar_today_outlined, 'Booking Horizon:', 'Clients can book up to ${prefs.maxAdvanceBookingDays} days in advance'),
              const SizedBox(height: 4),
              _buildPrefRow(Icons.bolt_rounded, 'Reservation Mode:', prefs.autoConfirmBookings ? 'Instant Auto-Confirm' : 'Manual Detailer Review'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrefRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildBookingAppointmentCard(BookingAppointment b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  b.vehicleYearMakeModel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '\$${b.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${b.package.title} • ${b.scheduledTimeSlot}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(b.clientName, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (b.clientPhone.isNotEmpty) ...[
                const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(b.clientPhone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context, DateTime date) {
    final hours = widget.repository.getHoursForDate(date);
    String startTime = hours.isOpen ? hours.openTime : '08:00 AM';
    final startMin = JobRepository.timeStringToMinutes(startTime);
    String endTime = JobRepository.formatMinutesToTime(startMin + 180);
    bool applyAllDays = true;

    final timeOptions = [
      '05:00 AM', '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
      '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM',
      '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Add Booking Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select appointment time window for clients:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: timeOptions.contains(startTime) ? startTime : timeOptions.first,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        startTime = val;
                                        final sMin = JobRepository.timeStringToMinutes(val);
                                        endTime = JobRepository.formatMinutesToTime(sMin + 180);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        child: Text('to', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: timeOptions.contains(endTime) ? endTime : timeOptions.last,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => endTime = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Apply to all operating days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Available across regular schedule', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                        Switch(
                          value: applyAllDays,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) => setDialogState(() => applyAllDays = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final slotStr = '$startTime - $endTime';
                    widget.repository.addCustomTimeSlot(
                      slotStr,
                      specificDate: applyAllDays ? null : date,
                    );
                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSlotDialog(BuildContext context, DateTime date, String currentSlot) {
    String startTime = '08:00 AM';
    String endTime = '11:00 AM';
    if (currentSlot.contains('-')) {
      final parts = currentSlot.split('-');
      startTime = parts.first.trim();
      endTime = parts.last.trim();
    }
    bool applyAllDays = true;

    final timeOptions = [
      '05:00 AM', '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
      '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM',
      '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Booking Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Editing slot: $currentSlot', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: timeOptions.contains(startTime) ? startTime : timeOptions.first,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => startTime = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        child: Text('to', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: timeOptions.contains(endTime) ? endTime : timeOptions.last,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => endTime = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Apply to all operating days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Update this slot across schedule', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                        Switch(
                          value: applyAllDays,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) => setDialogState(() => applyAllDays = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final newSlotStr = '$startTime - $endTime';
                    widget.repository.updateCustomTimeSlot(
                      currentSlot,
                      newSlotStr,
                      specificDate: applyAllDays ? null : date,
                    );
                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAutoGenerateSlotsDialog(BuildContext context, DateTime date, DayBusinessHours hours) {
    final prefs = widget.repository.getCalendarPreferences(detailerId: widget.repository.currentUser.id);
    int duration = prefs.slotDurationHours;
    if (![1, 2, 3, 4, 5, 6, 8].contains(duration)) {
      duration = 3;
    }
    bool applyAllDays = true;

    // Resolve initial operating window (fallback to open days if viewing a closed day)
    String startTime = hours.isOpen ? hours.openTime : '08:00 AM';
    String endTime = hours.isOpen ? hours.closeTime : '06:00 PM';
    if (!hours.isOpen) {
      final openDay = prefs.weeklySchedule.firstWhere(
        (d) => d.isOpen,
        orElse: () => const DayBusinessHours(weekday: 1, openTime: '08:00 AM', closeTime: '06:00 PM'),
      );
      startTime = openDay.openTime;
      endTime = openDay.closeTime;
    }

    final timeOptions = [
      '05:00 AM', '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
      '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM',
      '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM',
    ];
    if (!timeOptions.contains(startTime)) timeOptions.add(startTime);
    if (!timeOptions.contains(endTime)) timeOptions.add(endTime);
    timeOptions.sort((a, b) => JobRepository.timeStringToMinutes(a).compareTo(JobRepository.timeStringToMinutes(b)));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final previewSlots = JobRepository.generateSlotsForHours(
              openTime: startTime,
              closeTime: endTime,
              slotDurationHours: duration,
            );

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Auto-Generate Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Automatically generate booking arrival windows across operating hours.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      // Time Range Selector
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: timeOptions.contains(startTime) ? startTime : timeOptions.first,
                                      isExpanded: true,
                                      dropdownColor: AppTheme.surface,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => startTime = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                            child: Text('to', style: TextStyle(color: AppTheme.textMuted)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: timeOptions.contains(endTime) ? endTime : timeOptions.last,
                                      isExpanded: true,
                                      dropdownColor: AppTheme.surface,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => endTime = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Duration Selector
                      const Text('Slot Duration / Interval', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [1, 2, 3, 4, 5, 6, 8].map((d) {
                          final isSel = duration == d;
                          return ChoiceChip(
                            label: Text('$d Hour${d > 1 ? "s" : ""}'),
                            selected: isSel,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceLight,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.black : Colors.white,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            onSelected: (val) {
                              if (val) setDialogState(() => duration = d);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Live Slot Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withAlpha(50),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.preview_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Generated Slots Preview (${previewSlots.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${duration}h windows',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (previewSlots.isEmpty)
                              const Text(
                                'No full windows fit in this interval. Adjust start/end time or duration.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: previewSlots.map((s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.primary.withAlpha(60)),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Apply all days toggle
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Apply to all operating days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(
                                    applyAllDays
                                        ? 'Replaces template and refreshes all calendar dates'
                                        : 'Applies exclusively to ${DateFormat('MMM d').format(date)}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: applyAllDays,
                              activeThumbColor: AppTheme.primary,
                              onChanged: (val) => setDialogState(() => applyAllDays = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    widget.repository.autoGenerateTimeSlots(
                      openTime: startTime,
                      closeTime: endTime,
                      slotDurationHours: duration,
                      specificDate: applyAllDays ? null : date,
                    );
                    Navigator.of(ctx).pop();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          applyAllDays
                              ? 'Auto-generated $duration-hour slots for all operating days.'
                              : 'Auto-generated $duration-hour slots for ${DateFormat('MMM d').format(date)}.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Generate Slots', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTimeSlot(BuildContext context, DateTime date, String slot) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Delete Time Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete the arrival window "$slot"?',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose whether to remove this window only for ${DateFormat('EEE, MMM d').format(date)} or across all operating days.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.border),
              ),
              onPressed: () {
                widget.repository.removeCustomTimeSlot(
                  slot,
                  specificDate: date,
                  applyAllDays: false,
                  detailerId: widget.repository.currentUser.id,
                );
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "$slot" for ${DateFormat('MMM d').format(date)}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('This Date Only'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.repository.removeCustomTimeSlot(
                  slot,
                  specificDate: date,
                  applyAllDays: true,
                  detailerId: widget.repository.currentUser.id,
                );
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "$slot" across all operating days'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('All Operating Days', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearAllSlots(BuildContext context, DateTime date) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Clear All Time Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to clear all arrival windows for ${DateFormat('EEEE, MMM d').format(date)}?',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'This day will have 0 open slots and clients will not be able to book until you add slots or reset to schedule defaults.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.repository.clearTimeSlotsForDate(
                  date,
                  detailerId: widget.repository.currentUser.id,
                );
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleared all slots for ${DateFormat('MMM d').format(date)}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Clear Slots', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // RESPONSIVE BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        // Desktop / Large Screen: Multi-column side-by-side view with Focus Mode collapse
        if (isDesktop) {
          final pane1Width = constraints.maxWidth < 900
              ? 180.0
              : constraints.maxWidth < 1100
                  ? 210.0
                  : 240.0;
          final pane2Width = constraints.maxWidth < 900
              ? 230.0
              : constraints.maxWidth < 1100
                  ? 260.0
                  : 300.0;

          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                if (!_isFocusMode) ...[
                  // Pane 1: Studio Hub
                  SizedBox(
                    width: pane1Width,
                    child: _buildPane1(context, isMobile: false),
                  ),
                  const VerticalDivider(width: 1, color: AppTheme.border),

                  // Pane 2: Subcategory / Item List
                  SizedBox(
                    width: pane2Width,
                    child: _buildPane2(context, isMobile: false),
                  ),
                  const VerticalDivider(width: 1, color: AppTheme.border),
                ],

                // Pane 3: Workspace Canvas / Inspector (Expanded for 100% full screen focus)
                Expanded(
                  child: _buildPane3(context, isMobile: false),
                ),
              ],
            ),
          );
        }

        // Mobile / Small Screen: Drill-down navigation stack with back buttons
        return PopScope(
          canPop: _mobileStep == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _mobileStep > 0) {
              setState(() => _mobileStep--);
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: SafeArea(
              child: IndexedStack(
                index: _mobileStep,
                children: [
                  _buildPane1(context, isMobile: true),
                  _buildPane2(context, isMobile: true),
                  _buildPane3(context, isMobile: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
