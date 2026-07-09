import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// An unbooked relocation request as it appears on the driver's Gigs browse
/// list — driver_visibility RLS (Story 1.3) already scopes what a driver can
/// SELECT; this model only carries the columns the Gigs surface renders.
class Gig {
  const Gig({
    required this.id,
    required this.origin,
    required this.destination,
    required this.scheduledDate,
    required this.notes,
    required this.status,
  });

  final String id;
  final String origin;
  final String destination;
  final DateTime scheduledDate;
  final String? notes;
  final String status;

  String get formattedDate =>
      '${_monthAbbr[scheduledDate.month - 1]} ${scheduledDate.day}, ${scheduledDate.year}';

  factory Gig.fromRow(Map<String, dynamic> row) {
    return Gig(
      id: row['id'] as String,
      origin: row['origin'] as String,
      destination: row['destination'] as String,
      scheduledDate: DateTime.parse(row['scheduled_date'] as String),
      notes: row['notes'] as String?,
      status: row['status'] as String,
    );
  }
}

const _selectColumns = 'id, origin, destination, scheduled_date, notes, status';

/// Browse/book side of the driver-mobile Gigs surface (Story 3.2).
class GigsService {
  GigsService._();

  static final GigsService instance = GigsService._();

  /// Explicit columns, not `select('*')` — relocation_requests already has a
  /// column-scoped UPDATE grant (Story 1.2), so naming columns explicitly
  /// avoids relying on undocumented wildcard-select behavior against that
  /// same table (Story 2.2 established this discipline first).
  Future<List<Gig>> fetchUnbookedGigs() async {
    final rows = await supabase
        .from('relocation_requests')
        .select(_selectColumns)
        .eq('status', 'unbooked')
        .order('created_at', ascending: false);
    return rows.map(Gig.fromRow).toList();
  }

  /// One channel, INSERT + UPDATE only — relocation_requests is never hard-
  /// deleted (every retirement path is a status transition), so a DELETE
  /// handler would be dead code. No server-side column filter on `status`:
  /// an UPDATE's filter is evaluated against the *new* row, so filtering to
  /// `status=eq.unbooked` here would silently swallow the one UPDATE this
  /// screen most needs — the transition *out* of unbooked when someone else
  /// books a gig — since by the time that event would fire, the new row no
  /// longer matches. Branching on `row['status']` client-side handles both
  /// directions correctly.
  ///
  /// [onUpsert] fires when a row's new status is `unbooked` (a new gig
  /// appeared, or a reassignment reopened one — Story 1.4's revert path).
  /// [onRemove] fires when a previously-unbooked row's status changed to
  /// anything else (someone booked it, including this driver's own winning
  /// call). Per RLS's realtime-delivery semantics (see Dev Notes on the
  /// story), a driver who never bid on a gig someone else won receives no
  /// event for that change at all — an accepted, understood staleness
  /// window, not a bug this subscription needs to work around.
  RealtimeChannel subscribe({
    required void Function(Gig gig) onUpsert,
    required void Function(String id) onRemove,
  }) {
    void handle(PostgresChangePayload payload) {
      final row = payload.newRecord;
      if (row['status'] == 'unbooked') {
        onUpsert(Gig.fromRow(row));
      } else {
        onRemove(row['id'] as String);
      }
    }

    return supabase
        .channel('gigs-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'relocation_requests',
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'relocation_requests',
          callback: handle,
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    supabase.removeChannel(channel);
  }

  /// The two-step booking sequence — Story 1.3's Dev Notes pin this exactly:
  /// `book_request` was designed assuming the client performs its own direct
  /// `booking_bids` insert (committed immediately, as its own statement)
  /// *before* calling the RPC, not as something the RPC does internally.
  /// Calling `book_request` alone silently breaks the priority tie-break —
  /// not loudly, just by making lock-acquisition order the de-facto winner
  /// instead of `completed_rides_count`. If the insert itself throws (a
  /// network failure before the RPC is even reached), that exception
  /// propagates straight to the caller and `book_request` is never called.
  ///
  /// Returns `true` if this caller was assigned the request, `false`
  /// otherwise — branch on this return value directly, never on any
  /// subsequent realtime event (see Dev Notes for why that's required, not
  /// just faster).
  Future<bool> bookGig(String requestId) async {
    final driverId = supabase.auth.currentUser!.id;

    await supabase.from('booking_bids').insert({
      'request_id': requestId,
      'driver_id': driverId,
    });

    final won = await supabase.rpc(
      'book_request',
      params: {'p_request_id': requestId},
    );
    return won as bool;
  }
}
