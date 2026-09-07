import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/team_member.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/supabase_service.dart';

class AddTeamMemberDialog extends StatefulWidget {
  final JobRepository repository;

  const AddTeamMemberDialog({super.key, required this.repository});

  static Future<void> show(BuildContext context, {required JobRepository repository}) {
    return showDialog(
      context: context,
      builder: (ctx) => AddTeamMemberDialog(repository: repository),
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

  Uint8List? _uploadedAvatarBytes;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _avatarUrlCtrl.dispose();
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
        const SnackBar(content: Text('Please enter full name'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final newMember = TeamMember(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      roleTitle: role.isNotEmpty ? role : 'Detail Specialist',
      avatarUrl: url,
      localAvatarBytes: _uploadedAvatarBytes,
      completedJobsCount: 0,
      rating: 5.0,
      isFounder: false,
    );

    widget.repository.addTeamMember(newMember);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('$name added to your company roster!'),
          ],
        ),
        backgroundColor: AppTheme.surface,
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
                Row(
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
                    const Text(
                      'Add Hired Staff Member',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                  ],
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
                            : NetworkImage(_avatarUrlCtrl.text),
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
              const SizedBox(height: 12),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 16),

        // Bottom Action Bar (Universal UX)
        Row(
          children: [
            const Spacer(),
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
            const SizedBox(width: 10),
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
}
