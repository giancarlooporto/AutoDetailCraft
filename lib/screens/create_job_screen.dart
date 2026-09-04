import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../models/detail_job.dart';
import '../services/job_repository.dart';

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
  final _defectBadgeCtrl = TextEditingController(text: 'Swirls & Water Etchings');
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '650');

  String _selectedService = AppConstants.serviceTypes[1]; // Ceramic Coating
  PaintHardness _hardness = PaintHardness.soft;

  // Supabase storage sample URLs for demo
  String _beforeUrl = 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80';
  String _afterUrl = 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _paintColorCtrl.dispose();
    _defectBadgeCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _publishTransformation() {
    if (!_formKey.currentState!.validate()) return;

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
      initialPaintThicknessMicrons: 110.0,
      finalPaintThicknessMicrons: 108.5,
      defectSeverity: 7,
      serviceType: _selectedService,
      recipeStages: const [],
      beforeImageUrl: _beforeUrl,
      afterImageUrl: _afterUrl,
      defectBadge: _defectBadgeCtrl.text.trim(),
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
            Text('Transformation published to your portfolio & local feed!'),
          ],
        ),
        backgroundColor: AppTheme.surface,
      ),
    );

    widget.onJobCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Transformation', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
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
            // 1. Before & After Photos (Instagram-style visual uploader)
            const Text(
              '1. Before & After Photos (50/50 Slider)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                      image: DecorationImage(image: NetworkImage(_beforeUrl), fit: BoxFit.cover),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withAlpha(180),
                        child: const Text(
                          'BEFORE (Uploaded)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withAlpha(100)),
                      image: DecorationImage(image: NetworkImage(_afterUrl), fit: BoxFit.cover),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withAlpha(180),
                        child: const Text(
                          'AFTER (Uploaded)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '⚡ Powered by Supabase Storage bucket: "portfolio-media"',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),

            const SizedBox(height: 20),

            // 2. Vehicle & Service Details
            const Text('2. Vehicle & Service Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Post Caption / Headline (e.g. Wet Sand & 5-Year Coating on BMW M4)',
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
                    decoration: const InputDecoration(labelText: 'Model (e.g. 911 GT3)'),
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
                    decoration: const InputDecoration(labelText: 'Job Price (\$) (e.g. 650)', prefixText: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedService,
              decoration: const InputDecoration(labelText: 'Service Package Provided'),
              items: AppConstants.serviceTypes.skip(1).map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedService = v);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Job Story & Results (Describe paint condition, customer reaction)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _publishTransformation,
              child: const Text('Publish to AutoDetailCraft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
