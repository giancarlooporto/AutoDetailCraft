import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/supabase_service.dart';

class EditProfileDialog extends StatefulWidget {
  final JobRepository repository;
  final bool isStudioProfile;

  const EditProfileDialog({
    super.key,
    required this.repository,
    this.isStudioProfile = false,
  });

  static Future<void> show(
    BuildContext context, {
    required JobRepository repository,
    bool isStudioProfile = false,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => EditProfileDialog(
        repository: repository,
        isStudioProfile: isStudioProfile,
      ),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _businessCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _instagramCtrl;

  // Dedicated Address Controllers
  late TextEditingController _streetCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _zipCtrl;

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

    if (widget.isStudioProfile) {
      _streetCtrl = TextEditingController(text: user.studioStreetAddress);
      _unitCtrl = TextEditingController(text: user.studioUnitOrApt);
      _cityCtrl = TextEditingController(
        text: user.studioCity.isNotEmpty
            ? user.studioCity
            : (user.city.isNotEmpty ? user.city : (user.location.contains(',') ? user.location.split(',')[0].trim() : user.location)),
      );
      _stateCtrl = TextEditingController(
        text: user.studioState.isNotEmpty
            ? user.studioState
            : (user.state.isNotEmpty ? user.state : (user.location.contains(',') ? user.location.split(',')[1].trim() : '')),
      );
      _zipCtrl = TextEditingController(
        text: user.studioPostalCode.isNotEmpty ? user.studioPostalCode : user.postalCode,
      );
    } else {
      _streetCtrl = TextEditingController(text: user.streetAddress);
      _unitCtrl = TextEditingController(text: user.unitOrApt);
      _cityCtrl = TextEditingController(
        text: user.city.isNotEmpty ? user.city : (user.location.contains(',') ? user.location.split(',')[0].trim() : user.location),
      );
      _stateCtrl = TextEditingController(
        text: user.state.isNotEmpty ? user.state : (user.location.contains(',') ? user.location.split(',')[1].trim() : ''),
      );
      _zipCtrl = TextEditingController(text: user.postalCode);
    }

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
    _streetCtrl.dispose();
    _unitCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
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

        if (cloudUrl != null && cloudUrl.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Profile photo uploaded to Cloudflare R2!'),
                ],
              ),
              backgroundColor: AppTheme.surface,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload photo to Cloudflare R2.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.redAccent),
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

        if (cloudUrl != null && cloudUrl.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover banner uploaded to Cloudflare R2!'),
              backgroundColor: AppTheme.surface,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload cover banner to Cloudflare R2.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCover = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover upload error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _save() {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    final unit = _unitCtrl.text.trim();
    final zip = _zipCtrl.text.trim();

    // Auto-compose legacy location field for backward compatibility
    final composedCityState = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ].join(', ');

    final currentUser = widget.repository.currentUser;
    final UserProfile updated;

    if (widget.isStudioProfile) {
      updated = currentUser.copyWith(
        displayName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        businessName: _businessCtrl.text.trim().isNotEmpty ? _businessCtrl.text.trim() : null,
        studioStreetAddress: street,
        studioUnitOrApt: unit,
        studioCity: city,
        studioState: state,
        studioPostalCode: zip,
        location: composedCityState.isNotEmpty ? composedCityState : (_locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : currentUser.location),
        bio: _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        instagramHandle: _instagramCtrl.text.trim(),
        avatarUrl: _avatarUrl,
        localAvatarBytes: _avatarBytes,
        coverUrl: _coverUrl,
        localCoverBytes: _coverBytes,
      );
    } else {
      updated = currentUser.copyWith(
        displayName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        businessName: _businessCtrl.text.trim().isNotEmpty ? _businessCtrl.text.trim() : null,
        streetAddress: street,
        unitOrApt: unit,
        city: city,
        state: state,
        postalCode: zip,
        location: composedCityState.isNotEmpty ? composedCityState : (_locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : currentUser.location),
        bio: _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        instagramHandle: _instagramCtrl.text.trim(),
        avatarUrl: _avatarUrl,
        localAvatarBytes: _avatarBytes,
        coverUrl: _coverUrl,
        localCoverBytes: _coverBytes,
      );
    }

    widget.repository.updateCurrentUser(updated);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              widget.isStudioProfile
                  ? 'Studio location & profile saved!'
                  : 'Profile & home address saved!',
            ),
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
      title: Row(
        children: [
          Icon(
            widget.isStudioProfile ? Icons.storefront_outlined : Icons.edit_outlined,
            color: AppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            widget.isStudioProfile ? 'Edit Studio Profile & Location' : 'Edit Profile & Location',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
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
                        backgroundColor: AppTheme.surfaceLight,
                        backgroundImage: _avatarBytes != null
                            ? MemoryImage(_avatarBytes!) as ImageProvider
                            : (_avatarUrl.trim().isNotEmpty ? NetworkImage(_avatarUrl.trim()) : null),
                        child: (_avatarBytes == null && _avatarUrl.trim().isEmpty)
                            ? const Icon(Icons.person, size: 40, color: Colors.white54)
                            : null,
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
              TextFormField(
                key: const Key('edit_profile_name_input'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Dedicated Address Fields (100% Offline Manual Entry)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isStudioProfile ? Icons.storefront_rounded : Icons.home_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isStudioProfile ? 'Commercial Studio / Shop Address' : 'Personal Residential Address',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isStudioProfile
                          ? 'Used for customer drop-off bookings and Explore proximity sorting.'
                          : 'Used as default service location for mobile detailing bookings.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('edit_profile_street_input'),
                      controller: _streetCtrl,
                      decoration: InputDecoration(
                        labelText: widget.isStudioProfile ? 'Studio Street Address' : 'Street Address',
                        hintText: 'e.g. 1200 S Congress Ave',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('edit_profile_unit_input'),
                      controller: _unitCtrl,
                      decoration: InputDecoration(
                        labelText: widget.isStudioProfile ? 'Suite / Bay / Unit (Optional)' : 'Apt / Suite / Gate Code (Optional)',
                        hintText: widget.isStudioProfile ? 'e.g. Suite 104 or Bay B' : 'e.g. Apt 3B or Gate #1234',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            key: const Key('edit_profile_city_input'),
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              hintText: 'e.g. Austin',
                              prefixIcon: Icon(Icons.location_city_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: const Key('edit_profile_state_input'),
                            controller: _stateCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              hintText: 'TX',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: const Key('edit_profile_zip_input'),
                            controller: _zipCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Postal Code',
                              hintText: '78704',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
