import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        builder: (_, scrollCtrl) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              // Status Management Actions
              if (booking.status == BookingStatus.pending) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirm & Accept Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      repository.updateBookingStatus(booking.id, BookingStatus.confirmed);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Booking confirmed & added to schedule!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ] else if (booking.status == BookingStatus.confirmed) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('Start Service (In Progress)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      repository.updateBookingStatus(booking.id, BookingStatus.inProgress);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Service is now in progress!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Complete Service & Release Escrow', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      repository.updateBookingStatus(booking.id, BookingStatus.completed);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Service marked as completed & escrow released!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ] else if (booking.status == BookingStatus.inProgress) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Complete Service & Release Escrow', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      repository.updateBookingStatus(booking.id, BookingStatus.completed);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Service marked as completed & escrow released!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
                      onPressed: () {
                        final phone = booking.clientPhone.isNotEmpty ? booking.clientPhone : '(512) 555-0199';
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Detailer phone number ($phone) copied to clipboard!'),
                            action: SnackBarAction(label: 'Call', onPressed: () {}),
                          ),
                        );
                      },
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
                      onPressed: () {
                        final address = booking.clientAddress.isNotEmpty ? booking.clientAddress : 'Austin, TX';
                        final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
                        Clipboard.setData(ClipboardData(text: mapsUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Service location address copied: $address'),
                            action: SnackBarAction(label: 'OK', onPressed: () {}),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (booking.status != BookingStatus.cancelled && booking.status != BookingStatus.completed) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRescheduleDialog(context, repository, booking),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: AppTheme.primary),
                      label: const Text('Reschedule', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {
                        repository.cancelBooking(booking.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            content: const Row(
                              children: [
                                Icon(Icons.cancel_outlined, color: Color(0xFFFF5252), size: 18),
                                SizedBox(width: 8),
                                Text('Booking reservation has been cancelled.', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFFF5252)),
                      label: const Text('Cancel Reservation', style: TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  void _showRescheduleDialog(BuildContext context, JobRepository repo, BookingAppointment booking) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: booking.scheduledDate.isAfter(DateTime.now()) ? booking.scheduledDate : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: AppTheme.darkTheme,
        child: child!,
      ),
    );
    if (pickedDate == null || !context.mounted) return;

    final availableSlots = repo.calendarPreferences.customTimeSlots.isNotEmpty
        ? repo.calendarPreferences.customTimeSlots
        : ['09:00 AM - 12:00 PM', '01:00 PM - 04:00 PM'];
    String chosenSlot = availableSlots.first;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select New Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: chosenSlot,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(labelText: 'Available Slots'),
            items: availableSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              if (val != null) setDlgState(() => chosenSlot = val);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              onPressed: () {
                repo.rescheduleBooking(booking.id, pickedDate, chosenSlot);
                Navigator.pop(dlgCtx);
                Navigator.pop(context); // close detail modal
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Booking rescheduled to ${pickedDate.month}/${pickedDate.day} at $chosenSlot!'),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Confirm Reschedule', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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

  Widget _buildBookingCard(BuildContext context, BookingAppointment booking) {
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
                      backgroundImage: booking.detailerAvatar.isNotEmpty ? NetworkImage(booking.detailerAvatar) : null,
                      child: booking.detailerAvatar.isEmpty ? const Icon(Icons.storefront_rounded, size: 16) : null,
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
  }

  Widget _buildBookingsTabList(
    BuildContext context,
    List<BookingAppointment> list, {
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 44, color: AppTheme.textMuted.withAlpha(120)),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) => _buildBookingCard(context, list[idx]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final isLoggedIn = repository.isLoggedIn;
        final allBookings = repository.bookings;

        if (allBookings.isEmpty && !isLoggedIn) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Appointments & Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            body: _buildGuestBookingsView(context),
          );
        }

        final upcoming = allBookings.where((b) =>
            b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();
        final inProgress = allBookings.where((b) =>
            b.status == BookingStatus.inProgress).toList();
        final completed = allBookings.where((b) =>
            b.status == BookingStatus.completed).toList();
        final cancelled = allBookings.where((b) =>
            b.status == BookingStatus.cancelled).toList();

        return DefaultTabController(
          length: 4,
          initialIndex: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Appointments & Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: AppTheme.primary,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12.5),
                    tabs: [
                      Tab(text: 'Upcoming (${upcoming.length})'),
                      Tab(text: 'In Progress (${inProgress.length})'),
                      Tab(text: 'Completed (${completed.length})'),
                      Tab(text: 'Cancelled (${cancelled.length})'),
                    ],
                  ),
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: TabBarView(
                      children: [
                        _buildBookingsTabList(
                          context,
                          upcoming,
                          emptyTitle: 'No Upcoming Appointments',
                          emptySubtitle: 'Confirmed and pending appointments will appear here.',
                          emptyIcon: Icons.calendar_today_rounded,
                        ),
                        _buildBookingsTabList(
                          context,
                          inProgress,
                          emptyTitle: 'No Services In Progress',
                          emptySubtitle: 'Active detailing jobs underway will appear here.',
                          emptyIcon: Icons.play_circle_outline_rounded,
                        ),
                        _buildBookingsTabList(
                          context,
                          completed,
                          emptyTitle: 'No Completed Services',
                          emptySubtitle: 'Your finished detailing appointments will be archived here.',
                          emptyIcon: Icons.task_alt_rounded,
                        ),
                        _buildBookingsTabList(
                          context,
                          cancelled,
                          emptyTitle: 'No Cancelled Bookings',
                          emptySubtitle: 'Cancelled reservations will appear here.',
                          emptyIcon: Icons.cancel_outlined,
                        ),
                      ],
                    ),
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
