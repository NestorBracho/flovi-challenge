# Relocation Request — State Machine

> Companion to SPEC.md. Cited by CAP-2, CAP-3, CAP-6, CAP-7, CAP-9 through CAP-14. Demo-scoped: proves the concept, not a production lifecycle.

## States

- **unbooked** — created by dispatcher (CAP-2); no driver assigned. Shown to drivers as "available" (CAP-6).
- **booked** — a driver has claimed it (CAP-7) or been auto-assigned (CAP-12).
- **completed** — driver marked the ride done (CAP-14); increments that driver's completed-rides count.
- **cancelled** — dispatcher cancelled it (CAP-10); terminal, drops from all active views.

## Transitions

| From | To | Trigger | Notes |
| --- | --- | --- | --- |
| (none) | unbooked | Dispatcher creates request (CAP-2) | |
| unbooked | booked | Driver books (CAP-7) | Concurrent-booking tie-break: if two drivers attempt to book the same unbooked request at once, the driver with more completed rides wins; the other sees it as no longer available. |
| unbooked | cancelled | Dispatcher cancels (CAP-10) | Dispatcher can cancel from any state, any time. |
| booked | completed | Driver marks complete (CAP-14) | Increments the driver's completed-rides count — feeds the priority ranking used above and in reassignment below. |
| booked | cancelled | Dispatcher cancels (CAP-10) | Dispatcher can cancel from any state, any time. |
| booked | unbooked, then immediately re-evaluated → booked (new driver) or unbooked | Driver cancels with ≥24h notice (CAP-11) | Auto-reassignment (CAP-12): system immediately re-books to the active driver with the highest completed-rides count, excluding the cancelling driver. Dispatcher is notified in-app (CAP-13). If no other driver is available, the request reverts to unbooked and re-enters the available pool. |
| booked | (blocked, no transition) | Driver attempts to cancel within 24h of the ride | Rejected with a clear message; request stays booked. |

## Priority rule (shared)

Both the concurrent-booking tie-break (CAP-7) and cancellation auto-reassignment (CAP-12) use the same ranking: the driver with the higher completed-rides count wins or is selected. One rule, two call sites — keeps the mechanism consistent and cheap to build.
