import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_models.dart';
import '../services/job_repository.dart';
import 'auth_modal.dart';

class BookingsListScreen extends StatelessWidget {
  final JobRepository repository;

  const BookingsListScreen({super.key, required this.repository});

  void _showBookingDetailsModal(BuildContext context, BookingAppointment booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.package.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('with ${booking.detailerBusinessName}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: booking.status.statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: booking.status.statusColor.withAlpha(100)),
                    ),
                    child: Text(
                      booking.status.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: booking.status.statusColor),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.border, height: 24),
              _sectionHeader('Appointment Details', Icons.event_available_rounded),
              _infoTile('Vehicle', booking.vehicleYearMakeModel),
              _infoTile('Scheduled Date', DateFormat('EEEE, MMMM d, yyyy').format(booking.scheduledDate)),
              _infoTile('Arrival Window', booking.scheduledTimeSlot),
              _infoTile('Service Type', booking.locationType.label),
              _infoTile('Address / Location', booking.clientAddress),
              const SizedBox(height: 16),
              _sectionHeader('Escrow & Payment Breakdown', Icons.account_balance_wallet_outlined),
              _infoTile('Total Service Fee', '\$${booking.totalPrice.toStringAsFixed(0)}'),
              _infoTile('Deposit Paid (Held in Escrow)', '\$${booking.depositAmount.toStringAsFixed(0)}', color: AppTheme.primary),
              _infoTile('Balance Due on Completion', '\$${(booking.totalPrice - booking.depositAmount).toStringAsFixed(0)}'),
              if (booking.warrantyPassportId != null) ...[
                const SizedBox(height: 16),
                _sectionHeader('Vehicle Warranty Certificate', Icons.shield_outlined),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AutoDetailCraft Passport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Certificate ID: ${booking.warrantyPassportId}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Call Host'),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Directions / Map', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestBookingsView(BuildContext context) {
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
              child: const Icon(Icons.calendar_month_rounded, size: 50, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'View & Manage Detailing Bookings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to track your confirmed appointments, escrow deposits, and digital ceramic warranty certificates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In to View Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => AuthModal.show(context, repository: repository, initialIsSignUp: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final isLoggedIn = repository.isLoggedIn;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appointments & Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          body: !isLoggedIn
              ? _buildGuestBookingsView(context)
              : repository.bookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_note_rounded, size: 48, color: AppTheme.textMuted.withAlpha(120)),
                            const SizedBox(height: 14),
                            const Text(
                              'No Bookings Yet',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Explore verified detailers on the Explore tab and book your first paint correction or coating service.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: repository.bookings.length,
                      itemBuilder: (ctx, idx) {
                        final booking = repository.bookings[idx];
                        return GestureDetector(
                          onTap: () => _showBookingDetailsModal(context, booking),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: NetworkImage(booking.detailerAvatar),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(booking.detailerBusinessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(booking.locationType.label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: booking.status.statusColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: booking.status.statusColor.withAlpha(90)),
                                      ),
                                      child: Text(
                                        booking.status.label,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: booking.status.statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: AppTheme.border, height: 20),
                                Text(booking.package.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(booking.vehicleYearMakeModel, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('EEE, MMM d').format(booking.scheduledDate),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 14),
                                    const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(booking.scheduledTimeSlot, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                    const Spacer(),
                                    Text(
                                      '\$${booking.totalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
