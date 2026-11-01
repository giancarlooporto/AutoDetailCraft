import 'package:flutter/foundation.dart';
import 'package:detail_craft/models/booking_models.dart';
import 'package:detail_craft/services/job_repository.dart';

/// Represents a single recorded Realtime CDC broadcast event for test assertion.
class RealtimeBroadcastEvent {
  final JobRepository? sender;
  final Map<String, dynamic> payload;
  final bool isDelete;
  final DateTime timestamp;

  const RealtimeBroadcastEvent({
    this.sender,
    required this.payload,
    this.isDelete = false,
    required this.timestamp,
  });

  String? get bookingId => (payload['id'] ?? payload['booking_id'])?.toString();
  String? get status => payload['status']?.toString();
}

/// Lightweight, deterministic in-memory broadcast bus that simulates Supabase
/// Postgres CDC Realtime WebSocket event propagation across multiple running
/// JobRepository sessions (e.g. Device A, Device B, Detailer Studio).
class SimulatedRealtimeBus {
  final List<JobRepository> _sessions = [];
  final List<RealtimeBroadcastEvent> _history = [];

  /// Returns an unmodifiable view of all active registered sessions.
  List<JobRepository> get sessions => List.unmodifiable(_sessions);

  /// Returns an unmodifiable history log of all broadcast CDC events.
  List<RealtimeBroadcastEvent> get history => List.unmodifiable(_history);

  /// Total count of broadcast events transmitted.
  int get broadcastCount => _history.length;

  /// Register a repository session with the realtime bus.
  void register(JobRepository repo) {
    if (!_sessions.contains(repo)) {
      _sessions.add(repo);
    }
  }

  /// Unregister a repository session.
  void unregister(JobRepository repo) {
    _sessions.remove(repo);
  }

  /// Broadcasts a booking change payload from [sender] to all other registered sessions.
  /// Converts the [BookingAppointment] using its official [toSupabase] serialization.
  void broadcastBookingChange({
    required JobRepository sender,
    required BookingAppointment booking,
    bool isDelete = false,
  }) {
    final payload = booking.toSupabase();
    broadcastRawPayload(
      sender: sender,
      record: payload,
      isDelete: isDelete,
    );
  }

  /// Broadcasts an arbitrary Postgres CDC record (e.g. partial status update payload)
  /// to all registered sessions except the [sender].
  void broadcastRawPayload({
    required JobRepository sender,
    required Map<String, dynamic> record,
    bool isDelete = false,
  }) {
    final event = RealtimeBroadcastEvent(
      sender: sender,
      payload: Map<String, dynamic>.unmodifiable(record),
      isDelete: isDelete,
      timestamp: DateTime.now(),
    );
    _history.add(event);

    for (final session in _sessions) {
      if (!identical(session, sender)) {
        try {
          session.simulateRealtimeBookingPayload(record, isDelete: isDelete);
        } catch (e) {
          if (kDebugMode) {
            print('[SimulatedRealtimeBus] Error routing payload to session: $e');
          }
        }
      }
    }
  }

  /// Broadcasts a payload to ALL registered sessions, including the sender.
  /// Simulates an external webhook or cloud worker event (e.g. Stripe payment confirmation).
  void broadcastToAll(
    Map<String, dynamic> record, {
    bool isDelete = false,
  }) {
    final event = RealtimeBroadcastEvent(
      sender: null,
      payload: Map<String, dynamic>.unmodifiable(record),
      isDelete: isDelete,
      timestamp: DateTime.now(),
    );
    _history.add(event);

    for (final session in _sessions) {
      try {
        session.simulateRealtimeBookingPayload(record, isDelete: isDelete);
      } catch (e) {
        if (kDebugMode) {
          print('[SimulatedRealtimeBus] Error routing payload in broadcastToAll: $e');
        }
      }
    }
  }

  /// Clears the broadcast event history log.
  void clearHistory() {
    _history.clear();
  }

  /// Resets the bus by unregistering all sessions and clearing the event history.
  void clear() {
    _sessions.clear();
    _history.clear();
  }
}
