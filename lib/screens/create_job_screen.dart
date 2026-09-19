import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/detailing_presets.dart';
import '../models/detail_job.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/image_picker_service.dart';
import '../services/r2_storage_service.dart';
import '../widgets/split_slider_widget.dart';
import '../widgets/fullscreen_image_viewer.dart';

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
  final DetailJob? jobToEdit;

  const CreateJobScreen({
    super.key,
    required this.repository,
    required this.onJobCreated,
    this.jobToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required JobRepository repository,
    required VoidCallback onJobCreated,
    DetailJob? jobToEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateJobScreen(
        repository: repository,
        onJobCreated: onJobCreated,
        jobToEdit: jobToEdit,
      ),
    );
  }

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

  // Simplified Paint Inspection State
  int _defectSeverity = 6;
  String _defectBadge = 'Moderate Defects';
  String _paintGaugeHealthId = 'factory_healthy';
  double _initialMicrons = 122.0;
  double _finalMicrons = 119.0;
  String _gaugePanelNote = 'Hood & Driver Door Flagged';
  late final TextEditingController _initialMicronsCtrl;
  late final TextEditingController _finalMicronsCtrl;
  late final TextEditingController _gaugePanelNoteCtrl;

  // Simplified Studio Recipe Builder State
  List<RecipeStage> _recipeStages = [];
  String _selectedPresetId = 'preset_2_stage';

  final List<PhotoItem> _beforePhotos = [];
  final List<PhotoItem> _afterPhotos = [];

  // Independent single pair selection for the 50/50 hero cover
  int _selectedHeroBeforeIndex = 0;
  int _selectedHeroAfterIndex = 0;

  bool _isBulkUploadingBefore = false;
  bool _isBulkUploadingAfter = false;

  bool get _isEditing => widget.jobToEdit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.jobToEdit;
    if (edit != null) {
      _titleCtrl.text = edit.title;
      _vehicleMakeCtrl.text = edit.vehicleMake;
      _vehicleModelCtrl.text = edit.vehicleModel;
      _vehicleYearCtrl.text = edit.vehicleYear.toString();
      _paintColorCtrl.text = edit.paintColorName;
      _descriptionCtrl.text = edit.description;
      if (edit.quotedPrice != null) {
        _priceCtrl.text = edit.quotedPrice!.toStringAsFixed(0);
      }
      _selectedService = edit.serviceType;
      _hardness = edit.paintHardness;

      _defectSeverity = edit.defectSeverity;
      _defectBadge = edit.defectBadge;
      _initialMicrons = edit.initialPaintThicknessMicrons;
      _finalMicrons = edit.finalPaintThicknessMicrons;
      if (_initialMicrons < 100) {
        _paintGaugeHealthId = 'thin_clear';
      } else if (_initialMicrons > 180) {
        _paintGaugeHealthId = 'repainted';
      } else {
        _paintGaugeHealthId = 'factory_healthy';
      }

      _recipeStages = List.from(edit.recipeStages);

      // Populate before photos
      final befores = edit.allBeforePhotos;
      for (var i = 0; i < befores.length; i++) {
        _beforePhotos.add(PhotoItem(id: 'before_edit_$i', url: befores[i]));
      }
      final beforeHeroIdx = befores.indexOf(edit.beforeImageUrl);
      if (beforeHeroIdx != -1) _selectedHeroBeforeIndex = beforeHeroIdx;

      // Populate after photos
      final afters = edit.allAfterPhotos;
      for (var i = 0; i < afters.length; i++) {
        _afterPhotos.add(PhotoItem(id: 'after_edit_$i', url: afters[i]));
      }
      final afterHeroIdx = afters.indexOf(edit.afterImageUrl);
      if (afterHeroIdx != -1) _selectedHeroAfterIndex = afterHeroIdx;
    } else {
      // Default initial demonstration photos
      _beforePhotos.add(PhotoItem(
        id: 'before_init_1',
        url: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ));
      _afterPhotos.add(PhotoItem(
        id: 'after_init_1',
        url: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ));

      // Default recipe preset: 2-Stage Correction & Ceramic
      final defaultPreset = DetailingPresets.recipePresets.firstWhere(
        (p) => p.id == 'preset_2_stage',
        orElse: () => DetailingPresets.recipePresets.first,
      );
      _recipeStages = List.from(defaultPreset.stages);
    }

    _initialMicronsCtrl = TextEditingController(text: _initialMicrons.toStringAsFixed(1));
    _finalMicronsCtrl = TextEditingController(text: _finalMicrons.toStringAsFixed(1));
    _gaugePanelNoteCtrl = TextEditingController(text: _gaugePanelNote);
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
    _initialMicronsCtrl.dispose();
    _finalMicronsCtrl.dispose();
    _gaugePanelNoteCtrl.dispose();
    super.dispose();
  }

  SubscriptionTier get _tier => widget.repository.currentUser.subscriptionTier;
  int get _maxPhotosPerContainer => _tier.maxZones;

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
          : (_maxPhotosPerContainer - currentList.length).clamp(0, pickedFiles.length);

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

        // Background upload directly to R2 CDN
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
        if (index < _beforePhotos.length) {
          _beforePhotos.removeAt(index);
          if (_selectedHeroBeforeIndex >= _beforePhotos.length && _beforePhotos.isNotEmpty) {
            _selectedHeroBeforeIndex = _beforePhotos.length - 1;
          }
        }
      } else {
        if (index < _afterPhotos.length) {
          _afterPhotos.removeAt(index);
          if (_selectedHeroAfterIndex >= _afterPhotos.length && _afterPhotos.isNotEmpty) {
            _selectedHeroAfterIndex = _afterPhotos.length - 1;
          }
        }
      }
    });
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
              'You have reached the ${_tier.label} tier limit of $_maxPhotosPerContainer photos per container.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildUpgradeTierCard(
              title: 'Pro Studio (\$29/mo)',
              desc: 'Up to 15 Before & 15 After photos per transformation, verified badge & priority placement.',
              onSelect: () {
                widget.repository.updateSubscriptionTier(SubscriptionTier.pro);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Pro Studio Tier! You can now post up to 15 photos per container.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildUpgradeTierCard(
              title: 'Enterprise / Shop (\$79/mo)',
              desc: 'Unlimited photos in both containers, multi-tech team management & white-label PDF audit reports.',
              onSelect: () {
                widget.repository.updateSubscriptionTier(SubscriptionTier.enterprise);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Enterprise Tier! Unlimited transformation photos enabled.'),
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

    final safeBeforeIndex = _selectedHeroBeforeIndex.clamp(0, _beforePhotos.length - 1);
    final safeAfterIndex = _selectedHeroAfterIndex.clamp(0, _afterPhotos.length - 1);

    final heroBeforeUrl = _beforePhotos[safeBeforeIndex].url;
    final heroAfterUrl = _afterPhotos[safeAfterIndex].url;

    final allBeforeUrls = _beforePhotos.map((p) => p.url).where((u) => u.isNotEmpty).toList();
    final allAfterUrls = _afterPhotos.map((p) => p.url).where((u) => u.isNotEmpty).toList();

    // Only one single 50/50 hero zone is created
    final singleHeroZone = JobMediaZone(
      id: widget.jobToEdit != null ? widget.jobToEdit!.id : 'hero_pair_${DateTime.now().millisecondsSinceEpoch}',
      zoneName: 'Hero 50/50 Transformation',
      beforeImageUrl: heroBeforeUrl,
      afterImageUrl: heroAfterUrl,
      defectBadge: _defectBadge,
      initialMicrons: _initialMicrons,
      finalMicrons: _finalMicrons,
    );

    if (_isEditing) {
      final updated = widget.jobToEdit!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        vehicleYear: int.tryParse(_vehicleYearCtrl.text.trim()) ?? 2024,
        vehicleMake: _vehicleMakeCtrl.text.trim(),
        vehicleModel: _vehicleModelCtrl.text.trim(),
        paintColorName: _paintColorCtrl.text.trim(),
        paintHardness: _hardness,
        initialPaintThicknessMicrons: _initialMicrons,
        finalPaintThicknessMicrons: _finalMicrons,
        defectSeverity: _defectSeverity,
        defectBadge: _defectBadge,
        serviceType: _selectedService,
        recipeStages: _recipeStages,
        beforeImageUrl: heroBeforeUrl,
        afterImageUrl: heroAfterUrl,
        beforePhotos: allBeforeUrls,
        afterPhotos: allAfterUrls,
        mediaZones: [singleHeroZone],
        quotedPrice: double.tryParse(_priceCtrl.text.trim()),
      );
      widget.repository.updateJob(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Transformation updated successfully!'),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    } else {
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
        initialPaintThicknessMicrons: _initialMicrons,
        finalPaintThicknessMicrons: _finalMicrons,
        defectSeverity: _defectSeverity,
        serviceType: _selectedService,
        recipeStages: _recipeStages,
        beforeImageUrl: heroBeforeUrl,
        afterImageUrl: heroAfterUrl,
        defectBadge: _defectBadge,
        beforePhotos: allBeforeUrls,
        afterPhotos: allAfterUrls,
        mediaZones: [singleHeroZone],
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
              Text('Transformation recipe published to Explore & Portfolio!'),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    }

    widget.onJobCreated();
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    if (widget.jobToEdit == null) return;
    final job = widget.jobToEdit!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Transformation?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${job.title}"? This will permanently remove this transformation from your portfolio and Explore.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              widget.repository.deleteJob(job.id);
              widget.onJobCreated();
              Navigator.of(context).pop(); // Close create/edit screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transformation permanently removed.'),
                  backgroundColor: AppTheme.surface,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(PhotoItem photo, int index, bool isBefore) {
    final isSelectedAsHero = isBefore
        ? _selectedHeroBeforeIndex == index
        : _selectedHeroAfterIndex == index;

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

    final accentColor = isBefore ? AppTheme.hardnessSoft : AppTheme.primary;

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isBefore) {
                _selectedHeroBeforeIndex = index;
              } else {
                _selectedHeroAfterIndex = index;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            height: 90,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelectedAsHero ? accentColor : AppTheme.border,
                width: isSelectedAsHero ? 2.5 : 1.0,
              ),
              boxShadow: isSelectedAsHero
                  ? [
                      BoxShadow(
                        color: accentColor.withAlpha(80),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
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
        ),
        // Selected Hero Badge or Index
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isSelectedAsHero ? accentColor : Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isSelectedAsHero ? '★ HERO' : '#${index + 1}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelectedAsHero ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
        // Inspect Fullscreen Lightbox Button
        if (photo.url.isNotEmpty)
          Positioned(
            left: 4,
            top: 2,
            child: InkWell(
              onTap: () {
                final allUrls = (isBefore ? _beforePhotos : _afterPhotos)
                    .map((p) => p.url)
                    .where((u) => u.isNotEmpty)
                    .toList();
                final curIdx = allUrls.indexOf(photo.url);
                FullscreenImageViewer.open(
                  context,
                  images: allUrls,
                  initialIndex: curIdx >= 0 ? curIdx : 0,
                  title: isBefore ? 'Before Photo Inspection' : 'After Photo Inspection',
                );
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fullscreen_rounded, size: 13, color: Colors.white),
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
    if (_beforePhotos.isEmpty || _afterPhotos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upload at least one Before photo and one After photo above to select your single 50/50 hero pair.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final safeBeforeIdx = _selectedHeroBeforeIndex.clamp(0, _beforePhotos.length - 1);
    final safeAfterIdx = _selectedHeroAfterIndex.clamp(0, _afterPhotos.length - 1);

    final currentBeforeUrl = _beforePhotos[safeBeforeIdx].url;
    final currentAfterUrl = _afterPhotos[safeAfterIdx].url;

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
                  const Text('Selected 50/50 Hero Pair', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  'Before #${safeBeforeIdx + 1} ↔ After #${safeAfterIdx + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Only this single pair will be showcased as the interactive 50/50 slider in Explore. Tap thumbnails above to change your hero pair.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Side-by-side Selection Chips for quick switching
          Row(
            children: [
              // Before Photo Selector Dropdown / Chips
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.hardnessSoft.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppTheme.hardnessSoft, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Before Photo #${safeBeforeIdx + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // After Photo Selector Dropdown / Chips
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After Photo #${safeAfterIdx + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Interactive 50/50 Slider Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SplitSliderWidget(
              beforeImageUrl: currentBeforeUrl,
              afterImageUrl: currentAfterUrl,
              height: 240,
              defectBadge: _defectBadge.isNotEmpty ? _defectBadge : '50/50 Cover Preview',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefectSeveritySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.hardnessSoft.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lens_blur_rounded, color: AppTheme.hardnessSoft, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Paint Defect Severity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.hardnessSoft.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.hardnessSoft.withAlpha(80)),
                ),
                child: Text(
                  'Severity $_defectSeverity/10 • $_defectBadge',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.hardnessSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '1-Tap Defect Assessment: Quickly select initial paint condition for prospective clients and pro peers.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isNarrow ? 1 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: isNarrow ? 76 : 82,
                ),
                itemCount: DetailingPresets.defectSeverities.length,
                itemBuilder: (context, index) {
                  final opt = DetailingPresets.defectSeverities[index];
                  final isSelected = _defectSeverity == opt.severity;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _defectSeverity = opt.severity;
                        _defectBadge = opt.label;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.hardnessSoft.withAlpha(25) : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.hardnessSoft : AppTheme.border,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.hardnessSoft : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${opt.severity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: isSelected ? AppTheme.hardnessSoft : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt.description,
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.hardnessSoft, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaintGaugeHealthSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.straighten_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Paint Gauge & Clear Coat Health',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withAlpha(80)),
                ),
                child: Text(
                  '${_initialMicrons.toStringAsFixed(0)}µm → ${_finalMicrons.toStringAsFixed(0)}µm (-${(_initialMicrons - _finalMicrons).clamp(0.0, 99.0).toStringAsFixed(1)}µm)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '1-Tap Thickness Preset: Select overall clear coat health or customize initial / post-correction microns.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // 3 Preset Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isNarrow ? 1 : 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: isNarrow ? 80 : 96,
                ),
                itemCount: DetailingPresets.paintGaugePresets.length,
                itemBuilder: (context, index) {
                  final opt = DetailingPresets.paintGaugePresets[index];
                  final isSelected = _paintGaugeHealthId == opt.id;
                  final badgeColor = Color(int.parse(opt.badgeColorHex));

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _paintGaugeHealthId = opt.id;
                        _initialMicrons = opt.defaultInitialMicrons;
                        _finalMicrons = opt.defaultFinalMicrons;
                        _initialMicronsCtrl.text = _initialMicrons.toStringAsFixed(1);
                        _finalMicronsCtrl.text = _finalMicrons.toStringAsFixed(1);
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? badgeColor.withAlpha(25) : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? badgeColor : AppTheme.border,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? badgeColor : Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  opt.rangeLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            opt.status,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 13, color: isSelected ? badgeColor : AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${opt.defaultInitialMicrons.toStringAsFixed(0)}µm → ${opt.defaultFinalMicrons.toStringAsFixed(0)}µm',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? badgeColor : AppTheme.textSecondary,
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
            },
          ),

          const SizedBox(height: 12),

          // Custom Micron Adjuster & Optional Panel Tagging
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _initialMicronsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Initial Microns (µm)',
                    prefixIcon: Icon(Icons.straighten, size: 16),
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null) setState(() => _initialMicrons = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _finalMicronsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Post-Polish (µm)',
                    prefixIcon: Icon(Icons.check_rounded, size: 16),
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null) setState(() => _finalMicrons = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _gaugePanelNoteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flagged Panels / Zone',
                    prefixIcon: Icon(Icons.flag_outlined, size: 16),
                  ),
                  onChanged: (v) => _gaugePanelNote = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeBuilderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.science_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Studio Detailing Recipe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _recipeStages.add(RecipeStage(
                      stageName: '${_recipeStages.length + 1}. Polishing Stage',
                      chemical: 'Koch Chemie Micro Cut M3.02',
                      machine: 'Rupes LHR15 Mark III (15mm)',
                      pad: 'Rupes Yellow Fine Foam Pad',
                      technique: '3 passes @ speed 3.5',
                    ));
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '1-Tap Studio Presets: Auto-populate your machine, pad, chemical, and technique steps or customize with quick-chips.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // 1-Tap Preset Selector Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DetailingPresets.recipePresets.map((preset) {
                final isSelected = _selectedPresetId == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
                          size: 14,
                          color: isSelected ? Colors.black : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(preset.name),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceLight,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPresetId = preset.id;
                          _recipeStages = List.from(preset.stages);
                          _selectedService = preset.serviceType;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Quick-Select Chip Bubbles Header
          const Text(
            'Tap chips to auto-append into active stage:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Chips Carousel / Wrap
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...DetailingPresets.toolOptions.take(4).map((tool) => _buildAppendChip(tool, Icons.build_rounded, (t) {
                if (_recipeStages.isNotEmpty) {
                  final last = _recipeStages.removeLast();
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: last.stageName,
                    machine: t,
                    pad: last.pad,
                    chemical: last.chemical,
                    technique: last.technique,
                    dilution: last.dilution,
                    notes: last.notes,
                  )));
                } else {
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: '1. Machine Polishing',
                    machine: t,
                    chemical: 'Compound / Polish',
                  )));
                }
              })),
              ...DetailingPresets.padOptions.take(4).map((pad) => _buildAppendChip(pad, Icons.lens_outlined, (p) {
                if (_recipeStages.isNotEmpty) {
                  final last = _recipeStages.removeLast();
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: last.stageName,
                    machine: last.machine,
                    pad: p,
                    chemical: last.chemical,
                    technique: last.technique,
                    dilution: last.dilution,
                    notes: last.notes,
                  )));
                } else {
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: '1. Machine Polishing',
                    pad: p,
                    chemical: 'Compound / Polish',
                  )));
                }
              })),
              ...DetailingPresets.compoundOptions.take(4).map((comp) => _buildAppendChip(comp, Icons.science_rounded, (c) {
                if (_recipeStages.isNotEmpty) {
                  final last = _recipeStages.removeLast();
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: last.stageName,
                    machine: last.machine,
                    pad: last.pad,
                    chemical: c,
                    technique: last.technique,
                    dilution: last.dilution,
                    notes: last.notes,
                  )));
                } else {
                  setState(() => _recipeStages.add(RecipeStage(
                    stageName: '1. Correction Stage',
                    chemical: c,
                  )));
                }
              })),
              ...DetailingPresets.protectionOptions.take(3).map((prot) => _buildAppendChip(prot, Icons.shield_outlined, (p) {
                setState(() => _recipeStages.add(RecipeStage(
                  stageName: '${_recipeStages.length + 1}. Ceramic Protection',
                  chemical: p,
                  technique: 'Cross-hatch application, 2-minute flash time, level with edgeless microfiber',
                  notes: 'Allow 12-hour dry cure before exposure to moisture',
                )));
              })),
            ],
          ),

          const SizedBox(height: 16),

          // Render Active Stages
          if (_recipeStages.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No stages added. Tap a preset above to load a proven recipe.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipeStages.length,
              itemBuilder: (context, idx) {
                final stage = _recipeStages[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border.withAlpha(120)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primary.withAlpha(30),
                        child: Text('${idx + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage.stageName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 3),
                            if (stage.machine.isNotEmpty)
                              Text('Tool: ${stage.machine}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            if (stage.pad.isNotEmpty)
                              Text('Pad: ${stage.pad}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text('Chemical: ${stage.chemical}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            if (stage.technique.isNotEmpty)
                              Text('Technique: ${stage.technique}',
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                            if (stage.notes != null && stage.notes!.isNotEmpty)
                              Text('Note: ${stage.notes}',
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _recipeStages.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAppendChip(String label, IconData icon, Function(String) onAppend) {
    return ActionChip(
      avatar: Icon(icon, size: 12, color: AppTheme.primary),
      label: Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white)),
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => onAppend(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUploaded = _beforePhotos.length + _afterPhotos.length;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 880),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                        child: Icon(
                          _isEditing ? Icons.edit_note_rounded : Icons.add_photo_alternate_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isEditing ? 'Edit Transformation' : 'Post Transformation Recipe',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

              // Scrollable Form Content
              Expanded(
                child: ListView(
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
                              '($totalUploaded photos loaded)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tier == SubscriptionTier.free
                              ? 'Free tier: up to 3 Before & 3 After photos. Hosted on Cloudflare R2.'
                              : (_tier == SubscriptionTier.pro
                                  ? 'Pro tier: up to 15 Before & 15 After photos on Cloudflare R2.'
                                  : 'Enterprise tier: Unlimited inspection photos on Cloudflare R2.'),
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

            // Step 1: Bulk Before Photos Container
            _buildUploadBox(
              title: 'Before Photos Container',
              subtitle: 'Inspection photos showing swirls, scratches, oxidation',
              photos: _beforePhotos,
              isBefore: true,
              isLoading: _isBulkUploadingBefore,
              accentColor: AppTheme.hardnessSoft,
              icon: Icons.history_rounded,
            ),

            const SizedBox(height: 14),

            // Step 2: Bulk After Photos Container
            _buildUploadBox(
              title: 'After Photos Container',
              subtitle: 'Transformation photos showing gloss, clarity, reflection',
              photos: _afterPhotos,
              isBefore: false,
              isLoading: _isBulkUploadingAfter,
              accentColor: AppTheme.primary,
              icon: Icons.auto_awesome_rounded,
            ),

            const SizedBox(height: 14),

            // Step 3: Single Hero 50/50 Cover Selector
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
                    initialValue: _selectedService,
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
                    initialValue: _hardness,
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
            const SizedBox(height: 18),

            // Step 5: Simplified Paint Defect Severity (1-Tap)
            _buildDefectSeveritySection(),
            const SizedBox(height: 14),

            // Step 6: Simplified Paint Gauge & Clear Coat Health (1-Tap)
            _buildPaintGaugeHealthSection(),
            const SizedBox(height: 14),

            // Step 7: Simplified Studio Detailing Recipe Builder (1-Tap Presets + Chips)
            _buildRecipeBuilderSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

              // Bottom Action Bar (Universal UX)
              Row(
                children: [
                  if (_isEditing)
                    TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
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
                    onPressed: _publishTransformation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Publish Recipe',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
