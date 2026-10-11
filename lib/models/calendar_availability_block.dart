class DayBusinessHours {
  final int weekday; // 1 = Monday, ..., 7 = Sunday (matching DateTime.monday .. DateTime.sunday)
  final bool isOpen; // If false, recurring weekly day off
  final String openTime; // e.g. "08:00 AM"
  final String closeTime; // e.g. "06:00 PM"

  const DayBusinessHours({
    required this.weekday,
    this.isOpen = true,
    this.openTime = '08:00 AM',
    this.closeTime = '06:00 PM',
  });

  String get weekdayName {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Day $weekday';
    }
  }

  String get weekdayShort {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '$weekday';
    }
  }

  DayBusinessHours copyWith({
    int? weekday,
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) {
    return DayBusinessHours(
      weekday: weekday ?? this.weekday,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'isOpen': isOpen,
    'openTime': openTime,
    'closeTime': closeTime,
  };

  factory DayBusinessHours.fromJson(Map<String, dynamic> json) {
    return DayBusinessHours(
      weekday: json['weekday'] as int? ?? 1,
      isOpen: json['isOpen'] as bool? ?? true,
      openTime: json['openTime'] as String? ?? '08:00 AM',
      closeTime: json['closeTime'] as String? ?? '06:00 PM',
    );
  }
}

class DetailerCalendarPreferences {
  final List<DayBusinessHours> weeklySchedule;
  final int advanceNoticeHours; // Minimum hours notice before booking (e.g. 2, 6, 12, 24)
  final int bufferMinutesBetweenJobs; // Turnaround buffer (e.g. 0, 30, 60 mins)
  final int maxAdvanceBookingDays; // Max days in advance clients can book (e.g. 30, 60, 90)
  final bool autoConfirmBookings;

  const DetailerCalendarPreferences({
    this.weeklySchedule = const [],
    this.advanceNoticeHours = 2,
    this.bufferMinutesBetweenJobs = 30,
    this.maxAdvanceBookingDays = 60,
    this.autoConfirmBookings = true,
  });

  static List<DayBusinessHours> get defaultWeeklySchedule => [
    const DayBusinessHours(weekday: 1, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
    const DayBusinessHours(weekday: 2, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
    const DayBusinessHours(weekday: 3, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
    const DayBusinessHours(weekday: 4, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
    const DayBusinessHours(weekday: 5, isOpen: true, openTime: '08:00 AM', closeTime: '06:00 PM'),
    const DayBusinessHours(weekday: 6, isOpen: true, openTime: '09:00 AM', closeTime: '04:00 PM'),
    const DayBusinessHours(weekday: 7, isOpen: false, openTime: '09:00 AM', closeTime: '04:00 PM'), // Sunday off by default
  ];

  factory DetailerCalendarPreferences.defaults() {
    return DetailerCalendarPreferences(
      weeklySchedule: defaultWeeklySchedule,
      advanceNoticeHours: 2,
      bufferMinutesBetweenJobs: 30,
      maxAdvanceBookingDays: 60,
      autoConfirmBookings: true,
    );
  }

  DayBusinessHours getHoursForWeekday(int weekday) {
    return weeklySchedule.firstWhere(
      (h) => h.weekday == weekday,
      orElse: () => DayBusinessHours(weekday: weekday, isOpen: true),
    );
  }

  DetailerCalendarPreferences copyWith({
    List<DayBusinessHours>? weeklySchedule,
    int? advanceNoticeHours,
    int? bufferMinutesBetweenJobs,
    int? maxAdvanceBookingDays,
    bool? autoConfirmBookings,
  }) {
    return DetailerCalendarPreferences(
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      advanceNoticeHours: advanceNoticeHours ?? this.advanceNoticeHours,
      bufferMinutesBetweenJobs: bufferMinutesBetweenJobs ?? this.bufferMinutesBetweenJobs,
      maxAdvanceBookingDays: maxAdvanceBookingDays ?? this.maxAdvanceBookingDays,
      autoConfirmBookings: autoConfirmBookings ?? this.autoConfirmBookings,
    );
  }

  Map<String, dynamic> toJson() => {
    'weeklySchedule': weeklySchedule.map((h) => h.toJson()).toList(),
    'advanceNoticeHours': advanceNoticeHours,
    'bufferMinutesBetweenJobs': bufferMinutesBetweenJobs,
    'maxAdvanceBookingDays': maxAdvanceBookingDays,
    'autoConfirmBookings': autoConfirmBookings,
  };

  factory DetailerCalendarPreferences.fromJson(Map<String, dynamic> json) {
    final list = json['weeklySchedule'] as List<dynamic>?;
    final schedule = list != null
        ? list.map((item) => DayBusinessHours.fromJson(item as Map<String, dynamic>)).toList()
        : defaultWeeklySchedule;

    return DetailerCalendarPreferences(
      weeklySchedule: schedule.isNotEmpty ? schedule : defaultWeeklySchedule,
      advanceNoticeHours: json['advanceNoticeHours'] as int? ?? 2,
      bufferMinutesBetweenJobs: json['bufferMinutesBetweenJobs'] as int? ?? 30,
      maxAdvanceBookingDays: json['maxAdvanceBookingDays'] as int? ?? 60,
      autoConfirmBookings: json['autoConfirmBookings'] as bool? ?? true,
    );
  }
}

class CalendarAvailabilityBlock {
  final String id;
  final String detailerId;
  final DateTime date; // Year, Month, Day normalized
  final bool isAllDay;
  final List<String> blockedSlots; // e.g. ['09:00 AM', '10:00 AM'] when isAllDay == false
  final String? reason;
  final DateTime createdAt;

  const CalendarAvailabilityBlock({
    required this.id,
    required this.detailerId,
    required this.date,
    this.isAllDay = true,
    this.blockedSlots = const [],
    this.reason,
    required this.createdAt,
  });

  CalendarAvailabilityBlock copyWith({
    String? id,
    String? detailerId,
    DateTime? date,
    bool? isAllDay,
    List<String>? blockedSlots,
    String? reason,
    DateTime? createdAt,
  }) {
    return CalendarAvailabilityBlock(
      id: id ?? this.id,
      detailerId: detailerId ?? this.detailerId,
      date: date ?? this.date,
      isAllDay: isAllDay ?? this.isAllDay,
      blockedSlots: blockedSlots ?? this.blockedSlots,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'detailerId': detailerId,
    'date': date.toIso8601String(),
    'isAllDay': isAllDay,
    'blockedSlots': blockedSlots,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CalendarAvailabilityBlock.fromJson(Map<String, dynamic> json) {
    return CalendarAvailabilityBlock(
      id: json['id'] as String? ?? 'block_${DateTime.now().millisecondsSinceEpoch}',
      detailerId: json['detailerId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      isAllDay: json['isAllDay'] as bool? ?? true,
      blockedSlots: (json['blockedSlots'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
      reason: json['reason'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
