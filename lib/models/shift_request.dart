import 'calendar_availability_block.dart';

enum ShiftRequestStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case ShiftRequestStatus.pending:
        return 'Pending Approval';
      case ShiftRequestStatus.approved:
        return 'Approved';
      case ShiftRequestStatus.rejected:
        return 'Declined';
    }
  }
}

class ShiftRequest {
  final String id;
  final String detailerId; // Shop / studio ID
  final String teamMemberId;
  final String teamMemberName;
  final String? teamMemberRole;
  final List<DayBusinessHours> requestedSchedule;
  final DateTime? specificDateOff; // If requesting a specific single date off (null for weekly schedule change)
  final String reason; // e.g. "Doctor's appointment", "Family emergency"
  final ShiftRequestStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewerNotes;

  const ShiftRequest({
    required this.id,
    required this.detailerId,
    required this.teamMemberId,
    required this.teamMemberName,
    this.teamMemberRole,
    required this.requestedSchedule,
    this.specificDateOff,
    this.reason = '',
    this.status = ShiftRequestStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewerNotes,
  });

  bool get isPending => status == ShiftRequestStatus.pending;
  bool get isApproved => status == ShiftRequestStatus.approved;
  bool get isRejected => status == ShiftRequestStatus.rejected;

  Map<String, dynamic> toJson() => {
    'id': id,
    'detailer_id': detailerId,
    'team_member_id': teamMemberId,
    'team_member_name': teamMemberName,
    'team_member_role': teamMemberRole,
    'requested_schedule': requestedSchedule.map((h) => h.toJson()).toList(),
    if (specificDateOff != null) 'specific_date_off': specificDateOff!.toIso8601String(),
    'reason': reason,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
    if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
  };

  factory ShiftRequest.fromJson(Map<String, dynamic> json) {
    final schedList = json['requested_schedule'] as List<dynamic>?;
    final schedule = schedList
        ?.map((item) => DayBusinessHours.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList() ?? [];

    ShiftRequestStatus parsedStatus = ShiftRequestStatus.pending;
    final statusStr = json['status'] as String?;
    if (statusStr == 'approved') {
      parsedStatus = ShiftRequestStatus.approved;
    } else if (statusStr == 'rejected' || statusStr == 'declined') {
      parsedStatus = ShiftRequestStatus.rejected;
    }

    return ShiftRequest(
      id: json['id'] as String? ?? 'sr_${DateTime.now().millisecondsSinceEpoch}',
      detailerId: json['detailer_id'] as String? ?? '',
      teamMemberId: json['team_member_id'] as String? ?? '',
      teamMemberName: json['team_member_name'] as String? ?? 'Staff Member',
      teamMemberRole: json['team_member_role'] as String?,
      requestedSchedule: schedule,
      specificDateOff: json['specific_date_off'] != null
          ? DateTime.tryParse(json['specific_date_off'] as String)
          : null,
      reason: json['reason'] as String? ?? '',
      status: parsedStatus,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      reviewerNotes: json['reviewer_notes'] as String?,
    );
  }

  ShiftRequest copyWith({
    String? id,
    String? detailerId,
    String? teamMemberId,
    String? teamMemberName,
    String? teamMemberRole,
    List<DayBusinessHours>? requestedSchedule,
    DateTime? specificDateOff,
    String? reason,
    ShiftRequestStatus? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewerNotes,
  }) {
    return ShiftRequest(
      id: id ?? this.id,
      detailerId: detailerId ?? this.detailerId,
      teamMemberId: teamMemberId ?? this.teamMemberId,
      teamMemberName: teamMemberName ?? this.teamMemberName,
      teamMemberRole: teamMemberRole ?? this.teamMemberRole,
      requestedSchedule: requestedSchedule ?? this.requestedSchedule,
      specificDateOff: specificDateOff ?? this.specificDateOff,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
    );
  }
}
