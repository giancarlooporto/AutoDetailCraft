import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../screens/vehicle_editor_dialog.dart';
import '../services/job_repository.dart';

/// Centralized gate to verify that the client has at least one vehicle in "My Garage"
/// before proceeding with an appointment booking.
class ClientGarageGate {
  const ClientGarageGate._();

  /// Checks if the current user has vehicles in their garage.
  /// If empty, displays an educational alert dialog prompting them to add a vehicle first.
  /// If the user adds a vehicle, [onProceedToBooking] is invoked.
  /// Returns `true` if a vehicle exists or was just added, `false` otherwise.
  static Future<bool> ensureHasVehicle({
    required BuildContext context,
    required JobRepository repository,
    String? detailerName,
    VoidCallback? onProceedToBooking,
  }) async {
    if (repository.currentUser.myGarage.isNotEmpty) {
      onProceedToBooking?.call();
      return true;
    }

    final targetName = (detailerName != null && detailerName.trim().isNotEmpty)
        ? detailerName.trim()
        : 'the detailer';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.directions_car_filled_rounded, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add a Vehicle First',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To book an appointment with $targetName, please add your vehicle to My Garage first.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your vehicle type (Coupe, Sedan, SUV, Minivan, Truck) ensures seamless, accurate pricing.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Vehicle to Garage', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(ctx).pop();
              showDialog(
                context: context,
                builder: (_) => VehicleEditorDialog(repository: repository),
              ).then((_) {
                if (repository.currentUser.myGarage.isNotEmpty && context.mounted) {
                  onProceedToBooking?.call();
                }
              });
            },
          ),
        ],
      ),
    );

    return repository.currentUser.myGarage.isNotEmpty;
  }
}
