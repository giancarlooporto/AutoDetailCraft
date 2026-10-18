import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/team_member.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/supabase_service.dart';

class AddTeamMemberDialog extends StatefulWidget {
  final JobRepository repository;
  final void Function(TeamMember member)? onMemberAdded;

  const AddTeamMemberDialog({
    super.key,
    required this.repository,
    this.onMemberAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required JobRepository repository,
    void Function(TeamMember member)? onMemberAdded,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AddTeamMemberDialog(
        repository: repository,
        onMemberAdded: onMemberAdded,
      ),
    );
  }

  @override
  State<AddTeamMemberDialog> createState() => _AddTeamMemberDialogState();
}

class _AddTeamMemberDialogState extends State<AddTeamMemberDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController(text: 'Lead Paint Correction Specialist');
  final TextEditingController _avatarUrlCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
  );
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  Uint8List? _uploadedAvatarBytes;
  bool _isUploadingPhoto = false;

  // Permissions State
  final Set<String> _allowedSections = Set<String>.from(TeamMember.defaultStaffHubSections);
  bool _canEditInventory = true;
  bool _canViewPricing = true;
  bool _canManageTeam = false;
  bool _canViewAllTeamCalendar = true;

  @override
  void initState() {
    super.initState();
    _generateRandomPin();
  }

  void _generateRandomPin() {
    final rand = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    _pinCtrl.text = rand;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _avatarUrlCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotoFromDevice() async {
    try {
      final result = await pickImageFromDevice();
      if (result.bytes != null && result.bytes!.isNotEmpty) {
        setState(() {
          _uploadedAvatarBytes = result.bytes;
          _isUploadingPhoto = true;
        });

        final cloudUrl = await SupabaseService.uploadVehiclePhoto(
          userId: widget.repository.currentUser.id,
          bytes: result.bytes!,
          customFileName: 'team_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (!mounted) return;
        setState(() {
          _isUploadingPhoto = false;
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            _avatarUrlCtrl.text = cloudUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Staff photo uploaded from device!'),
              ],
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final role = _roleCtrl.text.trim();
    final url = _avatarUrlCtrl.text.trim().isNotEmpty
        ? _avatarUrlCtrl.text.trim()
        : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80';

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.border),
          ),
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Please enter staff member full name.'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final emailText = _emailCtrl.text.trim();
    final hasEmail = emailText.isNotEmpty;
    final passText = _passwordCtrl.text.trim();
    final inviteToken = hasEmail
        ? 'inv_${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'\s+'), '').toLowerCase()}'
        : null;
    final inviteStatus = hasEmail ? (passText.isNotEmpty ? 'accepted' : 'pending') : 'none';
    final inviteSentAt = hasEmail ? DateTime.now() : null;

    final newMember = TeamMember(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      roleTitle: role.isNotEmpty ? role : 'Detail Specialist',
      avatarUrl: url,
      localAvatarBytes: _uploadedAvatarBytes,
      completedJobsCount: 0,
      rating: 5.0,
      isFounder: false,
      allowedHubSections: _allowedSections.toList(),
      canEditInventory: _canEditInventory,
      canViewPricing: _canViewPricing,
      canManageTeam: _canManageTeam,
      canViewAllTeamCalendar: _canViewAllTeamCalendar,
      email: hasEmail ? emailText : null,
      pin: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : null,
      password: passText.isNotEmpty ? passText : null,
      inviteToken: inviteToken,
      inviteStatus: inviteStatus,
      inviteSentAt: inviteSentAt,
    );

    final messenger = ScaffoldMessenger.of(context);
    widget.repository.addTeamMember(newMember);
    widget.onMemberAdded?.call(newMember);
    Navigator.of(context).pop();

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasEmail
                    ? 'Added $name! Invitation link dispatched to $emailText for password setup.'
                    : 'Added $name to your company roster!',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Universal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add Hired Staff Member',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: ListView(
                children: [
              // Photo Preview & Picker Section
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundImage: _uploadedAvatarBytes != null
                            ? MemoryImage(_uploadedAvatarBytes!) as ImageProvider
                            : (_avatarUrlCtrl.text.trim().isNotEmpty
                                ? NetworkImage(_avatarUrlCtrl.text.trim()) as ImageProvider
                                : const NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80')),
                      ),
                    ),
                    InkWell(
                      onTap: _isUploadingPhoto ? null : _pickPhotoFromDevice,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Button: Upload from device
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Upload Photo from Device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _isUploadingPhoto ? null : _pickPhotoFromDevice,
                ),
              ),
              const SizedBox(height: 16),

              // Staff Full Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Staff Full Name',
                  hintText: 'e.g. Carlos Rodriguez',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Role / Specialty Title
              TextField(
                controller: _roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Role / Specialty Title',
                  hintText: 'e.g. Senior Paint Correction Specialist',
                  prefixIcon: Icon(Icons.work_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 8),

              // Preset Specialty Role Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Lead Detailer',
                  'Paint Correction Specialist',
                  'Ceramic Coating Tech',
                  'Interior Specialist',
                  'Apprentice Detailer',
                ].map((rolePreset) {
                  final isSelected = _roleCtrl.text == rolePreset;
                  return ActionChip(
                    label: Text(rolePreset, style: const TextStyle(fontSize: 11)),
                    backgroundColor: isSelected ? AppTheme.primary.withAlpha(40) : AppTheme.surfaceLight,
                    side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
                    onPressed: () {
                      setState(() {
                        _roleCtrl.text = rolePreset;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Or Photo URL (Alternative)
              TextField(
                controller: _avatarUrlCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Or Photo Web URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),

              // Staff Login Credentials Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pin_rounded, size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'STAFF LOGIN CREDENTIALS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                    icon: const Icon(Icons.refresh_rounded, size: 13, color: AppTheme.primary),
                    label: const Text('Generate PIN', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                    onPressed: () => setState(_generateRandomPin),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign a 4-digit quick PIN for shop tablet access, and an optional email/password for personal devices.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),

              // 4-Digit Quick PIN Field
              TextField(
                controller: _pinCtrl,
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
                    onPressed: () => setState(_generateRandomPin),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Staff Email Address (Optional)
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Staff Work Email (For Invitation & Password Setup)',
                  hintText: 'staff@studio.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 8),

              // Prominent Email Invitation Explanation Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _emailCtrl.text.trim().isNotEmpty
                        ? AppTheme.primary
                        : AppTheme.primary.withAlpha(90),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _emailCtrl.text.trim().isNotEmpty
                          ? Icons.mark_email_read_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _emailCtrl.text.trim().isNotEmpty
                                ? 'AUTOMATIC INVITATION WILL BE DISPATCHED'
                                : 'AUTOMATIC INVITATION & PASSWORD SETUP',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _emailCtrl.text.trim().isNotEmpty
                                ? 'Adding "${_emailCtrl.text.trim()}" will automatically generate a secure password setup link and dispatch an invitation email upon clicking "Add to Company".'
                                : 'Adding a work email will automatically generate and dispatch an invitation link for this staff member to set their personal password.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Staff Password (Optional)
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password (Optional fallback)',
                  hintText: 'Defaults to PIN if empty',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),

              // Permissions Header
              const Row(
                children: [
                  Icon(Icons.security_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'WORKBENCH ACCESS & PRIVILEGES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure which sections and actions this team member can access in the Studio Workbench.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),

              // Allowed Hub Sections
              const Text(
                'Visible Hub Sections (Pane 1):',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
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
                  final isAllowed = _allowedSections.contains(sec.$1);
                  return FilterChip(
                    avatar: Icon(sec.$3, size: 14, color: isAllowed ? Colors.black : AppTheme.textSecondary),
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
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _allowedSections.add(sec.$1);
                        } else {
                          if (_allowedSections.length > 1) {
                            _allowedSections.remove(sec.$1);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Granular Capability Switches
              const Text(
                'Operational Privileges (Panes 2 & 3):',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),

              _buildSwitchTile(
                title: 'Can Edit Inventory & Stock',
                subtitle: 'Add, edit, or adjust stock levels for hardware and chemicals.',
                value: _canEditInventory,
                onChanged: (val) => setState(() => _canEditInventory = val),
              ),
              const SizedBox(height: 6),
              _buildSwitchTile(
                title: 'Can View Financial Pricing',
                subtitle: 'View service package prices & financial revenue rates.',
                value: _canViewPricing,
                onChanged: (val) => setState(() => _canViewPricing = val),
              ),
              const SizedBox(height: 6),
              _buildSwitchTile(
                title: 'Can View All Team Calendar',
                subtitle: 'View master studio calendar vs. only their assigned shifts.',
                value: _canViewAllTeamCalendar,
                onChanged: (val) => setState(() => _canViewAllTeamCalendar = val),
              ),
              const SizedBox(height: 6),
              _buildSwitchTile(
                title: 'Can Manage Team Roster',
                subtitle: 'Hire, edit, or remove other team members from company.',
                value: _canManageTeam,
                onChanged: (val) => setState(() => _canManageTeam = val),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 16),

        // Bottom Action Bar (Universal UX)
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _submit,
              child: const Text('Add to Company', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
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
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
          value: value,
          activeThumbColor: AppTheme.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

