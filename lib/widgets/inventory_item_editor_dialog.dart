import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/detail_job.dart';

class InventoryItemEditorDialog extends StatefulWidget {
  final InventoryItem? itemToEdit;
  final InventoryCategory initialCategory;
  final List<String> hardwareOptions;
  final List<String> chemicalOptions;
  final ValueChanged<InventoryItem> onSave;
  final VoidCallback? onDelete;

  const InventoryItemEditorDialog({
    super.key,
    this.itemToEdit,
    this.initialCategory = InventoryCategory.hardware,
    this.hardwareOptions = const [],
    this.chemicalOptions = const [],
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    InventoryItem? itemToEdit,
    InventoryCategory initialCategory = InventoryCategory.hardware,
    List<String> hardwareOptions = const [],
    List<String> chemicalOptions = const [],
    required ValueChanged<InventoryItem> onSave,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryItemEditorDialog(
        itemToEdit: itemToEdit,
        initialCategory: itemToEdit?.category ?? initialCategory,
        hardwareOptions: hardwareOptions,
        chemicalOptions: chemicalOptions,
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
  String _status = 'In Service';
  late TextEditingController _locationController;
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
      text: item?.subCategory ??
          (_category == InventoryCategory.hardware
              ? 'Dual Action Polisher'
              : _category == InventoryCategory.chemicals
                  ? 'Heavy Cut Compound'
                  : 'Recipe'),
    );

    final rawStatus = item?.status ?? (_category == InventoryCategory.chemicals ? 'Full' : 'In Service');
    if (_category == InventoryCategory.chemicals) {
      _status = const ['Full', 'Half', 'Empty'].contains(rawStatus) ? rawStatus : 'Full';
    } else if (_category == InventoryCategory.hardware) {
      _status = const ['In Service', 'Repair', 'Optimal', 'Retired'].contains(rawStatus) ? rawStatus : 'In Service';
    } else {
      _status = 'Active';
    }

    _locationController = TextEditingController(text: item?.location ?? (_category == InventoryCategory.chemicals ? 'Chemical Shelf Bay 1' : 'Studio Bay 1'));
    _recipeStages = List<RecipeStage>.from(item?.recipeStages ?? [
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
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, String> specs = Map<String, String>.from(widget.itemToEdit?.specs ?? {});

    final item = InventoryItem(
      id: widget.itemToEdit?.id ?? 'inv_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _category,
      brand: _category == InventoryCategory.recipe ? '' : _brandController.text.trim(),
      subCategory: _category == InventoryCategory.recipe ? 'Recipe' : _subCategoryController.text.trim(),
      specs: specs,
      maintenance: widget.itemToEdit?.maintenance ?? '',
      assignedPadOrChemical: widget.itemToEdit?.assignedPadOrChemical ?? '',
      dilutionSpecs: widget.itemToEdit?.dilutionSpecs ?? '',
      dilutionRatio: widget.itemToEdit?.dilutionRatio,
      cureTimeOrFlashTime: widget.itemToEdit?.cureTimeOrFlashTime,
      safetyNotes: widget.itemToEdit?.safetyNotes,
      recipeStages: _category == InventoryCategory.recipe ? _recipeStages : const [],
      status: _category == InventoryCategory.recipe ? 'Active' : _status,
      location: _category == InventoryCategory.recipe ? '' : _locationController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    widget.onSave(item);
    Navigator.of(context).pop();
  }

  bool _containsItem(String text, String item) {
    if (text.isEmpty) return false;
    final parts = text.split(RegExp(r'\s*\+\s*|\s*,\s*')).map((s) => s.trim().toLowerCase());
    return parts.contains(item.trim().toLowerCase());
  }

  String _toggleItem(String text, String item, bool add) {
    final parts = text.split(RegExp(r'\s*\+\s*|\s*,\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (add) {
      if (!parts.any((p) => p.toLowerCase() == item.trim().toLowerCase())) {
        parts.add(item.trim());
      }
    } else {
      parts.removeWhere((p) => p.toLowerCase() == item.trim().toLowerCase());
    }
    return parts.join(' + ');
  }

  void _openMultiSelectPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String currentText,
    required ValueChanged<String> onSelected,
  }) {
    final selectedItems = currentText
        .split(RegExp(r'\s*\+\s*|\s*,\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380, maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final opt in options) ...[
                      CheckboxListTile(
                        value: selectedItems.any((s) => s.toLowerCase() == opt.toLowerCase()),
                        title: Text(opt, style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                        activeColor: AppTheme.primary,
                        checkColor: Colors.black,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setPickerState(() {
                            if (val == true) {
                              if (!selectedItems.any((s) => s.toLowerCase() == opt.toLowerCase())) {
                                selectedItems.add(opt);
                              }
                            } else {
                              selectedItems.removeWhere((s) => s.toLowerCase() == opt.toLowerCase());
                            }
                          });
                        },
                      ),
                    ],
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                onPressed: () {
                  onSelected(selectedItems.join(' + '));
                  Navigator.of(ctx).pop();
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRecipeStageEditor({int? editIndex}) {
    final isNew = editIndex == null;
    final stage = isNew
        ? RecipeStage(
            stageName: 'Stage ${_recipeStages.length + 1}',
            machine: widget.hardwareOptions.isNotEmpty ? widget.hardwareOptions.first : '',
            chemical: widget.chemicalOptions.isNotEmpty ? widget.chemicalOptions.first : '',
          )
        : _recipeStages[editIndex];

    final nameCtrl = TextEditingController(text: stage.stageName);
    final machCtrl = TextEditingController(text: stage.machine);
    final chemCtrl = TextEditingController(text: stage.chemical);
    final padCtrl = TextEditingController(text: stage.pad);
    final techCtrl = TextEditingController(text: stage.technique);
    final notesCtrl = TextEditingController(text: stage.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isNew ? 'Add Formula Step' : 'Edit Step: ${stage.stageName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Step / Stage Title',
                        hintText: 'e.g. Heavy Cut, Finish Polish, Ceramic Coating',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Machine / Tool(s) (Multi-select from Hardware + editable text)
                    TextField(
                      controller: machCtrl,
                      decoration: InputDecoration(
                        labelText: 'Machine / Tool(s)',
                        hintText: 'e.g. Rupes LHR15 + Flex PXE 80, or select below',
                        prefixIcon: const Icon(Icons.handyman_rounded, size: 18, color: AppTheme.primary),
                        suffixIcon: widget.hardwareOptions.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.playlist_add_check_rounded, color: AppTheme.primary),
                                tooltip: 'Check multiple from saved Hardware',
                                onPressed: () => _openMultiSelectPicker(
                                  context: ctx,
                                  title: 'Select Machines / Tools',
                                  options: widget.hardwareOptions,
                                  currentText: machCtrl.text,
                                  onSelected: (combined) {
                                    machCtrl.text = combined;
                                    setDialogState(() {});
                                  },
                                ),
                              )
                            : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (widget.hardwareOptions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final h in widget.hardwareOptions) ...[
                              FilterChip(
                                selected: _containsItem(machCtrl.text, h),
                                label: Text(
                                  h,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _containsItem(machCtrl.text, h) ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: _containsItem(machCtrl.text, h) ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selectedColor: AppTheme.primary,
                                checkmarkColor: Colors.black,
                                backgroundColor: AppTheme.surfaceLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    machCtrl.text = _toggleItem(machCtrl.text, h, selected);
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Chemical / Product(s) (Multi-select from Chemicals + editable text)
                    TextField(
                      controller: chemCtrl,
                      decoration: InputDecoration(
                        labelText: 'Chemical / Product(s)',
                        hintText: 'e.g. CarPro IronX + TarX, or select below',
                        prefixIcon: const Icon(Icons.science_rounded, size: 18, color: Colors.tealAccent),
                        suffixIcon: widget.chemicalOptions.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.tealAccent),
                                tooltip: 'Check multiple from saved Chemicals',
                                onPressed: () => _openMultiSelectPicker(
                                  context: ctx,
                                  title: 'Select Chemicals / Products',
                                  options: widget.chemicalOptions,
                                  currentText: chemCtrl.text,
                                  onSelected: (combined) {
                                    chemCtrl.text = combined;
                                    setDialogState(() {});
                                  },
                                ),
                              )
                            : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (widget.chemicalOptions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in widget.chemicalOptions) ...[
                              FilterChip(
                                selected: _containsItem(chemCtrl.text, c),
                                label: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _containsItem(chemCtrl.text, c) ? Colors.black : AppTheme.textSecondary,
                                    fontWeight: _containsItem(chemCtrl.text, c) ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selectedColor: Colors.tealAccent,
                                checkmarkColor: Colors.black,
                                backgroundColor: AppTheme.surfaceLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    chemCtrl.text = _toggleItem(chemCtrl.text, c, selected);
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    TextField(
                      controller: padCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pad / Applicator',
                        hintText: 'e.g. Lake Country Microfiber, Rupes Yellow Foam, Suede Block',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: techCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Technique / Passes',
                        hintText: 'e.g. 4 crosshatch passes @ speed 4.5, slow arm speed',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Step Notes / Wipe Off',
                        hintText: 'e.g. Wipe with 400 GSM edgeless microfiber + 15% IPA wipe',
                      ),
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
                  final newStage = RecipeStage(
                    stageName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Stage',
                    machine: machCtrl.text.trim(),
                    chemical: chemCtrl.text.trim().isNotEmpty ? chemCtrl.text.trim() : 'Compound',
                    pad: padCtrl.text.trim(),
                    technique: techCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );
                  setState(() {
                    if (isNew) {
                      _recipeStages.add(newStage);
                    } else {
                      _recipeStages[editIndex] = newStage;
                    }
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(isNew ? 'Add Step' : 'Update Step', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
                                if (cat == InventoryCategory.chemicals) {
                                  _status = 'Full';
                                  _subCategoryController.text = 'Heavy Cut Compound';
                                } else if (cat == InventoryCategory.hardware) {
                                  _status = 'In Service';
                                  _subCategoryController.text = 'Dual Action Polisher';
                                } else {
                                  _status = 'Active';
                                  _subCategoryController.text = 'Recipe';
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
                        if (_category == InventoryCategory.recipe) ...[
                          // RECIPE FORM: Clean & streamlined
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Formula / Recipe Name *',
                              hintText: 'e.g. German Ceramic Clear 2-Stage Formula',
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a formula name' : null,
                          ),
                          const SizedBox(height: 16),

                          // Stages List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FORMULA STAGES (${_recipeStages.length})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.5),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppTheme.primary),
                                label: const Text('+ Add Step', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                onPressed: () => _openRecipeStageEditor(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_recipeStages.isEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                                  label: const Text('Add your first formula step', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                                  onPressed: () => _openRecipeStageEditor(),
                                ),
                              ),
                            ),
                          ],

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
                                    onPressed: () => _openRecipeStageEditor(editIndex: i),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                    onPressed: () => setState(() => _recipeStages.removeAt(i)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          // HARDWARE & CHEMICALS FORM
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: _category == InventoryCategory.hardware ? 'Item Name / Model *' : 'Chemical / Product Name *',
                              hintText: _category == InventoryCategory.hardware
                                  ? 'e.g. Rupes LHR15 Mark III, Grit Guard Bucket'
                                  : 'e.g. Koch Chemie H9.02 Heavy Cut',
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
                                    hintText: 'e.g. Rupes, Koch Chemie, CarPro',
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
                                        ? 'e.g. Polisher, Wash Bucket, Mitt'
                                        : 'e.g. Heavy Cut Compound, Ceramic Coating',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _category == InventoryCategory.chemicals
                                    ? DropdownButtonFormField<String>(
                                        initialValue: const ['Full', 'Half', 'Empty'].contains(_status) ? _status : 'Full',
                                        decoration: const InputDecoration(labelText: 'Status'),
                                        dropdownColor: AppTheme.surface,
                                        items: const [
                                          DropdownMenuItem(value: 'Full', child: Text('Full', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                                          DropdownMenuItem(value: 'Half', child: Text('Half', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                                          DropdownMenuItem(value: 'Empty', child: Text('Empty', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _status = val);
                                        },
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue: const ['In Service', 'Repair', 'Optimal', 'Retired'].contains(_status) ? _status : 'In Service',
                                        decoration: const InputDecoration(labelText: 'Status'),
                                        dropdownColor: AppTheme.surface,
                                        items: const [
                                          DropdownMenuItem(value: 'In Service', child: Text('In Service', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                                          DropdownMenuItem(value: 'Repair', child: Text('Repair', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                                          DropdownMenuItem(value: 'Optimal', child: Text('Optimal', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                                          DropdownMenuItem(value: 'Retired', child: Text('Retired', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _status = val);
                                        },
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    labelText: 'Studio Location / Wall Bay',
                                    hintText: _category == InventoryCategory.chemicals ? 'e.g. Chemical Shelf Bay 1' : 'e.g. Bay 1 Tool Wall, Wash Bay Alpha',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Clean, unified Notes field
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            hintText: _category == InventoryCategory.hardware
                                ? 'e.g. Dual grit guard inserts for two-bucket wash, or primary 15mm DA polisher.'
                                : _category == InventoryCategory.chemicals
                                    ? 'e.g. Extremely low dusting formula with long working time on hard German clear coats.'
                                    : 'e.g. Proven heavy cut formula for rock-hard European factory clears.',
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
