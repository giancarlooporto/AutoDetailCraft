import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../services/job_repository.dart';

class BookingFlowScreen extends StatefulWidget {
  final UserProfile detailer;
  final ServicePackage? initialPackage;
  final JobRepository repository;

  const BookingFlowScreen({
    super.key,
    required this.detailer,
    this.initialPackage,
    required this.repository,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _currentStep = 0;

  // Form selections
  late ServicePackage _selectedPackage;
  VehicleSize _vehicleSize = VehicleSize.coupeSedan;
  ServiceLocationType _locationType = ServiceLocationType.mobile;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '9:00 AM - 12:00 PM';
  TeamMember? _selectedTeamMember; // Delegated / preferred detailer

  // Input Controllers
  final _vehicleModelCtrl = TextEditingController(text: '2024 Porsche 911 GT3');
  final _addressCtrl = TextEditingController(text: '742 Evergreen Terrace, Austin, TX');
  final _nameCtrl = TextEditingController(text: 'Giancarlo Oporto');
  final _phoneCtrl = TextEditingController(text: '(512) 555-0199');
  final _emailCtrl = TextEditingController(text: 'giancarlo@example.com');
  final _notesCtrl = TextEditingController();

  final List<String> _timeSlots = [
    '8:00 AM - 11:00 AM',
    '9:00 AM - 12:00 PM',
    '1:00 PM - 4:00 PM',
    '3:00 PM - 6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPackage = widget.initialPackage ??
        (widget.detailer.servicePackages.isNotEmpty
            ? widget.detailer.servicePackages.first
            : widget.repository.currentUser.servicePackages.first);
    _adjustSelectedSlotIfBlocked();
  }

  /// Check if a given time slot is already booked for this detailer on the selected date
  bool _isSlotBooked(String slot) {
    return widget.repository.bookings.any((b) {
      if (b.detailerId != widget.detailer.id) return false;
      if (b.status == BookingStatus.cancelled) return false;

      // Check date match
      final isSameDay = b.scheduledDate.year == _selectedDate.year &&
          b.scheduledDate.month == _selectedDate.month &&
          b.scheduledDate.day == _selectedDate.day;
      
      // If the booked package was multi-day (e.g. 2 days), block subsequent days
      final bookedDuration = b.package.estimatedDuration.toLowerCase();
      if (bookedDuration.contains('day')) {
        final match = RegExp(r'\d+').firstMatch(bookedDuration);
        final days = match != null ? int.parse(match.group(0)!) : 1;
        final diff = _selectedDate.difference(DateTime(b.scheduledDate.year, b.scheduledDate.month, b.scheduledDate.day)).inDays;
        if (diff >= 0 && diff < days) {
          return true; // Entire day is blocked by a multi-day job
        }
      }

      return isSameDay && b.scheduledTimeSlot == slot;
    });
  }

  /// Automatically select first available unblocked slot if currently selected is booked
  void _adjustSelectedSlotIfBlocked() {
    if (_isSlotBooked(_selectedTimeSlot)) {
      for (final slot in _timeSlots) {
        if (!_isSlotBooked(slot)) {
          _selectedTimeSlot = slot;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _vehicleModelCtrl.dispose();
    _addressCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    return _selectedPackage.basePrice * _vehicleSize.priceMultiplier;
  }

  double get _depositAmount {
    return (_calculatedTotal * 0.20).clamp(50.0, 200.0);
  }

  void _confirmAndSubmitBooking() {
    final booking = BookingAppointment(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      detailerId: widget.detailer.id,
      detailerName: _selectedTeamMember != null
          ? '${widget.detailer.businessName} (${_selectedTeamMember!.name})'
          : widget.detailer.displayName,
      detailerBusinessName: widget.detailer.businessName,
      detailerAvatar: _selectedTeamMember?.avatarUrl ?? widget.detailer.avatarUrl,
      clientName: _nameCtrl.text.trim(),
      clientPhone: _phoneCtrl.text.trim(),
      clientEmail: _emailCtrl.text.trim(),
      vehicleYearMakeModel: _vehicleModelCtrl.text.trim(),
      vehicleSize: _vehicleSize,
      package: _selectedPackage,
      locationType: _locationType,
      clientAddress: _locationType == ServiceLocationType.mobile
          ? _addressCtrl.text.trim()
          : '${widget.detailer.businessName} Studio, ${widget.detailer.location}',
      scheduledDate: _selectedDate,
      scheduledTimeSlot: _selectedTimeSlot,
      totalPrice: _calculatedTotal,
      depositAmount: _depositAmount,
      status: BookingStatus.confirmed,
      clientNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      warrantyPassportId: 'ADC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    widget.repository.addBooking(booking);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Booking Reserved!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your appointment with ${widget.detailer.businessName} has been reserved.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            if (_selectedTeamMember != null) ...[
              const SizedBox(height: 6),
              Text(
                'Assigned Specialist: ${_selectedTeamMember!.name} (${_selectedTeamMember!.roleTitle})',
                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _receiptRow('Service', _selectedPackage.title),
                  const SizedBox(height: 6),
                  _receiptRow('Vehicle', _vehicleModelCtrl.text),
                  const SizedBox(height: 6),
                  _receiptRow('Date', DateFormat('EEE, MMM d, yyyy').format(_selectedDate)),
                  const SizedBox(height: 6),
                  _receiptRow('Time', _selectedTimeSlot),
                  const Divider(color: AppTheme.border, height: 16),
                  _receiptRow('Total Price', '\$${_calculatedTotal.toStringAsFixed(0)}', isBold: true),
                  const SizedBox(height: 4),
                  _receiptRow('Deposit Reserved', '\$${_depositAmount.toStringAsFixed(0)} (Secure Escrow)', color: AppTheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🛡️ Covered by AutoDetailCraft Guarantee & Pre-Inspection Protection.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('View in My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book Detailing Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'with ${widget.detailer.businessName}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                _stepIndicator(0, '1. Package'),
                _stepDivider(0),
                _stepIndicator(1, '2. Vehicle & Date'),
                _stepDivider(1),
                _stepIndicator(2, '3. Checkout'),
              ],
            ),
          ),

          // Step Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(),
            ),
          ),

          // Bottom Price & Continue Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('TOTAL ESTIMATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      Text(
                        '\$${_calculatedTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_currentStep < 2) {
                        setState(() => _currentStep++);
                      } else {
                        _confirmAndSubmitBooking();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentStep == 2 ? 'Reserve & Book' : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isDone
              ? AppTheme.primary
              : isActive
                  ? AppTheme.primary.withAlpha(50)
                  : AppTheme.surfaceLight,
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.black)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? AppTheme.primary : AppTheme.border,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPackageSelectionStep();
      case 1:
        return _buildVehicleAndDateStep();
      case 2:
        return _buildCheckoutReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPackageSelectionStep() {
    final packages = widget.detailer.servicePackages.isNotEmpty
        ? widget.detailer.servicePackages
        : widget.repository.currentUser.servicePackages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a Detailing Package',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the level of correction and protection for your vehicle.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ...packages.map((pkg) {
          final isSelected = _selectedPackage.id == pkg.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedPackage = pkg),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pkg.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'From \$${pkg.basePrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(pkg.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: pkg.includes.take(3).map((item) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(item, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVehicleAndDateStep() {
    final team = widget.detailer.teamMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select Hired Specialist if available under this company
        if (team.isNotEmpty) ...[
          const Text('Select Preferred Detail Specialist (Optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Choose a dedicated team member from this shop:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedTeamMember = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTeamMember == null ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _selectedTeamMember == null ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(
                    'First Available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedTeamMember == null ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...team.map((m) {
                final isSelected = _selectedTeamMember?.id == m.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTeamMember = m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 12, backgroundImage: NetworkImage(m.avatarUrl)),
                        const SizedBox(width: 6),
                        Text(
                          m.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],

        const Text('Vehicle Size', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: VehicleSize.values.map((size) {
            final isSelected = _vehicleSize == size;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _vehicleSize = size),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(size.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        size.label.split(' / ').first,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        size.priceMultiplier == 1.0 ? 'Standard' : '+${((size.priceMultiplier - 1.0) * 100).toInt()}%',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _vehicleModelCtrl,
          decoration: const InputDecoration(
            labelText: 'Car Year, Make, Model (e.g. 2024 Porsche 911)',
            prefixIcon: Icon(Icons.car_repair_rounded),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Service Location Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: ServiceLocationType.values.map((type) {
            final isSelected = _locationType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _locationType = type),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(type.icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        type == ServiceLocationType.mobile ? 'Mobile (Home/Work)' : 'Drop-off at Shop',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_locationType == ServiceLocationType.mobile) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Your Street Address & Zip Code',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Select Date & Time Window', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _adjustSelectedSlotIfBlocked();
                    });
                  }
                },
                child: const Text('Change Date', style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((slot) {
            final isBooked = _isSlotBooked(slot);
            final isSelected = _selectedTimeSlot == slot && !isBooked;

            return Tooltip(
              message: isBooked ? 'Detailer already booked for this time window' : 'Available',
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: isBooked ? TextDecoration.lineThrough : null,
                        color: isBooked
                            ? Colors.grey.shade600
                            : (isSelected ? Colors.black : Colors.white),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isBooked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent.withAlpha(100), width: 0.8),
                        ),
                        child: const Text(
                          'BOOKED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                checkmarkColor: Colors.black,
                showCheckmark: isSelected,
                side: BorderSide(
                  color: isBooked
                      ? Colors.redAccent.withAlpha(50)
                      : (isSelected ? AppTheme.primary : AppTheme.border),
                ),
                onSelected: isBooked
                    ? null
                    : (val) {
                        if (val) setState(() => _selectedTimeSlot = slot);
                      },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckoutReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Client Contact Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Mobile Phone (For SMS updates)', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email Address (For Warranty Receipt)', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Special requests / paint condition notes (Optional)'),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('AutoDetailCraft Escrow & Guarantee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• 24-Hour Free Cancellation & No-Show Protection\n• Mandatory Pre-Inspection Photo Check-in\n• Digital Warranty Certificate logged upon completion\n• Funds released only after service is verified',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
              ),
              const Divider(color: AppTheme.border, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Due Today (Deposit Hold):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('\$${_depositAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining Balance at Completion:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  Text('\$${(_calculatedTotal - _depositAmount).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
