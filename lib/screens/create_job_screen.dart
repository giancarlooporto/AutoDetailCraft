import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/detail_job.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/r2_storage_service.dart';
import '../widgets/split_slider_widget.dart';

class PhotoItem {
  String id;
  String url;
  Uint8List? bytes;
  bool isUploading;

  PhotoItem({
    required this.id,
    required this.url,
    this.bytes,
    this.isUploading = false,
  });
}

class CreateJobScreen extends StatefulWidget {
  final JobRepository repository;
  final VoidCallback onJobCreated;

  const CreateJobScreen({
    super.key,
    required this.repository,
    required this.onJobCreated,
  });

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController(text: '2024');
  final _paintColorCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '650');

  String _selectedService = AppConstants.serviceTypes[1]; // Ceramic Coating
  PaintHardness _hardness = PaintHardness.soft;

  final List<PhotoItem> _beforePhotos = [];
  final List<PhotoItem> _afterPhotos = [];
  int _selectedHeroIndex = 0;

  bool _isBulkUploadingBefore = false;
  bool _isBulkUploadingAfter = false;

  @override
  void initState() {
    super.initState();
    // Default initial demonstration photos
    _beforePhotos.add(PhotoItem(
      id: 'before_init_1',
      url: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
    ));
    _afterPhotos.add(PhotoItem(
      id: 'after_init_1',
      url: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
    ));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _paintColorCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  SubscriptionTier get _tier => widget.repository.currentUser.subscriptionTier;
  int get _maxPairs => _tier.maxZones;

  Future<void> _pickAndUploadBulk({required bool isBefore}) async {
    setState(() {
      if (isBefore) {
        _isBulkUploadingBefore = true;
      } else {
        _isBulkUploadingAfter = true;
      }
    });

    try {
      final pickedFiles = await pickMultipleImagesFromDevice();
      if (pickedFiles.isEmpty) return;

      final currentList = isBefore ? _beforePhotos : _afterPhotos;
      final remainingSlots = _tier == SubscriptionTier.enterprise
          ? pickedFiles.length
          : (_maxPairs - currentList.length).clamp(0, pickedFiles.length);

      if (remainingSlots <= 0) {
        _showUpgradeDialog();
        return;
      }

      final filesToUpload = pickedFiles.take(remainingSlots).toList();
      final user = widget.repository.currentUser;

      for (var i = 0; i < filesToUpload.length; i++) {
        final file = filesToUpload[i];
        final photoItem = PhotoItem(
          id: '${isBefore ? "before" : "after"}_${DateTime.now().millisecondsSinceEpoch}_$i',
          url: '',
          bytes: file.bytes,
          isUploading: true,
        );

        setState(() {
          currentList.add(photoItem);
        });

        // Background upload to R2
        _uploadPhotoItem(photoItem, file.bytes, user.id, isBefore);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('Added ${filesToUpload.length} ${isBefore ? "Before" : "After"} photo(s).'),
              ],
            ),
            backgroundColor: AppTheme.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isBefore) {
            _isBulkUploadingBefore = false;
          } else {
            _isBulkUploadingAfter = false;
          }
        });
      }
    }
  }

  Future<void> _uploadPhotoItem(PhotoItem item, Uint8List bytes, String userId, bool isBefore) async {
    try {
      final fileName = 'job_${isBefore ? "before" : "after"}_${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final cdnUrl = await R2StorageService.uploadImage(
        userId: userId,
        bytes: bytes,
        customFileName: fileName,
      );

      if (mounted) {
        setState(() {
          item.isUploading = false;
          if (cdnUrl != null && cdnUrl.isNotEmpty) {
            item.url = cdnUrl;
          } else {
            item.url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          item.isUploading = false;
          item.url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    }
  }

  void _removePhoto(int index, bool isBefore) {
    setState(() {
      if (isBefore) {
        if (index < _beforePhotos.length) _beforePhotos.removeAt(index);
      } else {
        if (index < _afterPhotos.length) _afterPhotos.removeAt(index);
      }
      if (_selectedHeroIndex >= _pairedCount && _pairedCount > 0) {
        _selectedHeroIndex = _pairedCount - 1;
      }
    });
  }

  int get _pairedCount {
    return _beforePhotos.length < _afterPhotos.length ? _beforePhotos.length : _afterPhotos.length;
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Upgrade Your Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached the ${_tier.label} tier limit of $_maxPairs photo pairs (${_maxPairs * 2} photos).',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildUpgradeTierCard(
              title: 'Pro Studio (\$29/mo)',
              desc: 'Up to 15 angles (30 photos) per transformation recipe, verified badge & priority placement.',
              onSelect: () {
                widget.repository.updateSubscriptionTier(SubscriptionTier.pro);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Pro Studio Tier! You can now post up to 15 angles.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildUpgradeTierCard(
              title: 'Enterprise / Shop (\$79/mo)',
              desc: 'Unlimited photo zones, multi-tech team management & white-label PDF audit reports.',
              onSelect: () {
                widget.repository.updateSubscriptionTier(SubscriptionTier.enterprise);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Enterprise Tier! Unlimited transformation zones enabled.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeTierCard({
    required String title,
    required String desc,
    required VoidCallback onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: onSelect,
                child: const Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _publishTransformation() {
    if (!_formKey.currentState!.validate()) return;

    if (_beforePhotos.isEmpty || _afterPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one Before and one After photo.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Check if any photo is still uploading
    final isStillUploading = _beforePhotos.any((p) => p.isUploading) || _afterPhotos.any((p) => p.isUploading);
    if (isStillUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photos are still uploading to R2 CDN. Please wait a moment...'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Construct mediaZones from paired before and after photos
    final pairs = _pairedCount;
    final List<JobMediaZone> mediaZones = [];
    final angleNames = [
      'Front Hood & Headlights',
      'Driver Side Doors',
      'Passenger Side Profile',
      'Rear Trunk & Bumper',
      'Wheels & Calipers',
      'Interior Cockpit & Leather',
      'Defect Macro / Sun Spot',
    ];

    for (var i = 0; i < pairs; i++) {
      final name = i < angleNames.length ? angleNames[i] : 'Angle ${i + 1}';
      mediaZones.add(JobMediaZone(
        id: 'zone_${DateTime.now().millisecondsSinceEpoch}_$i',
        zoneName: name,
        beforeImageUrl: _beforePhotos[i].url,
        afterImageUrl: _afterPhotos[i].url,
        defectBadge: '50/50 Transformation',
        initialMicrons: 112.0,
        finalMicrons: 109.5,
      ));
    }

    final safeHeroIndex = _selectedHeroIndex.clamp(0, pairs > 0 ? pairs - 1 : 0);
    final heroBeforeUrl = _beforePhotos[safeHeroIndex].url;
    final heroAfterUrl = _afterPhotos[safeHeroIndex].url;

    final newJob = DetailJob(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}',
      author: widget.repository.currentUser,
      createdAt: DateTime.now(),
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      vehicleYear: int.tryParse(_vehicleYearCtrl.text.trim()) ?? 2024,
      vehicleMake: _vehicleMakeCtrl.text.trim(),
      vehicleModel: _vehicleModelCtrl.text.trim(),
      paintColorName: _paintColorCtrl.text.trim(),
      paintCode: 'OEM',
      paintHardness: _hardness,
      initialPaintThicknessMicrons: 112.0,
      finalPaintThicknessMicrons: 109.5,
      defectSeverity: 7,
      serviceType: _selectedService,
      recipeStages: const [],
      mediaZones: mediaZones,
      beforeImageUrl: heroBeforeUrl,
      afterImageUrl: heroAfterUrl,
      defectBadge: '50/50 Transformation',
      durationHours: 6.0,
      quotedPrice: double.tryParse(_priceCtrl.text.trim()),
      likesCount: 0,
      isLiked: false,
      savesCount: 0,
      isSaved: false,
      comments: [],
    );

    widget.repository.addJob(newJob);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Transformation recipe published to your portfolio!'),
          ],
        ),
        backgroundColor: AppTheme.surface,
      ),
    );

    widget.onJobCreated();
    Navigator.of(context).pop();
  }

  Widget _buildPhotoThumbnail(PhotoItem photo, int index, bool isBefore) {
    ImageProvider? provider;
    if (photo.bytes != null && photo.bytes!.isNotEmpty) {
      provider = MemoryImage(photo.bytes!);
    } else if (photo.url.isNotEmpty) {
      if (photo.url.startsWith('data:image')) {
        try {
          final base64String = photo.url.split(',').last;
          provider = MemoryImage(base64Decode(base64String));
        } catch (_) {
          provider = NetworkImage(photo.url);
        }
      } else {
        provider = NetworkImage(photo.url);
      }
    }

    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isBefore ? AppTheme.hardnessSoft.withAlpha(120) : AppTheme.primary.withAlpha(120)),
            image: provider != null
                ? DecorationImage(
                    image: provider,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photo.isUploading
              ? Container(
                  color: Colors.black.withAlpha(160),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ),
                )
              : null,
        ),
        // Index badge
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${index + 1}',
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        // Remove button
        Positioned(
          right: 12,
          top: 2,
          child: InkWell(
            onTap: () => _removePhoto(index, isBefore),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadBox({
    required String title,
    required String subtitle,
    required List<PhotoItem> photos,
    required bool isBefore,
    required bool isLoading,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: photos.isNotEmpty ? accentColor.withAlpha(140) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accentColor.withAlpha(80)),
                          ),
                          child: Text(
                            '${photos.length} photo${photos.length == 1 ? "" : "s"}',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: Text(
                  isLoading ? 'Uploading...' : 'Add Photos',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: isLoading ? null : () => _pickAndUploadBulk(isBefore: isBefore),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 94,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return _buildPhotoThumbnail(photos[index], index, isBefore);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroSelectorCard() {
    final pairs = _pairedCount;
    if (pairs == 0) return const SizedBox.shrink();

    final safeIndex = _selectedHeroIndex.clamp(0, pairs - 1);
    final currentBeforeUrl = _beforePhotos[safeIndex].url;
    final currentAfterUrl = _afterPhotos[safeIndex].url;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.compare_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('Select Hero 50/50 Cover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withAlpha(80)),
                ),
                child: Text(
                  'Pair ${safeIndex + 1} of $pairs Selected',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose which photo pair will be showcased as the main 50/50 slider in Explore and your profile.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Angle pair selection chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(pairs, (index) {
                final isSelected = _selectedHeroIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 14,
                          color: isSelected ? Colors.black : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text('Pair #${index + 1}'),
                      ],
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceLight,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedHeroIndex = index;
                        });
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Live Interactive 50/50 Slider Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SplitSliderWidget(
              beforeImageUrl: currentBeforeUrl,
              afterImageUrl: currentAfterUrl,
              height: 240,
              defectBadge: '50/50 Live Preview',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Post Transformation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Publish', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _publishTransformation,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tier Usage Header Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _tier == SubscriptionTier.free
                        ? Icons.cloud_queue_rounded
                        : (_tier == SubscriptionTier.pro ? Icons.star_rounded : Icons.diamond_rounded),
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_tier.label} Tier',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($_pairedCount of ${_tier == SubscriptionTier.enterprise ? "Unlimited" : _maxPairs} pairs)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tier == SubscriptionTier.free
                              ? 'Free tier: 3 pairs (6 photos max) hosted on Cloudflare R2.'
                              : (_tier == SubscriptionTier.pro
                                  ? 'Pro tier: 15 pairs (30 photos max) on Cloudflare R2.'
                                  : 'Enterprise tier: Unlimited photos & pairs on Cloudflare R2.'),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_tier != SubscriptionTier.enterprise)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: _showUpgradeDialog,
                      child: const Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Step 1: Bulk Before Photos
            _buildUploadBox(
              title: 'Before Photos',
              subtitle: 'Select inspection photos (swirls, scratches, oxidation)',
              photos: _beforePhotos,
              isBefore: true,
              isLoading: _isBulkUploadingBefore,
              accentColor: AppTheme.hardnessSoft,
              icon: Icons.history_rounded,
            ),

            const SizedBox(height: 14),

            // Step 2: Bulk After Photos
            _buildUploadBox(
              title: 'After Photos',
              subtitle: 'Select transformation results (gloss, depth, reflections)',
              photos: _afterPhotos,
              isBefore: false,
              isLoading: _isBulkUploadingAfter,
              accentColor: AppTheme.primary,
              icon: Icons.auto_awesome_rounded,
            ),

            const SizedBox(height: 14),

            // Step 3: Hero 50/50 Comparison Selector
            _buildHeroSelectorCard(),

            const SizedBox(height: 22),

            // Step 4: Vehicle & Service Info
            const Text('Vehicle & Service Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Post Headline (e.g. 2-Stage Paint Correction & 5-Yr Ceramic on BMW M4)',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _vehicleYearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _vehicleMakeCtrl,
                    decoration: const InputDecoration(labelText: 'Make (e.g. Porsche)'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _vehicleModelCtrl,
                    decoration: const InputDecoration(labelText: 'Model (e.g. 911 GT3 RS)'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _paintColorCtrl,
                    decoration: const InputDecoration(labelText: 'Paint Color (e.g. Shark Blue)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Job Price (\$) (e.g. 850)', prefixText: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedService,
                    decoration: const InputDecoration(labelText: 'Service Package Provided'),
                    items: AppConstants.serviceTypes.skip(1).map((s) {
                      return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedService = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<PaintHardness>(
                    value: _hardness,
                    decoration: const InputDecoration(labelText: 'Clearcoat Hardness'),
                    items: PaintHardness.values.map((h) {
                      return DropdownMenuItem(value: h, child: Text(h.label, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _hardness = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Job Story & Craft Details (Paint observations, pad/compound combo, customer reaction)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _publishTransformation,
              child: const Text('Publish Transformation Recipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
