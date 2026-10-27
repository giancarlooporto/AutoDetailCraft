import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../models/user_vehicle.dart';
import '../services/job_repository.dart';
import '../services/supabase_auth_service.dart';
import 'vehicle_editor_dialog.dart';
import 'auth_modal.dart';
import 'edit_profile_dialog.dart';
import '../widgets/job_recipe_card.dart';
import 'detailer_workbench_view.dart';

class ProfileScreen extends StatefulWidget {
  final JobRepository repository;

  const ProfileScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _clientTabController;

  @override
  void initState() {
    super.initState();
    _clientTabController = TabController(length: 2, vsync: this);
    if (widget.repository.isLoggedIn || SupabaseAuthService.isLoggedIn) {
      widget.repository.refreshGarage();
    }
  }

  @override
  void dispose() {
    _clientTabController.dispose();
    super.dispose();
  }

  void _openVehicleEditor(BuildContext context, [UserVehicle? vehicle]) {
    if (!widget.repository.isLoggedIn) {
      AuthModal.show(
        context,
        repository: widget.repository,
        initialIsSignUp: false,
        onSuccess: () => _openVehicleEditor(context, vehicle),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => VehicleEditorDialog(
        repository: widget.repository,
        vehicleToEdit: vehicle,
        onDelete: vehicle != null
            ? () {
                widget.repository.removeVehicleFromGarage(vehicle.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text('${vehicle.fullName} removed from Garage.'),
                        ],
                      ),
                      backgroundColor: AppTheme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  void _showAccountMenu(BuildContext context) {
    final user = widget.repository.currentUser;
    final hasStudio = user.role == UserRole.detailer ||
        user.role == UserRole.superAdmin ||
        user.isVerifiedHost ||
        user.servicePackages.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: AppTheme.primary, size: 22),
            SizedBox(width: 10),
            Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(25), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                ),
                title: const Text('Edit Profile & Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Change name, photo, bio, address', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  EditProfileDialog.show(context, repository: widget.repository);
                },
              ),
              const Divider(color: AppTheme.border, height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withAlpha(25), shape: BoxShape.circle),
                  child: const Icon(Icons.logout_rounded, color: Colors.orangeAccent, size: 18),
                ),
                title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Return to guest mode', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () async {
                  final sm = ScaffoldMessenger.of(context);
                  Navigator.of(ctx).pop();
                  await widget.repository.logoutUser();
                  if (mounted) {
                    sm.showSnackBar(
                      const SnackBar(
                        content: Text('You have been logged out.'),
                        backgroundColor: AppTheme.surface,
                      ),
                    );
                  }
                },
              ),
              const Divider(color: AppTheme.border, height: 1),
              if (hasStudio) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: user.isStudioPaused ? Colors.green.withAlpha(25) : Colors.amber.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      user.isStudioPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: user.isStudioPaused ? Colors.greenAccent : Colors.amber,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    user.isStudioPaused ? 'Resume Studio' : 'Pause Studio',
                    style: TextStyle(
                      color: user.isStudioPaused ? Colors.greenAccent : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    user.isStudioPaused
                        ? 'Studio is currently paused. Tap to resume public bookings.'
                        : 'Temporarily hide from search. Services & inventory are saved.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleStudioPauseToggle(context);
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.redAccent.withAlpha(25), shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_outlined, color: Colors.redAccent, size: 18),
                  ),
                  title: const Text('Quit Detailing', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Deletes studio services & inventory. Reverts to Vehicle Owner (Client).', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleQuitDetailing(context);
                  },
                ),
              ] else ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.redAccent.withAlpha(25), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                  ),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Permanently remove vehicle owner account and garage', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteAccount(context);
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? All registered vehicles, profile info, and local settings will be permanently cleared.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final sm = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              await widget.repository.deleteAccount();
              if (mounted) {
                sm.showSnackBar(
                  const SnackBar(
                    content: Text('Account data has been deleted.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleStudioPauseToggle(BuildContext context) async {
    final repo = widget.repository;
    final isPaused = repo.currentUser.isStudioPaused;
    final sm = ScaffoldMessenger.of(context);

    if (isPaused) {
      final res = await repo.setStudioPaused(false);
      if (!res.success) {
        if (mounted) {
          sm.showSnackBar(
            SnackBar(
              content: Text(
                res.error ?? 'Could not resume studio.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {});
        sm.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Studio operations resumed! Your studio is now live in search.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F261C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.greenAccent.withAlpha(180), width: 1),
            ),
          ),
        );
      }
      return;
    }

    if (repo.hasActiveStudioBookings) {
      _showActiveBookingsBlockerDialog(context, action: 'pause');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Pause Studio Operations?'),
          ],
        ),
        content: const Text(
          'When turned off, your studio will no longer appear in client search or discovery.\n\nAll your services, custom pricing, inventory, team members, and recipes are safely saved and will be instantly restored when you turn it back on.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final res = await repo.setStudioPaused(true);
              if (!res.success) {
                if (mounted) {
                  sm.showSnackBar(
                    SnackBar(
                      content: Text(
                        res.error ?? 'Could not pause studio.',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              if (mounted) {
                setState(() {});
                sm.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Studio operations paused and hidden from search.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF231C10),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.amber, width: 1),
                    ),
                  ),
                );
              }
            },
            child: const Text('Pause Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleQuitDetailing(BuildContext context) {
    final repo = widget.repository;
    final sm = ScaffoldMessenger.of(context);

    if (repo.hasActiveStudioBookings) {
      _showActiveBookingsBlockerDialog(context, action: 'quit');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.storefront_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Quit Detailing?'),
          ],
        ),
        content: const Text(
          'Quitting detailing will permanently delete everything from your studio side:\n\n• All Services & Custom Packages\n• All Inventory (Hardware, Chemicals, Recipes)\n• Studio Profile & Team Settings\n\nYour account will revert to Client mode (Vehicle Owner).\nYour personal vehicles in your garage and personal bookings will NOT be deleted.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final res = await repo.quitDetailing();
              if (!res.success) {
                if (mounted) {
                  sm.showSnackBar(
                    SnackBar(
                      content: Text(res.error ?? 'Could not quit detailing.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }
              if (mounted) {
                setState(() {});
                sm.showSnackBar(
                  const SnackBar(
                    content: Text('Studio data deleted. Reverted to Vehicle Owner (Client) mode.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              }
            },
            child: const Text('Delete Studio & Revert to Client', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showActiveBookingsBlockerDialog(BuildContext context, {required String action}) {
    final repo = widget.repository;
    final sm = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final active = repo.activeStudioBookings;
          final hasActive = active.isNotEmpty;

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  hasActive ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: hasActive ? Colors.orangeAccent : Colors.greenAccent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cancel & Notify Customers first before Pausing or Quitting',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: hasActive
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detailers cannot ${action == 'pause' ? 'pause operations' : 'quit detailing'} while customers are still booked. You have ${active.length} active upcoming appointment${active.length == 1 ? '' : 's'}.\n\nYou must cancel and notify each customer before ${action == 'pause' ? 'pausing' : 'quitting'}:',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: active.length,
                            separatorBuilder: (context, index) => const Divider(color: AppTheme.border, height: 12),
                            itemBuilder: (_, i) {
                              final b = active[i];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            b.clientName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, h:mm a').format(b.scheduledDate),
                                          style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${b.package.title} • ${b.vehicleYearMakeModel} (${b.scheduledTimeSlot})',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.cancel_schedule_send_rounded, size: 14),
                                        label: const Text('Notify & Cancel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          await repo.cancelStudioBookingWithClientNotification(
                                            b.id,
                                            reason: action == 'pause'
                                                ? 'Studio operations temporarily paused'
                                                : 'Studio operations retiring',
                                          );
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Each customer receives a direct message informing them that the appointment is cancelled and guiding them to rebook another detailer.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'All customer appointments have been cancelled and customers notified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action == 'pause'
                              ? 'You can now safely pause your studio operations.'
                              : 'You can now proceed to quit detailing and delete all studio data.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  hasActive ? 'Close (Keep Bookings)' : 'Close',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              if (hasActive)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cancel_schedule_send_rounded, size: 15),
                  label: const Text('Cancel & Notify All Customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () async {
                    await repo.cancelAllActiveStudioBookings(
                      reason: action == 'pause'
                          ? 'Studio operations temporarily paused'
                          : 'Studio operations retiring',
                    );
                    setDialogState(() {});
                  },
                ),
              if (!hasActive)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action == 'pause' ? Colors.amber : Colors.redAccent,
                    foregroundColor: action == 'pause' ? Colors.black : Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (action == 'pause') {
                      final res = await repo.setStudioPaused(true);
                      if (!res.success) {
                        if (mounted) {
                          sm.showSnackBar(
                            SnackBar(
                              content: Text(
                                res.error ?? 'Could not pause studio.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      if (mounted) {
                        setState(() {});
                        sm.showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Studio operations paused and hidden from search.',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF231C10),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.amber, width: 1),
                            ),
                          ),
                        );
                      }
                    } else {
                      final res = await repo.quitDetailing();
                      if (!res.success) {
                        if (mounted) {
                          sm.showSnackBar(
                            SnackBar(
                              content: Text(
                                res.error ?? 'Could not quit detailing.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      if (mounted) {
                        setState(() {});
                        sm.showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Studio data deleted. Reverted to Vehicle Owner (Client) mode.',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2C1417),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.redAccent.withAlpha(180), width: 1),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    action == 'pause' ? 'Pause Studio Now' : 'Delete Studio & Revert to Client',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withAlpha(60), width: 2),
              ),
              child: const Icon(Icons.directions_car_filled_rounded, size: 54, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to AutoDetailCraft',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in or create an account to manage your personal garage, store paint correction recipes, or start your own detailing business host profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In to My Garage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => AuthModal.show(context, repository: widget.repository, initialIsSignUp: false),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Create New Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => AuthModal.show(context, repository: widget.repository, initialIsSignUp: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final constrainedWidth = screenWidth > 1280 ? 1280.0 : screenWidth;
    final dynamicBannerHeight = (constrainedWidth / 3.0).clamp(220.0, 420.0);
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final isLoggedIn = widget.repository.isLoggedIn;
        if (!isLoggedIn) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Garage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: AppTheme.background,
              elevation: 0,
            ),
            body: _buildGuestView(),
          );
        }

        final user = widget.repository.currentUser;
        final isDetailer = widget.repository.isDetailerWorkbenchMode ||
            user.role == UserRole.detailer ||
            widget.repository.workbenchMode == 'studio';

        // If in detailer studio workbench mode, render DetailerWorkbenchView directly
        if (isDetailer) {
          return DetailerWorkbenchView(repository: widget.repository);
        }

        final savedJobs = widget.repository.savedJobs;
        final garage = user.myGarage;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: dynamicBannerHeight,
                  pinned: false,
                  backgroundColor: AppTheme.background,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      tooltip: 'Account Settings',
                      onPressed: () => _showAccountMenu(context),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Blurred Full-Width Background
                        user.localCoverBytes != null
                            ? Image.memory(user.localCoverBytes!, fit: BoxFit.cover)
                            : (user.coverUrl.trim().isNotEmpty
                                ? Image.network(
                                    user.coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surfaceLight),
                                  )
                                : Container(color: AppTheme.surfaceLight)),
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                            child: Container(color: Colors.black.withAlpha(100)),
                          ),
                        ),
                        // 2. Crisp Centered Foreground Image
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: user.localCoverBytes != null
                                  ? Image.memory(user.localCoverBytes!, fit: BoxFit.cover)
                                  : (user.coverUrl.trim().isNotEmpty
                                      ? Image.network(
                                          user.coverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                        )
                                      : const SizedBox()),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.background.withAlpha(200),
                                AppTheme.background,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1280),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => EditProfileDialog.show(context, repository: widget.repository),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.primary, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(150),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 36,
                                        backgroundColor: AppTheme.surfaceLight,
                                        backgroundImage: user.localAvatarBytes != null
                                            ? MemoryImage(user.localAvatarBytes!) as ImageProvider
                                            : (user.avatarUrl.trim().isNotEmpty
                                                ? NetworkImage(user.avatarUrl.trim())
                                                : null),
                                        child: (user.localAvatarBytes == null && user.avatarUrl.trim().isEmpty)
                                            ? Text(
                                                user.displayName.isNotEmpty
                                                    ? user.displayName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.displayName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => EditProfileDialog.show(context, repository: widget.repository),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(100),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            child: const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.location,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Vehicle Owner',
                                            style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          key: const Key('become_a_detailer_btn'),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.black,
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => widget.repository.toggleHostMode(targetRole: UserRole.detailer),
                                          icon: const Icon(Icons.storefront_rounded, size: 14, color: Colors.black),
                                          label: const Text(
                                            'Become a Detailer',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (user.bio.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              user.bio,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Client Mode Tabs (My Garage / Saved Recipes)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _clientTabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primary,
                      tabs: const [
                        Tab(text: 'My Garage'),
                        Tab(text: 'Saved Recipes'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
                    controller: _clientTabController,
                    children: [
                      // CLIENT TAB 1: My Garage
                      RefreshIndicator(
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        onRefresh: () async {
                          await widget.repository.refreshGarage();
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 720;
                            final isWide = constraints.maxWidth >= 1024;
                            final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1100),
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: isDesktop ? 300 : double.infinity,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppTheme.primary),
                                            foregroundColor: AppTheme.primary,
                                            minimumSize: const Size(double.infinity, 44),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Vehicle to My Garage', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () => _openVehicleEditor(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (garage.isEmpty)
                                      Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 24),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                                          constraints: const BoxConstraints(maxWidth: 480),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surface.withAlpha(160),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppTheme.border.withAlpha(120)),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(18),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary.withAlpha(20),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppTheme.primary.withAlpha(60)),
                                                ),
                                                child: const Icon(Icons.directions_car_outlined, size: 40, color: AppTheme.primary),
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'No Vehicles in Garage Yet',
                                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Register your personal car to store OEM paint codes, track digital detail warranty passports, and quickly book tailored packages.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                                              ),
                                              const SizedBox(height: 20),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppTheme.primary,
                                                  side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.add, size: 16),
                                                label: const Text('Add Your First Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                                                onPressed: () => _openVehicleEditor(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else if (!isDesktop)
                                      // Single column for mobile with uniform 16:9 photo framing
                                      ...garage.map((veh) => _buildGarageVehicleCard(veh))
                                    else
                                      // Multi-column grid for desktop/tablet so cards remain balanced and uniform
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 0.88,
                                        ),
                                        itemCount: garage.length,
                                        itemBuilder: (context, index) {
                                          return _buildGarageVehicleCard(garage[index], isGrid: true);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // CLIENT TAB 2: Saved Recipes
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: savedJobs.isEmpty
                              ? Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(20),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppTheme.primary.withAlpha(60)),
                                          ),
                                          child: const Icon(Icons.bookmark_border_rounded, size: 40, color: AppTheme.primary),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'No Saved Recipes Yet',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Bookmark transformations from the feed to reference for your vehicle.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isDesktop = constraints.maxWidth >= 720;
                                    final isWide = constraints.maxWidth >= 1024;
                                    final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

                                    return Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 1200),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: !isDesktop
                                              ? ListView.builder(
                                                  padding: const EdgeInsets.all(16),
                                                  itemCount: savedJobs.length,
                                                  itemBuilder: (context, index) {
                                                    final job = savedJobs[index];
                                                    return JobRecipeCard(
                                                      job: job,
                                                      repository: widget.repository,
                                                      onJobChanged: () => setState(() {}),
                                                      onLike: () => widget.repository.toggleLike(job.id),
                                                      onSave: () => widget.repository.toggleSave(job.id),
                                                    );
                                                  },
                                                )
                                              : SingleChildScrollView(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      for (int col = 0; col < crossAxisCount; col++) ...[
                                                        if (col > 0) const SizedBox(width: 16),
                                                        Expanded(
                                                          child: Column(
                                                            children: [
                                                              for (int i = col; i < savedJobs.length; i += crossAxisCount)
                                                                JobRecipeCard(
                                                                  job: savedJobs[i],
                                                                  repository: widget.repository,
                                                                  onJobChanged: () => setState(() {}),
                                                                  onLike: () => widget.repository.toggleLike(savedJobs[i].id),
                                                                  onSave: () => widget.repository.toggleSave(savedJobs[i].id),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGarageVehicleCard(UserVehicle veh, {bool isGrid = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vehicle Image Container with strict 16:9 Aspect Ratio
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: AppTheme.surfaceLight,
                child: veh.localImageBytes != null && veh.localImageBytes!.isNotEmpty
                    ? Image.memory(
                        veh.localImageBytes!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      )
                    : (veh.imageUrl.isNotEmpty
                        ? Image.network(
                            veh.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppTheme.surfaceLight,
                              child: const Center(
                                child: Icon(Icons.directions_car_filled_rounded, size: 48, color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        : Container(
                            color: AppTheme.surfaceLight,
                            child: const Center(
                              child: Icon(Icons.directions_car_filled_rounded, size: 48, color: AppTheme.textMuted),
                            ),
                          )),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        veh.fullName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Edit Button
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                      tooltip: 'Edit Vehicle & Photo',
                      onPressed: () => _openVehicleEditor(context, veh),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(VehicleBodyType.getIcon(veh.vehicleType), size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            veh.vehicleType,
                            style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.palette_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Paint Color: ${veh.colorName}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (veh.lastDetailService != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Active Care: ${veh.lastDetailService}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar || oldDelegate.tabBar.controller != tabBar.controller;
  }
}
