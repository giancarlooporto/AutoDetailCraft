import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_models.dart';

/// Reusable status progression stepper and badge for booking appointments.
/// Accurately visualizes Pending -> Confirmed -> In Progress -> Completed,
/// or a prominent Cancelled / Slot Released badge.
class BookingStatusTracker extends StatelessWidget {
  final BookingAppointment booking;

  const BookingStatusTracker({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    if (booking.status == BookingStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252).withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF5252).withAlpha(70)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFFF5252)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Status: Cancelled • Slot Released',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5252),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      (BookingStatus.pending, 'Pending', Icons.hourglass_top_rounded),
      (BookingStatus.confirmed, 'Confirmed', Icons.check_circle_outline_rounded),
      (BookingStatus.inProgress, 'In Progress', Icons.play_circle_outline_rounded),
      (BookingStatus.completed, 'Completed', Icons.task_alt_rounded),
    ];

    int currentStepIndex;
    switch (booking.status) {
      case BookingStatus.pending:
        currentStepIndex = 0;
        break;
      case BookingStatus.confirmed:
        currentStepIndex = 1;
        break;
      case BookingStatus.inProgress:
        currentStepIndex = 2;
        break;
      case BookingStatus.completed:
        currentStepIndex = 3;
        break;
      case BookingStatus.cancelled:
        currentStepIndex = -1;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withAlpha(70)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (i) {
          final step = steps[i];
          final isDone = i < currentStepIndex;
          final isCurrent = i == currentStepIndex;
          final color = isDone
              ? const Color(0xFF00E676)
              : (isCurrent ? step.$1.statusColor : AppTheme.textMuted.withAlpha(90));

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : step.$3,
                        size: 13,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          step.$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? color : (isDone ? Colors.white70 : AppTheme.textMuted),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 8,
                    height: 1.5,
                    color: i < currentStepIndex ? const Color(0xFF00E676) : AppTheme.border,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
