import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/user_vehicle.dart';
import '../models/team_member.dart';
import '../services/job_repository.dart';
import '../services/supabase_auth_service.dart';
import '../services/mock_data_service.dart';
import 'auth_modal.dart';
import 'vehicle_editor_dialog.dart';

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
  UserVehicle? _selectedGarageVehicle;
  ServiceLocationType _locationType = ServiceLocationType.mobile;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  late DateTime _calendarDisplayMonth;
  String _selectedTimeSlot = '9:00 AM - 12:00 PM';
  String _selectedStartTime = '9:00 AM';
  String _selectedPickUpTime = '5:00 PM';
  DateTime? _calculatedCompletionDate;
  String? _calculatedFinishTime;
  TeamMember? _selectedTeamMember; // Delegated / preferred detailer

  // Input Controllers
  final _vehicleModelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<String> get _timeSlots {
    final overrideBlock = widget.repository.getCustomDayOverride(_selectedDate, detailerId: widget.detailer.id);
    if (overrideBlock != null && overrideBlock.hasCustomSlotsOverride) {
      if (overrideBlock.customSlots.isEmpty) {
        return <String>[];
      }
      return overrideBlock.customSlots.map((s) {
        final startMin = JobRepository.parseSlotRange(s).$1;
        final startStr = JobRepository.formatMinutesToTime(startMin);
        if (_selectedPackage.isMultiDay) {
          final finishStr = JobRepository.formatMinutesToTime(startMin + 60);
          return '$startStr - $finishStr';
        } else {
          final finishStr = JobRepository.formatMinutesToTime(startMin + _selectedPackage.durationMinutes);
          return '$startStr - $finishStr';
        }
      }).toList();
    }

    final hours = widget.repository.getHoursForDate(_selectedDate, detailerId: widget.detailer.id);
    final effectiveOpen = hours.openTime.isNotEmpty ? hours.openTime : '08:00 AM';
    final effectiveClose = hours.closeTime.isNotEmpty ? hours.closeTime : '06:00 PM';
    var openMin = JobRepository.timeStringToMinutes(effectiveOpen);
    var closeMin = JobRepository.closeTimeToMinutes(effectiveClose);
    if (closeMin <= openMin) {
      openMin = 480;
      closeMin = 1080;
    }

    final candidateStartMins = <int>{};
    for (int m = openMin; m < closeMin; m += 30) {
      candidateStartMins.add(m);
    }

    final sortedStarts = candidateStartMins.toList()..sort();
    return sortedStarts.map((startMin) {
      final startStr = JobRepository.formatMinutesToTime(startMin);
      if (_selectedPackage.isMultiDay) {
        final finishStr = JobRepository.formatMinutesToTime(startMin + 60);
        return '$startStr - $finishStr';
      } else {
        final finishStr = JobRepository.formatMinutesToTime(startMin + _selectedPackage.durationMinutes);
        return '$startStr - $finishStr';
      }
    }).toList();
  }

  void _recalculateCompletionAndSlot() {
    if (_selectedStartTime.isEmpty) {
      _calculatedCompletionDate = null;
      _calculatedFinishTime = null;
      _selectedTimeSlot = '';
      return;
    }
    final prevCompDate = _calculatedCompletionDate;
    final comp = widget.repository.calculateCompletionDateTime(
      _selectedDate,
      _selectedStartTime,
      _selectedPackage,
      detailerId: widget.detailer.id,
    );
    _calculatedCompletionDate = comp.completionDate;
    _calculatedFinishTime = comp.completionTime;

    if (_selectedPackage.isMultiDay) {
      final pickUpTimes = widget.repository.getAvailablePickUpTimes(
        _calculatedCompletionDate ?? _selectedDate,
        detailerId: widget.detailer.id,
        earliestTime: comp.completionTime,
      );
      final compMins = JobRepository.closeTimeToMinutes(comp.completionTime);
      final currentPickUpMins = JobRepository.closeTimeToMinutes(_selectedPickUpTime);
      final hasSelected = pickUpTimes.any(
        (t) => JobRepository.closeTimeToMinutes(t) == currentPickUpMins,
      );
      final dateChanged = prevCompDate == null || !DateUtils.isSameDay(prevCompDate, comp.completionDate);

      if (pickUpTimes.isNotEmpty && (dateChanged || !hasSelected || currentPickUpMins < compMins)) {
        final matchingCompTime = pickUpTimes.firstWhere(
          (t) => JobRepository.closeTimeToMinutes(t) == compMins,
          orElse: () => pickUpTimes.first,
        );
        _selectedPickUpTime = matchingCompTime;
      } else if (_selectedPickUpTime.isEmpty) {
        _selectedPickUpTime = comp.completionTime;
      }
      _selectedTimeSlot = 'Drop-off: $_selectedStartTime • Ready: $_selectedPickUpTime';
    } else {
      _selectedTimeSlot = '$_selectedStartTime - ${comp.completionTime}';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      }
    });
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
    final authEmail = SupabaseAuthService.currentAuthUser?.email;
    if (authEmail != null && authEmail.isNotEmpty) {
      _emailCtrl.text = authEmail;
    } else if (user.username.isNotEmpty && user.username.contains('@')) {
      _emailCtrl.text = user.username;
    } else {
      _emailCtrl.text = '';
    }
    if (user.location.isNotEmpty) {
      _addressCtrl.text = user.location;
    }
    if (user.myGarage.isNotEmpty) {
      _selectedGarageVehicle = user.myGarage.first;
      _vehicleModelCtrl.text = _selectedGarageVehicle!.fullName;
      _vehicleSize = _selectedGarageVehicle!.resolvedVehicleSize;
    } else {
      _selectedGarageVehicle = null;
      _vehicleModelCtrl.text = '';
      _vehicleSize = VehicleSize.coupeSedan;
    }

    _selectedPackage = widget.initialPackage ??
        (widget.detailer.servicePackages.isNotEmpty
            ? widget.detailer.servicePackages.first
            : (widget.repository.currentUser.servicePackages.isNotEmpty
                ? widget.repository.currentUser.servicePackages.first
                : (MockDataService.standardPackages.isNotEmpty
                    ? MockDataService.standardPackages.first
                    : const ServicePackage(
                        id: 'pkg_custom',
                        title: 'Custom Detail Service',
                        description: 'Tailored detailing service',
                        basePrice: 150.0,
                        estimatedDuration: '2 hrs',
                        includes: ['Exterior Wash'],
                      ))));

    if (_timeSlots.isNotEmpty) {
      final startMin = JobRepository.parseSlotRange(_timeSlots.first).$1;
      _selectedStartTime = JobRepository.formatMinutesToTime(startMin);
    } else {
      _selectedStartTime = '';
      _selectedTimeSlot = '';
    }
    _recalculateCompletionAndSlot();
    _adjustSelectedSlotIfBlocked();
    widget.repository.refreshAvailabilityBlocks(detailerId: widget.detailer.id);
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {
        final garage = widget.repository.currentUser.myGarage;
        if (garage.isNotEmpty) {
          if (_selectedGarageVehicle == null || !garage.any((v) => v.id == _selectedGarageVehicle?.id)) {
            _selectedGarageVehicle = garage.first;
            _vehicleModelCtrl.text = _selectedGarageVehicle!.fullName;
            _vehicleSize = _selectedGarageVehicle!.resolvedVehicleSize;
          }
        } else {
          _selectedGarageVehicle = null;
          _vehicleModelCtrl.text = '';
        }
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

    final overrideBlock = widget.repository.getCustomDayOverride(_selectedDate, detailerId: widget.detailer.id);
    if (overrideBlock != null && overrideBlock.hasCustomSlotsOverride) {
      if (overrideBlock.customSlots.isEmpty) {
        return 'No Slots Available on this Date';
      }
      final startMin = JobRepository.parseSlotRange(slot).$1;
      final matchesCustom = overrideBlock.customSlots.any((cs) => JobRepository.parseSlotRange(cs).$1 == startMin);
      if (!matchesCustom) {
        return 'Time Window Not Offered';
      }
    }

    final startMin = JobRepository.parseSlotRange(slot).$1;
    final startStr = JobRepository.formatMinutesToTime(startMin);
    final openMin = JobRepository.timeStringToMinutes(hours.openTime);
    final closeMin = JobRepository.closeTimeToMinutes(hours.closeTime);

    if (startMin < openMin || startMin >= closeMin) {
      return 'Outside Business Operating Hours';
    }

    // Same-day: closing time protection based on package duration
    if (!_selectedPackage.isMultiDay) {
      if (startMin + _selectedPackage.durationMinutes > closeMin) {
        return 'Finishes After Shop Closing (${hours.closeTime})';
      }
    }

    final slotToCheck = _selectedPackage.isMultiDay
        ? '$startStr - ${JobRepository.formatMinutesToTime(startMin + 60)}'
        : '$startStr - ${JobRepository.formatMinutesToTime(startMin + _selectedPackage.durationMinutes)}';

    if (_selectedTeamMember != null) {
      if (!widget.repository.isMemberOnDutyOnDate(_selectedTeamMember!.id, _selectedDate, detailerId: widget.detailer.id)) {
        return '${_selectedTeamMember!.name} is Off Duty on this Date';
      }
      if (widget.repository.isSlotExplicitlyBlocked(widget.detailer.id, _selectedDate, slotToCheck, teamMemberId: _selectedTeamMember!.id)) {
        return '${_selectedTeamMember!.name} Unavailable for this Time Window';
      }
    } else {
      if (widget.repository.isSlotBlocked(widget.detailer.id, _selectedDate, slotToCheck)) {
        return 'Time Window Blocked by Detailer';
      }
    }
    if (!widget.repository.isSlotWithinOperatingHours(_selectedDate, slotToCheck, detailerId: widget.detailer.id)) {
      return 'Outside Business Operating Hours';
    }
    if (!widget.repository.isSlotWithinLeadTime(_selectedDate, startStr, detailerId: widget.detailer.id)) {
      final leadHours = widget.repository.getCalendarPreferences(detailerId: widget.detailer.id).advanceNoticeHours;
      return 'Requires ${leadHours}h Minimum Advance Notice';
    }
    if (_isSlotBookedByOtherAppointment(slotToCheck)) {
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
    if (_timeSlots.isEmpty) {
      _selectedTimeSlot = '';
      _selectedStartTime = '';
      _recalculateCompletionAndSlot();
      return;
    }
    if (_selectedTimeSlot.isEmpty || !_timeSlots.contains(_selectedTimeSlot) || _isSlotBooked(_selectedTimeSlot)) {
      String? firstAvailable;
      for (final slot in _timeSlots) {
        if (!_isSlotBooked(slot)) {
          firstAvailable = slot;
          break;
        }
      }
      final targetSlot = firstAvailable ?? _timeSlots.first;
      _selectedTimeSlot = targetSlot;
      final start = JobRepository.parseSlotRange(targetSlot).$1;
      _selectedStartTime = JobRepository.formatMinutesToTime(start);
    }
    _recalculateCompletionAndSlot();
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
    if (_selectedGarageVehicle != null) {
      return _selectedPackage.calculatePriceForVehicle(_selectedGarageVehicle);
    }
    return _selectedPackage.calculatePriceForVehicleSize(_vehicleSize);
  }

  double get _depositAmount {
    return (_calculatedTotal * 0.20).clamp(50.0, 200.0);
  }

  Future<void> _confirmAndSubmitBooking() async {
    if (widget.repository.currentUser.myGarage.isEmpty || _selectedGarageVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a vehicle to My Garage first before completing your booking.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name for the booking reservation.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 2);
      return;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number so the detailer can contact you.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 2);
      return;
    }

    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+(\.[\w\-]+)+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address for warranty and booking confirmation.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 2);
      return;
    }

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

    if (!widget.repository.isLoggedIn) {
      AuthModal.show(
        context,
        repository: widget.repository,
        onSuccess: () {
          if (mounted) _confirmAndSubmitBooking();
        },
      );
      return;
    }

    final vehicleModelText = _selectedGarageVehicle != null
        ? _selectedGarageVehicle!.fullName
        : _vehicleModelCtrl.text.trim();
    final effectiveVehicleSize = _selectedGarageVehicle != null
        ? _selectedGarageVehicle!.resolvedVehicleSize
        : _vehicleSize;

    final comp = widget.repository.calculateCompletionDateTime(
      _selectedDate,
      _selectedStartTime,
      _selectedPackage,
      detailerId: widget.detailer.id,
    );
    final effectiveCompletionDate = _calculatedCompletionDate ?? comp.completionDate;
    final effectiveEndTime = _selectedPackage.isMultiDay
        ? _selectedPickUpTime
        : comp.completionTime;

    final booking = BookingAppointment(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      clientId: widget.repository.isLoggedIn ? widget.repository.currentUser.id : null,
      detailerId: widget.detailer.id,
      assignedTeamMemberId: _selectedTeamMember?.id,
      assignedTeamMemberName: _selectedTeamMember?.name,
      detailerName: _selectedTeamMember != null
          ? '${widget.detailer.businessName.isNotEmpty ? widget.detailer.businessName : widget.detailer.displayName} (${_selectedTeamMember!.name})'
          : (widget.detailer.displayName.isNotEmpty
              ? widget.detailer.displayName
              : (widget.detailer.businessName.isNotEmpty ? widget.detailer.businessName : 'Detailing Studio')),
      detailerBusinessName: widget.detailer.businessName.isNotEmpty
          ? widget.detailer.businessName
          : (widget.detailer.displayName.isNotEmpty ? widget.detailer.displayName : 'Detailing Studio'),
      detailerAvatar: _selectedTeamMember?.avatarUrl ?? widget.detailer.avatarUrl,
      clientName: _nameCtrl.text.trim(),
      clientPhone: _phoneCtrl.text.trim(),
      clientEmail: _emailCtrl.text.trim().toLowerCase(),
      vehicleYearMakeModel: vehicleModelText,
      vehicleSize: effectiveVehicleSize,
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
      completionDate: effectiveCompletionDate,
      startTime: _selectedStartTime,
      endTime: effectiveEndTime,
      durationMinutes: _selectedPackage.durationMinutes,
      isMultiDay: _selectedPackage.isMultiDay,
    );

    final success = await widget.repository.addBookingAsync(booking);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation failed: Slot was just reserved by another customer. Please choose another date or time.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _currentStep = 1);
      return;
    }

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
                  _receiptRow('Vehicle', vehicleModelText),
                  const SizedBox(height: 6),
                  if (_selectedPackage.isMultiDay) ...[
                    _receiptRow('Drop-off', '${DateFormat('EEE, MMM d').format(_selectedDate)} at $_selectedStartTime'),
                    const SizedBox(height: 6),
                    _receiptRow('Ready for Pick-up', '${DateFormat('EEE, MMM d').format(effectiveCompletionDate)} at $_selectedPickUpTime'),
                    const SizedBox(height: 6),
                    _receiptRow('Turnaround', _selectedPackage.durationBadge),
                  ] else ...[
                    _receiptRow('Date', DateFormat('EEE, MMM d, yyyy').format(_selectedDate)),
                    const SizedBox(height: 6),
                    _receiptRow('Time Window', _selectedTimeSlot),
                    const SizedBox(height: 6),
                    _receiptRow('Duration', _selectedPackage.durationBadge),
                  ],
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
              widget.repository.setActiveTab(1);
              Navigator.of(ctx).pop();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
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
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 450 ? 12 : 20,
              vertical: 12,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(child: _stepIndicator(0, MediaQuery.sizeOf(context).width < 450 ? 'Package' : '1. Package')),
                _stepDivider(0),
                Expanded(child: _stepIndicator(1, MediaQuery.sizeOf(context).width < 450 ? 'Date' : '2. Vehicle & Date')),
                _stepDivider(1),
                Expanded(child: _stepIndicator(2, MediaQuery.sizeOf(context).width < 450 ? 'Checkout' : '3. Checkout')),
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
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 450 ? 14 : 20,
              vertical: 12,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
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
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_currentStep > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 4),
                  Flexible(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.sizeOf(context).width < 450 ? 10 : 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_currentStep == 1) {
                          if (widget.repository.currentUser.myGarage.isEmpty || _selectedGarageVehicle == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please add a vehicle to My Garage first before proceeding with booking.'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            showDialog(
                              context: context,
                              builder: (_) => VehicleEditorDialog(repository: widget.repository),
                            ).then((_) {
                              if (widget.repository.currentUser.myGarage.isNotEmpty && mounted) {
                                setState(() {
                                  _selectedGarageVehicle = widget.repository.currentUser.myGarage.last;
                                  _vehicleModelCtrl.text = _selectedGarageVehicle!.fullName;
                                  _vehicleSize = _selectedGarageVehicle!.resolvedVehicleSize;
                                });
                              }
                            });
                            return;
                          }
                          if (_timeSlots.isEmpty || _selectedTimeSlot.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No time slots available for this date. Please choose another date.'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          if (_isSlotBooked(_selectedTimeSlot)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_getSlotUnavailableReason(_selectedTimeSlot) ?? 'Selected slot is unavailable. Please choose another date or time.'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                        }
                        if (_currentStep < 2) {
                          setState(() => _currentStep++);
                        } else {
                          _confirmAndSubmitBooking();
                        }
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep == 2 ? 'Reserve & Book' : 'Continue',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
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
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    final isMobile = MediaQuery.sizeOf(context).width < 450;
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
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
            onTap: () {
              setState(() {
                _selectedPackage = pkg;
                _recalculateCompletionAndSlot();
                _adjustSelectedSlotIfBlocked();
              });
            },
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pkg.includes.take(3).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.surfaceLight,
                              backgroundImage: m.localAvatarBytes != null
                                  ? MemoryImage(m.localAvatarBytes!) as ImageProvider
                                  : (m.avatarUrl.trim().isNotEmpty
                                      ? NetworkImage(m.avatarUrl.trim())
                                      : null),
                              child: (m.localAvatarBytes == null && m.avatarUrl.trim().isEmpty)
                                  ? const Icon(Icons.person_rounded, size: 14, color: AppTheme.textMuted)
                                  : null,
                            ),
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
          ),
          const SizedBox(height: 16),
        ],

        if (widget.repository.currentUser.myGarage.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vehicle to Detail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('+ Add Vehicle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => VehicleEditorDialog(repository: widget.repository),
                  ).then((_) {
                    if (widget.repository.currentUser.myGarage.isNotEmpty && mounted) {
                      setState(() {
                        _selectedGarageVehicle = widget.repository.currentUser.myGarage.last;
                        _vehicleModelCtrl.text = _selectedGarageVehicle!.fullName;
                        _vehicleSize = _selectedGarageVehicle!.resolvedVehicleSize;
                      });
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<UserVehicle>(
            key: ValueKey('booking_vehicle_dropdown_${_selectedGarageVehicle?.id}'),
            isExpanded: true,
            initialValue: widget.repository.currentUser.myGarage.any((v) => v.id == _selectedGarageVehicle?.id)
                ? widget.repository.currentUser.myGarage.firstWhere((v) => v.id == _selectedGarageVehicle?.id)
                : widget.repository.currentUser.myGarage.first,
            decoration: InputDecoration(
              labelText: 'Select Vehicle from My Garage',
              prefixIcon: const Icon(Icons.directions_car_rounded, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
            ),
            items: widget.repository.currentUser.myGarage.map((veh) {
              return DropdownMenuItem<UserVehicle>(
                value: veh,
                child: Row(
                  children: [
                    Icon(VehicleBodyType.getIcon(veh.vehicleType), size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        veh.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withAlpha(70)),
                      ),
                      child: Text(
                        veh.vehicleType,
                        style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (veh) {
              if (veh != null) {
                setState(() {
                  _selectedGarageVehicle = veh;
                  _vehicleModelCtrl.text = veh.fullName;
                  _vehicleSize = veh.resolvedVehicleSize;
                });
              }
            },
          ),
          if (_selectedGarageVehicle != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(VehicleBodyType.getIcon(_selectedGarageVehicle!.vehicleType), color: AppTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedGarageVehicle!.vehicleType,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${_selectedGarageVehicle!.colorName}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedPackage.getSurchargeForVehicleType(_selectedGarageVehicle!.vehicleType) > 0
                              ? 'Base \$${_selectedPackage.basePrice.toStringAsFixed(0)} + \$${_selectedPackage.getSurchargeForVehicleType(_selectedGarageVehicle!.vehicleType).toStringAsFixed(0)} ${_selectedGarageVehicle!.vehicleType} fee'
                              : 'Standard vehicle size pricing applied',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${_calculatedTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Container(
            key: const Key('empty_garage_banner'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Vehicle in My Garage',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please add a vehicle to My Garage first. Your vehicle body size (Coupe, Sedan, SUV, Minivan, Truck) ensures seamless, accurate pricing.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Vehicle to My Garage', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => VehicleEditorDialog(repository: widget.repository),
                    ).then((_) {
                      if (widget.repository.currentUser.myGarage.isNotEmpty && mounted) {
                        setState(() {
                          _selectedGarageVehicle = widget.repository.currentUser.myGarage.last;
                          _vehicleModelCtrl.text = _selectedGarageVehicle!.fullName;
                          _vehicleSize = _selectedGarageVehicle!.resolvedVehicleSize;
                        });
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Date & Time Window', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Live availability direct from ${widget.detailer.businessName}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

        if (_selectedPackage.isMultiDay) ...[
          // Multi-Day Service Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🗓️ Multi-Day Service: ${_selectedPackage.turnaroundDays} Day${_selectedPackage.turnaroundDays > 1 ? 's' : ''} Turnaround',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Choice 1: Date-Time Start
          const Text('Choice 1: Drop-off Date & Time (Start)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_timeSlots.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'No drop-off slots available for this date. Please select another date.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ] else ...(() {
            final baseSlots = widget.repository.getTimeSlotsForDate(_selectedDate, detailerId: widget.detailer.id);
            return [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((slot) {
                  final reason = _getSlotUnavailableReason(slot);
                  final isUnavailable = reason != null;
                  final startMin = JobRepository.parseSlotRange(slot).$1;
                  final startStr = JobRepository.formatMinutesToTime(startMin);
                  final isSelected = (_selectedStartTime == startStr || _selectedTimeSlot == slot) && !isUnavailable;

                  String badgeText = 'UNAVAILABLE';
                  if (reason != null) {
                    if (reason.contains('Booked')) {
                      badgeText = 'BOOKED';
                    } else if (reason.contains('Notice')) {
                      badgeText = 'LEAD TIME';
                    } else if (reason.contains('Blocked')) {
                      badgeText = 'BLOCKED';
                    } else if (reason.contains('Closed') || reason.contains('Operating') || reason.contains('Finishes After')) {
                      badgeText = 'CLOSED';
                    }
                  }

                  final matchingBase = baseSlots.firstWhere(
                    (bs) => JobRepository.parseSlotRange(bs).$1 == startMin,
                    orElse: () => '',
                  );

                  return Tooltip(
                    message: reason ?? 'Available for Drop-off',
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            startStr,
                            style: TextStyle(
                              fontSize: 12,
                              decoration: isUnavailable ? TextDecoration.lineThrough : null,
                              color: isUnavailable
                                  ? Colors.grey.shade600
                                  : (isSelected ? Colors.black : Colors.white),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          SizedBox(
                            width: 0,
                            height: 0,
                            child: OverflowBox(
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: 0,
                              maxHeight: 0,
                              child: Text(slot, style: const TextStyle(fontSize: 0)),
                            ),
                          ),
                          if (matchingBase.isNotEmpty && matchingBase != slot) ...[
                            SizedBox(
                              width: 0,
                              height: 0,
                              child: OverflowBox(
                                minWidth: 0,
                                minHeight: 0,
                                maxWidth: 0,
                                maxHeight: 0,
                                child: Text(matchingBase, style: const TextStyle(fontSize: 0)),
                              ),
                            ),
                          ],
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
                              if (val) {
                                setState(() {
                                  _selectedStartTime = startStr;
                                  _recalculateCompletionAndSlot();
                                });
                              }
                            },
                    ),
                  );
                }).toList(),
              ),
            ];
          })(),
          const SizedBox(height: 16),

          // Choice 2: Date-Time Finished
          const Text('Choice 2: Ready for Pick-up (Finished)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Estimated Ready Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_calculatedCompletionDate ?? _selectedDate)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Select Preferred Pick-up Time:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.repository.getAvailablePickUpTimes(
                    _calculatedCompletionDate ?? _selectedDate,
                    detailerId: widget.detailer.id,
                    earliestTime: _calculatedFinishTime,
                  ).map((pickUpTime) {
                    final isSelected = JobRepository.closeTimeToMinutes(_selectedPickUpTime) == JobRepository.closeTimeToMinutes(pickUpTime);
                    return FilterChip(
                      label: Text(
                        pickUpTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      checkmarkColor: Colors.black,
                      showCheckmark: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedPickUpTime = pickUpTime;
                            _selectedTimeSlot = 'Drop-off: $_selectedStartTime • Ready: $_selectedPickUpTime';
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Multi-Day Turnaround Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync_alt_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Multi-Day Turnaround Schedule', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        'Drop-off: ${DateFormat('EEE, MMM d').format(_selectedDate)} $_selectedStartTime • Ready: ${DateFormat('EEE, MMM d').format(_calculatedCompletionDate ?? _selectedDate)} $_selectedPickUpTime',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Package Duration Indicator (Same-Day)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⏱️ Duration: ${_selectedPackage.durationBadge} (${_selectedPackage.title})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text('Select Arrival / Start Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_timeSlots.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'No appointment slots available for this date. Please select another date.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ] else ...(() {
            final baseSlots = widget.repository.getTimeSlotsForDate(_selectedDate, detailerId: widget.detailer.id);
            return [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((slot) {
                  final reason = _getSlotUnavailableReason(slot);
                  final isUnavailable = reason != null;
                  final startMin = JobRepository.parseSlotRange(slot).$1;
                  final startStr = JobRepository.formatMinutesToTime(startMin);
                  final finishMin = startMin + _selectedPackage.durationMinutes;
                  final dynamicSlot = '$startStr - ${JobRepository.formatMinutesToTime(finishMin)}';
                  final isSelected = (_selectedTimeSlot == slot || _selectedTimeSlot == dynamicSlot || _selectedStartTime == startStr) && !isUnavailable;

                  int? availableCapacity;
                  if (!isUnavailable && widget.detailer.teamMembers.isNotEmpty && _selectedTeamMember == null) {
                    final status = widget.repository.getSlotStaffingStatus(_selectedDate, slot, detailerId: widget.detailer.id);
                    if (status.onDutyCount > 1 && status.availableCapacity < status.onDutyCount) {
                      availableCapacity = status.availableCapacity;
                    }
                  }

                  String badgeText = 'UNAVAILABLE';
                  if (reason != null) {
                    if (reason.contains('Booked')) {
                      badgeText = 'BOOKED';
                    } else if (reason.contains('Notice')) {
                      badgeText = 'LEAD TIME';
                    } else if (reason.contains('Blocked')) {
                      badgeText = 'BLOCKED';
                    } else if (reason.contains('Closed') || reason.contains('Operating') || reason.contains('Finishes After')) {
                      badgeText = 'CLOSED';
                    }
                  }

                  final matchingBase = baseSlots.firstWhere(
                    (bs) => JobRepository.parseSlotRange(bs).$1 == startMin,
                    orElse: () => '',
                  );

                  return Tooltip(
                    message: reason ?? 'Available for Booking',
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              startStr,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                decoration: isUnavailable ? TextDecoration.lineThrough : null,
                                color: isUnavailable
                                    ? Colors.grey.shade600
                                    : (isSelected ? Colors.black : Colors.white),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 0,
                            height: 0,
                            child: OverflowBox(
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: 0,
                              maxHeight: 0,
                              child: Text(slot, style: const TextStyle(fontSize: 0)),
                            ),
                          ),
                          if (matchingBase.isNotEmpty && matchingBase != slot) ...[
                            SizedBox(
                              width: 0,
                              height: 0,
                              child: OverflowBox(
                                minWidth: 0,
                                minHeight: 0,
                                maxWidth: 0,
                                maxHeight: 0,
                                child: Text(matchingBase, style: const TextStyle(fontSize: 0)),
                              ),
                            ),
                          ],
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
                          if (availableCapacity != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.primary.withAlpha(100), width: 0.8),
                              ),
                              child: Text(
                                '$availableCapacity left',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
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
                              if (val) {
                                setState(() {
                                  _selectedStartTime = startStr;
                                  _selectedTimeSlot = dynamicSlot;
                                  _recalculateCompletionAndSlot();
                                });
                              }
                            },
                    ),
                  );
                }).toList(),
              ),
            ];
          })(),
          // Live Schedule Card (Same-Day)
          if (_selectedStartTime.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Schedule Window',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Drop-off: $_selectedStartTime • Estimated Finish: ${_calculatedFinishTime ?? ''} Today',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
        // Schedule & Service Summary Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPackage.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedPackage.durationBadge,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.border, height: 16),
              if (_selectedPackage.isMultiDay) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Drop-off (Start):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '${DateFormat('EEE, MMM d').format(_selectedDate)} at $_selectedStartTime',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ready Pick-up (Finished):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '${DateFormat('EEE, MMM d').format(_calculatedCompletionDate ?? _selectedDate)} at $_selectedPickUpTime',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scheduled Date:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Time Window:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      _selectedTimeSlot,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

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
                  Expanded(
                    child: Text(
                      'Direct Detailer Booking & Escrow Hold',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  const Flexible(
                    child: Text(
                      'Due Today (Deposit Hold):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('\$${_depositAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Remaining Balance at Completion:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
