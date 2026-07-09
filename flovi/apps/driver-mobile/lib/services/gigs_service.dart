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

/// A relocation request row as it appears on either driver-mobile list —
/// Gigs (Story 3.2, unbooked only) or Booked (Story 3.3, this driver's own
/// booked rows) — driver_visibility RLS (Story 1.3) already scopes what a
/// driver can SELECT; this model only carries the columns either surface
/// renders. [driverId] is null for unbooked rows and is only meaningful once
/// a row has been assigned.
class Gig {
  const Gig({
    required this.id,
    required this.origin,
    required this.destination,
    required this.scheduledDate,
    required this.notes,
    required this.status,
    required this.driverId,
  });

  final String id;
  final String origin;
  final String destination;
  final DateTime scheduledDate;
  final String? notes;
  final String status;
  final String? driverId;

  String get formattedDate =>
      '${_monthAbbr[scheduledDate.month - 1]} ${scheduledDate.day}, ${scheduledDate.year}';

  /// Story 3.4 Task 1's client-side echo of AD-7's cutoff formula —
  /// `scheduled_date @ 00:00 UTC − 24h` — for instant proactive Cancel-button
  /// feedback only; `cancel_request_driver`'s own server-side re-check is
  /// still the authoritative gate. Built from [scheduledDate]'s already-parsed
  /// year/month/day rather than re-parsing the raw column string a second
  /// time: those components are exactly what was written in the source date
  /// string regardless of which timezone `DateTime.parse` assumed when first
  /// constructing [scheduledDate], so rebuilding them via `DateTime.utc(...)`
  /// here sidesteps `DateTime.parse`'s local-time default on a bare date
  /// string — the exact trap this task calls out.
  DateTime get cancelCutoffUtc => DateTime.utc(
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
  ).subtract(const Duration(hours: 24));

  bool get isCancellable => DateTime.now().toUtc().isBefore(cancelCutoffUtc);

  factory Gig.fromRow(Map<String, dynamic> row) {
    return Gig(
      id: row['id'] as String,
      origin: row['origin'] as String,
      destination: row['destination'] as String,
      scheduledDate: DateTime.parse(row['scheduled_date'] as String),
      notes: row['notes'] as String?,
      status: row['status'] as String,
      driverId: row['driver_id'] as String?,
    );
  }
}

const _selectColumns =
    'id, origin, destination, scheduled_date, notes, status, driver_id';

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

  /// This driver's own currently-booked rows for the Booked list (Story
  /// 3.3). Scoped server-side to `status = booked AND driver_id = me` even
  /// though driver_visibility RLS would already let this driver's own rows
  /// of *any* status (including completed/cancelled history) through — the
  /// extra filter here is what narrows a broad RLS grant down to what this
  /// specific view is for, the same split Story 3.2 established for Gigs.
  Future<List<Gig>> fetchBookedGigs(String driverId) async {
    final rows = await supabase
        .from('relocation_requests')
        .select(_selectColumns)
        .eq('status', 'booked')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);
    return rows.map(Gig.fromRow).toList();
  }

  RealtimeChannel? _channel;
  final List<void Function(Map<String, dynamic> row)> _listeners = [];

  /// One shared channel for the whole `relocation_requests` table, fanned
  /// out to every caller — Gigs (Story 3.2) and Booked (Story 3.3) both read
  /// the same table under the same driver_visibility RLS policy and only
  /// differ in which status/driver_id predicate they apply to the raw row,
  /// so a second independent channel here would just be two WebSocket
  /// connections doing the same job (the dispatcher-web app's notifications
  /// badge, Story 2.4, established this same "lift the subscription above
  /// the single view that needs it" precedent). Each caller's [onChange]
  /// receives the raw row and decides for itself whether it's an
  /// upsert-into or a remove-from its own filtered list.
  ///
  /// INSERT + UPDATE only — relocation_requests is never hard-deleted (every
  /// retirement path is a status transition), so a DELETE handler would be
  /// dead code.
  void subscribe({required void Function(Map<String, dynamic> row) onChange}) {
    _listeners.add(onChange);
    _channel ??= supabase
        .channel('relocation-requests-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'relocation_requests',
          callback: _dispatch,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'relocation_requests',
          callback: _dispatch,
        )
        .subscribe();
  }

  void _dispatch(PostgresChangePayload payload) {
    final row = payload.newRecord;
    // Iterate a copy: a listener's own callback can synchronously trigger
    // navigation/dispose that mutates _listeners mid-iteration.
    for (final listener in List.of(_listeners)) {
      listener(row);
    }
  }

  /// Only tears down the actual channel once the last caller has left —
  /// Gigs and Booked are both kept alive simultaneously by GoRouter's
  /// StatefulShellRoute, so one screen unmounting must not cut the other's
  /// feed.
  void unsubscribe(void Function(Map<String, dynamic> row) onChange) {
    _listeners.remove(onChange);
    if (_listeners.isEmpty && _channel != null) {
      supabase.removeChannel(_channel!);
      _channel = null;
    }
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

  /// Story 3.4 Task 2's Cancel action. Left uncaught here — a caller past
  /// the server's own 24h re-check gets a [PostgrestException] whose
  /// `message` is pinned exactly by Story 1.4 to
  /// `'Too close to the ride to cancel (within 24h).'`; the caller displays
  /// that message directly (AD-3, AC #4) rather than this layer re-deriving
  /// or paraphrasing it.
  Future<void> cancelBooking(String requestId) async {
    await supabase.rpc(
      'cancel_request_driver',
      params: {'p_request_id': requestId},
    );
  }

  /// Story 3.4 Task 3's Mark complete action.
  Future<void> completeRequest(String requestId) async {
    await supabase.rpc(
      'complete_request',
      params: {'p_request_id': requestId},
    );
  }
}
