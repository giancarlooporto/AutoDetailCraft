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

class AutomotiveAnglePreset {
  final String zoneName;
  final IconData icon;
  final String shotGuide;
  final String defaultBadge;

  const AutomotiveAnglePreset({
    required this.zoneName,
    required this.icon,
    required this.shotGuide,
    required this.defaultBadge,
  });
}

const List<AutomotiveAnglePreset> kAnglePresets = [
  AutomotiveAnglePreset(
    zoneName: 'Front / Hood & Headlights',
    icon: Icons.directions_car_rounded,
    shotGuide: '📸 Shoot 45° front corner, eye-level with hood curvature under direct light to reveal swirl defects.',
    defaultBadge: 'Swirls & Water Etchings',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Driver Side / Doors & Fender',
    icon: Icons.view_sidebar_rounded,
    shotGuide: '📸 Shoot side profile along the waistline to capture reflection clarity and scratch elimination.',
    defaultBadge: 'Heavy Micro-Marring',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Passenger Side / Doors',
    icon: Icons.view_sidebar_outlined,
    shotGuide: '📸 Stand 6 feet away at a 30° rake down the doors under sun/inspection lamp.',
    defaultBadge: 'Clear Coat Scratches',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Rear / Trunk & Bumper',
    icon: Icons.car_crash_rounded,
    shotGuide: '📸 Shoot 45° rear corner showing tailgate reflections, diffuser, and bumper gloss.',
    defaultBadge: 'Buffer Trails Removed',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Wheels, Tires & Brake Calipers',
    icon: Icons.tire_repair_rounded,
    shotGuide: '📸 Shoot 90° straight onto wheel face, barrel depth, and ceramic caliper finish.',
    defaultBadge: 'Brake Dust Etching Removed',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Interior / Cockpit & Leather',
    icon: Icons.airline_seat_recline_extra_rounded,
    shotGuide: '📸 Shoot driver bolster, steering wheel, center console, and matte OEM leather finish.',
    defaultBadge: 'Leather Restored & Matte Coated',
  ),
  AutomotiveAnglePreset(
    zoneName: 'Paint Defect Macro / Sun Spot',
    icon: Icons.lens_blur_rounded,
    shotGuide: '📸 Close-up 6-12 inches with high-intensity LED light showing true scratch depth vs corrected surface.',
    defaultBadge: 'Deep RIDS & Swirls Eliminated',
  ),
];

class ZoneDraft {
  String id;
  String zoneName;
  String shotGuide;
  String defectBadge;
  String? beforeImageUrl;
  String? afterImageUrl;
  Uint8List? beforeBytes;
  Uint8List? afterBytes;
  bool isUploadingBefore;
  bool isUploadingAfter;
  double? initialMicrons;
  double? finalMicrons;

  ZoneDraft({
    required this.id,
    required this.zoneName,
    required this.shotGuide,
    required this.defectBadge,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.beforeBytes,
    this.afterBytes,
    this.isUploadingBefore = false,
    this.isUploadingAfter = false,
    this.initialMicrons = 112.0,
    this.finalMicrons = 109.5,
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

  late List<ZoneDraft> _zones;

  @override
  void initState() {
    super.initState();
    _zones = [
      ZoneDraft(
        id: 'zone_${DateTime.now().millisecondsSinceEpoch}',
        zoneName: kAnglePresets[0].zoneName,
        shotGuide: kAnglePresets[0].shotGuide,
        defectBadge: kAnglePresets[0].defaultBadge,
        beforeImageUrl: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
        afterImageUrl: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
        initialMicrons: 112.5,
        finalMicrons: 109.8,
      ),
    ];
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
  int get _maxZones => _tier.maxZones;
  bool get _canAddZone => _zones.length < _maxZones;

  int _heroZoneIndex = 0;
  bool _isBulkUploadingBefore = false;
  bool _isBulkUploadingAfter = false;

  Future<void> _uploadSingleZonePhoto({
    required ZoneDraft zone,
    required Uint8List bytes,
    required bool isBefore,
  }) async {
    final user = widget.repository.currentUser;
    setState(() {
      if (isBefore) {
        zone.isUploadingBefore = true;
        zone.beforeBytes = bytes;
      } else {
        zone.isUploadingAfter = true;
        zone.afterBytes = bytes;
      }
    });

    try {
      final fileName = 'job_${isBefore ? "before" : "after"}_${zone.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final cdnUrl = await R2StorageService.uploadImage(
        userId: user.id,
        bytes: bytes,
        customFileName: fileName,
      );

      setState(() {
        if (isBefore) {
          if (cdnUrl != null && cdnUrl.isNotEmpty) {
            zone.beforeImageUrl = cdnUrl;
          } else {
            zone.beforeImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          }
          zone.isUploadingBefore = false;
        } else {
          if (cdnUrl != null && cdnUrl.isNotEmpty) {
            zone.afterImageUrl = cdnUrl;
          } else {
            zone.afterImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          }
          zone.isUploadingAfter = false;
        }
      });
    } catch (_) {
      setState(() {
        if (isBefore) {
          zone.isUploadingBefore = false;
          zone.beforeImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        } else {
          zone.isUploadingAfter = false;
          zone.afterImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      });
    }
  }

  Future<void> _pickBulkImages({required bool isBefore}) async {
    setState(() {
      if (isBefore) {
        _isBulkUploadingBefore = true;
      } else {
        _isBulkUploadingAfter = true;
      }
    });

    try {
      final pickedFiles = await pickMultipleImagesFromDevice();
      if (pickedFiles.isEmpty) {
        setState(() {
          if (isBefore) {
            _isBulkUploadingBefore = false;
          } else {
            _isBulkUploadingAfter = false;
          }
        });
        return;
      }

      // If selecting Before photos, expand zones if needed up to max allowed
      if (isBefore && _zones.length < pickedFiles.length) {
        final needed = pickedFiles.length - _zones.length;
        for (var i = 0; i < needed; i++) {
          if (!_canAddZone) break;
          final unusedPreset = kAnglePresets.firstWhere(
            (p) => !_zones.any((z) => z.zoneName == p.zoneName),
            orElse: () => kAnglePresets[_zones.length % kAnglePresets.length],
          );
          _zones.add(
            ZoneDraft(
              id: 'zone_${DateTime.now().millisecondsSinceEpoch}_$i',
              zoneName: unusedPreset.zoneName,
              shotGuide: unusedPreset.shotGuide,
              defectBadge: unusedPreset.defaultBadge,
              initialMicrons: 110.0,
              finalMicrons: 108.0,
            ),
          );
        }
      }

      // Map each image sequentially into zones
      final count = pickedFiles.length.clamp(0, _zones.length);
      for (var i = 0; i < count; i++) {
        final zone = _zones[i];
        final file = pickedFiles[i];
        _uploadSingleZonePhoto(zone: zone, bytes: file.bytes, isBefore: isBefore);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.photo_library_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('Loaded $count ${isBefore ? "Before" : "After"} photos across vehicle angles!'),
              ],
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } finally {
      setState(() {
        if (isBefore) {
          _isBulkUploadingBefore = false;
        } else {
          _isBulkUploadingAfter = false;
        }
      });
    }
  }

  Future<void> _pickAndUploadImage(ZoneDraft zone, bool isBefore) async {
    setState(() {
      if (isBefore) {
        zone.isUploadingBefore = true;
      } else {
        zone.isUploadingAfter = true;
      }
    });

    try {
      final picked = await pickImageFromDevice();
      if (picked.bytes == null) {
        setState(() {
          if (isBefore) {
            zone.isUploadingBefore = false;
          } else {
            zone.isUploadingAfter = false;
          }
        });
        return;
      }

      await _uploadSingleZonePhoto(
        zone: zone,
        bytes: picked.bytes!,
        isBefore: isBefore,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('${isBefore ? "Before" : "After"} photo uploaded!'),
              ],
            ),
            backgroundColor: AppTheme.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        if (isBefore) {
          zone.isUploadingBefore = false;
        } else {
          zone.isUploadingAfter = false;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _addZone() {
    if (!_canAddZone) {
      _showUpgradeDialog();
      return;
    }

    final unusedPreset = kAnglePresets.firstWhere(
      (p) => !_zones.any((z) => z.zoneName == p.zoneName),
      orElse: () => kAnglePresets[_zones.length % kAnglePresets.length],
    );

    setState(() {
      _zones.add(
        ZoneDraft(
          id: 'zone_${DateTime.now().millisecondsSinceEpoch}',
          zoneName: unusedPreset.zoneName,
          shotGuide: unusedPreset.shotGuide,
          defectBadge: unusedPreset.defaultBadge,
          initialMicrons: 110.0,
          finalMicrons: 108.0,
        ),
      );
    });
  }

  void _removeZone(int index) {
    if (_zones.length <= 1) return;
    setState(() {
      _zones.removeAt(index);
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
              'You have reached the ${_tier.label} limit of $_maxZones zone angles (${_maxZones * 2} photos).',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildUpgradeTierCard(
              title: 'Pro Studio (\$29/mo)',
              desc: 'Up to 15 angles (30 photos) per transformation recipe, verified badge & priority placement.',
              onSelect: () {
                widget.repository.updateSubscriptionTier(SubscriptionTier.pro);
                Navigator.of(ctx).pop();
                _addZone();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Pro Studio Tier! You can now post up to 15 zones (30 photos).'),
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
                _addZone();
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

    // Validate that at least the first zone has both photos
    final incompleteZone = _zones.firstWhere(
      (z) => z.beforeImageUrl == null || z.beforeImageUrl!.isEmpty || z.afterImageUrl == null || z.afterImageUrl!.isEmpty,
      orElse: () => ZoneDraft(id: '', zoneName: '', shotGuide: '', defectBadge: ''),
    );

    if (incompleteZone.id.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload both Before and After photos for "${incompleteZone.zoneName}".'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final mediaZones = _zones.map((z) => JobMediaZone(
      id: z.id,
      zoneName: z.zoneName,
      beforeImageUrl: z.beforeImageUrl ?? '',
      afterImageUrl: z.afterImageUrl ?? '',
      defectBadge: z.defectBadge,
      initialMicrons: z.initialMicrons,
      finalMicrons: z.finalMicrons,
    )).toList();

    final safeHeroIndex = _heroZoneIndex.clamp(0, mediaZones.length - 1);
    final primaryZone = mediaZones[safeHeroIndex];

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
      initialPaintThicknessMicrons: primaryZone.initialMicrons ?? 110.0,
      finalPaintThicknessMicrons: primaryZone.finalMicrons ?? 108.5,
      defectSeverity: 7,
      serviceType: _selectedService,
      recipeStages: const [],
      mediaZones: mediaZones,
      beforeImageUrl: primaryZone.beforeImageUrl,
      afterImageUrl: primaryZone.afterImageUrl,
      defectBadge: primaryZone.defectBadge ?? '50/50 Transformation',
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
                              '(${_zones.length} of ${_tier == SubscriptionTier.enterprise ? "Unlimited" : _maxZones} angles used)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tier == SubscriptionTier.free
                              ? 'Free tier: 3 before + 3 after photos (6 photos max) on Cloudflare R2.'
                              : (_tier == SubscriptionTier.pro
                                  ? 'Pro tier: 15 angles (30 photos max) on Cloudflare R2.'
                                  : 'Enterprise tier: Unlimited photos & zones on Cloudflare R2.'),
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

            // Section 1: Multi-Zone Guided Before & After Photos
            Container(
              padding: const EdgeInsets.all(14),
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
                      const Text(
                        '1. Guided Angle Photos (50/50 Zones)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addZone,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Angle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload photos in bulk or slot by slot. Select multiple photos at once and they will automatically map across guided vehicle angles.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Bulk Upload Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: AppTheme.hardnessSoft,
                            side: const BorderSide(color: AppTheme.hardnessSoft, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isBulkUploadingBefore
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.hardnessSoft))
                              : const Icon(Icons.flash_on_rounded, size: 18),
                          label: Text(
                            _isBulkUploadingBefore ? 'Importing...' : 'Bulk Before Photos',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isBulkUploadingBefore || _isBulkUploadingAfter
                              ? null
                              : () => _pickBulkImages(isBefore: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isBulkUploadingAfter
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(
                            _isBulkUploadingAfter ? 'Importing...' : 'Bulk After Photos',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isBulkUploadingBefore || _isBulkUploadingAfter
                              ? null
                              : () => _pickBulkImages(isBefore: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Quick Angle Preset Chips
                  const Text(
                    'Quick Add Vehicle Angles:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: kAnglePresets.map((preset) {
                        final alreadyAdded = _zones.any((z) => z.zoneName == preset.zoneName);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Icon(
                              preset.icon,
                              size: 14,
                              color: alreadyAdded ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            label: Text(
                              preset.zoneName.split(' / ').first,
                              style: TextStyle(
                                fontSize: 11,
                                color: alreadyAdded ? Colors.white : AppTheme.textSecondary,
                                fontWeight: alreadyAdded ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            backgroundColor: alreadyAdded ? AppTheme.primary.withAlpha(25) : AppTheme.surfaceLight,
                            side: BorderSide(
                              color: alreadyAdded ? AppTheme.primary.withAlpha(100) : AppTheme.border,
                            ),
                            onPressed: alreadyAdded
                                ? null
                                : () {
                                    if (!_canAddZone) {
                                      _showUpgradeDialog();
                                      return;
                                    }
                                    setState(() {
                                      _zones.add(
                                        ZoneDraft(
                                          id: 'zone_${DateTime.now().millisecondsSinceEpoch}',
                                          zoneName: preset.zoneName,
                                          shotGuide: preset.shotGuide,
                                          defectBadge: preset.defaultBadge,
                                          initialMicrons: 110.0,
                                          finalMicrons: 108.0,
                                        ),
                                      );
                                    });
                                  },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Render Each Zone Draft
            ..._zones.asMap().entries.map((entry) {
              final index = entry.key;
              final zone = entry.value;
              return _buildZoneCard(zone, index);
            }),

            const SizedBox(height: 20),

            // Section 2: Vehicle & Service Info
            const Text('2. Vehicle & Service Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                labelText: 'Job Story & Craft Details (Paint hardness observations, pad/compound combo, customer reaction)',
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

  Widget _buildZoneCard(ZoneDraft zone, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Zone Title & Delete button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Angle ${index + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: zone.zoneName,
                    isExpanded: true,
                    dropdownColor: AppTheme.surfaceLight,
                    items: kAnglePresets.map((preset) {
                      return DropdownMenuItem<String>(
                        value: preset.zoneName,
                        child: Row(
                          children: [
                            Icon(preset.icon, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                preset.zoneName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal == null) return;
                      final match = kAnglePresets.firstWhere((p) => p.zoneName == newVal);
                      setState(() {
                        zone.zoneName = match.zoneName;
                        zone.shotGuide = match.shotGuide;
                        zone.defectBadge = match.defaultBadge;
                      });
                    },
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _heroZoneIndex = index;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _heroZoneIndex == index ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _heroZoneIndex == index ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _heroZoneIndex == index ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: _heroZoneIndex == index ? Colors.black : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _heroZoneIndex == index ? 'Hero Cover' : 'Set Cover',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: _heroZoneIndex == index ? Colors.black : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_zones.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: 'Remove this angle',
                  onPressed: () {
                    if (_heroZoneIndex == index) {
                      _heroZoneIndex = 0;
                    } else if (_heroZoneIndex > index) {
                      _heroZoneIndex--;
                    }
                    _removeZone(index);
                  },
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Shot Guide Tip Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withAlpha(50)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 15, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zone.shotGuide,
                    style: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Side-by-Side Upload Slots
          Row(
            children: [
              // BEFORE Photo Slot
              Expanded(
                child: _buildPhotoUploadSlot(
                  title: 'BEFORE (Defects)',
                  imageUrl: zone.beforeImageUrl,
                  imageBytes: zone.beforeBytes,
                  isUploading: zone.isUploadingBefore,
                  accentColor: AppTheme.hardnessSoft,
                  onTap: () => _pickAndUploadImage(zone, true),
                ),
              ),
              const SizedBox(width: 12),
              // AFTER Photo Slot
              Expanded(
                child: _buildPhotoUploadSlot(
                  title: 'AFTER (Corrected)',
                  imageUrl: zone.afterImageUrl,
                  imageBytes: zone.afterBytes,
                  isUploading: zone.isUploadingAfter,
                  accentColor: AppTheme.primary,
                  onTap: () => _pickAndUploadImage(zone, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Defect Badge and Paint Gauge Microns
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: zone.defectBadge,
                  decoration: const InputDecoration(
                    labelText: 'Defect Badge',
                    prefixIcon: Icon(Icons.tune_rounded, size: 16),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => zone.defectBadge = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: zone.initialMicrons != null ? '${zone.initialMicrons}' : '112.0',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pre µm',
                    suffixText: 'µm',
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => zone.initialMicrons = double.tryParse(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: zone.finalMicrons != null ? '${zone.finalMicrons}' : '109.5',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Post µm',
                    suffixText: 'µm',
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => zone.finalMicrons = double.tryParse(v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadSlot({
    required String title,
    required String? imageUrl,
    Uint8List? imageBytes,
    required bool isUploading,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final hasBytes = imageBytes != null && imageBytes.isNotEmpty;
    final hasUrl = imageUrl != null && imageUrl.isNotEmpty;
    final hasImage = hasBytes || hasUrl;

    ImageProvider? imageProvider;
    if (hasBytes) {
      imageProvider = MemoryImage(imageBytes);
    } else if (hasUrl) {
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64String = imageUrl.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } catch (_) {
          imageProvider = NetworkImage(imageUrl);
        }
      } else {
        imageProvider = NetworkImage(imageUrl);
      }
    }

    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? accentColor.withAlpha(150) : AppTheme.border,
            width: hasImage ? 1.5 : 1,
          ),
          image: imageProvider != null
              ? DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: isUploading
            ? Container(
                color: Colors.black.withAlpha(140),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      SizedBox(height: 8),
                      Text(
                        'Uploading to R2...',
                        style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (!hasImage)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 28, color: accentColor),
                          const SizedBox(height: 6),
                          Text(
                            'Upload $title',
                            style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Direct to R2 CDN',
                            style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  // Bottom Label Bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.black.withAlpha(180),
                      child: Text(
                        hasImage ? '$title (Tap to Replace)' : title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: hasImage ? Colors.white : accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
