import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../models/inventory_item.dart';
import '../core/theme/app_theme.dart';

class ServicePackageEditorDialog extends StatefulWidget {
  final ServicePackage? package;
  final List<InventoryItem> availableRecipes;
  final Function(ServicePackage) onSave;
  final VoidCallback? onDelete;

  const ServicePackageEditorDialog({
    super.key,
    this.package,
    this.availableRecipes = const [],
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    ServicePackage? package,
    List<InventoryItem> availableRecipes = const [],
    required Function(ServicePackage) onSave,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ServicePackageEditorDialog(
        package: package,
        availableRecipes: availableRecipes,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ServicePackageEditorDialog> createState() => _ServicePackageEditorDialogState();
}

class _ServicePackageEditorDialogState extends State<ServicePackageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _durationValueController;
  late TextEditingController _includesController;

  String _durationUnit = 'hours'; // 'hours' or 'days'
  bool _isPopular = false;
  String? _linkedRecipeId;
  String? _linkedRecipeName;

  final List<String> _suggestedCategories = [
    'Interior Detail',
    'Exterior Detail & Decon',
    'Full Detail (In & Out)',
    '1-Stage Paint Correction',
    '2-Stage Multi-Cut Polish',
    'Ceramic Coating (3-Year)',
    'Ceramic Coating (5-Year)',
    'Paint Protection Film (PPF)',
    'Headlight Restoration',
    'Engine Bay Detail',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? p.basePrice.toStringAsFixed(0) : '150');
    _linkedRecipeId = p?.recipeId;
    _linkedRecipeName = p?.recipeName;
    
    // Parse duration string e.g. "3-4 hrs" or "2 days"
    String initialVal = '3';
    String initialUnit = 'hours';
    if (p != null) {
      final dur = p.estimatedDuration.toLowerCase();
      if (dur.contains('day')) {
        initialUnit = 'days';
        final match = RegExp(r'\d+').firstMatch(dur);
        if (match != null) initialVal = match.group(0)!;
      } else {
        initialUnit = 'hours';
        final match = RegExp(r'\d+').firstMatch(dur);
        if (match != null) initialVal = match.group(0)!;
      }
    }
    _durationValueController = TextEditingController(text: initialVal);
    _durationUnit = initialUnit;

    _includesController = TextEditingController(
      text: p?.includes.join('\n') ?? 'Hand wash & wheel deep clean\nIron decon & clay bar\nInterior vacuum & steam wipe',
    );
    _isPopular = p?.isPopular ?? false;
  }

  void _importRecipe(InventoryItem recipe) {
    setState(() {
      _linkedRecipeId = recipe.id;
      _linkedRecipeName = recipe.name;
      if (recipe.recipeStages.isNotEmpty) {
        final steps = recipe.recipeStages.map((s) {
          final title = s.stageName.trim();
          if (title.isNotEmpty) return title;
          final parts = <String>[];
          if (s.machine.trim().isNotEmpty) parts.add(s.machine.trim());
          if (s.chemical.trim().isNotEmpty) parts.add(s.chemical.trim());
          return parts.isNotEmpty ? parts.join(' + ') : 'Standard Treatment Stage';
        }).toList();
        _includesController.text = steps.join('\n');
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported "${recipe.name}" steps (${recipe.recipeStages.length} stages)'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _durationValueController.dispose();
    _includesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final includesList = _includesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final durNum = int.tryParse(_durationValueController.text.trim()) ?? 3;
    final durString = _durationUnit == 'days'
        ? (durNum == 1 ? '1 full day' : '$durNum days')
        : (durNum == 1 ? '1 hour' : '$durNum hours');

    final updatedPackage = ServicePackage(
      id: widget.package?.id ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      basePrice: double.tryParse(_priceController.text.trim()) ?? 150.0,
      estimatedDuration: durString,
      includes: includesList.isNotEmpty ? includesList : ['Professional application & guarantee'],
      isPopular: _isPopular,
      recipeId: _linkedRecipeId,
      recipeName: _linkedRecipeName,
    );

    widget.onSave(updatedPackage);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.package != null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
                        child: const Icon(Icons.design_services_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit Service Package' : 'Create Service Package',
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

              // Scrollable Inputs
              Expanded(
                child: ListView(
                  children: [
                    // Quick category suggestions chips
                    const Text(
                      'QUICK TEMPLATES',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestedCategories.map((cat) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _titleController.text = cat;
                              if (cat.contains('Ceramic') || cat.contains('PPF')) {
                                _durationUnit = 'days';
                                _durationValueController.text = '2';
                                _priceController.text = '899';
                              } else if (cat.contains('Correction')) {
                                _durationUnit = 'hours';
                                _durationValueController.text = '8';
                                _priceController.text = '450';
                              } else {
                                _durationUnit = 'hours';
                                _durationValueController.text = '3';
                                _priceController.text = '180';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withAlpha(80),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(cat, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Package Title
                    const Text('Package Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('e.g. 2-Stage Paint Correction & Ceramic Seal'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 14),

                    // Price & Duration Row
                    Row(
                      children: [
                        // Base Price
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Base Price (\$ USD) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: _inputDecoration('150', prefix: '\$ '),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter price';
                                  if (double.tryParse(val.trim()) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Duration Value
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Duration *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _durationValueController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: _inputDecoration('3'),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter duration';
                                  if (int.tryParse(val.trim()) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unit Selector (Hours vs Days)
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _durationUnit,
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'hours', child: Text('Hours')),
                                      DropdownMenuItem(value: 'days', child: Text('Days')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _durationUnit = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description
                    const Text('Service Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration('Explain what results the client can expect...'),
                    ),
                    const SizedBox(height: 14),

                    // Included Features
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'What’s Included (Treatments & Steps)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.availableRecipes.isNotEmpty)
                          PopupMenuButton<InventoryItem>(
                            tooltip: 'Import from Studio Recipe',
                            color: AppTheme.surfaceLight,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            onSelected: _importRecipe,
                            itemBuilder: (context) => widget.availableRecipes.map((r) => PopupMenuItem<InventoryItem>(
                              value: r,
                              child: Row(
                                children: [
                                  const Icon(Icons.science_outlined, size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${r.recipeStages.length} steps',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            )).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primary.withAlpha(80)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 14, color: AppTheme.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Import Recipe',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _includesController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration('e.g. Foam pre-wash\nIron decontamination & Clay bar\n1-stage machine finish polish'),
                    ),
                    if (_linkedRecipeName != null && _linkedRecipeName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.science_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Linked Studio Recipe: $_linkedRecipeName',
                                style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _linkedRecipeId = null;
                                  _linkedRecipeName = null;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.close_rounded, size: 15, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Popular Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: _isPopular ? Colors.amber : AppTheme.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Mark as Popular / Most Booked', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text('Highlights this card with a glowing accent in your studio', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isPopular,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (val) => setState(() => _isPopular = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.of(context).pop();
                      },
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
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Create Package',
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

  InputDecoration _inputDecoration(String hint, {String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppTheme.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
    );
  }
}
