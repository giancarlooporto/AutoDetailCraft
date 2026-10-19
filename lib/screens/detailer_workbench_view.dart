import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/shift_request.dart';
import '../services/local_storage_service.dart';

enum StudioHubSection {
  portfolio('Portfolio', 'PORTFOLIO', 'Showcase builds & media', Icons.photo_library_rounded),
  services('Services', 'SERVICES', 'Packages & pricing menus', Icons.design_services_rounded),
  inventory('Inventory', 'INVENTORY', 'Hardware, chemicals, recipe', Icons.inventory_2_rounded),
  calendar('Calendar', 'CALENDAR', 'Bookings & host schedule', Icons.calendar_month_rounded),
  teams('My Teams', 'MY TEAMS', 'Staff roles & technicians', Icons.groups_rounded),
  savedRecipes('Saved Recipes', 'SAVED RECIPES', 'Technical playbook', Icons.bookmark_rounded),
  settings('Settings', 'SETTINGS', 'Shop, profile & account', Icons.settings_rounded);

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
  // Hardcoded arrangement B (Notebook Sketch sequence)
  static const List<StudioHubSection> _hardcodedHubSections = [
    StudioHubSection.portfolio,
    StudioHubSection.services,
    StudioHubSection.inventory,
    StudioHubSection.calendar,
    StudioHubSection.teams,
    StudioHubSection.savedRecipes,
  ];

  bool get _canEditInventory =>
      widget.repository.activeTeamMember?.allowsInventoryEdit ?? true;

  bool get _canViewPricing =>
      widget.repository.activeTeamMember?.allowsPricingView ?? true;

  bool get _canManageTeam =>
      widget.repository.activeTeamMember?.allowsTeamManagement ?? true;

  bool get _canViewAllCalendar =>
      widget.repository.activeTeamMember?.allowsAllCalendarView ?? true;

  List<StudioHubSection> get _visibleHubSections {
    final activeMember = widget.repository.activeTeamMember;
    if (activeMember == null) return _hardcodedHubSections;
    final allowed = _hardcodedHubSections
        .where((s) => activeMember.isSectionAllowed(s.name))
        .toList();
    return allowed.isNotEmpty ? allowed : [StudioHubSection.portfolio];
  }

  StudioHubSection _selectedHub = StudioHubSection.portfolio;
  String _inventoryCategoryFilter = 'HARDWARE'; // HARDWARE, CHEMICALS, RECIPE
  String _selectedSettingsCategory = 'SHOP_MODE'; // SHOP_MODE, STUDIO_PROFILE, ACCOUNT

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
  String _selectedCalendarTeamMemberId = 'all'; // 'all' (Studio), 'founder', or teamMemberId

  // Responsive state
  bool _isFocusMode = false;
  int _mobileStep = 0; // 0 = Hub (Pane 1), 1 = List (Pane 2), 2 = Inspector (Pane 3)
  Timer? _autoLockTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialCalendarDate != null) {
      _selectedHub = StudioHubSection.calendar;
      _selectedCalendarDate = widget.initialCalendarDate!;
      _calendarDisplayMonth = DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, 1);
    } else {
      _loadSavedHubSection();
    }
    widget.repository.addListener(_onRepoChanged);
    _ensureSelection();
    _startAutoLockTimer();
  }

  void _startAutoLockTimer() {
    // Admin mode never auto-locks (switching to Shop locks immediately).
    _autoLockTimer?.cancel();
  }

  Future<void> _lockOwnerViewOrSetupPin() async {
    if (!widget.repository.hasOwnerPin) {
      final created = await _showCreateOwnerPinDialog();
      if (!created) return;
    }
    widget.repository.lockOwnerView();
    if (mounted) setState(() {});
  }

  void _resetAutoLockTimer() {
    _autoLockTimer?.cancel();
  }

  Future<void> _loadSavedHubSection() async {
    final savedName = await LocalStorageService.loadStudioHubSection();
    final savedCategory = await LocalStorageService.loadInventoryCategoryFilter();
    final savedInvId = await LocalStorageService.loadSelectedInventoryId();
    if (mounted) {
      setState(() {
        if (savedName != null && widget.initialCalendarDate == null) {
          final match = StudioHubSection.values.where((s) => s.name == savedName);
          if (match.isNotEmpty) {
            _selectedHub = match.first;
          }
        }
        if (savedCategory != null && (savedCategory == 'HARDWARE' || savedCategory == 'CHEMICALS' || savedCategory == 'RECIPE')) {
          _inventoryCategoryFilter = savedCategory;
        }
        if (savedInvId != null && savedInvId.isNotEmpty) {
          _selectedInventoryId = savedInvId;
        }
        _ensureSelection();
      });
    }
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {
        _ensureSelection();
      });
      _startAutoLockTimer();
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
    if (_selectedServicePackageId != null && !user.servicePackages.any((p) => p.id == _selectedServicePackageId)) {
      _selectedServicePackageId = null;
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

    if (widget.repository.isViewingAsTeamMember && _selectedHub == StudioHubSection.settings) {
      _selectedHub = _visibleHubSections.first;
    }
  }

  void _selectHub(StudioHubSection section, {bool isMobile = false}) {
    LocalStorageService.saveStudioHubSection(section.name);
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
        return _selectedServicePackageId != null && user.servicePackages.any((p) => p.id == _selectedServicePackageId);
      case StudioHubSection.savedRecipes:
        return widget.repository.savedJobs.isNotEmpty;
      case StudioHubSection.settings:
        return false;
    }
  }

  // --- ACTIONS ---

  void _openAdd({bool isMobile = false}) {
    switch (_selectedHub) {
      case StudioHubSection.calendar:
        CalendarPreferencesDialog.show(context, repository: widget.repository);
        break;
      case StudioHubSection.inventory:
        if (!_canEditInventory) return;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added "${newItem.name}" to inventory'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {
              _selectedInventoryId = newItem.id;
              if (isMobile) _mobileStep = 2;
            });
            LocalStorageService.saveSelectedInventoryId(newItem.id);
          },
        );
        break;
      case StudioHubSection.teams:
        if (!_canManageTeam) return;
        AddTeamMemberDialog.show(
          context,
          repository: widget.repository,
          onMemberAdded: (_) {
            setState(() {});
          },
        );
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
        if (!_canViewPricing) return;
        ServicePackageEditorDialog.show(
          context,
          availableRecipes: widget.repository.recipeItems,
          onSave: (pkg) {
            widget.repository.addServicePackage(pkg);
            setState(() {
              _selectedServicePackageId = pkg.id;
              if (isMobile) _mobileStep = 2;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.border),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Service package "${pkg.title}" created successfully!'),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
        break;
      case StudioHubSection.savedRecipes:
        widget.repository.setActiveTab(0);
        break;
      case StudioHubSection.settings:
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
        if (!_canEditInventory) return;
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
        if (!_canViewPricing) return;
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
          onSave: (up) {
            widget.repository.updateServicePackage(up);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.border),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Service package "${up.title}" updated successfully!'),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onDelete: () {
            widget.repository.removeServicePackage(pkg.id);
            setState(() {
              if (_selectedServicePackageId == pkg.id) {
                _selectedServicePackageId = null;
              }
              if (_mobileStep == 2) _mobileStep = 1;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.border),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('Service package "${pkg.title}" removed.'),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
        break;
      case StudioHubSection.teams:
        if (!_canManageTeam) return;
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
      case StudioHubSection.settings:
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
        if (!_canEditInventory) return;
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
        if (!_canViewPricing) return;
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
        if (!_canManageTeam) return;
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
      case StudioHubSection.settings:
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
              setState(() {
                if (_selectedHub == StudioHubSection.services) {
                  _selectedServicePackageId = null;
                }
                if (_mobileStep == 2) {
                  _mobileStep = 1;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  content: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text('"$itemTitle" removed successfully.'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
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
          // Studio Profile Header Card (Clicking studio name/profile opens Public Storefront)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withAlpha(120),
              border: const Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('studio_header_storefront_btn'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicStudioScreen(
                            detailer: user,
                            repository: widget.repository,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
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
                    ),
                  ),
                ),
                _buildActiveIdentityBanner(context),
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
                for (final section in _visibleHubSections) ...[
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

          // Pinned at the very bottom-left of Pane 1: Settings (Admin / Owner only)
          if (!widget.repository.isViewingAsTeamMember)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedHub == StudioHubSection.settings
                      ? AppTheme.primary.withAlpha(25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedHub == StudioHubSection.settings
                        ? AppTheme.primary.withAlpha(120)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    key: const ValueKey('pane1_settings_btn'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _selectedHub == StudioHubSection.settings ? AppTheme.primary : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: _selectedHub == StudioHubSection.settings ? Colors.black : AppTheme.textSecondary,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedHub == StudioHubSection.settings ? FontWeight.bold : FontWeight.w600,
                        color: _selectedHub == StudioHubSection.settings ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Shop, profile & account',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectHub(StudioHubSection.settings, isMobile: isMobile),
                  ),
                ),
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
      case StudioHubSection.settings:
        return 3;
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (section == StudioHubSection.teams && widget.repository.pendingShiftRequests.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.repository.pendingShiftRequests.length} req',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
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
            ],
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
          if (_selectedHub != StudioHubSection.savedRecipes &&
              _selectedHub != StudioHubSection.inventory &&
              _selectedHub != StudioHubSection.calendar &&
              _selectedHub != StudioHubSection.settings) ...[
            if ((_selectedHub != StudioHubSection.teams || _canManageTeam) &&
                (_selectedHub != StudioHubSection.services || _canViewPricing)) ...[
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
      case StudioHubSection.settings:
        return 'Configure studio & account options';
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
            LocalStorageService.saveInventoryCategoryFilter(category);
            setState(() {
              _inventoryCategoryFilter = category;
              if (isMobile) {
                _mobileStep = 2;
              }
              _ensureSelection();
              if (_selectedInventoryId != null) {
                LocalStorageService.saveSelectedInventoryId(_selectedInventoryId!);
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
      case StudioHubSection.settings:
        return _buildSettingsPane2(context, isMobile: isMobile);
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
                  backgroundColor: AppTheme.surfaceLight,
                  backgroundImage: member.localAvatarBytes != null
                      ? MemoryImage(member.localAvatarBytes!) as ImageProvider
                      : (member.avatarUrl.trim().isNotEmpty
                          ? NetworkImage(member.avatarUrl.trim())
                          : null),
                  child: (member.localAvatarBytes == null && member.avatarUrl.trim().isEmpty)
                      ? const Icon(Icons.person_rounded, size: 18, color: AppTheme.textMuted)
                      : null,
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
                    if (widget.repository.pendingShiftRequests.any((r) => r.teamMemberId == member.id)) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withAlpha(120)),
                        ),
                        child: const Text(
                          'REQ',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
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
                    _canViewPricing ? '\$${pkg.basePrice.toStringAsFixed(0)}' : '••••',
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
                  _selectedServicePackageId = isSelected ? null : pkg.id;
                  if (isMobile && !isSelected) _mobileStep = 2;
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

  // --- CALENDAR TEAM FILTER BAR (DROPDOWN) ---
  Widget _buildCalendarTeamFilterBar({String? keyPrefix}) {
    final user = widget.repository.currentUser;
    final staff = widget.repository.getStudioStaff(detailerId: user.id);
    if (staff.length <= 1) return const SizedBox.shrink();

    final activeMember = widget.repository.activeTeamMember;
    final isRestricted = !_canViewAllCalendar && activeMember != null;

    if (isRestricted) {
      if (_selectedCalendarTeamMemberId != activeMember.id) {
        _selectedCalendarTeamMemberId = activeMember.id;
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withAlpha(120), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_outlined, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Personal Schedule (${activeMember.name})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('LOCKED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
          ],
        ),
      );
    }

    // Verify current selection is valid
    final isValidSelection = _selectedCalendarTeamMemberId == 'all' ||
        staff.any((m) => m.id == _selectedCalendarTeamMemberId);
    final currentId = isValidSelection ? _selectedCalendarTeamMemberId : 'all';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: currentId == 'all' ? AppTheme.border : AppTheme.primary.withAlpha(160),
          width: currentId == 'all' ? 1.0 : 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: Key(keyPrefix != null ? 'calendar_team_dropdown_$keyPrefix' : 'calendar_team_dropdown'),
          value: currentId,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          menuMaxHeight: 380,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 22, color: AppTheme.primary),
          selectedItemBuilder: (context) {
            return [
              _buildDropdownSelectedRow(
                id: 'all',
                label: 'All Team (Entire Studio)',
                icon: Icons.groups_rounded,
              ),
              ...staff.map((m) => _buildDropdownSelectedRow(
                id: m.id,
                label: m.isFounder ? 'Founder (You)' : m.name,
                icon: Icons.person_rounded,
                avatarUrl: m.avatarUrl,
              )),
            ];
          },
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: _buildDropdownItemRow(
                id: 'all',
                label: 'All Team (Entire Studio)',
                icon: Icons.groups_rounded,
                subtitle: 'Master studio availability & all appointments',
                badgeText: '${staff.length} Staff',
                isSelected: currentId == 'all',
              ),
            ),
            ...staff.map((m) {
              return DropdownMenuItem<String>(
                value: m.id,
                child: _buildDropdownItemRow(
                  id: m.id,
                  label: m.isFounder ? 'Founder (You)' : m.name,
                  icon: Icons.person_rounded,
                  avatarUrl: m.avatarUrl,
                  subtitle: m.roleTitle,
                  badgeText: m.isFounder ? 'Shop Owner' : null,
                  isSelected: currentId == m.id,
                ),
              );
            }),
          ],
          onChanged: (newId) {
            if (newId != null) {
              setState(() {
                _selectedCalendarTeamMemberId = newId;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildDropdownSelectedRow({
    required String id,
    required String label,
    IconData? icon,
    String? avatarUrl,
  }) {
    return Row(
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
          CircleAvatar(
            radius: 9,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 15, color: id == 'all' ? AppTheme.primary : Colors.white),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: id == 'all' ? Colors.white : AppTheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownItemRow({
    required String id,
    required String label,
    IconData? icon,
    String? avatarUrl,
    String? subtitle,
    String? badgeText,
    required bool isSelected,
  }) {
    return Row(
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withAlpha(30) : AppTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withAlpha(25) : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
        if (isSelected) ...[
          const SizedBox(width: 6),
          const Icon(Icons.check_rounded, size: 16, color: AppTheme.primary),
        ],
      ],
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
        // Team Filter Bar
        _buildCalendarTeamFilterBar(keyPrefix: 'pane2'),

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
            final isViewingAll = _selectedCalendarTeamMemberId == 'all';
            final targetMemberId = isViewingAll ? null : _selectedCalendarTeamMemberId;

            final isRecurringOff = isViewingAll
                ? widget.repository.isDateRecurringDayOff(cellDate, detailerId: user.id)
                : widget.repository.isMemberRecurringDayOff(_selectedCalendarTeamMemberId, cellDate, detailerId: user.id);
            final isExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(user.id, cellDate, teamMemberId: targetMemberId);
            final isFullyBlocked = isViewingAll
                ? widget.repository.isDateFullyBlocked(user.id, cellDate)
                : !widget.repository.isMemberOnDutyOnDate(_selectedCalendarTeamMemberId, cellDate, detailerId: user.id);
            final dayBlocks = widget.repository.getBlocksForDate(cellDate, detailerId: user.id);
            final isPartiallyBlocked = isViewingAll
                ? (!isExplicitlyBlocked && dayBlocks.any((b) => b.blockedSlots.isNotEmpty))
                : (!isExplicitlyBlocked && widget.repository.getTimeSlotsForDate(cellDate, detailerId: user.id).any(
                    (s) => widget.repository.isSlotExplicitlyBlocked(user.id, cellDate, s, teamMemberId: _selectedCalendarTeamMemberId),
                  ));
            final staff = widget.repository.getStudioStaff(detailerId: user.id);
            final dayBookings = isViewingAll
                ? widget.repository.getBookingsForDate(cellDate, detailerId: user.id)
                : widget.repository.getBookingsForDate(cellDate, detailerId: user.id).where(
                    (b) => b.assignedTeamMemberId == _selectedCalendarTeamMemberId || staff.length <= 1,
                  ).toList();
            final isFullyBooked = !isFullyBlocked && !isRecurringOff && widget.repository.isDateFullyBooked(cellDate, detailerId: user.id, teamMemberId: targetMemberId);

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
                  if (_canEditInventory) ...[
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
                  ],
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
                  if ((_selectedHub != StudioHubSection.teams || _canManageTeam) &&
                      (_selectedHub != StudioHubSection.services || _canViewPricing)) ...[
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
        return _buildTeamInspector(context, isMobile: isMobile);
      case StudioHubSection.portfolio:
        return _buildPortfolioInspector(context);
      case StudioHubSection.services:
        return _buildServiceInspector(context, isMobile: isMobile);
      case StudioHubSection.savedRecipes:
        return _buildSavedRecipesInspector(context);
      case StudioHubSection.settings:
        return _buildSettingsInspector(context, isMobile: isMobile);
    }
  }

  // --- SETTINGS (PANE 2 & PANE 3) ---
  Widget _buildSettingsPane2(BuildContext context, {bool isMobile = false}) {
    final options = [
      (
        id: 'SHOP_MODE',
        title: 'Shop',
        subtitle: 'Working with a team & Shop / Admin lock',
        icon: Icons.storefront_rounded,
      ),
      (
        id: 'STUDIO_PROFILE',
        title: 'Studio Profile',
        subtitle: 'Edit studio name, bio, location & photos',
        icon: Icons.badge_outlined,
      ),
      (
        id: 'ACCOUNT',
        title: 'Account & Mode',
        subtitle: 'Switch to Client Mode & Log Out',
        icon: Icons.manage_accounts_rounded,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final opt = options[idx];
        final isSelected = _selectedSettingsCategory == opt.id;
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
              key: ValueKey('settings_option_${opt.id.toLowerCase()}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedSettingsCategory = opt.id;
                  if (isMobile) _mobileStep = 2;
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
                        opt.icon,
                        size: 18,
                        color: isSelected ? Colors.black : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.subtitle,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsInspector(BuildContext context, {bool isMobile = false}) {
    final repo = widget.repository;
    final user = repo.currentUser;

    if (_selectedSettingsCategory == 'STUDIO_PROFILE') {
      return Container(
        padding: const EdgeInsets.all(20),
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
                CircleAvatar(
                  radius: 26,
                  backgroundImage: user.localAvatarBytes != null
                      ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                      : NetworkImage(user.avatarUrl),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.businessName.isNotEmpty ? user.businessName : user.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.location.isNotEmpty ? user.location : 'No location set',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user.bio.isNotEmpty ? user.bio : 'No studio bio added yet.',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Studio Profile & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => EditProfileDialog.show(context, repository: repo),
            ),
          ],
        ),
      );
    }

    if (_selectedSettingsCategory == 'ACCOUNT') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Client Mode (My Garage)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Switch from your Detailer Studio Workbench to your personal Client Garage view.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('settings_switch_client_mode_btn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.directions_car_rounded, size: 16),
                  label: const Text('Switch to Client Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => repo.toggleHostMode(targetRole: UserRole.client),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Account Session',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign out of your studio account on this browser.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const ValueKey('settings_logout_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () async {
                    final sm = ScaffoldMessenger.of(context);
                    await repo.logoutUser();
                    if (mounted) {
                      sm.showSnackBar(
                        const SnackBar(
                          content: Text('You have been logged out.'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Default: SHOP_MODE ("Working with a Team?" toggle + Admin PIN settings)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withAlpha(100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Working with a Team?',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'When enabled, displays the Shop / Admin switch in Pane 1 so you can lock the studio into Shop mode for your team. When off, you work solo in Admin mode with no lock button.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    key: const ValueKey('working_with_team_switch'),
                    value: repo.workingWithTeam,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) async {
                      await repo.setWorkingWithTeam(val);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin 4-Digit Security PIN',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repo.hasOwnerPin ? 'PIN Secured' : 'No PIN created yet',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.lock_person_rounded, size: 15),
                    label: Text(
                      repo.hasOwnerPin ? 'Change Admin PIN' : 'Create Admin PIN',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showChangeOwnerPinDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
              if (_canEditInventory) ...[
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
                    LocalStorageService.saveStudioHubSection(StudioHubSection.services.name);
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
                if (_canEditInventory)
                  _buildStatusDropdown(item)
                else
                  _buildStatusBadge(item),
                if (_canEditInventory) const SizedBox(width: 8),
              ],
              if (_canEditInventory) ...[
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
                      _canEditInventory ? _buildStatusDropdown(item) : _buildStatusBadge(item)
                    else
                      const SizedBox.shrink(),
                    if (_canEditInventory)
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
                      )
                    else
                      const SizedBox.shrink(),
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
                widget.repository.updateChemicalFillStatus(item.id, newStatus);
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

  Widget _buildStatusBadge(InventoryItem item) {
    if (item.category == InventoryCategory.recipe) {
      return const SizedBox.shrink();
    }

    String currentStatus = 'In Service';
    Color color = AppTheme.primary;

    if (item.category == InventoryCategory.chemicals) {
      currentStatus = const ['Full', 'Half', 'Empty'].contains(item.status) ? item.status : 'Full';
      if (currentStatus == 'Full') color = Colors.greenAccent;
      if (currentStatus == 'Half') color = Colors.orangeAccent;
      if (currentStatus == 'Empty') color = Colors.redAccent;
    } else {
      currentStatus = const ['In Service', 'Repair', 'Optimal', 'Retired'].contains(item.status) ? item.status : 'In Service';
      if (currentStatus == 'In Service') color = AppTheme.primary;
      if (currentStatus == 'Repair') color = Colors.orangeAccent;
      if (currentStatus == 'Optimal') color = Colors.greenAccent;
      if (currentStatus == 'Retired') color = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Text(
        currentStatus,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _openEditInventoryItem(InventoryItem item) {
    if (!_canEditInventory) return;
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
      onSave: (updated) {
        widget.repository.updateInventoryItem(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${updated.name}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onDelete: () {
        widget.repository.removeInventoryItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.name}" from inventory'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _confirmDeleteInventoryItem(InventoryItem item) {
    if (!_canEditInventory) return;
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${item.name}" from inventory'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TEAM MEMBER INSPECTOR ---
  Widget _buildTeamInspector(BuildContext context, {bool isMobile = false}) {
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
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('View Calendar & Shifts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  LocalStorageService.saveStudioHubSection(StudioHubSection.calendar.name);
                  setState(() {
                    _selectedHub = StudioHubSection.calendar;
                    _selectedCalendarTeamMemberId = 'founder';
                    if (isMobile) _mobileStep = 1;
                  });
                },
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
          if (!widget.repository.isViewingAsTeamMember) ...[
            const SizedBox(height: 16),
            _buildOwnerSecurityCard(context),
          ],
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
              backgroundColor: AppTheme.surfaceLight,
              backgroundImage: member.localAvatarBytes != null
                  ? MemoryImage(member.localAvatarBytes!) as ImageProvider
                  : (member.avatarUrl.trim().isNotEmpty
                      ? NetworkImage(member.avatarUrl.trim())
                      : null),
              child: (member.localAvatarBytes == null && member.avatarUrl.trim().isEmpty)
                  ? const Icon(Icons.person_rounded, size: 34, color: AppTheme.textMuted)
                  : null,
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
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: Text('View ${member.name.split(" ").first}\'s Calendar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                LocalStorageService.saveStudioHubSection(StudioHubSection.calendar.name);
                setState(() {
                  _selectedHub = StudioHubSection.calendar;
                  _selectedCalendarTeamMemberId = member.id;
                  if (isMobile) _mobileStep = 1;
                });
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: Text(widget.repository.isViewingAsTeamMember ? 'Request Shift Change' : 'Edit Shift Schedule', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showEditTeamMemberScheduleDialog(context, member),
            ),
            if (!member.isFounder && !widget.repository.isViewingAsTeamMember) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.badge_outlined, size: 14),
                label: Text(
                  'Log in as ${member.name.split(" ").first}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  widget.repository.setActiveTeamMember(member.id);
                  if (!member.isSectionAllowed(_selectedHub.name)) {
                    _selectedHub = _visibleHubSections.first;
                  }
                  setState(() {});
                },
              ),
            ],
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
        const SizedBox(height: 14),
        _buildShiftRequestsCard(context, forMemberId: member.id),
        _buildTeamMemberCredentialsCard(context, member),
        _buildTeamMemberPermissionsMatrixCard(context, member),
        _buildTeamMemberScheduleCard(context, member),
      ],
    );
  }

  Widget _buildTeamMemberCredentialsCard(BuildContext context, TeamMember member) {
    if (member.isFounder) return const SizedBox.shrink();
    final isOwner = !widget.repository.isViewingAsTeamMember;
    final canManage = isOwner || (widget.repository.activeTeamMember?.canManageTeam ?? false);
    if (!canManage) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 16, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'STAFF CREDENTIALS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canManage)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _showEditTeamMemberCredentialsDialog(context, member),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 11, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('Edit PIN / Credentials', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('4-Digit Quick PIN', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.dialpad_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            member.pin?.isNotEmpty == true ? member.pin! : 'Not set',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Staff Work Email', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              member.email?.isNotEmpty == true ? member.email! : 'None assigned',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Account & Invitation Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: member.isStaffAccountActive
                  ? Colors.green.withAlpha(20)
                  : Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: member.isStaffAccountActive
                    ? Colors.green.withAlpha(80)
                    : Colors.amber.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            member.isStaffAccountActive
                                ? Icons.check_circle_rounded
                                : Icons.mark_email_unread_rounded,
                            size: 14,
                            color: member.isStaffAccountActive ? Colors.greenAccent : Colors.amberAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              member.isStaffAccountActive
                                  ? 'Staff Account Active & Configured'
                                  : 'Staff Password Setup Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: member.isStaffAccountActive ? Colors.greenAccent : Colors.amberAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (member.isStaffAccountActive && canManage) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showStaffAcceptInviteDialog(context, member),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                          ),
                          child: const Text('Reset Password', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!member.isStaffAccountActive) ...[
                  const SizedBox(height: 6),
                  Text(
                    member.email != null && member.email!.isNotEmpty
                        ? 'An automated invitation email was dispatched to ${member.email}. Staff can use the secure link below to set their personal password.'
                        : 'Assign an email address to dispatch an automated invitation link, or set their password now directly.',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      member.getInviteLink(),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (canManage)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.key_rounded, size: 13),
                          label: const Text('Set Password Now'),
                          onPressed: () => _showStaffAcceptInviteDialog(context, member),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text('Copy Invite Link'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: member.getInviteLink()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                                  SizedBox(width: 8),
                                  Text('Invitation link copied to clipboard!'),
                                ],
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: AppTheme.surface,
                            ),
                          );
                        },
                      ),
                      if (member.email != null && member.email!.isNotEmpty && canManage)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 13),
                          label: const Text('Resend Invite'),
                          onPressed: () async {
                            await widget.repository.sendStaffInvite(member);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.send_rounded, color: AppTheme.primary, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Invitation link resent to ${member.email}!'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppTheme.surface,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStaffAcceptInviteDialog(BuildContext context, TeamMember member) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? localError;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lock_reset_rounded, size: 18, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Set Password for ${member.name.split(" ").first}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Configure a personal password for ${member.email ?? member.name} so they can log in directly on any device.',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (localError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: '••••••••',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final pass = passCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();
                          if (pass.length < 6) {
                            setDialogState(() => localError = 'Password must be at least 6 characters.');
                            return;
                          }
                          if (pass != confirm) {
                            setDialogState(() => localError = 'Passwords do not match.');
                            return;
                          }
                          final res = await widget.repository.acceptStaffInvite(
                            token: member.inviteToken ?? member.id,
                            password: pass,
                          );
                          if (res.success) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('Staff password set for ${member.name}! Account is now active.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppTheme.surface,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() => localError = res.error ?? 'Failed to set password.');
                          }
                        },
                        child: const Text('Save & Activate', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditTeamMemberCredentialsDialog(BuildContext context, TeamMember member) {
    final pinCtrl = TextEditingController(text: member.pin ?? '');
    final emailCtrl = TextEditingController(text: member.email ?? '');
    final passCtrl = TextEditingController(text: member.password ?? '');

    void generatePin() {
      final rand = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
      pinCtrl.text = rand;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Edit ${member.name.split(" ").first}\'s Credentials',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '4-Digit Quick PIN',
                      hintText: 'e.g. 1234',
                      prefixIcon: const Icon(Icons.dialpad_rounded, size: 18),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.casino_outlined, size: 18, color: AppTheme.primary),
                        tooltip: 'Generate Random PIN',
                        onPressed: () => setDialogState(generatePin),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Staff Work Email',
                      hintText: 'staff@studio.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (Optional fallback)',
                      hintText: 'Defaults to PIN if empty',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final newPin = pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : null;
                          final newEmail = emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null;
                          final newPass = passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null;
                          final token = member.inviteToken ??
                              (newEmail != null
                                  ? 'inv_${DateTime.now().millisecondsSinceEpoch}_${member.name.replaceAll(RegExp(r'\s+'), '').toLowerCase()}'
                                  : null);
                          final status = newPass != null ? 'accepted' : (newEmail != null ? 'pending' : 'none');

                          final updated = member.copyWith(
                            pin: newPin,
                            email: newEmail,
                            password: newPass,
                            inviteToken: token,
                            inviteStatus: status,
                          );
                          widget.repository.updateTeamMember(updated);
                          Navigator.of(ctx).pop();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated login credentials for ${member.name}'),
                              backgroundColor: AppTheme.surface,
                            ),
                          );
                        },
                        child: const Text('Save Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamMemberPermissionsMatrixCard(BuildContext context, TeamMember member) {
    final isOwner = !widget.repository.isViewingAsTeamMember;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.security_rounded, size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'WORKBENCH ACCESS & PERMISSIONS MATRIX',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (!isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text('Read-Only View', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOwner
                ? 'Configure which studio hubs and features ${member.name.split(" ").first} can access.'
                : 'Granted permissions configured by your shop owner for the studio workbench.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),

          // Pane 1 Sections
          const Text(
            'ALLOWED HUB SECTIONS (PANE 1):',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ('portfolio', 'Portfolio', Icons.photo_library_rounded),
              ('services', 'Services', Icons.design_services_rounded),
              ('inventory', 'Inventory', Icons.inventory_2_rounded),
              ('calendar', 'Calendar', Icons.calendar_month_rounded),
              ('teams', 'My Teams', Icons.groups_rounded),
              ('savedRecipes', 'Saved Recipes', Icons.bookmark_rounded),
            ].map((sec) {
              final isAllowed = member.isSectionAllowed(sec.$1);
              return FilterChip(
                avatar: Icon(sec.$3, size: 13, color: isAllowed ? Colors.black : AppTheme.textSecondary),
                label: Text(
                  sec.$2,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAllowed ? Colors.black : Colors.white,
                    fontWeight: isAllowed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isAllowed,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surfaceLight,
                side: BorderSide(color: isAllowed ? AppTheme.primary : AppTheme.border),
                showCheckmark: false,
                onSelected: isOwner
                    ? (selected) {
                        final current = List<String>.from(member.allowedHubSections ?? TeamMember.allHubSections);
                        if (selected) {
                          if (!current.contains(sec.$1)) current.add(sec.$1);
                        } else {
                          if (current.length > 1) {
                            current.remove(sec.$1);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('A team member must have at least one allowed hub section.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                        }
                        final updated = member.copyWith(allowedHubSections: current);
                        widget.repository.updateTeamMember(updated);
                        setState(() {});
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Granular Capabilities (Panes 2 & 3)
          const Text(
            'OPERATIONAL CAPABILITIES (PANES 2 & 3):',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

          _buildPermissionToggle(
            title: 'Edit Inventory & Chemicals',
            subtitle: 'Add, modify, delete, or change stock levels for hardware and chemicals.',
            value: member.allowsInventoryEdit,
            isOwner: isOwner,
            onChanged: (val) {
              final updated = member.copyWith(canEditInventory: val);
              widget.repository.updateTeamMember(updated);
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          _buildPermissionToggle(
            title: 'View Financials & Pricing',
            subtitle: 'View service package pricing and financial revenue rates.',
            value: member.allowsPricingView,
            isOwner: isOwner,
            onChanged: (val) {
              final updated = member.copyWith(canViewPricing: val);
              widget.repository.updateTeamMember(updated);
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          _buildPermissionToggle(
            title: 'View All Team Calendar',
            subtitle: 'View master studio schedule vs. only their assigned shifts.',
            value: member.allowsAllCalendarView,
            isOwner: isOwner,
            onChanged: (val) {
              final updated = member.copyWith(canViewAllTeamCalendar: val);
              widget.repository.updateTeamMember(updated);
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          _buildPermissionToggle(
            title: 'Manage Team Roster',
            subtitle: 'Hire, edit, or remove other team members from company.',
            value: member.allowsTeamManagement,
            isOwner: isOwner,
            onChanged: (val) {
              final updated = member.copyWith(canManageTeam: val);
              widget.repository.updateTeamMember(updated);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionToggle({
    required String title,
    required String subtitle,
    required bool value,
    required bool isOwner,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          value: value,
          activeThumbColor: AppTheme.primary,
          onChanged: isOwner ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildTeamMemberScheduleCard(BuildContext context, TeamMember member) {
    final user = widget.repository.currentUser;
    final studioPrefs = widget.repository.getCalendarPreferences(detailerId: user.id);

    final days = [
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
      (7, 'Sun'),
    ];

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('WEEKLY WORKING SHIFTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                onPressed: () => _showEditTeamMemberScheduleDialog(context, member),
                child: Text(widget.repository.isViewingAsTeamMember ? 'Request Shift' : 'Edit Shifts', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: days.map((d) {
              final weekday = d.$1;
              final dayLabel = d.$2;

              bool isWorking = true;
              if (member.customWeeklySchedule != null && member.customWeeklySchedule!.isNotEmpty) {
                final dayHours = member.customWeeklySchedule!.firstWhere(
                  (h) => h.weekday == weekday,
                  orElse: () => DayBusinessHours(weekday: weekday, isOpen: true),
                );
                isWorking = dayHours.isOpen;
              } else {
                final dayHours = studioPrefs.getHoursForWeekday(weekday);
                isWorking = dayHours.isOpen;
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isWorking ? Colors.greenAccent.withAlpha(20) : AppTheme.surfaceLight.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isWorking ? Colors.greenAccent.withAlpha(80) : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(dayLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        isWorking ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isWorking ? Colors.greenAccent : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showEditTeamMemberScheduleDialog(BuildContext context, TeamMember member) {
    final user = widget.repository.currentUser;
    final studioPrefs = widget.repository.getCalendarPreferences(detailerId: user.id);

    final isViewingAsStaff = widget.repository.isViewingAsTeamMember;
    final activeMemberId = widget.repository.activeTeamMemberId;

    if (isViewingAsStaff && member.id != activeMemberId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff members can only view or request shift changes for their own schedule.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentSchedule = member.customWeeklySchedule != null && member.customWeeklySchedule!.isNotEmpty
        ? List<DayBusinessHours>.from(member.customWeeklySchedule!)
        : List<DayBusinessHours>.from(studioPrefs.weeklySchedule);

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
            title: Row(
              children: [
                Icon(
                  isViewingAsStaff ? Icons.schedule_send_rounded : Icons.edit_calendar_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isViewingAsStaff ? 'Request Shift for ${member.name}' : 'Edit Shifts for ${member.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isViewingAsStaff
                        ? 'Select your desired weekly working days and days off. Your request will be sent to the shop owner for review:'
                        : 'Configure regular weekly working days and days off for this technician:',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ...[1, 2, 3, 4, 5, 6, 7].map((weekday) {
                    final idx = currentSchedule.indexWhere((h) => h.weekday == weekday);
                    final dayHours = idx != -1
                        ? currentSchedule[idx]
                        : DayBusinessHours(weekday: weekday, isOpen: true);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dayHours.isOpen ? Colors.greenAccent.withAlpha(80) : AppTheme.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          dense: true,
                          title: Text(dayHours.weekdayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            dayHours.isOpen ? 'Working (${dayHours.openTime} - ${dayHours.closeTime})' : 'Recurring Day Off',
                            style: TextStyle(fontSize: 11, color: dayHours.isOpen ? Colors.greenAccent : AppTheme.textMuted),
                          ),
                          value: dayHours.isOpen,
                          activeThumbColor: Colors.greenAccent,
                          onChanged: (val) {
                            setDialogState(() {
                              final updated = DayBusinessHours(
                                weekday: weekday,
                                isOpen: val,
                                openTime: dayHours.openTime,
                                closeTime: dayHours.closeTime,
                              );
                              if (idx != -1) {
                                currentSchedule[idx] = updated;
                              } else {
                                currentSchedule.add(updated);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  }),
                  if (isViewingAsStaff) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason for Shift Request (optional)',
                        hintText: 'e.g. Schedule adjustment, family event, appointment...',
                        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  if (isViewingAsStaff) {
                    final req = ShiftRequest(
                      id: 'sr_${DateTime.now().millisecondsSinceEpoch}',
                      detailerId: user.id,
                      teamMemberId: member.id,
                      teamMemberName: member.name,
                      teamMemberRole: member.roleTitle,
                      requestedSchedule: currentSchedule,
                      reason: reasonController.text.trim(),
                      createdAt: DateTime.now(),
                    );
                    await widget.repository.submitShiftRequest(req);
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Shift request submitted for ${member.name}. Awaiting shop owner approval.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  } else {
                    widget.repository.updateTeamMemberWeeklySchedule(member.id, currentSchedule);
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated weekly schedule for ${member.name}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text(
                  isViewingAsStaff ? 'Request Shift' : 'Save Shifts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShiftRequestsCard(BuildContext context, {String? forMemberId}) {
    final allPending = widget.repository.pendingShiftRequests;
    final pending = forMemberId != null
        ? allPending.where((r) => r.teamMemberId == forMemberId).toList()
        : allPending;

    if (pending.isEmpty) return const SizedBox.shrink();

    final isOwner = !widget.repository.isViewingAsTeamMember;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(120), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.amber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'INCOMING SHIFT REQUESTS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pending.length} Pending',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          ...pending.map((req) {
            final offDays = req.requestedSchedule.where((h) => !h.isOpen).map((h) => h.weekdayShort).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            req.teamMemberName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          if (req.teamMemberRole != null && req.teamMemberRole!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('(${req.teamMemberRole})', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(req.createdAt),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (req.reason.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Reason: "${req.reason}"',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amberAccent),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      const Text('Requested Days Off: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      Text(
                        offDays.isNotEmpty ? offDays.join(', ') : 'None (Full Working Week)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: offDays.isNotEmpty ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isOwner)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                            label: const Text('Approve Request', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await widget.repository.approveShiftRequest(req.id);
                              setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Approved shift change for ${req.teamMemberName}. Schedule updated.'),
                                    backgroundColor: Colors.greenAccent.shade700,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Decline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await widget.repository.rejectShiftRequest(req.id);
                              setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Declined shift request from ${req.teamMemberName}.'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.amber),
                        SizedBox(width: 4),
                        Text('Awaiting approval by shop owner.', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActiveIdentityBanner(BuildContext context) {
    final isViewingStaff = widget.repository.isViewingAsTeamMember;
    final activeMember = widget.repository.activeTeamMember;
    final isStaffSession = widget.repository.isStaffSession;

    // 1. When a staff member is logged in / viewing: show "Admin" button that opens the lock/login modal
    if (isViewingStaff && activeMember != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isStaffSession ? const Color(0xFF00E676).withAlpha(15) : Colors.amber.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isStaffSession ? const Color(0xFF00E676).withAlpha(100) : Colors.amber.withAlpha(100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStaffSession ? Icons.lock_person_rounded : Icons.badge_rounded,
                  size: 14,
                  color: isStaffSession ? const Color(0xFF00E676) : Colors.amber,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isStaffSession ? 'Staff Session: ${activeMember.name}' : 'Staff View: ${activeMember.name}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isStaffSession ? const Color(0xFF00E676) : Colors.amber,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    activeMember.roleTitle,
                    style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isStaffSession) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      widget.repository.logoutStaffMember();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent.withAlpha(120)),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                InkWell(
                  key: const ValueKey('staff_return_to_admin_btn'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    widget.repository.lockOwnerView();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 11, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          'Lock',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. When in Admin (Owner) mode: if "Working with a Team?" is OFF, hide the switch completely (working solo)
    if (!widget.repository.workingWithTeam) {
      return const SizedBox.shrink();
    }

    // 3. When "Working with a Team?" is ON: show the "Shop / Admin" switch
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withAlpha(90),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          // SHOP option -> locks immediately into the Studio Kiosk Lock Modal
          Expanded(
            child: InkWell(
              key: const ValueKey('switch_to_shop_mode_btn'),
              borderRadius: BorderRadius.circular(7),
              onTap: _lockOwnerViewOrSetupPin,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Shop',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ADMIN option -> currently active (never auto-locks)
          Expanded(
            child: Container(
              key: const ValueKey('active_admin_mode_pill'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 12, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// First-time Owner PIN setup: enter the PIN twice. No default PIN exists.
  Future<bool> _showCreateOwnerPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    bool saving = false;

    InputDecoration deco(String hint) => InputDecoration(
          counterText: '',
          hintText: hint,
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
        );

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> submit() async {
            if (saving) return;
            setDialogState(() {
              saving = true;
              errorMessage = null;
            });
            final res = await widget.repository.createOwnerPin(
              pin: pinController.text,
              confirm: confirmController.text,
            );
            if (res.ok) {
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
            } else {
              setDialogState(() {
                saving = false;
                errorMessage = res.message;
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_person_rounded, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Create Owner Master PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a private 4-digit PIN to shield your financials and owner controls from staff on shared devices.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text('Create 4-Digit PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pinController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: deco('4-digit numbers only'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Confirm PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: deco('Re-enter 4-digit PIN'),
                    onSubmitted: (_) => submit(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: saving ? null : submit,
                child: const Text('Create PIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner Master PIN created and secured.')),
      );
      setState(() {});
      return true;
    }
    return false;
  }

  Future<void> _showChangeOwnerPinDialog() async {
    if (!widget.repository.hasOwnerPin) {
      await _showCreateOwnerPinDialog();
      return;
    }
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    int selectedMinutes = widget.repository.ownerAutoLockMinutes;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_person_rounded, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text('Owner Security & Privacy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Protect your financial figures, payout accounts, and business controls when leaving devices on the shop floor.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text('Current Owner PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: currentPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Enter current PIN',
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('New 4-Digit PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '4-digit numbers only',
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Confirm New PIN', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Re-enter 4-digit PIN',
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Auto-Lock on Inactivity', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMinutes,
                    dropdownColor: AppTheme.surface,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Disabled (Manual lock only)', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 2, child: Text('2 minutes of inactivity', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 5, child: Text('5 minutes of inactivity (Recommended)', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 15, child: Text('15 minutes of inactivity', style: TextStyle(color: Colors.white, fontSize: 13))),
                      DropdownMenuItem(value: 30, child: Text('30 minutes of inactivity', style: TextStyle(color: Colors.white, fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMinutes = val);
                      }
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final cur = currentPinController.text.trim();
                  final n = newPinController.text.trim();
                  final conf = confirmPinController.text.trim();

                  if (n.isNotEmpty || conf.isNotEmpty) {
                    if (n.length != 4 || int.tryParse(n) == null) {
                      setDialogState(() => errorMessage = 'New PIN must be exactly 4 digits.');
                      return;
                    }
                    if (n != conf) {
                      setDialogState(() => errorMessage = 'New PIN and confirmation do not match.');
                      return;
                    }
                    final res = await widget.repository.changeOwnerPin(currentPin: cur, newPin: n);
                    if (!res.ok) {
                      setDialogState(() => errorMessage = res.error == 'wrong_pin'
                          ? 'Current PIN is incorrect. ${res.remaining != null ? '${res.remaining} attempts left.' : ''}'
                          : res.message);
                      return;
                    }
                  }

                  await widget.repository.setOwnerAutoLockMinutes(selectedMinutes);
                  _startAutoLockTimer();
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Owner security settings updated.')),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Save Security Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOwnerSecurityCard(BuildContext context) {
    final repo = widget.repository;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('OWNER SECURITY & SHOP PRIVACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  repo.hasOwnerPin ? 'PIN Secured' : 'No PIN Yet',
                  style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Keep your gross shop revenue, bank payout details, and owner permissions shielded from team members on shared shop workstations.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto-Lock Inactivity Timer', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      repo.ownerAutoLockMinutes > 0 ? '${repo.ownerAutoLockMinutes} minutes' : 'Disabled (Manual only)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.settings_rounded, size: 14),
                label: Text(
                  repo.hasOwnerPin ? 'Change PIN / Timer' : 'Create PIN',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showChangeOwnerPinDialog(),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.lock_rounded, size: 14),
                label: const Text('Lock View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _lockOwnerViewOrSetupPin,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerLockShield(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final isCompactPhone = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final double modalMaxWidth = isCompactPhone ? 380 : (isTablet ? 540 : 560);
    final EdgeInsets modalPadding = isCompactPhone
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
        : (isTablet
            ? const EdgeInsets.symmetric(horizontal: 28, vertical: 26)
            : const EdgeInsets.symmetric(horizontal: 32, vertical: 28));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: isCompactPhone ? 12 : 24,
            right: isCompactPhone ? 12 : 24,
            top: isCompactPhone ? 8 : 16,
            bottom: (isCompactPhone ? 8 : 16) + (viewInsets.bottom > 0 ? 4 : 0),
          ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: modalMaxWidth,
                maxHeight: (size.height - viewInsets.bottom - 24).clamp(320.0, 760.0),
              ),
              padding: modalPadding,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(isCompactPhone ? 18 : 24),
                border: Border.all(color: AppTheme.primary.withAlpha(100), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(30),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _OwnerLockShieldContent(
                repository: widget.repository,
                isCompactPhone: isCompactPhone,
                isTablet: isTablet,
                onUnlocked: () {
                  setState(() {
                    final activeMember = widget.repository.activeTeamMember;
                    if (activeMember != null && !activeMember.isSectionAllowed(_selectedHub.name)) {
                      _selectedHub = _visibleHubSections.first;
                    }
                  });
                },
              ),
            ),
          ),
        ),
      ),
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
    final selectedPkg = pkgs.where((p) => p.id == _selectedServicePackageId).firstOrNull;

    if (selectedPkg == null) {
      return _buildServiceInspectorEmptyState(isMobile: isMobile);
    }

    final pkg = selectedPkg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(pkg.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Text(_canViewPricing ? '\$${pkg.basePrice.toStringAsFixed(0)}' : '••••', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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

  Widget _buildServiceInspectorEmptyState({bool isMobile = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withAlpha(80), width: 1.5),
            ),
            child: const Icon(
              Icons.miscellaneous_services_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Select or Create a Service Package',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a service package from your studio menu on the left to inspect pricing, durations, linked recipes, and included treatments — or create a brand new service tier.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Create New Package',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _openAdd(isMobile: isMobile),
          ),
        ],
      ),
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
                          LocalStorageService.saveStudioHubSection(StudioHubSection.inventory.name);
                          LocalStorageService.saveInventoryCategoryFilter('RECIPE');
                          if (recipe.id.isNotEmpty) {
                            LocalStorageService.saveSelectedInventoryId(recipe.id);
                          }
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
    final staff = widget.repository.getStudioStaff(detailerId: user.id);
    final date = _selectedCalendarDate;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final isViewingAll = _selectedCalendarTeamMemberId == 'all';
    final currentMember = staff.firstWhere((s) => s.id == _selectedCalendarTeamMemberId, orElse: () => staff.first);

    final isRecurringOff = isViewingAll
        ? widget.repository.isDateRecurringDayOff(date, detailerId: user.id)
        : widget.repository.isMemberRecurringDayOff(_selectedCalendarTeamMemberId, date, detailerId: user.id);
    final isExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(
      user.id,
      date,
      teamMemberId: isViewingAll ? null : _selectedCalendarTeamMemberId,
    );
    final isMemberOnDuty = isViewingAll
        ? true
        : widget.repository.isMemberOnDutyOnDate(_selectedCalendarTeamMemberId, date, detailerId: user.id);

    final hours = widget.repository.getHoursForDate(date, detailerId: user.id);
    final allDayBookings = widget.repository.getBookingsForDate(date, detailerId: user.id);
    final dayBookings = isViewingAll
        ? allDayBookings
        : allDayBookings.where((b) => b.assignedTeamMemberId == _selectedCalendarTeamMemberId || staff.length <= 1).toList();
    final dayBlocks = widget.repository.getBlocksForDate(date, detailerId: user.id);
    final prefs = widget.repository.getCalendarPreferences(detailerId: user.id);

    final daySlots = widget.repository.getTimeSlotsForDate(date, detailerId: user.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShiftRequestsCard(context),
        // Team Selector Filter Bar
        _buildCalendarTeamFilterBar(keyPrefix: 'pane3'),

        // If viewing individual technician personal schedule, show banner
        if (!isViewingAll) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing Personal Schedule: ${currentMember.name} (${currentMember.roleTitle})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (_canViewAllCalendar) ...[
                  InkWell(
                    onTap: () => setState(() => _selectedCalendarTeamMemberId = 'all'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('Back to All Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Day Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
                  ? Colors.redAccent.withAlpha(100)
                  : AppTheme.border,
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
                      color: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
                          ? Colors.redAccent.withAlpha(30)
                          : (isRecurringOff ? AppTheme.surfaceLight : AppTheme.primary.withAlpha(30)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isViewingAll
                          ? (isExplicitlyBlocked
                              ? Icons.block_rounded
                              : (isRecurringOff ? Icons.nightlife_rounded : Icons.calendar_today_rounded))
                          : (isMemberOnDuty ? Icons.person_rounded : Icons.person_off_rounded),
                      color: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
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
                                color: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
                                    ? Colors.redAccent.withAlpha(30)
                                    : (isRecurringOff
                                        ? Colors.amber.withAlpha(30)
                                        : Colors.greenAccent.withAlpha(30)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isViewingAll
                                    ? (isExplicitlyBlocked
                                        ? 'DAY BLOCKED'
                                        : (isRecurringOff ? 'RECURRING DAY OFF' : 'OPEN FOR BOOKINGS'))
                                    : (isMemberOnDuty
                                        ? 'ON DUTY TODAY'
                                        : (isExplicitlyBlocked ? 'OFF TODAY (BLOCKED)' : 'WEEKLY DAY OFF')),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
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
                        backgroundColor: (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
                            ? Colors.green
                            : Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        (isViewingAll ? isExplicitlyBlocked : !isMemberOnDuty)
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isViewingAll
                            ? (isExplicitlyBlocked ? 'Unblock Full Day' : 'Block Full Day')
                            : (isMemberOnDuty
                                ? 'Give ${currentMember.name.split(" ").first} Day Off'
                                : 'Set ${currentMember.name.split(" ").first} as Working'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        if (isViewingAll) {
                          if (isExplicitlyBlocked) {
                            widget.repository.toggleBlockDay(date, detailerId: user.id);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unblocked full day: ${DateFormat("EEE, MMM d").format(date)}'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          } else if (staff.length > 1) {
                            _showBlockDayScopeDialog(context, date, user.id);
                          } else {
                            widget.repository.toggleBlockDay(date, detailerId: user.id);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Blocked full day: ${DateFormat("EEE, MMM d").format(date)}'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          widget.repository.toggleBlockDay(
                            date,
                            teamMemberId: _selectedCalendarTeamMemberId,
                            detailerId: user.id,
                          );
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated schedule for ${currentMember.name.split(" ").first} on ${DateFormat("MMM d").format(date)}'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
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

        // Staff Roster Today Card (Visible in All Team view)
        if (isViewingAll && staff.length > 1) ...[
          _buildStaffRosterTodayCard(context, date, staff, user.id),
        ],

        const SizedBox(height: 20),

        // Section 1: Turo-Style Slot Availability
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Text(
                        'HOURLY SLOT AVAILABILITY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                      ),
                      _badge(
                        isViewingAll ? 'ALL TEAM' : currentMember.name.toUpperCase(),
                        AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isViewingAll
                        ? 'Tap any window to manage studio or technician booking capacity.'
                        : 'Manage ${currentMember.name.split(" ").first}\'s hourly working availability.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                  widget.repository.clearBlockedSlotsForDate(
                    date,
                    detailerId: user.id,
                    teamMemberId: isViewingAll ? null : _selectedCalendarTeamMemberId,
                  );
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
            if (isViewingAll) {
              final status = widget.repository.getSlotStaffingStatus(date, slot, detailerId: user.id);
              final conflictingAppt = widget.repository.getConflictingBookingForSlot(date, slot, detailerId: user.id);
              final isBooked = conflictingAppt != null;
              final isExactMatch = isBooked && conflictingAppt.scheduledTimeSlot == slot;
              final isDayOff = !hours.isOpen || isRecurringOff;
              final isDayExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(user.id, date);
              final isStudioSlotBlocked = widget.repository.isSlotExplicitlyBlocked(user.id, date, slot);
              final inOperatingHours = widget.repository.isSlotWithinOperatingHours(date, slot, detailerId: user.id);
              final hasDayConflict = isBooked && (isDayOff || isDayExplicitlyBlocked);

              Color borderColor = AppTheme.border;
              Color bgColor = AppTheme.surface;
              String statusTitle = 'Available for Booking';
              Color statusColor = Colors.greenAccent;
              IconData iconData = Icons.check_circle_outline_rounded;
              bool isStruck = false;

              if (staff.length <= 1) {
                if (isBooked) {
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
                } else if (isStudioSlotBlocked) {
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
                } else {
                  borderColor = AppTheme.border;
                  bgColor = AppTheme.surface;
                  statusTitle = 'Available for Booking';
                  statusColor = Colors.greenAccent;
                  iconData = Icons.check_circle_outline_rounded;
                  isStruck = false;
                }
              } else {
                // Multi-technician studio (staff.length > 1)
                if (isDayExplicitlyBlocked) {
                  borderColor = Colors.redAccent.withAlpha(100);
                  bgColor = Colors.redAccent.withAlpha(15);
                  statusTitle = 'Day Blocked by Detailer';
                  statusColor = Colors.redAccent;
                  iconData = Icons.block_rounded;
                  isStruck = true;
                } else if (isStudioSlotBlocked) {
                  borderColor = Colors.redAccent.withAlpha(100);
                  bgColor = Colors.redAccent.withAlpha(15);
                  statusTitle = 'Blocked by Detailer';
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
                } else if (!inOperatingHours && hours.isOpen) {
                  borderColor = AppTheme.border;
                  bgColor = AppTheme.surfaceLight.withAlpha(60);
                  statusTitle = 'Outside Operating Hours';
                  statusColor = AppTheme.textMuted;
                  iconData = Icons.access_time_rounded;
                  isStruck = true;
                } else if (status.isFullyBooked) {
                  borderColor = Colors.green.withAlpha(120);
                  bgColor = Colors.green.withAlpha(20);
                  statusTitle = 'Fully Booked (${status.activeBookingsCount} of ${status.onDutyCount} Reserved)';
                  statusColor = Colors.greenAccent;
                  iconData = Icons.directions_car_rounded;
                  isStruck = false;
                } else if (status.activeBookingsCount > 0) {
                  borderColor = Colors.cyanAccent.withAlpha(120);
                  bgColor = Colors.cyanAccent.withAlpha(15);
                  statusTitle = '${status.availableCapacity} Techs Available (${status.activeBookingsCount} Booked)';
                  statusColor = Colors.cyanAccent;
                  iconData = Icons.groups_rounded;
                  isStruck = false;
                } else {
                  borderColor = AppTheme.border;
                  bgColor = AppTheme.surface;
                  statusTitle = 'Available for Booking';
                  statusColor = Colors.greenAccent;
                  iconData = Icons.check_circle_outline_rounded;
                  isStruck = false;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              if (conflictingAppt != null) ...[
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
                        if (!status.isFullyBooked && !isBooked) ...[
                          if (isDayOff && !isDayExplicitlyBlocked && !isStudioSlotBlocked) ...[
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
                                foregroundColor: (isStudioSlotBlocked || isDayExplicitlyBlocked) ? Colors.greenAccent : Colors.redAccent,
                                side: BorderSide(
                                  color: (isStudioSlotBlocked || isDayExplicitlyBlocked)
                                      ? Colors.greenAccent.withAlpha(120)
                                      : Colors.redAccent.withAlpha(100),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                if (isStudioSlotBlocked || isDayExplicitlyBlocked) {
                                  widget.repository.toggleBlockSlot(date, slot, detailerId: user.id);
                                  setState(() {});
                                } else if (staff.length > 1) {
                                  _showBlockSlotScopeDialog(context, date, slot, user.id);
                                } else {
                                  widget.repository.toggleBlockSlot(date, slot, detailerId: user.id);
                                  setState(() {});
                                }
                              },
                              child: Text(
                                (isStudioSlotBlocked || isDayExplicitlyBlocked) ? 'Reopen' : 'Block Slot',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ] else if ((status.isFullyBooked || isBooked) && conflictingAppt != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FULL',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                          ),
                        ],
                        if (staff.length > 1 && conflictingAppt != null)
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppTheme.primary),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: const EdgeInsets.all(4),
                            tooltip: 'Assign Technician',
                            onPressed: () => _showAssignTechnicianDialog(context, conflictingAppt),
                          ),
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
                      ],
                    ),
                    if (staff.length > 1) ...[
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: staff.map((m) {
                          final isOff = status.offMemberIds.contains(m.id);
                          final booking = allDayBookings.where((b) =>
                            b.assignedTeamMemberId == m.id &&
                            widget.repository.isBookingConflictingWithSlot(b, date, slot),
                          ).firstOrNull;

                          Color chipBg = Colors.greenAccent.withAlpha(20);
                          Color chipBorder = Colors.greenAccent.withAlpha(80);
                          Color chipText = Colors.greenAccent;
                          String chipLabel = '${m.name.split(' ').first}: Available';

                          if (isOff) {
                            chipBg = AppTheme.surfaceLight.withAlpha(40);
                            chipBorder = AppTheme.border;
                            chipText = AppTheme.textMuted;
                            chipLabel = '${m.name.split(' ').first}: Off';
                          } else if (booking != null) {
                            chipBg = Colors.amber.withAlpha(25);
                            chipBorder = Colors.amber.withAlpha(100);
                            chipText = Colors.amber;
                            chipLabel = '${m.name.split(' ').first}: Booked (${booking.clientName.split(' ').first})';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: chipBorder),
                            ),
                            child: Text(
                              chipLabel,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: chipText),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            } else {
              // Individual Technician View for this slot
              final isSlotBooked = widget.repository.isMemberBookedForSlot(_selectedCalendarTeamMemberId, date, slot, detailerId: user.id);
              final isSlotBlocked = widget.repository.isSlotExplicitlyBlocked(user.id, date, slot, teamMemberId: _selectedCalendarTeamMemberId);
              final isMemberOff = !isMemberOnDuty;
              final conflictingAppt = widget.repository.getConflictingBookingForSlot(
                date,
                slot,
                detailerId: user.id,
                teamMemberId: _selectedCalendarTeamMemberId,
              );
              final inOperatingHours = widget.repository.isSlotWithinOperatingHours(date, slot, detailerId: user.id);

              Color borderColor = AppTheme.border;
              Color bgColor = AppTheme.surface;
              String statusTitle = 'Available for Booking';
              Color statusColor = Colors.greenAccent;
              IconData iconData = Icons.check_circle_outline_rounded;
              bool isStruck = false;

              if (isSlotBooked) {
                borderColor = Colors.green.withAlpha(120);
                bgColor = Colors.green.withAlpha(20);
                statusTitle = conflictingAppt != null
                    ? 'Booked: ${conflictingAppt.vehicleYearMakeModel} (${conflictingAppt.clientName})'
                    : 'Booked by Client';
                statusColor = Colors.greenAccent;
                iconData = Icons.directions_car_rounded;
                isStruck = false;
              } else if (isSlotBlocked || isMemberOff) {
                borderColor = Colors.redAccent.withAlpha(100);
                bgColor = Colors.redAccent.withAlpha(15);
                statusTitle = isMemberOff ? 'Tech Off Today' : 'Slot Blocked for ${currentMember.name.split(" ").first}';
                statusColor = Colors.redAccent;
                iconData = Icons.block_rounded;
                isStruck = true;
              } else if (!inOperatingHours) {
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
                          if (conflictingAppt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${conflictingAppt.package.title} • \$${conflictingAppt.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isSlotBooked) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isSlotBlocked ? Colors.greenAccent : Colors.redAccent,
                          side: BorderSide(
                            color: isSlotBlocked
                                ? Colors.greenAccent.withAlpha(120)
                                : Colors.redAccent.withAlpha(100),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          widget.repository.toggleBlockSlot(
                            date,
                            slot,
                            teamMemberId: _selectedCalendarTeamMemberId,
                            detailerId: user.id,
                          );
                          setState(() {});
                        },
                        child: Text(
                          isSlotBlocked ? 'Reopen' : 'Block Slot',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }
          }),

        const SizedBox(height: 20),

        // Section 2: Confirmed Bookings List
        Text(
          isViewingAll ? 'CONFIRMED APPOINTMENTS (${dayBookings.length})' : '${currentMember.name.toUpperCase()}\'S APPOINTMENTS (${dayBookings.length})',
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
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 20, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isViewingAll
                        ? 'No client bookings scheduled for this date.'
                        : 'No appointments assigned to ${currentMember.name} for this date.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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

  Widget _buildStaffRosterTodayCard(BuildContext context, DateTime date, List<TeamMember> staff, String detailerId) {
    final onDutyStaff = staff.where((s) => widget.repository.isMemberOnDutyOnDate(s.id, date, detailerId: detailerId)).toList();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
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
                  Icon(Icons.groups_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'DAILY STAFF ROSTER',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white, letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: onDutyStaff.isNotEmpty ? Colors.greenAccent.withAlpha(25) : Colors.redAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${onDutyStaff.length} of ${staff.length} on duty',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: onDutyStaff.isNotEmpty ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          ...staff.map((m) {
            final isOnDuty = widget.repository.isMemberOnDutyOnDate(m.id, date, detailerId: detailerId);
            final isRecurringOff = widget.repository.isMemberRecurringDayOff(m.id, date, detailerId: detailerId);
            final isExplicitlyBlocked = widget.repository.isDateExplicitlyBlocked(detailerId, date, teamMemberId: m.id);

            String statusText = 'Working Today';
            Color statusColor = Colors.greenAccent;
            if (isExplicitlyBlocked) {
              statusText = 'Off Today (Blocked)';
              statusColor = Colors.redAccent;
            } else if (isRecurringOff) {
              statusText = 'Weekly Day Off';
              statusColor = Colors.amber;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOnDuty ? AppTheme.border : Colors.redAccent.withAlpha(60)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.surfaceLight,
                    backgroundImage: m.localAvatarBytes != null
                        ? MemoryImage(m.localAvatarBytes!) as ImageProvider
                        : (m.avatarUrl.trim().isNotEmpty ? NetworkImage(m.avatarUrl.trim()) : null),
                    child: (m.localAvatarBytes == null && m.avatarUrl.trim().isEmpty)
                        ? const Icon(Icons.person_rounded, size: 15, color: AppTheme.textMuted)
                        : null,
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
                                m.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (m.isFounder) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('FOUNDER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isOnDuty ? Colors.redAccent : Colors.greenAccent,
                      side: BorderSide(color: isOnDuty ? Colors.redAccent.withAlpha(120) : Colors.greenAccent.withAlpha(120)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      widget.repository.toggleBlockDay(date, teamMemberId: m.id, detailerId: detailerId);
                      setState(() {});
                    },
                    child: Text(
                      isOnDuty ? 'Give Day Off' : 'Set Working',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCalendarTeamMemberId = m.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showBlockDayScopeDialog(BuildContext context, DateTime date, String detailerId) {
    final staff = widget.repository.getStudioStaff(detailerId: detailerId);
    if (staff.length <= 1) {
      widget.repository.toggleBlockDay(date, detailerId: detailerId);
      return;
    }

    final dateStr = DateFormat('EEE, MMM d').format(date);
    final isStudioBlocked = widget.repository.isDateExplicitlyBlocked(detailerId, date);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
            title: Text('Manage Availability for $dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose whether to close the entire studio or give specific team members the day off:', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),

                  // Entire Studio Block Toggle
                  ListTile(
                    tileColor: AppTheme.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isStudioBlocked ? Colors.redAccent.withAlpha(120) : AppTheme.border)),
                    leading: Icon(isStudioBlocked ? Icons.lock_rounded : Icons.storefront_rounded, color: isStudioBlocked ? Colors.redAccent : AppTheme.primary),
                    title: const Text('Entire Studio (All Team)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(isStudioBlocked ? 'Studio currently closed to all bookings' : 'Close shop entirely for all technicians', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isStudioBlocked ? Colors.green : Colors.redAccent,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        widget.repository.toggleBlockDay(date, detailerId: detailerId);
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isStudioBlocked ? 'Reopened studio for all bookings on $dateStr' : 'Closed studio for all bookings on $dateStr'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(isStudioBlocked ? 'Reopen' : 'Close Studio'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('OR MANAGE INDIVIDUAL SHIFTS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 8),

                  ...staff.map((m) {
                    final isOnDuty = widget.repository.isMemberOnDutyOnDate(m.id, date, detailerId: detailerId);
                    final isMemberBlocked = widget.repository.isDateExplicitlyBlocked(detailerId, date, teamMemberId: m.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundImage: m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
                          child: m.avatarUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
                        ),
                        title: Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(isOnDuty ? 'Working (On Duty)' : (isMemberBlocked ? 'Day Off (Blocked)' : 'Weekly Day Off'), style: TextStyle(fontSize: 10.5, color: isOnDuty ? Colors.greenAccent : Colors.amber)),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isOnDuty ? Colors.redAccent : Colors.greenAccent,
                            side: BorderSide(color: isOnDuty ? Colors.redAccent.withAlpha(120) : Colors.greenAccent.withAlpha(120)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            widget.repository.toggleBlockDay(date, teamMemberId: m.id, detailerId: detailerId);
                            setDialogState(() {});
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isOnDuty ? 'Gave ${m.name.split(" ").first} the day off on $dateStr' : 'Set ${m.name.split(" ").first} as working on $dateStr'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Text(isOnDuty ? 'Give Day Off' : 'Set Working', style: const TextStyle(fontSize: 10.5)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBlockSlotScopeDialog(BuildContext context, DateTime date, String slot, String detailerId) {
    final staff = widget.repository.getStudioStaff(detailerId: detailerId);
    final isStudioSlotBlocked = widget.repository.isSlotExplicitlyBlocked(detailerId, date, slot);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
            title: Text('Manage Slot: $slot', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select whether to block this time window for the whole shop or a specific technician:', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),

                  ListTile(
                    tileColor: AppTheme.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isStudioSlotBlocked ? Colors.redAccent.withAlpha(120) : AppTheme.border)),
                    leading: Icon(isStudioSlotBlocked ? Icons.lock_rounded : Icons.storefront_rounded, color: isStudioSlotBlocked ? Colors.redAccent : AppTheme.primary),
                    title: const Text('Entire Studio (All Team)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(isStudioSlotBlocked ? 'Window currently blocked for all' : 'Block this window for all clients', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isStudioSlotBlocked ? Colors.green : Colors.redAccent,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        widget.repository.toggleBlockSlot(date, slot, detailerId: detailerId);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: Text(isStudioSlotBlocked ? 'Unblock' : 'Block Slot'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('OR BLOCK FOR INDIVIDUAL TECHNICIAN:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 8),

                  ...staff.map((m) {
                    final isMemberSlotBlocked = widget.repository.isSlotExplicitlyBlocked(detailerId, date, slot, teamMemberId: m.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundImage: m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
                          child: m.avatarUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
                        ),
                        title: Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(isMemberSlotBlocked ? 'Window Blocked' : 'Window Open', style: TextStyle(fontSize: 10.5, color: isMemberSlotBlocked ? Colors.redAccent : Colors.greenAccent)),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isMemberSlotBlocked ? Colors.greenAccent : Colors.redAccent,
                            side: BorderSide(color: isMemberSlotBlocked ? Colors.greenAccent.withAlpha(120) : Colors.redAccent.withAlpha(120)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            widget.repository.toggleBlockSlot(date, slot, teamMemberId: m.id, detailerId: detailerId);
                            setDialogState(() {});
                            setState(() {});
                          },
                          child: Text(isMemberSlotBlocked ? 'Open' : 'Block', style: const TextStyle(fontSize: 10.5)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignTechnicianDialog(BuildContext context, BookingAppointment b) {
    final user = widget.repository.currentUser;
    final staff = widget.repository.getStudioStaff(detailerId: user.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
        title: const Text('Assign Technician to Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle: ${b.vehicleYearMakeModel} (${b.package.title})', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ...staff.map((m) {
              final isAssigned = b.assignedTeamMemberId == m.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isAssigned ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isAssigned ? AppTheme.primary : AppTheme.border),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundImage: m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
                    child: m.avatarUrl.isEmpty ? const Icon(Icons.person, size: 14) : null,
                  ),
                  title: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(m.roleTitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: isAssigned
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                      : TextButton(
                          child: const Text('Assign', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                          onPressed: () {
                            widget.repository.assignBookingTechnician(b.id, m.id, m.name);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                        ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
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
    final user = widget.repository.currentUser;
    final staff = widget.repository.getStudioStaff(detailerId: user.id);

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
          if (staff.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 13, color: AppTheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b.assignedTeamMemberName != null && b.assignedTeamMemberName!.isNotEmpty
                        ? 'Assigned: ${b.assignedTeamMemberName}'
                        : 'Unassigned (General Studio Booking)',
                    style: TextStyle(
                      fontSize: 11,
                      color: b.assignedTeamMemberName != null ? AppTheme.primary : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _showAssignTechnicianDialog(context, b),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withAlpha(80)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 12, color: AppTheme.primary),
                        SizedBox(width: 3),
                        Text('Assign', style: TextStyle(fontSize: 10.5, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    if (widget.repository.isOwnerLocked && !widget.repository.isStaffSession) {
      return _buildOwnerLockShield(context);
    }

    final visibleHubs = _visibleHubSections;
    if (_selectedHub != StudioHubSection.settings && !visibleHubs.contains(_selectedHub)) {
      _selectedHub = visibleHubs.first;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetAutoLockTimer(),
      onPointerMove: (_) => _resetAutoLockTimer(),
      child: LayoutBuilder(
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
      ),
    );
  }
}

class _OwnerLockShieldContent extends StatefulWidget {
  final JobRepository repository;
  final VoidCallback onUnlocked;
  final bool isCompactPhone;
  final bool isTablet;

  const _OwnerLockShieldContent({
    required this.repository,
    required this.onUnlocked,
    this.isCompactPhone = false,
    this.isTablet = false,
  });

  @override
  State<_OwnerLockShieldContent> createState() => _OwnerLockShieldContentState();
}

class _OwnerLockShieldContentState extends State<_OwnerLockShieldContent> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  final _teamScrollController = ScrollController();
  String _selectedProfileId = 'admin'; // 'admin' or TeamMember.id
  String? _errorMessage;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _teamScrollController.dispose();
    super.dispose();
  }

  void _selectProfile(String profileId) {
    setState(() {
      _selectedProfileId = profileId;
      _errorMessage = null;
      _pinController.clear();
    });
    _focusNode.requestFocus();
  }

  Future<void> _verifyPin(String pin) async {
    if (_verifying || pin.trim().length != 4) return;
    setState(() => _verifying = true);

    if (_selectedProfileId == 'admin') {
      final res = await widget.repository.unlockOwnerModeWithPin(pin);
      if (!mounted) return;
      if (res.ok) {
        _verifying = false;
        widget.onUnlocked();
      } else {
        setState(() {
          _verifying = false;
          _errorMessage = res.message;
          _pinController.clear();
        });
        _focusNode.requestFocus();
      }
    } else {
      final ok = await widget.repository.unlockAsTeamMemberWithPinAsync(_selectedProfileId, pin);
      if (!mounted) return;
      if (ok) {
        _verifying = false;
        widget.onUnlocked();
      } else {
        setState(() {
          _verifying = false;
          _errorMessage = 'Incorrect PIN. Try again.';
          _pinController.clear();
        });
        _focusNode.requestFocus();
      }
    }
  }

  String _formatShortName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    final first = parts.first;
    final lastInitial = parts.last[0].toUpperCase();
    return '$first $lastInitial.';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.repository.currentUser;
    final studioName = user.businessName.trim().isNotEmpty
        ? user.businessName.trim()
        : user.displayName;
    final members = user.teamMembers;
    final pin = _pinController.text;
    final isAdminSelected = _selectedProfileId == 'admin';
    final selectedMember = isAdminSelected
        ? null
        : members.where((m) => m.id == _selectedProfileId).firstOrNull;

    final int crossAxisCount = widget.isCompactPhone ? 2 : 3;
    final double tileHeight = widget.isCompactPhone ? 44 : 50;
    final double gridSpacing = widget.isCompactPhone ? 8 : 10;
    // Fits 3 full rows (9 staff on iPad/Desktop, 6 on compact iPhone) without scrolling;
    // 10+ staff scrolls inside the Team container only.
    final double maxTeamGridHeight = (tileHeight * 3) + (gridSpacing * 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- PINNED HEADER: Lock Icon + Studio Business Name ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(widget.isCompactPhone ? 7 : 9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withAlpha(28),
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: widget.isCompactPhone ? 18 : 22,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                studioName,
                style: TextStyle(
                  fontSize: widget.isCompactPhone ? 17 : 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isCompactPhone ? 12 : 16),

        // --- PINNED ADMIN BUTTON (Centered) ---
        Center(
          child: InkWell(
            key: const ValueKey('lock_profile_admin'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectProfile('admin'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCompactPhone ? 22 : 28,
                vertical: widget.isCompactPhone ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isAdminSelected
                    ? AppTheme.primary.withAlpha(38)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAdminSelected ? AppTheme.primary : AppTheme.border,
                  width: isAdminSelected ? 2 : 1,
                ),
                boxShadow: isAdminSelected
                    ? [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 12)]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: widget.isCompactPhone ? 16 : 18,
                    color: isAdminSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: widget.isCompactPhone ? 13.5 : 15,
                      fontWeight: FontWeight.bold,
                      color: isAdminSelected ? AppTheme.primary : Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- TEAM SECTION (Scrolls internally only if > 9 staff) ---
        if (members.isNotEmpty) ...[
          SizedBox(height: widget.isCompactPhone ? 14 : 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Team',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxTeamGridHeight),
              child: Scrollbar(
                controller: _teamScrollController,
                thumbVisibility: members.length > (crossAxisCount * 3),
                child: GridView.builder(
                  controller: _teamScrollController,
                  shrinkWrap: true,
                  physics: members.length > (crossAxisCount * 3)
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: tileHeight,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                  ),
                  itemCount: members.length,
                  itemBuilder: (ctx, idx) {
                    final m = members[idx];
                    final isSelected = _selectedProfileId == m.id;
                    return InkWell(
                      key: ValueKey('lock_profile_${m.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _selectProfile(m.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withAlpha(35)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: widget.isCompactPhone ? 12 : 14,
                              backgroundColor: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.primary.withAlpha(30),
                              backgroundImage: m.localAvatarBytes != null
                                  ? MemoryImage(m.localAvatarBytes!) as ImageProvider
                                  : (m.avatarUrl.trim().isNotEmpty
                                      ? NetworkImage(m.avatarUrl.trim())
                                      : null),
                              child: (m.localAvatarBytes == null && m.avatarUrl.trim().isEmpty)
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: widget.isCompactPhone ? 14 : 16,
                                      color: isSelected ? Colors.black : AppTheme.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatShortName(m.name),
                                style: TextStyle(
                                  fontSize: widget.isCompactPhone ? 12 : 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? AppTheme.primary : Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],

        SizedBox(height: widget.isCompactPhone ? 16 : 22),

        // --- PINNED FOOTER: Selected Target + 4-Digit Auto-Login Input ---
        Text(
          isAdminSelected
              ? 'Enter 4-digit PIN for Admin'
              : 'Enter 4-digit PIN for ${selectedMember != null ? _formatShortName(selectedMember.name) : ''}',
          style: TextStyle(
            fontSize: widget.isCompactPhone ? 11.5 : 12.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        // PIN Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: widget.isCompactPhone ? 13 : 15,
              height: widget.isCompactPhone ? 13 : 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppTheme.primary : AppTheme.surfaceLight,
                border: Border.all(
                  color: isFilled ? AppTheme.primary : AppTheme.border,
                  width: 1.5,
                ),
                boxShadow: isFilled
                    ? [BoxShadow(color: AppTheme.primary.withAlpha(120), blurRadius: 8)]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // 4-Digit Input Box (Auto-verifies & logs in immediately on 4th digit)
        SizedBox(
          width: widget.isCompactPhone ? 190 : 220,
          child: TextField(
            controller: _pinController,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.isCompactPhone ? 20 : 22,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: const TextStyle(fontSize: 18, letterSpacing: 8, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              contentPadding: EdgeInsets.symmetric(
                vertical: widget.isCompactPhone ? 8 : 10,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _errorMessage = null;
              });
              if (val.length == 4) {
                _verifyPin(val);
              }
            },
            onSubmitted: (val) => _verifyPin(val),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
