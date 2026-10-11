import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/calendar_availability_block.dart';
import '../services/job_repository.dart';

class CalendarPreferencesDialog extends StatefulWidget {
  final JobRepository repository;

  const CalendarPreferencesDialog({
    super.key,
    required this.repository,
  });

  static Future<void> show(BuildContext context, {required JobRepository repository}) {
    return showDialog(
      context: context,
      builder: (_) => CalendarPreferencesDialog(repository: repository),
    );
  }

  @override
  State<CalendarPreferencesDialog> createState() => _CalendarPreferencesDialogState();
}

class _CalendarPreferencesDialogState extends State<CalendarPreferencesDialog> {
  late List<DayBusinessHours> _schedule;
  late int _advanceNoticeHours;
  late int _bufferMinutes;
  late int _maxAdvanceDays;
  late bool _autoConfirm;
  late List<String> _slots;
  late int _slotDurationHours;

  final List<String> _timeOptions = [
    '05:00 AM', '06:00 AM', '07:00 AM', '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM',
    '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    final prefs = widget.repository.calendarPreferences;
    _schedule = List.from(prefs.weeklySchedule.map((h) => h.copyWith()));
    if (_schedule.isEmpty) {
      _schedule = List.from(DetailerCalendarPreferences.defaultWeeklySchedule.map((h) => h.copyWith()));
    }
    _advanceNoticeHours = prefs.advanceNoticeHours;
    _bufferMinutes = prefs.bufferMinutesBetweenJobs;
    _maxAdvanceDays = prefs.maxAdvanceBookingDays;
    _autoConfirm = prefs.autoConfirmBookings;
    _slots = List.from(prefs.customTimeSlots);
    if (_slots.isEmpty) {
      _slots = List.from(DetailerCalendarPreferences.defaultTimeSlots);
    }
    _slotDurationHours = prefs.slotDurationHours;
  }

  void _checkAndSyncSlotsForNewOpenTime(String newOpenTime) {
    final newOpenMin = JobRepository.timeStringToMinutes(newOpenTime);
    final earliestSlotMin = _slots.isEmpty
        ? 1440
        : _slots.map(JobRepository.timeStringToMinutes).reduce((a, b) => a < b ? a : b);
    if (newOpenMin < earliestSlotMin) {
      final endMin = newOpenMin + (_slotDurationHours * 60);
      final newSlot = '${JobRepository.formatMinutesToTime(newOpenMin)} - ${JobRepository.formatMinutesToTime(endMin)}';
      if (!_slots.contains(newSlot)) {
        _slots.insert(0, newSlot);
        _slots.sort((a, b) => JobRepository.timeStringToMinutes(a).compareTo(JobRepository.timeStringToMinutes(b)));
      }
    }
  }

  void _save() {
    final updated = DetailerCalendarPreferences(
      weeklySchedule: _schedule,
      advanceNoticeHours: _advanceNoticeHours,
      bufferMinutesBetweenJobs: _bufferMinutes,
      maxAdvanceBookingDays: _maxAdvanceDays,
      autoConfirmBookings: _autoConfirm,
      slotDurationHours: _slotDurationHours,
      customTimeSlots: _slots,
    );
    widget.repository.updateCalendarPreferences(updated);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar & operating schedule preferences updated'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendar & Operating Preferences',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Configure recurring days off, business hours, and lead time rules',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
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

            // Scrollable Content
            Expanded(
              child: ListView(
                children: [
                  // Section 1: Weekly Hours & Recurring Days Off
                  const Text(
                    'RECURRING WEEKLY SCHEDULE & DAYS OFF',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toggle days on/off to automatically close the studio on recurring days (e.g. Sundays). Closed days cannot be booked by clients.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < _schedule.length; i++) ...[
                    _buildDayScheduleRow(i),
                    if (i < _schedule.length - 1) const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 20),

                  // Section 2: Turo-Style Host Protection Rules
                  const Text(
                    'BOOKING LEAD TIME & TURNAROUND RULES',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Protect your calendar from sudden bookings and buffer time between consecutive jobs.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),

                  // Advance notice dropdown
                  _buildDropdownRow(
                    label: 'Minimum Advance Notice',
                    description: 'Clients cannot book slots with less lead time than this.',
                    icon: Icons.timer_outlined,
                    value: _advanceNoticeHours,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 hour notice')),
                      DropdownMenuItem(value: 2, child: Text('2 hours notice (Default)')),
                      DropdownMenuItem(value: 6, child: Text('6 hours notice')),
                      DropdownMenuItem(value: 12, child: Text('12 hours notice')),
                      DropdownMenuItem(value: 24, child: Text('24 hours (1 full day)')),
                      DropdownMenuItem(value: 48, child: Text('48 hours (2 full days)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _advanceNoticeHours = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Buffer between jobs
                  _buildDropdownRow(
                    label: 'Turnaround Buffer Between Jobs',
                    description: 'Time reserved for shop cleanup, pad cleaning, and mobile transit.',
                    icon: Icons.hourglass_empty_rounded,
                    value: _bufferMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('No buffer (Back-to-back)')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes turnaround')),
                      DropdownMenuItem(value: 60, child: Text('1 hour turnaround')),
                      DropdownMenuItem(value: 120, child: Text('2 hours turnaround')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _bufferMinutes = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Maximum booking window
                  _buildDropdownRow(
                    label: 'Booking Horizon',
                    description: 'How far in advance clients can schedule appointments.',
                    icon: Icons.date_range_rounded,
                    value: _maxAdvanceDays,
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('Up to 30 days ahead')),
                      DropdownMenuItem(value: 60, child: Text('Up to 60 days ahead (Default)')),
                      DropdownMenuItem(value: 90, child: Text('Up to 90 days ahead')),
                      DropdownMenuItem(value: 180, child: Text('Up to 6 months ahead')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _maxAdvanceDays = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Auto-confirm switch
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant Confirmation (Auto-Accept)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'When enabled, client bookings on available slots are instantly confirmed.',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoConfirm,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) => setState(() => _autoConfirm = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 3: Time Slot Availability Windows
                  _buildSlotsSection(),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Schedule Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleRow(int index) {
    final day = _schedule[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: day.isOpen ? AppTheme.surfaceLight : AppTheme.surfaceLight.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: day.isOpen ? AppTheme.border : Colors.redAccent.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          // Day Name
          SizedBox(
            width: 85,
            child: Text(
              day.weekdayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: day.isOpen ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ),

          // Open / Closed Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: day.isOpen,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) {
                  setState(() {
                    _schedule[index] = day.copyWith(isOpen: val);
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                day.isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: day.isOpen ? AppTheme.primary : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Operating Hours Selectors or Closed label
          Expanded(
            child: day.isOpen
                ? Row(
                    children: [
                      // Open Time Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(day.openTime) ? day.openTime : _timeOptions.first,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _schedule[index] = day.copyWith(openTime: val);
                                    _checkAndSyncSlotsForNewOpenTime(val);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('to', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ),
                      // Close Time Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(day.closeTime) ? day.closeTime : _timeOptions.last,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _schedule[index] = day.copyWith(closeTime: val));
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withAlpha(60)),
                    ),
                    child: const Text(
                      'Recurring Day Off (Closed every week)',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required String description,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOURLY BOOKING TIME SLOTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Define appointment windows clients can book during open hours.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Add Slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _showAddSlotModal,
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 13),
              label: const Text('Auto-Gen', style: TextStyle(fontSize: 11)),
              onPressed: _autoGenerateSlotsFromSchedule,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Duration selector
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Default Slot Window Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              Wrap(
                spacing: 6,
                children: [1, 2, 3, 4].map((d) {
                  final isSel = _slotDurationHours == d;
                  return ChoiceChip(
                    label: Text('${d}h'),
                    selected: isSel,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _slotDurationHours = d);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Slots List
        if (_slots.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text(
                'No custom slots defined. Tap "+ Add Slot" or "Auto-Gen" to create windows.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slots.map((slot) {
              return Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      slot,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textSecondary),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit Slot',
                      onPressed: () => _showEditSlotModal(slot),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      tooltip: 'Delete Slot',
                      onPressed: () {
                        setState(() {
                          _slots.remove(slot);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _autoGenerateSlotsFromSchedule() {
    final openDays = _schedule.where((d) => d.isOpen).toList();
    if (openDays.isEmpty) return;

    String minOpen = openDays.first.openTime;
    String maxClose = openDays.first.closeTime;
    for (final d in openDays) {
      if (JobRepository.timeStringToMinutes(d.openTime) < JobRepository.timeStringToMinutes(minOpen)) {
        minOpen = d.openTime;
      }
      if (JobRepository.timeStringToMinutes(d.closeTime) > JobRepository.timeStringToMinutes(maxClose)) {
        maxClose = d.closeTime;
      }
    }

    final generated = JobRepository.generateSlotsForHours(
      openTime: minOpen,
      closeTime: maxClose,
      slotDurationHours: _slotDurationHours,
    );
    if (generated.isNotEmpty) {
      setState(() => _slots = generated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-generated ${generated.length} slots from $minOpen to $maxClose (${_slotDurationHours}h windows)'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddSlotModal() {
    String startTime = '08:00 AM';
    final openDays = _schedule.where((d) => d.isOpen).toList();
    if (openDays.isNotEmpty) {
      startTime = openDays.first.openTime;
    }
    final sMin = JobRepository.timeStringToMinutes(startTime);
    String endTime = JobRepository.formatMinutesToTime(sMin + (_slotDurationHours * 60));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Add Booking Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select time window:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(startTime) ? startTime : _timeOptions.first,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    startTime = val;
                                    final sm = JobRepository.timeStringToMinutes(val);
                                    endTime = JobRepository.formatMinutesToTime(sm + (_slotDurationHours * 60));
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(endTime) ? endTime : _timeOptions.last,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => endTime = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                  onPressed: () {
                    final newSlot = '$startTime - $endTime';
                    if (!_slots.contains(newSlot)) {
                      setState(() {
                        _slots.add(newSlot);
                        _slots.sort((a, b) => JobRepository.timeStringToMinutes(a).compareTo(JobRepository.timeStringToMinutes(b)));
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSlotModal(String currentSlot) {
    String startTime = '08:00 AM';
    String endTime = '11:00 AM';
    if (currentSlot.contains('-')) {
      final parts = currentSlot.split('-');
      startTime = parts.first.trim();
      endTime = parts.last.trim();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Slot Window', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Editing: $currentSlot', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(startTime) ? startTime : _timeOptions.first,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => startTime = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _timeOptions.contains(endTime) ? endTime : _timeOptions.last,
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => endTime = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                  onPressed: () {
                    final newSlot = '$startTime - $endTime';
                    final idx = _slots.indexOf(currentSlot);
                    if (idx != -1) {
                      setState(() {
                        _slots[idx] = newSlot;
                        _slots.sort((a, b) => JobRepository.timeStringToMinutes(a).compareTo(JobRepository.timeStringToMinutes(b)));
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Save Slot', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
