import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_picker_service.dart';
import '../services/supabase_service.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/vehicle_data.dart';
import '../models/user_vehicle.dart';
import '../services/job_repository.dart';
import '../services/vehicle_api_service.dart';

class VehicleEditorDialog extends StatefulWidget {
  final JobRepository repository;
  final UserVehicle? vehicleToEdit; // If null, creating new

  const VehicleEditorDialog({
    super.key,
    required this.repository,
    this.vehicleToEdit,
  });

  @override
  State<VehicleEditorDialog> createState() => _VehicleEditorDialogState();
}

class _VehicleEditorDialogState extends State<VehicleEditorDialog> {
  // Mode toggles for custom entry
  bool _isManualMake = false;
  bool _isManualModel = false;
  bool _isCustomColor = false;
  bool _isLoadingModels = false;
  bool _isLoadingMakes = false;
  bool _isUploadingToCloud = false;

  late int _selectedYear;
  late String _selectedMake;
  late String _selectedModel;
  late String _selectedColor;
  late String _imageUrl;
  Uint8List? _uploadedImageBytes;

  List<String> _availableMakes = VehicleDatabase.allMakes;
  List<String> _availableModels = [];
  List<String> _availableColors = [];

  final TextEditingController _customYearCtrl = TextEditingController(text: '2024');
  final TextEditingController _customMakeCtrl = TextEditingController();
  final TextEditingController _customModelCtrl = TextEditingController();
  final TextEditingController _customColorCtrl = TextEditingController();
  final List<String> _samplePresets = [
    'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.vehicleToEdit != null) {
      final v = widget.vehicleToEdit!;
      _selectedYear = v.year;
      _customYearCtrl.text = v.year.toString();
      _uploadedImageBytes = v.localImageBytes;

      if (VehicleDatabase.allMakes.contains(v.make)) {
        _selectedMake = v.make;
        _selectedModel = v.model;
        _selectedColor = v.colorName;
      } else {
        _isManualMake = true;
        _isManualModel = true;
        _isCustomColor = true;
        _customMakeCtrl.text = v.make;
        _customModelCtrl.text = v.model;
        _customColorCtrl.text = v.colorName;
        _selectedMake = VehicleDatabase.allMakes.first;
        _selectedModel = v.model;
        _selectedColor = v.colorName;
      }
      _imageUrl = v.imageUrl;
      _loadModels(initialModel: v.model, initialColor: v.colorName);
    } else {
      _selectedYear = VehicleDatabase.allStandardYears.first; // Latest year (2026)
      _selectedMake = VehicleDatabase.allMakes.first; // First alphabetically (Acura)
      _selectedModel = '';
      _selectedColor = '';
      _imageUrl = 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80';
      _loadMakes();
      _loadModels();
    }
  }

  @override
  void dispose() {
    _customYearCtrl.dispose();
    _customMakeCtrl.dispose();
    _customModelCtrl.dispose();
    _customColorCtrl.dispose();
    super.dispose();
  }

  // Upload original photo — delegates to web (dart:html) or stub on other platforms
  Future<void> _pickOriginalPhoto() async {
    try {
      final result = await pickImageFromDevice();
      final bytes = result.bytes;
      final fileName = result.name ?? 'photo';

      if (bytes != null && bytes.isNotEmpty) {
        setState(() => _uploadedImageBytes = bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Photo selected: $fileName')),
                ],
              ),
              backgroundColor: AppTheme.surface,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Fetch live models from NHTSA vPIC API
  Future<void> _loadModels({String? initialModel, String? initialColor}) async {
    if (_isManualMake) return;

    setState(() => _isLoadingModels = true);

    final models = await VehicleApiService.fetchModelsForMakeAndYear(_selectedMake, _selectedYear);

    if (!mounted) return;

    setState(() {
      _availableModels = models;
      _isLoadingModels = false;

      if (initialModel != null && models.contains(initialModel)) {
        _selectedModel = initialModel;
      } else if (models.isNotEmpty) {
        if (!models.contains(_selectedModel)) {
          _selectedModel = models.first;
        }
      }

      _availableColors = VehicleApiService.getFactoryColorsFor(_selectedMake, _selectedModel);

      if (initialColor != null && _availableColors.contains(initialColor)) {
        _selectedColor = initialColor;
      } else if (_availableColors.isNotEmpty) {
        if (!_availableColors.contains(_selectedColor)) {
          _selectedColor = _availableColors.first;
        }
      }

      if (_uploadedImageBytes == null) {
        _imageUrl = VehicleApiService.getStudioImageFor(_selectedMake, _selectedModel);
      }
    });
  }

  Future<void> _loadMakes({String? keepMake}) async {
    if (_isManualMake) return;
    setState(() => _isLoadingMakes = true);

    final makes = await VehicleApiService.fetchMakesForYear(_selectedYear);

    if (!mounted) return;
    setState(() {
      _availableMakes = makes;
      _isLoadingMakes = false;
      // Keep current make if still valid, else reset to first
      if (!makes.contains(_selectedMake)) {
        _selectedMake = makes.isNotEmpty ? makes.first : VehicleDatabase.allMakes.first;
      }
    });
  }

  void _onYearChanged(int newYear) {
    setState(() => _selectedYear = newYear);
    _loadMakes();
    _loadModels();
  }

  void _onMakeChanged(String newMake) {
    setState(() {
      _selectedMake = newMake;
      _isManualModel = false;
    });
    _loadModels();
  }

  void _onModelChanged(String newModel) {
    setState(() {
      _selectedModel = newModel;
      _availableColors = VehicleApiService.getFactoryColorsFor(_selectedMake, newModel);
      if (_availableColors.isNotEmpty) {
        _selectedColor = _availableColors.first;
      }
      if (_uploadedImageBytes == null) {
        _imageUrl = VehicleApiService.getStudioImageFor(_selectedMake, newModel);
      }
    });
  }

  Future<void> _saveVehicle() async {
    final year = _isManualMake
        ? (int.tryParse(_customYearCtrl.text.trim()) ?? _selectedYear)
        : _selectedYear;

    final make = _isManualMake && _customMakeCtrl.text.trim().isNotEmpty
        ? _customMakeCtrl.text.trim()
        : _selectedMake;

    final model = (_isManualMake || _isManualModel) && _customModelCtrl.text.trim().isNotEmpty
        ? _customModelCtrl.text.trim()
        : _selectedModel;

    final color = _isCustomColor && _customColorCtrl.text.trim().isNotEmpty
        ? _customColorCtrl.text.trim()
        : _selectedColor;

    if (make.isEmpty || model.isEmpty) return;

    setState(() => _isUploadingToCloud = true);

    String finalImageUrl = _imageUrl;

    // Upload to Supabase Storage if user selected an original photo
    if (_uploadedImageBytes != null) {
      final cloudUrl = await SupabaseService.uploadVehiclePhoto(
        userId: widget.repository.currentUser.id,
        bytes: _uploadedImageBytes!,
      );
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        finalImageUrl = cloudUrl;
      }
    }

    final vehicle = UserVehicle(
      id: widget.vehicleToEdit?.id ?? 'veh_${DateTime.now().millisecondsSinceEpoch}',
      year: year,
      make: make,
      model: model,
      colorName: color,
      paintCode: 'OEM',
      imageUrl: finalImageUrl,
      localImageBytes: _uploadedImageBytes,
      lastDetailService: widget.vehicleToEdit?.lastDetailService ?? 'Awaiting First Pro Detail',
      lastDetailDate: widget.vehicleToEdit?.lastDetailDate,
    );

    if (widget.vehicleToEdit != null) {
      widget.repository.updateVehicleInGarage(vehicle);
    } else {
      widget.repository.addVehicleToGarage(vehicle);
    }

    if (mounted) {
      setState(() => _isUploadingToCloud = false);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(widget.vehicleToEdit != null ? 'Vehicle updated successfully!' : 'Vehicle added to your Garage & Cloud!'),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableMakes = _availableMakes.isNotEmpty ? _availableMakes : VehicleDatabase.allMakes;
    final models = _availableModels.isNotEmpty
        ? _availableModels
        : VehicleDatabase.getModelsForMakeAndYear(_selectedMake, _selectedYear).map((m) => m.model).toList();

    final colors = _availableColors.isNotEmpty
        ? _availableColors
        : VehicleApiService.getFactoryColorsFor(_selectedMake, _selectedModel);

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            widget.vehicleToEdit != null ? 'Edit Vehicle' : 'Add Vehicle to Garage',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NHTSA Database verification badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(50)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 13, color: AppTheme.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Live NHTSA vPIC Database (Official US DOT Vehicle Registry)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // STEP 1: YEAR FIRST (1950 - 2026)
              const Text('1. Production Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              if (!_isManualMake)
                DropdownButtonFormField<int>(
                  value: VehicleDatabase.allStandardYears.contains(_selectedYear) ? _selectedYear : VehicleDatabase.allStandardYears.first,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: VehicleDatabase.allStandardYears.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) {
                    if (v != null) _onYearChanged(v);
                  },
                )
              else
                TextField(
                  controller: _customYearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Year (e.g. 2024, 1969)',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

              const SizedBox(height: 14),

              // STEP 2: MAKE (Live from NHTSA + Alphabetized)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('2. Vehicle Make', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      if (_isLoadingMakes) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isManualMake = !_isManualMake;
                      if (_isManualMake) {
                        _isManualModel = true;
                        _isCustomColor = true;
                      }
                    }),
                    child: Text(
                      _isManualMake ? 'Select from list' : '+ Type manually',
                      style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_isManualMake)
                DropdownButtonFormField<String>(
                  value: availableMakes.contains(_selectedMake) ? _selectedMake : (availableMakes.isNotEmpty ? availableMakes.first : VehicleDatabase.allMakes.first),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.business_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: (availableMakes.isNotEmpty ? availableMakes : VehicleDatabase.allMakes)
                      .map((make) => DropdownMenuItem(value: make, child: Text(make)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _onMakeChanged(v);
                  },
                )
              else
                TextField(
                  controller: _customMakeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Make (e.g. Lucid, Koenigsegg, Pagani, Lotus)',
                    prefixIcon: Icon(Icons.business_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

              const SizedBox(height: 14),

              // STEP 3: MODEL (Live Complete Models from NHTSA API)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('3. Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      if (_isLoadingModels) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      ],
                    ],
                  ),
                  if (!_isManualMake)
                    GestureDetector(
                      onTap: () => setState(() => _isManualModel = !_isManualModel),
                      child: Text(
                        _isManualModel ? 'Pick from registry' : '+ Custom model',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_isManualMake && !_isManualModel && models.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: models.contains(_selectedModel) ? _selectedModel : models.first,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_car_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    helperText: '${models.length} official models for $_selectedMake ($_selectedYear)',
                    helperStyle: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                  items: models.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v != null) _onModelChanged(v);
                  },
                )
              else
                TextField(
                  controller: _customModelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model (e.g. Air Sapphire, Emira, Custom GT)',
                    prefixIcon: Icon(Icons.directions_car_rounded, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

              const SizedBox(height: 14),

              // STEP 4: PAINT COLOR (Dynamically Populated by Selected Model & Year)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('4. Factory OEM Paint Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  GestureDetector(
                    onTap: () => setState(() => _isCustomColor = !_isCustomColor),
                    child: Text(
                      _isCustomColor ? 'Pick OEM Color' : 'Custom / Wrap',
                      style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_isCustomColor && !_isManualMake)
                DropdownButtonFormField<String>(
                  value: colors.contains(_selectedColor) ? _selectedColor : (colors.isNotEmpty ? colors.first : 'Gloss Black'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.palette_outlined, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: colors.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedColor = v);
                  },
                )
              else
                TextField(
                  controller: _customColorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Paint / Vinyl Wrap Color',
                    hintText: 'e.g. Satin Nardo Grey Wrap, Candy Apple Red',
                    prefixIcon: Icon(Icons.palette_outlined, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

              const SizedBox(height: 16),

              // STEP 5: VEHICLE PHOTO PREVIEW & UPLOAD ORIGINAL PHOTO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('5. Vehicle Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  if (_uploadedImageBytes != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 11, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text('Photo Ready', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _uploadedImageBytes != null ? AppTheme.primary : AppTheme.border, width: _uploadedImageBytes != null ? 2 : 1),
                  image: _uploadedImageBytes != null
                      ? DecorationImage(image: MemoryImage(_uploadedImageBytes!), fit: BoxFit.cover)
                      : DecorationImage(image: NetworkImage(_imageUrl), fit: BoxFit.cover),
                ),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button 1: Upload Original Photo
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 15, color: Colors.black),
                          label: const Text('Upload My Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _pickOriginalPhoto,
                        ),
                        const SizedBox(width: 6),

                        // Button 2: Choose Presets
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(210),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.image_search_rounded, size: 16, color: Colors.white),
                            tooltip: 'Select Studio Preset',
                            onSelected: (url) => setState(() {
                              _uploadedImageBytes = null;
                              _imageUrl = url;
                            }),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                enabled: false,
                                child: Text('Select High-Res Studio Preset:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                              ),
                              ..._samplePresets.map(
                                (url) => PopupMenuItem(
                                  value: url,
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(url, width: 40, height: 26, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Select Preset Photo', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('📸 Upload your own high-resolution car photo or choose a studio preset', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploadingToCloud ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isUploadingToCloud ? null : _saveVehicle,
          child: _isUploadingToCloud
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(widget.vehicleToEdit != null ? 'Save Changes' : 'Add to Garage', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
