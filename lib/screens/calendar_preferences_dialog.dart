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

  static final List<String> _openTimeOptions = List.generate(48, (i) {
    return JobRepository.formatMinutesToTime(i * 30);
  });

  static final List<String> _closeTimeOptions = [
    ...List.generate(47, (i) => JobRepository.formatMinutesToTime((i + 1) * 30)),
    '12:00 AM (Midnight)',
  ];

  static String _matchOpenTimeOption(String timeStr) {
    final targetMins = JobRepository.timeStringToMinutes(timeStr);
    for (final opt in _openTimeOptions) {
      if (JobRepository.timeStringToMinutes(opt) == targetMins) {
        return opt;
      }
    }
    return _openTimeOptions.first;
  }

  static String _matchCloseTimeOption(String timeStr) {
    final targetMins = JobRepository.closeTimeToMinutes(timeStr);
    for (final opt in _closeTimeOptions) {
      if (JobRepository.closeTimeToMinutes(opt) == targetMins) {
        return opt;
      }
    }
    return _closeTimeOptions.last;
  }

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

  void _save() {
    for (final day in _schedule) {
      if (day.isOpen) {
        final openMin = JobRepository.timeStringToMinutes(day.openTime);
        final closeMin = JobRepository.closeTimeToMinutes(day.closeTime);
        if (closeMin <= openMin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Closing time must be after opening time on ${day.weekdayName}.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

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
                      DropdownMenuItem(value: 15, child: Text('15 minutes turnaround')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes turnaround')),
                      DropdownMenuItem(value: 45, child: Text('45 minutes turnaround')),
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
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),

            // Footer Actions
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
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
                ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    MediaQuery.sizeOf(context).width < 450 ? 'Save Preferences' : 'Save Schedule Preferences',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpen24HoursChip(DayBusinessHours day, int index, bool is24Hours) {
    return InkWell(
      onTap: () {
        setState(() {
          if (is24Hours) {
            _schedule[index] = day.copyWith(
              openTime: '08:00 AM',
              closeTime: '06:00 PM',
            );
          } else {
            _schedule[index] = day.copyWith(
              isOpen: true,
              openTime: '12:00 AM',
              closeTime: '12:00 AM',
            );
          }
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: is24Hours ? AppTheme.primary.withAlpha(35) : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: is24Hours ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              is24Hours ? Icons.check_circle_rounded : Icons.all_inclusive_rounded,
              size: 13,
              color: is24Hours ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Open 24 Hours',
              style: TextStyle(
                fontSize: 11,
                fontWeight: is24Hours ? FontWeight.bold : FontWeight.normal,
                color: is24Hours ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayScheduleRow(int index) {
    final day = _schedule[index];
    final is24Hours = day.isOpen &&
        JobRepository.timeStringToMinutes(day.openTime) == 0 &&
        JobRepository.closeTimeToMinutes(day.closeTime) == 1440;

    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: day.isOpen ? AppTheme.surfaceLight : AppTheme.surfaceLight.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: day.isOpen ? AppTheme.border : Colors.redAccent.withAlpha(60),
        ),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.weekdayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: day.isOpen ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: day.isOpen,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _schedule[index] = day.copyWith(
                                isOpen: val,
                                openTime: (val && day.openTime.isEmpty) ? '08:00 AM' : day.openTime,
                                closeTime: (val && day.closeTime.isEmpty) ? '06:00 PM' : day.closeTime,
                              );
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
                  ],
                ),
                if (day.isOpen) ...[
                  const SizedBox(height: 8),
                  _buildOpen24HoursChip(day, index, is24Hours),
                  const SizedBox(height: 8),
                  Row(
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
                              value: _matchOpenTimeOption(day.openTime),
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: _openTimeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _schedule[index] = day.copyWith(openTime: val);
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
                              value: _matchCloseTimeOption(day.closeTime),
                              isExpanded: true,
                              dropdownColor: AppTheme.surface,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: _closeTimeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _schedule[index] = day.copyWith(closeTime: val == '12:00 AM (Midnight)' ? '12:00 AM' : val));
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                ],
              ],
            )
          : Row(
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
                          _schedule[index] = day.copyWith(
                            isOpen: val,
                            openTime: (val && day.openTime.isEmpty) ? '08:00 AM' : day.openTime,
                            closeTime: (val && day.closeTime.isEmpty) ? '06:00 PM' : day.closeTime,
                          );
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
                const SizedBox(width: 10),

                // Operating Hours Selectors or Closed label
                Expanded(
                  child: day.isOpen
                      ? Row(
                          children: [
                            _buildOpen24HoursChip(day, index, is24Hours),
                            const SizedBox(width: 10),
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
                                    value: _matchOpenTimeOption(day.openTime),
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    items: _openTimeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _schedule[index] = day.copyWith(openTime: val);
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
                                    value: _matchCloseTimeOption(day.closeTime),
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surface,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    items: _closeTimeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _schedule[index] = day.copyWith(closeTime: val == '12:00 AM (Midnight)' ? '12:00 AM' : val));
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
}
