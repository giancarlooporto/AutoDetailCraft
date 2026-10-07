import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../models/inventory_item.dart';
import '../core/theme/app_theme.dart';

class ServicePackageTemplate {
  final String title;
  final double price;
  final String durationValue;
  final String durationUnit; // 'minutes', 'hours', 'days'
  final String description;
  final List<String> includes;

  const ServicePackageTemplate({
    required this.title,
    required this.price,
    required this.durationValue,
    required this.durationUnit,
    required this.description,
    required this.includes,
  });
}

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

  String _durationUnit = 'hours'; // 'minutes', 'hours', or 'days'
  bool _isPopular = false;
  String? _linkedRecipeId;
  String? _linkedRecipeName;
  String? _suggestedRecipeTitle;

  static const List<ServicePackageTemplate> templates = [
    ServicePackageTemplate(
      title: 'Interior Detail',
      price: 180,
      durationValue: '3',
      durationUnit: 'hours',
      description: 'Complete interior rejuvenation and sanitization. Lifts deep dirt, body oils, and odors to restore an OEM matte factory finish on all cabin surfaces.',
      includes: [
        'High-power vacuum of carpets, trunk & crevices',
        'Deep steam cleaning of dash, console & door panels',
        'Shampoo extraction of cloth upholstery & floor mats',
        'pH-neutral leather cleaning & conditioning balm',
        'Streak-free interior glass & rear-view cleaning',
        'UV matte protection shield on plastics & vinyl',
        'Antimicrobial HVAC vent blowout & odor neutralizer',
      ],
    ),
    ServicePackageTemplate(
      title: 'Exterior Detail & Decon',
      price: 160,
      durationValue: '3',
      durationUnit: 'hours',
      description: 'Multi-stage exterior decontamination wash that dissolves road grime, embedded iron fallout, and mineral deposits, sealed with a 6-month ceramic spray shield.',
      includes: [
        'High-lubricity pH-neutral foam pre-wash & 2-bucket hand wash',
        'Deep wheel face, inner barrel & brake caliper clean',
        'Chemical iron & fallout decontamination spray',
        'Fine synthetic clay bar mechanical decontamination',
        'Touchless filtered warm-air blow dry & microfiber finish',
        'Hydrophobic 6-month ceramic spray sealant applied',
        'Satin tire dressing & exterior trim UV restoration',
      ],
    ),
    ServicePackageTemplate(
      title: 'Full Detail (In & Out)',
      price: 280,
      durationValue: '5',
      durationUnit: 'hours',
      description: 'Our complete vehicle transformation package combining an intensive interior sanitization with a full exterior decontamination wash and paint gloss sealant.',
      includes: [
        'Full exterior snow foam hand wash & wheel barrels',
        'Iron fallout decontamination & clay bar smooth treatment',
        'Deep carpet, floor mat & seat shampoo extraction',
        'Steam sanitization of high-touch dash, consoles & cup holders',
        'Leather cleanse, conditioning & UV satin dashboard dressing',
        'High-gloss ceramic spray sealant (4–6 month protection)',
        'Crystal-clear interior & exterior glass clarity polish',
        'Tire shine & matte exterior plastics dressing',
      ],
    ),
    ServicePackageTemplate(
      title: '1-Stage Paint Correction',
      price: 450,
      durationValue: '6',
      durationUnit: 'hours',
      description: 'Precision single-step machine polish designed to eliminate 50–70% of light swirl marks, haze, and wash marring while significantly enhancing optical clarity and gloss.',
      includes: [
        'Multi-stage foam wash & iron/clay decontamination',
        'Ultrasonic digital paint depth gauge inspection',
        'Delicate trim, rubber & badge tape masking',
        'Single-step dual-action machine polish & refinement pad',
        'Elimination of 50–70% of light swirl marks and haze',
        'Panel wipe alcohol (IPA) prep to verify true finish',
        '12-month synthetic ceramic paint sealant applied',
      ],
    ),
    ServicePackageTemplate(
      title: '2-Stage Multi-Cut Polish',
      price: 750,
      durationValue: '1',
      durationUnit: 'days',
      description: 'Intensive compound and jeweling polish process eliminating 85–95% of moderate-to-deep scratches, etching, and swirl marks for a mirror-like show-car reflection.',
      includes: [
        'Full decontamination wash (iron spray, tar remover, clay mitt)',
        'Digital paint gauge mapping across all metal and composite panels',
        'Full trim, badge, and edge masking protection',
        'Stage 1: Heavy cutting microfiber compound to level defects',
        'Stage 2: Micro-finishing foam jeweling polish for high clarity',
        'Elimination of 85–95% of swirl marks, scratches & wash marring',
        'Full IPA solvent panel wipe inspection under multi-spectrum LED',
        '12-month ceramic gloss seal protective layer',
      ],
    ),
    ServicePackageTemplate(
      title: 'Ceramic Coating (3-Year)',
      price: 950,
      durationValue: '1',
      durationUnit: 'days',
      description: 'Professional 9H nano-ceramic coating creating a permanent hard glass bond over your paint. Drastically repels water, road salt, bird drops, and UV degradation for 3 years.',
      includes: [
        'Comprehensive decon wash, iron melt & synthetic clay treatment',
        'Single-stage machine polish enhancement for maximum bonding',
        'Dual alcohol surface prep wipe down',
        'Professional 9H ceramic coating applied to all painted surfaces',
        'Hydrophobic glass rain repellent on windshield & front windows',
        'Wheel face ceramic barrier coating',
        'IR heat lamp curing session & CARFAX warranty registration',
      ],
    ),
    ServicePackageTemplate(
      title: 'Ceramic Coating (5-Year)',
      price: 1600,
      durationValue: '2',
      durationUnit: 'days',
      description: 'Our flagship multi-layer ceramic defense package featuring an ultra-dense 9H+ base layer paired with a slick sacrificial topcoat for maximum chemical resistance, self-cleaning, and candy gloss.',
      includes: [
        'Full decontamination wash & chemical iron bath',
        'Multi-stage paint correction to remove 90%+ swirls & defects',
        'Base Layer: Ultra-dense 9H+ hardness ceramic nano-composite',
        'Top Layer: Ultra-hydrophobic slick gloss sacrificial topper',
        'Ceramic coating applied to all painted surfaces & door jambs',
        'High-temp wheel faces & exhaust tips ceramic coating',
        'Full glass hydrophobic ceramic coating treatment',
        '24-hour climate-controlled IR curing & annual inspection warranty',
      ],
    ),
    ServicePackageTemplate(
      title: 'Paint Protection Film (PPF)',
      price: 2200,
      durationValue: '2',
      durationUnit: 'days',
      description: 'High-impact 8-mil self-healing polyurethane film installed on vulnerable strike zones. Completely stops rock chips, road sand, bug acid, and scratches before they touch your paint.',
      includes: [
        'Multi-stage decontamination wash & clay bar surface prep',
        'Light paint correction polish to eliminate sub-film defects',
        'Full computer-cut template plot & edge wrapping where possible',
        'Full front clip coverage: Bumper, full hood, fenders, mirrors & headlights',
        'Optical clarity 8-mil self-healing TPU polyurethane film',
        'Hydrophobic top-coat infused for easy maintenance washes',
        'Heat-gun edge inspection & post-installation cure check',
        '10-year manufacturer warranty against yellowing or peeling',
      ],
    ),
    ServicePackageTemplate(
      title: 'Headlight Restoration',
      price: 110,
      durationValue: '1',
      durationUnit: 'hours',
      description: 'Multi-stage wet-sanding and compound refinement removing yellowing and cloudy oxidation from polycarbonate lenses, sealed with an OEM UV clear coat.',
      includes: [
        'Fender and bumper surrounding paint protective masking',
        'Progressive wet sanding (1000, 2000, 3000 grit) to remove oxidation',
        'Rotary compounding & jeweling polish to restore crystal clarity',
        'Solvent wipe to remove residue',
        'OEM-grade high-gloss UV blocking sealant applied',
      ],
    ),
    ServicePackageTemplate(
      title: 'Engine Bay Detail',
      price: 90,
      durationValue: '1',
      durationUnit: 'hours',
      description: 'Safe, low-moisture degreasing and detailed brush work across the engine bay, finished with a heat-resistant OEM non-silicone satin dress.',
      includes: [
        'Electrical alternator, battery & intake sensitive component masking',
        'Foaming citrus engine degreaser soak & agitation with soft brushes',
        'Low-moisture, regulated pressure rinse',
        'Filtered warm-air dry of all electrical connectors and valleys',
        'Heat-resistant OEM non-silicone satin matte plastic and hose dressing',
        'Underside hood liner wipe-down and latch grease touch-up',
      ],
    ),
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
    
    // Parse duration string e.g. "3-4 hrs", "45 mins", or "2 days"
    String initialVal = '3';
    String initialUnit = 'hours';
    if (p != null) {
      final dur = p.estimatedDuration.toLowerCase();
      if (dur.contains('day')) {
        initialUnit = 'days';
        final match = RegExp(r'\d+').firstMatch(dur);
        if (match != null) initialVal = match.group(0)!;
      } else if (dur.contains('min')) {
        initialUnit = 'minutes';
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

  void _applyTemplate(ServicePackageTemplate t) {
    setState(() {
      _titleController.text = t.title;
      _priceController.text = t.price.toStringAsFixed(0);
      _durationValueController.text = t.durationValue;
      _durationUnit = t.durationUnit;
      _descController.text = t.description;
      _includesController.text = t.includes.join('\n');
      _suggestedRecipeTitle = null;
    });
  }

  void _importRecipe(InventoryItem recipe) {
    setState(() {
      _linkedRecipeId = recipe.id;
      _linkedRecipeName = recipe.name;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = recipe.name;
        _suggestedRecipeTitle = null;
      } else if (_titleController.text.trim() != recipe.name) {
        _suggestedRecipeTitle = recipe.name;
      }
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
        : _durationUnit == 'minutes'
            ? '$durNum mins'
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
                      'QUICK TEMPLATES (PRE-FILLS ALL DETAILS & STEPS)',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: templates.map((tmpl) {
                        final isSelected = _titleController.text.trim() == tmpl.title;
                        return InkWell(
                          onTap: () => _applyTemplate(tmpl),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary.withAlpha(40) : AppTheme.surfaceLight.withAlpha(80),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                                width: isSelected ? 1.2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_rounded, size: 12, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  tmpl.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
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
                    if (_suggestedRecipeTitle != null && _titleController.text.trim() != _suggestedRecipeTitle) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _titleController.text = _suggestedRecipeTitle!;
                              _suggestedRecipeTitle = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primary.withAlpha(80)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Use Recipe Title: "${_suggestedRecipeTitle!}"',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        // Unit Selector (Hours vs Days vs Minutes)
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
                                      DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
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
