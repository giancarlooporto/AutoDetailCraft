import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/supabase_service.dart';

class EditProfileDialog extends StatefulWidget {
  final JobRepository repository;

  const EditProfileDialog({super.key, required this.repository});

  static Future<void> show(BuildContext context, {required JobRepository repository}) {
    return showDialog(
      context: context,
      builder: (ctx) => EditProfileDialog(repository: repository),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _businessCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _instagramCtrl;

  late String _avatarUrl;
  Uint8List? _avatarBytes;
  late String _coverUrl;
  Uint8List? _coverBytes;

  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    final user = widget.repository.currentUser;
    _nameCtrl = TextEditingController(text: user.displayName);
    _businessCtrl = TextEditingController(text: user.businessName);
    _locationCtrl = TextEditingController(text: user.location);
    _bioCtrl = TextEditingController(text: user.bio);
    _phoneCtrl = TextEditingController(text: user.phone);
    _instagramCtrl = TextEditingController(text: user.instagramHandle);
    _avatarUrl = user.avatarUrl;
    _avatarBytes = user.localAvatarBytes;
    _coverUrl = user.coverUrl;
    _coverBytes = user.localCoverBytes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewAvatar() async {
    try {
      final result = await pickImageFromDevice();
      if (result.bytes != null && result.bytes!.isNotEmpty) {
        setState(() {
          _avatarBytes = result.bytes;
          _isUploadingAvatar = true;
        });

        final cloudUrl = await SupabaseService.uploadVehiclePhoto(
          userId: widget.repository.currentUser.id,
          bytes: result.bytes!,
          customFileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (!mounted) return;
        setState(() {
          _isUploadingAvatar = false;
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            _avatarUrl = cloudUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Profile photo updated!'),
              ],
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickNewCover() async {
    try {
      final result = await pickImageFromDevice();
      if (result.bytes != null && result.bytes!.isNotEmpty) {
        setState(() {
          _coverBytes = result.bytes;
          _isUploadingCover = true;
        });

        final cloudUrl = await SupabaseService.uploadVehiclePhoto(
          userId: widget.repository.currentUser.id,
          bytes: result.bytes!,
          customFileName: 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (!mounted) return;
        setState(() {
          _isUploadingCover = false;
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            _coverUrl = cloudUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover banner photo updated!'),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  void _save() {
    final updated = widget.repository.currentUser.copyWith(
      displayName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      businessName: _businessCtrl.text.trim().isNotEmpty ? _businessCtrl.text.trim() : null,
      location: _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : null,
      bio: _bioCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      instagramHandle: _instagramCtrl.text.trim(),
      avatarUrl: _avatarUrl,
      localAvatarBytes: _avatarBytes,
      coverUrl: _coverUrl,
      localCoverBytes: _coverBytes,
    );

    widget.repository.updateCurrentUser(updated);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Profile & Location saved! You are now discoverable on Explore.'),
          ],
        ),
        backgroundColor: AppTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDetailer = widget.repository.currentUser.role == UserRole.detailer;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
          SizedBox(width: 10),
          Text('Edit Profile & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Photos section (Avatar & Cover)
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
                        radius: 42,
                        backgroundImage: _avatarBytes != null
                            ? MemoryImage(_avatarBytes!) as ImageProvider
                            : NetworkImage(_avatarUrl),
                      ),
                    ),
                    InkWell(
                      onTap: _isUploadingAvatar ? null : _pickNewAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingAvatar
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
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickNewAvatar,
                  icon: const Icon(Icons.upload_file_rounded, size: 14, color: AppTheme.primary),
                  label: const Text('Change Photo (Upload from device)', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // Full Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Location / City & State
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'City & State / Location',
                  hintText: 'e.g. Austin, Texas or Los Angeles, CA',
                  helperText: 'Enables users to search and discover you in this location',
                  helperStyle: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Business Name (Detailer Mode)
              if (isDetailer) ...[
                TextField(
                  controller: _businessCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detailing Business / Studio Name',
                    prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Phone Number
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Instagram Handle
              TextField(
                controller: _instagramCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram Handle',
                  hintText: '@handle',
                  prefixIcon: Icon(Icons.camera_alt_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Bio
              TextField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'About / Bio',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Cover Banner changer
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 38),
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Change Studio Cover Banner Photo', style: TextStyle(fontSize: 12)),
                onPressed: _isUploadingCover ? null : _pickNewCover,
              ),
            ],
          ),
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _save,
          child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
