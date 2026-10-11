import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/team_member.dart';
import '../models/calendar_availability_block.dart';
import '../services/job_repository.dart';

class BookingFlowScreen extends StatefulWidget {
  final UserProfile detailer;
  final ServicePackage? initialPackage;
  final DateTime? initialDate;
  final JobRepository repository;

  const BookingFlowScreen({
    super.key,
    required this.detailer,
    this.initialPackage,
    this.initialDate,
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
  late DateTime _calendarDisplayMonth;
  String _selectedTimeSlot = '9:00 AM - 12:00 PM';
  TeamMember? _selectedTeamMember; // Delegated / preferred detailer

  // Input Controllers
  final _vehicleModelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<String> get _timeSlots {
    final slots = widget.repository.getTimeSlotsForDate(_selectedDate, detailerId: widget.detailer.id);
    if (slots.isNotEmpty) return slots;
    return DetailerCalendarPreferences.defaultTimeSlots;
  }

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    _calendarDisplayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final user = widget.repository.currentUser;
    if (user.displayName.isNotEmpty) {
      _nameCtrl.text = user.displayName;
    }
    if (user.phone.isNotEmpty) {
      _phoneCtrl.text = user.phone;
    }
    if (user.username.isNotEmpty) {
      _emailCtrl.text = user.username.contains('@') ? user.username : '${user.username}@example.com';
    }
    if (user.location.isNotEmpty) {
      _addressCtrl.text = user.location;
    }
    if (user.myGarage.isNotEmpty) {
      final v = user.myGarage.first;
      _vehicleModelCtrl.text = '${v.year} ${v.make} ${v.model}'.trim();
    } else {
      _vehicleModelCtrl.text = '2024 Porsche 911 GT3';
    }

    _selectedPackage = widget.initialPackage ??
        (widget.detailer.servicePackages.isNotEmpty
            ? widget.detailer.servicePackages.first
            : widget.repository.currentUser.servicePackages.first);

    if (_timeSlots.isNotEmpty && !_timeSlots.contains(_selectedTimeSlot)) {
      _selectedTimeSlot = _timeSlots.first;
    }
    _adjustSelectedSlotIfBlocked();
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {
        _adjustSelectedSlotIfBlocked();
      });
    }
  }

  /// Check if slot is already reserved by another confirmed client booking or conflicting
  bool _isSlotBookedByOtherAppointment(String slot) {
    return widget.repository.isSlotConflictedByBooking(
      _selectedDate,
      slot,
      detailerId: widget.detailer.id,
      teamMemberId: _selectedTeamMember?.id,
    );
  }

  /// Returns reason string if slot is unavailable, or null if open
  String? _getSlotUnavailableReason(String slot) {
    if (widget.repository.isDateRecurringDayOff(_selectedDate, detailerId: widget.detailer.id)) {
      return 'Shop Closed (Recurring Weekly Day Off)';
    }
    final hours = widget.repository.getHoursForDate(_selectedDate, detailerId: widget.detailer.id);
    if (!hours.isOpen) {
      return 'Studio Closed (Day Off in Operating Hours)';
    }
    if (widget.repository.isDateFullyBlocked(widget.detailer.id, _selectedDate)) {
      return 'Day Blocked by Detailer';
    }
    if (_selectedTeamMember != null) {
      if (!widget.repository.isMemberOnDutyOnDate(_selectedTeamMember!.id, _selectedDate, detailerId: widget.detailer.id)) {
        return '${_selectedTeamMember!.name} is Off Duty on this Date';
      }
      if (widget.repository.isSlotExplicitlyBlocked(widget.detailer.id, _selectedDate, slot, teamMemberId: _selectedTeamMember!.id)) {
        return '${_selectedTeamMember!.name} Unavailable for this Time Window';
      }
    } else {
      if (widget.repository.isSlotBlocked(widget.detailer.id, _selectedDate, slot)) {
        return 'Time Window Blocked by Detailer';
      }
    }
    if (!widget.repository.isSlotWithinOperatingHours(_selectedDate, slot, detailerId: widget.detailer.id)) {
      return 'Outside Business Operating Hours';
    }
    if (!widget.repository.isSlotWithinLeadTime(_selectedDate, slot, detailerId: widget.detailer.id)) {
      final leadHours = widget.repository.getCalendarPreferences(detailerId: widget.detailer.id).advanceNoticeHours;
      return 'Requires ${leadHours}h Minimum Advance Notice';
    }
    if (_isSlotBookedByOtherAppointment(slot)) {
      return _selectedTeamMember != null
          ? '${_selectedTeamMember!.name} is Booked for this Window'
          : 'Shop Fully Booked for this Time Window';
    }
    return null;
  }

  /// Check if a given time slot is unavailable for any reason
  bool _isSlotBooked(String slot) {
    return _getSlotUnavailableReason(slot) != null;
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
    widget.repository.removeListener(_onRepoChanged);
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
    final conflictReason = _getSlotUnavailableReason(_selectedTimeSlot);
    if (conflictReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot complete reservation: $conflictReason. Please choose another date or time.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final booking = BookingAppointment(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      clientId: widget.repository.isLoggedIn ? widget.repository.currentUser.id : null,
      detailerId: widget.detailer.id,
      assignedTeamMemberId: _selectedTeamMember?.id,
      assignedTeamMemberName: _selectedTeamMember?.name,
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
      status: widget.repository.calendarPreferences.autoConfirmBookings
          ? BookingStatus.confirmed
          : BookingStatus.pending,
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
                      if (_currentStep == 1 && _isSlotBooked(_selectedTimeSlot)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_getSlotUnavailableReason(_selectedTimeSlot) ?? 'Selected slot is unavailable. Please choose another date or time.'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
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
                onTap: () {
                  setState(() {
                    _selectedTeamMember = null;
                    _adjustSelectedSlotIfBlocked();
                  });
                },
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
                final isOff = !widget.repository.isMemberOnDutyOnDate(m.id, _selectedDate, detailerId: widget.detailer.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTeamMember = m;
                      _adjustSelectedSlotIfBlocked();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withAlpha(25)
                          : (isOff ? AppTheme.surfaceLight.withAlpha(80) : AppTheme.surface),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : (isOff ? AppTheme.border.withAlpha(100) : AppTheme.border),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: isOff ? 0.5 : 1.0,
                          child: CircleAvatar(radius: 12, backgroundImage: NetworkImage(m.avatarUrl)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.primary
                                : (isOff ? AppTheme.textMuted : AppTheme.textPrimary),
                          ),
                        ),
                        if (isOff) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OFF',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Date & Time Window', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'Live availability direct from ${widget.detailer.businessName}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
              label: const Text('Change Date', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
              onPressed: () async {
                final now = DateUtils.dateOnly(DateTime.now());
                final initial = _selectedDate.isBefore(now) ? now : DateUtils.dateOnly(_selectedDate);
                final horizonDays = widget.repository.getCalendarPreferences(detailerId: widget.detailer.id).maxAdvanceBookingDays;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: now,
                  lastDate: now.add(Duration(days: horizonDays > 0 ? horizonDays : 60)),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _calendarDisplayMonth = DateTime(picked.year, picked.month, 1);
                    _adjustSelectedSlotIfBlocked();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Interactive Calendar Grid (mirrors Detailer Workbench calendar)
        _buildCustomerCalendarMonthView(),
        const SizedBox(height: 12),

        // Selected Day Details Banner
        _buildSelectedDayBanner(),
        const SizedBox(height: 14),

        const Text('Select Arrival Window', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((slot) {
            final reason = _getSlotUnavailableReason(slot);
            final isUnavailable = reason != null;
            final isSelected = _selectedTimeSlot == slot && !isUnavailable;

            String badgeText = 'UNAVAILABLE';
            if (reason != null) {
              if (reason.contains('Booked')) {
                badgeText = 'BOOKED';
              } else if (reason.contains('Notice')) {
                badgeText = 'LEAD TIME';
              } else if (reason.contains('Blocked')) {
                badgeText = 'BLOCKED';
              } else if (reason.contains('Closed') || reason.contains('Operating')) {
                badgeText = 'CLOSED';
              }
            }

            return Tooltip(
              message: reason ?? 'Available for Booking',
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: isUnavailable ? TextDecoration.lineThrough : null,
                        color: isUnavailable
                            ? Colors.grey.shade600
                            : (isSelected ? Colors.black : Colors.white),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isUnavailable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent.withAlpha(100), width: 0.8),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
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
                  color: isUnavailable
                      ? Colors.redAccent.withAlpha(50)
                      : (isSelected ? AppTheme.primary : AppTheme.border),
                ),
                onSelected: isUnavailable
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

  Widget _buildCustomerCalendarMonthView() {
    final year = _calendarDisplayMonth.year;
    final month = _calendarDisplayMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOfMonth = DateTime(year, month, 1);
    final leadingBlanks = (firstDayOfMonth.weekday - 1);
    final monthName = DateFormat('MMMM yyyy').format(_calendarDisplayMonth);
    final today = DateUtils.dateOnly(DateTime.now());
    final prefs = widget.repository.getCalendarPreferences(detailerId: widget.detailer.id);
    final horizonDays = prefs.maxAdvanceBookingDays > 0 ? prefs.maxAdvanceBookingDays : 60;
    final maxDate = today.add(Duration(days: horizonDays));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous Month',
                onPressed: () {
                  setState(() {
                    _calendarDisplayMonth = DateTime(year, month - 1, 1);
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Text(
                    monthName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Next Month',
                onPressed: () {
                  setState(() {
                    _calendarDisplayMonth = DateTime(year, month + 1, 1);
                  });
                },
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  setState(() {
                    final now = DateTime.now();
                    _calendarDisplayMonth = DateTime(now.year, now.month, 1);
                    _selectedDate = now;
                    _adjustSelectedSlotIfBlocked();
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day of Week Header
          Row(
            children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 7-Column Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.85,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final day = index - leadingBlanks + 1;
              final cellDate = DateTime(year, month, day);
              final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
              final isToday = DateUtils.isSameDay(cellDate, today);
              final isPast = cellDate.isBefore(today);
              final isBeyondHorizon = cellDate.isAfter(maxDate);
              final isDisabled = isPast || isBeyondHorizon;

              final isRecurringOff = widget.repository.isDateRecurringDayOff(cellDate, detailerId: widget.detailer.id);
              final isFullyBlocked = widget.repository.isDateFullyBlocked(widget.detailer.id, cellDate);
              final dayBookings = widget.repository.getBookingsForDate(cellDate, detailerId: widget.detailer.id);
              final isFullyBooked = !isFullyBlocked && !isRecurringOff && widget.repository.isDateFullyBooked(cellDate, detailerId: widget.detailer.id);
              final dayBlocks = widget.repository.getBlocksForDate(cellDate, detailerId: widget.detailer.id);
              final isPartiallyBlocked = !isFullyBlocked && dayBlocks.any((b) => b.blockedSlots.isNotEmpty);

              Color cellBg = AppTheme.surface;
              Color cellBorder = AppTheme.border;
              if (isSelected) {
                cellBg = AppTheme.primary.withAlpha(40);
                cellBorder = AppTheme.primary;
              } else if (isFullyBlocked) {
                cellBg = Colors.redAccent.withAlpha(20);
                cellBorder = Colors.redAccent.withAlpha(80);
              } else if (isFullyBooked) {
                cellBg = Colors.amber.withAlpha(20);
                cellBorder = Colors.amber.withAlpha(80);
              } else if (isRecurringOff) {
                cellBg = AppTheme.surfaceLight.withAlpha(40);
                cellBorder = AppTheme.border.withAlpha(50);
              } else if (isDisabled) {
                cellBg = AppTheme.surface.withAlpha(30);
                cellBorder = AppTheme.border.withAlpha(30);
              } else if (isToday) {
                cellBorder = AppTheme.primary.withAlpha(100);
              }

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = cellDate;
                          _adjustSelectedSlotIfBlocked();
                        });
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: cellBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cellBorder,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                                color: isDisabled
                                    ? Colors.grey.shade700
                                    : (isSelected
                                        ? AppTheme.primary
                                        : (isRecurringOff ? AppTheme.textMuted : Colors.white)),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (isFullyBlocked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(40),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('BLK', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ),
                        ] else if (isFullyBooked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(40),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('FULL', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ),
                        ] else if (dayBookings.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withAlpha(40),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('${dayBookings.length}bk', style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          ),
                        ] else if (isRecurringOff) ...[
                          const Text('OFF', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                        ] else if (isPartiallyBlocked) ...[
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ] else if (!isDisabled) ...[
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withAlpha(150),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),

          // Calendar Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendPill(Colors.greenAccent, 'Available'),
              _legendPill(Colors.amber, 'Booked / Full'),
              _legendPill(Colors.redAccent, 'Blocked'),
              _legendPill(AppTheme.textMuted, 'Shop Closed (Off)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendPill(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSelectedDayBanner() {
    final dayHours = widget.repository.getHoursForDate(_selectedDate, detailerId: widget.detailer.id);
    final isRecurringOff = widget.repository.isDateRecurringDayOff(_selectedDate, detailerId: widget.detailer.id);
    final isDayOff = isRecurringOff || !dayHours.isOpen;
    final isFullyBlocked = widget.repository.isDateFullyBlocked(widget.detailer.id, _selectedDate);
    final isFullyBooked = !isFullyBlocked && !isDayOff && widget.repository.isDateFullyBooked(_selectedDate, detailerId: widget.detailer.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isFullyBlocked || isFullyBooked)
              ? (isFullyBlocked ? Colors.redAccent.withAlpha(100) : Colors.amber.withAlpha(100))
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFullyBlocked
                      ? Colors.redAccent.withAlpha(30)
                      : (isFullyBooked
                          ? Colors.amber.withAlpha(30)
                          : (isDayOff ? AppTheme.surfaceLight : Colors.greenAccent.withAlpha(30))),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFullyBlocked
                      ? 'DAY BLOCKED'
                      : (isFullyBooked
                          ? 'FULLY BOOKED'
                          : (isDayOff ? 'CLOSED' : '${dayHours.openTime} - ${dayHours.closeTime}')),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isFullyBlocked
                        ? Colors.redAccent
                        : (isFullyBooked
                            ? Colors.amber
                            : (isDayOff ? AppTheme.textMuted : Colors.greenAccent)),
                  ),
                ),
              ),
            ],
          ),
          if (isDayOff || isFullyBlocked || isFullyBooked) ...[
            const SizedBox(height: 6),
            Text(
              isFullyBlocked
                  ? 'Detailer has marked this day unavailable on their calendar.'
                  : (isFullyBooked
                      ? 'All arrival windows for this date have been booked.'
                      : 'Studio is closed on ${DateFormat('EEEE').format(_selectedDate)}s (day off in operating hours).'),
              style: TextStyle(
                fontSize: 11,
                color: isFullyBlocked ? Colors.redAccent : (isFullyBooked ? Colors.amber : AppTheme.textMuted),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
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
              Row(
                children: const [
                  Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Direct Detailer Booking & Escrow Hold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• 24-Hour Free Cancellation & Deposit Protection\n• Mandatory Pre-Inspection Photo Walkaround\n• Digital Warranty Certificate logged upon completion\n• AutoDetailCraft provides SaaS scheduling tools; detailing workmanship is provided directly by the independent studio.',
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
