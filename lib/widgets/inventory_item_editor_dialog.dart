import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/detail_job.dart';
import 'dilution_dialog.dart';

class InventoryItemEditorDialog extends StatefulWidget {
  final InventoryItem? itemToEdit;
  final InventoryCategory initialCategory;
  final ValueChanged<InventoryItem> onSave;
  final VoidCallback? onDelete;

  const InventoryItemEditorDialog({
    super.key,
    this.itemToEdit,
    this.initialCategory = InventoryCategory.hardware,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    InventoryItem? itemToEdit,
    InventoryCategory initialCategory = InventoryCategory.hardware,
    required ValueChanged<InventoryItem> onSave,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryItemEditorDialog(
        itemToEdit: itemToEdit,
        initialCategory: itemToEdit?.category ?? initialCategory,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<InventoryItemEditorDialog> createState() => _InventoryItemEditorDialogState();
}

class _InventoryItemEditorDialogState extends State<InventoryItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late InventoryCategory _category;
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _subCategoryController;
  late TextEditingController _statusController;
  late TextEditingController _locationController;

  // Hardware specific
  late TextEditingController _maintenanceController;
  late TextEditingController _assignedPadChemicalController;
  late TextEditingController _throwController;
  late TextEditingController _backingPlateController;
  late TextEditingController _opmController;
  late TextEditingController _powerController;

  // Chemical specific
  late TextEditingController _dilutionSpecsController;
  late TextEditingController _dilutionRatioController;
  late TextEditingController _flashTimeController;
  late TextEditingController _cutLevelController;
  late TextEditingController _glossLevelController;
  late TextEditingController _stockController;
  late TextEditingController _safetyNotesController;

  // Recipe specific
  late TextEditingController _targetHardnessController;
  late TextEditingController _expectedCutController;
  late TextEditingController _laborTimeController;
  late List<RecipeStage> _recipeStages;

  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _category = item?.category ?? widget.initialCategory;

    _nameController = TextEditingController(text: item?.name ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _subCategoryController = TextEditingController(
      text: item?.subCategory ?? (_category == InventoryCategory.hardware
          ? 'Dual Action Polisher'
          : _category == InventoryCategory.chemicals
              ? 'Heavy Cut Compound'
              : 'Multi-Step Paint Correction'),
    );
    _statusController = TextEditingController(text: item?.status ?? 'In Service');
    _locationController = TextEditingController(text: item?.location ?? 'Studio Bay 1');

    // Hardware
    _maintenanceController = TextEditingController(text: item?.maintenance ?? '');
    _assignedPadChemicalController = TextEditingController(text: item?.assignedPadOrChemical ?? '');
    _throwController = TextEditingController(text: item?.specs['Orbit / Throw'] ?? item?.specs['Throw'] ?? '15 mm');
    _backingPlateController = TextEditingController(text: item?.specs['Backing Plate'] ?? '5 inch (125mm)');
    _opmController = TextEditingController(text: item?.specs['OPM Range'] ?? item?.specs['Speed'] ?? '3,000 - 5,200 OPM');
    _powerController = TextEditingController(text: item?.specs['Power'] ?? '500 Watts');

    // Chemical
    _dilutionSpecsController = TextEditingController(text: item?.dilutionSpecs ?? 'Ready to Use (Neat 1:0)');
    _dilutionRatioController = TextEditingController(text: item?.dilutionRatio ?? 'Neat');
    _flashTimeController = TextEditingController(text: item?.cureTimeOrFlashTime ?? 'Flash time: 1-2 mins');
    _cutLevelController = TextEditingController(text: item?.specs['Cut Level'] ?? '9.0 / 10');
    _glossLevelController = TextEditingController(text: item?.specs['Gloss Level'] ?? '5.0 / 10');
    _stockController = TextEditingController(text: item?.specs['Stock Volume'] ?? item?.specs['Stock Level'] ?? '1,000 ml (80%)');
    _safetyNotesController = TextEditingController(text: item?.safetyNotes ?? 'Nitrile gloves & safety glasses recommended.');

    // Recipe
    _targetHardnessController = TextEditingController(text: item?.specs['Target Hardness'] ?? 'Hard Ceramic Clear (Porsche / BMW)');
    _expectedCutController = TextEditingController(text: item?.specs['Target Defect Elimination'] ?? '90% Swirl Removal');
    _laborTimeController = TextEditingController(text: item?.specs['Estimated Labor Time'] ?? '6 - 8 Man Hours');
    _recipeStages = List<RecipeStage>.from(item?.recipeStages ?? [
      const RecipeStage(
        stageName: 'Chemical Decon',
        chemical: 'Iron Remover & Clay Towel',
        technique: 'Chemical dwell 4 mins, surface clay glide',
      ),
      const RecipeStage(
        stageName: 'Compounding Cut',
        machine: 'Rupes LHR15 Mark III',
        pad: 'Microfiber Cutting Pad',
        chemical: 'Koch Chemie H9.02',
        technique: '4 crosshatch passes @ speed 4.5',
      ),
      const RecipeStage(
        stageName: 'Finishing Polish',
        machine: 'Rupes LHR15 Mark III',
        pad: 'Yellow Fine Foam Pad',
        chemical: 'Sonax Perfect Finish 04-06',
        technique: '3 passes @ speed 3.5 for high gloss mirror',
      ),
    ]);

    _notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _subCategoryController.dispose();
    _statusController.dispose();
    _locationController.dispose();
    _maintenanceController.dispose();
    _assignedPadChemicalController.dispose();
    _throwController.dispose();
    _backingPlateController.dispose();
    _opmController.dispose();
    _powerController.dispose();
    _dilutionSpecsController.dispose();
    _dilutionRatioController.dispose();
    _flashTimeController.dispose();
    _cutLevelController.dispose();
    _glossLevelController.dispose();
    _stockController.dispose();
    _safetyNotesController.dispose();
    _targetHardnessController.dispose();
    _expectedCutController.dispose();
    _laborTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, String> specs = Map<String, String>.from(widget.itemToEdit?.specs ?? {});
    if (_category == InventoryCategory.hardware) {
      if (_throwController.text.isNotEmpty) specs['Orbit / Throw'] = _throwController.text.trim();
      if (_backingPlateController.text.isNotEmpty) specs['Backing Plate'] = _backingPlateController.text.trim();
      if (_opmController.text.isNotEmpty) specs['OPM Range'] = _opmController.text.trim();
      if (_powerController.text.isNotEmpty) specs['Power'] = _powerController.text.trim();
    } else if (_category == InventoryCategory.chemicals) {
      if (_cutLevelController.text.isNotEmpty) specs['Cut Level'] = _cutLevelController.text.trim();
      if (_glossLevelController.text.isNotEmpty) specs['Gloss Level'] = _glossLevelController.text.trim();
      if (_stockController.text.isNotEmpty) specs['Stock Volume'] = _stockController.text.trim();
    } else {
      if (_targetHardnessController.text.isNotEmpty) specs['Target Hardness'] = _targetHardnessController.text.trim();
      if (_expectedCutController.text.isNotEmpty) specs['Target Defect Elimination'] = _expectedCutController.text.trim();
      if (_laborTimeController.text.isNotEmpty) specs['Estimated Labor Time'] = _laborTimeController.text.trim();
    }

    final item = InventoryItem(
      id: widget.itemToEdit?.id ?? 'inv_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      subCategory: _subCategoryController.text.trim(),
      specs: specs,
      maintenance: _maintenanceController.text.trim(),
      assignedPadOrChemical: _assignedPadChemicalController.text.trim(),
      dilutionSpecs: _dilutionSpecsController.text.trim(),
      dilutionRatio: _dilutionRatioController.text.trim().isNotEmpty ? _dilutionRatioController.text.trim() : null,
      cureTimeOrFlashTime: _flashTimeController.text.trim().isNotEmpty ? _flashTimeController.text.trim() : null,
      safetyNotes: _safetyNotesController.text.trim().isNotEmpty ? _safetyNotesController.text.trim() : null,
      recipeStages: _category == InventoryCategory.recipe ? _recipeStages : const [],
      status: _statusController.text.trim().isNotEmpty ? _statusController.text.trim() : 'In Service',
      location: _locationController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  void _addRecipeStage() {
    setState(() {
      _recipeStages.add(
        RecipeStage(
          stageName: 'Stage ${_recipeStages.length + 1}',
          machine: 'Rupes LHR15 Mark III',
          pad: 'Finishing Pad',
          chemical: 'Finish Polish',
          technique: '3 passes @ speed 3.5',
        ),
      );
    });
  }

  void _editRecipeStage(int index) {
    final stage = _recipeStages[index];
    final nameCtrl = TextEditingController(text: stage.stageName);
    final machCtrl = TextEditingController(text: stage.machine);
    final padCtrl = TextEditingController(text: stage.pad);
    final chemCtrl = TextEditingController(text: stage.chemical);
    final techCtrl = TextEditingController(text: stage.technique);
    final notesCtrl = TextEditingController(text: stage.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Edit Step: ${stage.stageName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Stage Title', hintText: 'e.g. Heavy Cut'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: machCtrl,
                  decoration: const InputDecoration(labelText: 'Machine', hintText: 'e.g. Rupes LHR15'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: padCtrl,
                  decoration: const InputDecoration(labelText: 'Pad', hintText: 'e.g. Lake Country Microfiber'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: chemCtrl,
                  decoration: const InputDecoration(labelText: 'Chemical / Compound', hintText: 'e.g. Koch Chemie H9.02'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: techCtrl,
                  decoration: const InputDecoration(labelText: 'Technique', hintText: 'e.g. 4 crosshatch passes @ speed 4.5'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'e.g. Wipe with IPA 15%'),
                ),
              ],
            ),
          ),
        ),
        actions: [
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
              setState(() {
                _recipeStages[index] = RecipeStage(
                  stageName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Stage',
                  machine: machCtrl.text.trim(),
                  pad: padCtrl.text.trim(),
                  chemical: chemCtrl.text.trim().isNotEmpty ? chemCtrl.text.trim() : 'Compound',
                  technique: techCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                );
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Update Step', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _category == InventoryCategory.hardware
                            ? Icons.handyman_rounded
                            : _category == InventoryCategory.chemicals
                                ? Icons.science_rounded
                                : Icons.auto_stories_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit ${_category.label}' : 'Add New ${_category.label}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            _category.description,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Selector (If adding new)
                if (!isEditing) ...[
                  Row(
                    children: [
                      for (final cat in InventoryCategory.values) ...[
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _category = cat;
                                if (_subCategoryController.text.isEmpty ||
                                    _subCategoryController.text == 'Dual Action Polisher' ||
                                    _subCategoryController.text == 'Heavy Cut Compound' ||
                                    _subCategoryController.text == 'Multi-Step Paint Correction') {
                                  _subCategoryController.text = cat == InventoryCategory.hardware
                                      ? 'Dual Action Polisher'
                                      : cat == InventoryCategory.chemicals
                                          ? 'Heavy Cut Compound'
                                          : 'Multi-Step Paint Correction';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _category == cat ? AppTheme.primary.withAlpha(30) : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _category == cat ? AppTheme.primary : AppTheme.border,
                                  width: _category == cat ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _category == cat ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (cat != InventoryCategory.recipe) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Scrollable Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Core Attributes
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: _category == InventoryCategory.recipe ? 'Formula / Recipe Name *' : 'Item Name / Model *',
                            hintText: _category == InventoryCategory.hardware
                                ? 'e.g. Rupes LHR15 Mark III (15mm)'
                                : _category == InventoryCategory.chemicals
                                    ? 'e.g. Koch Chemie H9.02 Heavy Cut'
                                    : 'e.g. German Ceramic Clear 2-Stage Formula',
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _brandController,
                                decoration: const InputDecoration(
                                  labelText: 'Brand / Manufacturer',
                                  hintText: 'e.g. Rupes, CarPro, Sonax',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _subCategoryController,
                                decoration: InputDecoration(
                                  labelText: 'Subcategory / Type',
                                  hintText: _category == InventoryCategory.hardware
                                      ? 'e.g. Polisher, Pad, Meter'
                                      : _category == InventoryCategory.chemicals
                                          ? 'e.g. Compound, Coating, APC'
                                          : 'e.g. Hard Clear, 1-Step Polish',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _statusController,
                                decoration: const InputDecoration(
                                  labelText: 'Status Badge',
                                  hintText: 'e.g. In Service, Optimal, Ready',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                  labelText: 'Studio Location / Wall Bay',
                                  hintText: 'e.g. Bay 1 Tool Wall, Rack A',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // CATEGORY SPECIFIC FIELDS
                        if (_category == InventoryCategory.hardware) ...[
                          const Text(
                            'HARDWARE SPECIFICATIONS & MAINTENANCE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _throwController,
                                  decoration: const InputDecoration(
                                    labelText: 'Orbit / Throw',
                                    hintText: 'e.g. 15 mm',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _backingPlateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Backing Plate',
                                    hintText: 'e.g. 5 in (125mm)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _opmController,
                                  decoration: const InputDecoration(
                                    labelText: 'OPM / Speed Range',
                                    hintText: 'e.g. 3000 - 5200 OPM',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _powerController,
                                  decoration: const InputDecoration(
                                    labelText: 'Power Consumption',
                                    hintText: 'e.g. 500 Watts',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _assignedPadChemicalController,
                            decoration: const InputDecoration(
                              labelText: 'Assigned Pad & Chemical Match',
                              hintText: 'e.g. Lake Country HDO Microfiber + Koch Chemie H9.02',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _maintenanceController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Maintenance Schedule & Service Log',
                              hintText: 'e.g. Carbon brushes inspected @ 150 hrs. Backing plate bearing lubricated monthly.',
                            ),
                          ),
                        ] else if (_category == InventoryCategory.chemicals) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CHEMICAL DILUTION & SAFETY SPECS',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.calculate_outlined, size: 14, color: AppTheme.primary),
                                label: const Text('Dilution Calc', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                                onPressed: () => showDialog(context: context, builder: (_) => const DilutionDialog()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _dilutionSpecsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dilution Specs',
                                    hintText: 'e.g. Ready to Use (Neat 1:0) or 1:10 dilution',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _dilutionRatioController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ratio',
                                    hintText: 'e.g. 1:10',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cutLevelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cut Level',
                                    hintText: 'e.g. 9.0 / 10',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _glossLevelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Gloss Level',
                                    hintText: 'e.g. 5.0 / 10',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _stockController,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock Level',
                                    hintText: 'e.g. 3.5 Liters (70%)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _flashTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Flash Time / Working Cycle',
                              hintText: 'e.g. Working cycle 4-6 passes. Wipe off immediately.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _assignedPadChemicalController,
                            decoration: const InputDecoration(
                              labelText: 'Recommended Pad Pairing',
                              hintText: 'e.g. Microfiber Cutting Pad or Wool Pad',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _safetyNotesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Safety PPE & Handling Instructions',
                              hintText: 'e.g. Nitrile gloves and organic vapor respirator recommended.',
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'PAINT CORRECTION FORMULA & STEP SEQUENCE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _targetHardnessController,
                                  decoration: const InputDecoration(
                                    labelText: 'Clear Hardness Target',
                                    hintText: 'e.g. Hard Ceramic Clear (Porsche / BMW)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _expectedCutController,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Correction',
                                    hintText: 'e.g. 90 - 95% Cut',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _laborTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Estimated Time',
                              hintText: 'e.g. 6 - 8 Man Hours',
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Stages List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FORMULA STAGES (${_recipeStages.length})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                                label: const Text('+ Add Step', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                                onPressed: _addRecipeStage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (int i = 0; i < _recipeStages.length; i++) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${i + 1}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _recipeStages[i].stageName,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        Text(
                                          '${_recipeStages[i].chemical}${_recipeStages[i].machine.isNotEmpty ? " • ${_recipeStages[i].machine}" : ""}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
                                    onPressed: () => _editRecipeStage(i),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                    onPressed: () => setState(() => _recipeStages.removeAt(i)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'General Pro Tips & Notes',
                            hintText: 'e.g. Always tape rubber trim before running high-speed compound passes.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),

                // Footer Actions
                Row(
                  children: [
                    if (isEditing && widget.onDelete != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        onPressed: () {
                          widget.onDelete!();
                          Navigator.of(context).pop();
                        },
                      ),
                      const Spacer(),
                    ] else ...[
                      const Spacer(),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Add to Inventory',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
