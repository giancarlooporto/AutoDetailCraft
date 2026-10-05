import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
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

enum StudioHubSection {
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

  const DetailerWorkbenchView({
    super.key,
    required this.repository,
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

  // Responsive state
  bool _isFocusMode = false;
  int _mobileStep = 0; // 0 = Hub (Pane 1), 1 = List (Pane 2), 2 = Inspector (Pane 3)

  @override
  void initState() {
    super.initState();
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
      _ensureSelection();
      if (isMobile) {
        _mobileStep = 1;
      }
    });
  }

  bool _hasActiveItemToInspect() {
    final user = widget.repository.currentUser;
    switch (_selectedHub) {
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
      case StudioHubSection.inventory:
        InventoryCategory cat = InventoryCategory.hardware;
        if (_inventoryCategoryFilter == 'CHEMICALS') cat = InventoryCategory.chemicals;
        if (_inventoryCategoryFilter == 'RECIPE') cat = InventoryCategory.recipe;
        InventoryItemEditorDialog.show(
          context,
          initialCategory: cat,
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
      case StudioHubSection.inventory:
        final inventory = widget.repository.inventoryItems;
        if (inventory.isEmpty) return;
        final item = inventory.firstWhere(
          (i) => i.id == _selectedInventoryId,
          orElse: () => inventory.first,
        );
        InventoryItemEditorDialog.show(
          context,
          itemToEdit: item,
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
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInventoryCategoryRow(
                    category: 'HARDWARE',
                    label: 'HARDWARE',
                    subtitle: 'Polishers, pads, lights & meters',
                    icon: Icons.handyman_rounded,
                    count: widget.repository.hardwareItems.length,
                    isSelected: _inventoryCategoryFilter == 'HARDWARE',
                  ),
                  const SizedBox(height: 6),
                  _buildInventoryCategoryRow(
                    category: 'CHEMICALS',
                    label: 'CHEMICALS',
                    subtitle: 'Compounds, coatings, prep sprays',
                    icon: Icons.science_rounded,
                    count: widget.repository.chemicalItems.length,
                    isSelected: _inventoryCategoryFilter == 'CHEMICALS',
                  ),
                  const SizedBox(height: 6),
                  _buildInventoryCategoryRow(
                    category: 'RECIPE',
                    label: 'RECIPE',
                    subtitle: 'Correction formulas & build steps',
                    icon: Icons.auto_stories_rounded,
                    count: widget.repository.recipeItems.length,
                    isSelected: _inventoryCategoryFilter == 'RECIPE',
                  ),
                ],
              ),
            ),
          ],

          // Item List Body
          Expanded(
            child: _buildPane2Content(context, isMobile: isMobile),
          ),

          // Bottom: [ + ADD ] button to add new equipment, chemical, formula, team, or service
          if (_selectedHub != StudioHubSection.savedRecipes) ...[
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _inventoryCategoryFilter = category;
              List<InventoryItem> filtered = [];
              if (category == 'HARDWARE') {
                filtered = widget.repository.hardwareItems;
              } else if (category == 'CHEMICALS') {
                filtered = widget.repository.chemicalItems;
              } else if (category == 'RECIPE') {
                filtered = widget.repository.recipeItems;
              }
              if (filtered.isNotEmpty) {
                _selectedInventoryId = filtered.first.id;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPane2Content(BuildContext context, {bool isMobile = false}) {
    switch (_selectedHub) {
      case StudioHubSection.inventory:
        return _buildInventoryList(isMobile: isMobile);
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

  // --- INVENTORY LIST ---
  Widget _buildInventoryList({bool isMobile = false}) {
    List<InventoryItem> items = widget.repository.inventoryItems;
    if (_inventoryCategoryFilter == 'HARDWARE') {
      items = items.where((i) => i.category == InventoryCategory.hardware).toList();
    } else if (_inventoryCategoryFilter == 'CHEMICALS') {
      items = items.where((i) => i.category == InventoryCategory.chemicals).toList();
    } else if (_inventoryCategoryFilter == 'RECIPE') {
      items = items.where((i) => i.category == InventoryCategory.recipe).toList();
    }

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 36, color: AppTheme.textMuted),
              SizedBox(height: 10),
              Text('No Items in This Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text('Use "[ + ADD ]" below to record new hardware, chemicals, or formula steps.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == _selectedInventoryId;

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
                  size: 16,
                  color: item.category == InventoryCategory.hardware
                      ? Colors.blueAccent
                      : item.category == InventoryCategory.chemicals
                          ? Colors.tealAccent
                          : Colors.purpleAccent,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.status,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${item.brand.isNotEmpty ? "${item.brand} • " : ""}${item.subCategory}',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.category == InventoryCategory.hardware && item.assignedPadOrChemical.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.assignedPadOrChemical,
                      style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (item.category == InventoryCategory.chemicals && item.dilutionSpecs.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.dilutionSpecs,
                      style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedInventoryId = item.id;
                  if (isMobile) _mobileStep = 2;
                });
              },
            ),
          ),
        );
      },
    );
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
                    '${_selectedHub.tag} INSPECTOR',
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

                // Top Right: [EDIT] button and Delete action
                if (_hasActiveItemToInspect() && _selectedHub != StudioHubSection.savedRecipes) ...[
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildInspectorBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorBody(BuildContext context) {
    switch (_selectedHub) {
      case StudioHubSection.inventory:
        return _buildInventoryInspector(context);
      case StudioHubSection.teams:
        return _buildTeamInspector(context);
      case StudioHubSection.portfolio:
        return _buildPortfolioInspector(context);
      case StudioHubSection.services:
        return _buildServiceInspector(context);
      case StudioHubSection.savedRecipes:
        return _buildSavedRecipesInspector(context);
    }
  }

  // --- INVENTORY INSPECTOR ---
  Widget _buildInventoryInspector(BuildContext context) {
    final items = widget.repository.inventoryItems;
    if (items.isEmpty) {
      return const Center(child: Text('No inventory items to inspect. Click "[ + ADD ]" to create.'));
    }

    final item = items.firstWhere(
      (i) => i.id == _selectedInventoryId,
      orElse: () => items.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Badges
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(80)),
              ),
              child: Icon(
                item.category == InventoryCategory.hardware
                    ? Icons.handyman_rounded
                    : item.category == InventoryCategory.chemicals
                        ? Icons.science_rounded
                        : Icons.auto_stories_rounded,
                color: AppTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.brand.isNotEmpty) ...[
                        Text(
                          item.brand,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: AppTheme.textMuted)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        item.subCategory,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(item.status, Colors.greenAccent),
                      if (item.location.isNotEmpty) _badge(item.location, Colors.blueAccent),
                      _badge(item.category.label, Colors.purpleAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 16),

        // Specs Grid
        if (item.specs.isNotEmpty) ...[
          Text(
            item.category == InventoryCategory.hardware
                ? 'TECHNICAL HARDWARE SPECIFICATIONS'
                : item.category == InventoryCategory.chemicals
                    ? 'CHEMICAL CHARACTERISTICS'
                    : 'FORMULA TARGETS & CLEAR HARDNESS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in item.specs.entries) ...[
                Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(entry.value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Hardware Specific Sections
        if (item.category == InventoryCategory.hardware) ...[
          _buildInfoSection(
            title: 'MAINTENANCE SCHEDULE & SERVICE LOG',
            content: item.maintenance.isNotEmpty ? item.maintenance : 'Standard routine inspection performed.',
            icon: Icons.build_circle_outlined,
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            title: 'ASSIGNED PAD & CHEMICAL PAIRING',
            content: item.assignedPadOrChemical.isNotEmpty ? item.assignedPadOrChemical : 'None assigned yet.',
            icon: Icons.layers_outlined,
          ),
        ],

        // Chemical Specific Sections
        if (item.category == InventoryCategory.chemicals) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'DILUTION SPECS & MIXING RATIO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.calculate_outlined, size: 15),
                      label: const Text('Open Dilution Calculator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => showDialog(context: context, builder: (_) => const DilutionDialog()),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.dilutionSpecs.isNotEmpty ? item.dilutionSpecs : 'Neat (1:0)',
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (item.cureTimeOrFlashTime != null) ...[
                  const SizedBox(height: 10),
                  Text('Working & Flash Cycle: ${item.cureTimeOrFlashTime}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          if (item.assignedPadOrChemical.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              title: 'RECOMMENDED APPLICATION PADS',
              content: item.assignedPadOrChemical,
              icon: Icons.brush_outlined,
            ),
          ],
          if (item.safetyNotes != null) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              title: 'SAFETY PPE & BAY HANDLING',
              content: item.safetyNotes!,
              icon: Icons.health_and_safety_outlined,
              color: Colors.orangeAccent,
            ),
          ],
        ],

        // Recipe Specific Sections
        if (item.category == InventoryCategory.recipe && item.recipeStages.isNotEmpty) ...[
          const Text(
            'STEP-BY-STEP PAINT CORRECTION SEQUENCE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < item.recipeStages.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primary.withAlpha(100)),
                    ),
                    child: Text(
                      'STEP ${i + 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.recipeStages[i].stageName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        if (item.recipeStages[i].chemical.isNotEmpty) ...[
                          Text('Chemical: ${item.recipeStages[i].chemical}', style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                        ],
                        if (item.recipeStages[i].machine.isNotEmpty) ...[
                          Text('Machine: ${item.recipeStages[i].machine}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                        if (item.recipeStages[i].pad.isNotEmpty) ...[
                          Text('Pad: ${item.recipeStages[i].pad}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                        if (item.recipeStages[i].technique.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Technique: ${item.recipeStages[i].technique}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                        if (item.recipeStages[i].notes != null) ...[
                          const SizedBox(height: 2),
                          Text('Wipe / Note: ${item.recipeStages[i].notes}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        if (item.notes != null) ...[
          const SizedBox(height: 16),
          _buildInfoSection(
            title: 'OPERATOR PRO TIPS & NOTES',
            content: item.notes!,
            icon: Icons.lightbulb_outline_rounded,
          ),
        ],
      ],
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
  Widget _buildServiceInspector(BuildContext context) {
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
