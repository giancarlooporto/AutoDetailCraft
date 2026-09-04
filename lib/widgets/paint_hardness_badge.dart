import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/detail_job.dart';

class PaintHardnessBadge extends StatelessWidget {
  final PaintHardness hardness;
  final bool isCompact;

  const PaintHardnessBadge({
    super.key,
    required this.hardness,
    this.isCompact = false,
  });

  String get label {
    switch (hardness) {
      case PaintHardness.soft:
        return 'Soft / Sticky Clear';
      case PaintHardness.medium:
        return 'Medium Clear';
      case PaintHardness.hard:
        return 'Rock-Hard Clear';
      case PaintHardness.singleStage:
        return 'Single Stage Lacquer';
    }
  }

  Color get color {
    switch (hardness) {
      case PaintHardness.soft:
        return AppTheme.hardnessSoft;
      case PaintHardness.medium:
        return AppTheme.hardnessMedium;
      case PaintHardness.hard:
        return AppTheme.hardnessHard;
      case PaintHardness.singleStage:
        return Colors.deepOrangeAccent;
    }
  }

  IconData get icon {
    switch (hardness) {
      case PaintHardness.soft:
        return Icons.warning_amber_rounded;
      case PaintHardness.medium:
        return Icons.check_circle_outline_rounded;
      case PaintHardness.hard:
        return Icons.shield_rounded;
      case PaintHardness.singleStage:
        return Icons.history_edu_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(100), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
