---
id: SPEC-relocation-dispatch
companions: ["stack.md", "state-machines.md", "challenge-context.md"]
sources: ["../../../../docs/brief.md"]
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability only — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Relocation-Dispatch Demo — Two Connected Apps

## Why

This is a mandate to meet: the Flovi AI Build Challenge, a timed skill assessment that evaluates the candidate as an AI-powered engineer, not as a hand-coder. The candidate must build and ship two connected apps — a dispatcher web app and a driver mobile app, sharing one relocation-request/gig backend — entirely via AI-generated code, live on the internet, within a 4-hour window from start to published URLs. What's graded is prompting quality, product judgment, debugging mindset, delivery, and honest reflection — not the code itself.

## Capabilities

- **CAP-1**
  - **intent:** A user signs in via Google OAuth through the dispatcher web app; signing up through this app persists their account with the dispatcher role.
  - **success:** An unauthenticated visitor is redirected to Google OAuth from the dispatcher app; on first sign-in their account is saved with role=dispatcher, and they land in the authenticated dispatcher dashboard.

- **CAP-2**
  - **intent:** Signed-in dispatcher creates a new relocation request (origin, destination, date, notes).
  - **success:** Submitting the form persists a new request in the `unbooked` state (see `state-machines.md`), visible in the list immediately.

- **CAP-3**
  - **intent:** Signed-in dispatcher views all relocation requests with a visible status indicator per request.
  - **success:** The list renders every request with a status badge reflecting its lifecycle state (`state-machines.md`), updating without manual reload when status changes elsewhere.

- **CAP-4**
  - **intent:** Signed-in dispatcher edits fields of an existing relocation request and saves updates.
  - **success:** Editing a field and saving persists the change; the updated value shows in the list immediately.

- **CAP-5**
  - **intent:** A user signs in via Google OAuth through the driver mobile app; signing up through this app persists their account with the driver role.
  - **success:** An unauthenticated driver is redirected to Google OAuth from the driver app; on first sign-in their account is saved with role=driver, and they land on the available-gigs screen.

- **CAP-6**
  - **intent:** Signed-in driver browses relocation gigs in the `unbooked` state.
  - **success:** The gigs list shows only unbooked requests; a newly created dispatcher request appears without an app restart.

- **CAP-7**
  - **intent:** Signed-in driver books an available gig in one tap and receives confirmation.
  - **success:** Tapping "book" shows a confirmation; if two drivers attempt to book the same gig concurrently, the driver with more completed rides is awarded it and the other sees it as no longer available; the winner's gig appears in their booked list (priority rule shared with CAP-12, detailed in `state-machines.md`).

- **CAP-8**
  - **intent:** Signed-in driver views the gigs they have personally booked.
  - **success:** The booked-gigs screen shows only currently-booked requests for the signed-in driver, with current status.

- **CAP-9**
  - **intent:** Changes made in either app (new request, edit, booking, cancellation, reassignment) propagate to the other app without a manual refresh.
  - **success:** A dispatcher create/edit appears or updates in the driver app within seconds; a driver booking, cancellation, or reassignment updates the dispatcher's status view within seconds — no manual reload on either side.

- **CAP-10**
  - **intent:** Signed-in dispatcher cancels an existing relocation request at any time, regardless of its current status.
  - **success:** Cancelling sets the request to `cancelled`, removes it from driver available/booked views, and the dispatcher's list reflects the cancelled status immediately.

- **CAP-11**
  - **intent:** Signed-in driver cancels a gig they've booked, provided at least 24 hours remain before the scheduled date.
  - **success:** A cancellation attempted within 24h of the scheduled date is blocked with a clear message; cancelling with ≥24h notice releases the gig for automatic reassignment (CAP-12).

- **CAP-12**
  - **intent:** When a driver cancels with valid notice, the system automatically re-books the gig to another eligible driver so the dispatcher's view stays uninterrupted.
  - **success:** Within seconds of a valid driver cancellation, the gig is reassigned to the active driver with the highest completed-rides count (excluding the cancelling driver), or reverts to `unbooked` if none is available — same priority rule as CAP-7 (`state-machines.md`).

- **CAP-13**
  - **intent:** Dispatcher is notified in-app when a driver cancellation and automatic reassignment occurs for one of their requests.
  - **success:** A visible notification/indicator referencing the affected request appears in the dispatcher app when this event occurs, without manual refresh (reuses CAP-9's realtime channel).

- **CAP-14**
  - **intent:** Signed-in driver marks a booked gig as completed once the ride has occurred.
  - **success:** Marking complete sets the request to `completed` and increments that driver's completed-rides count (feeds the CAP-7/CAP-12 priority ranking); the gig no longer lists as an active booked gig.

## Constraints

- Zero lines of code written by hand — every file must be AI-generated.
- 4-hour hard cap from start to published URLs.
- Both apps must be live and accessible on the internet, not just running locally.
- Source lives in a publicly visible repository (GitHub/GitLab) with a commit history that shows the project's evolution.
- Visual design must read as modern and polished, not a bare tutorial app.
- Must produce a prompt log (written or recorded) capturing key prompts, what came back, and what was changed and why.
- Must be demoable end-to-end in a 5-minute walkthrough as if showing a real customer.
- Must include a written reflection: what worked, what broke, where AI got in the way.

## Non-goals

- App-store publishing / native binary distribution — a hosted Flutter web build or APK-run instructions satisfy the mobile deliverable.
- Code quality, architecture elegance, and test coverage are not evaluation targets — the challenge grades the operator, not the codebase.
- Dispatcher manually assigning a request to a specific driver — drivers self-select by booking, and reassignment (CAP-12) is system-automatic, not dispatcher-picked.
- Payments/invoicing, driver ratings, in-app chat, and multi-tenant/admin management are not part of this build.

## Success signal

Within the 4-hour window, both apps are live at public URLs and the public repo shows incremental commits. A dispatcher-created request becomes visible and bookable by a driver, and that booking's status reflects back into the dispatcher's list — both directions without a manual refresh.

## Assumptions

- Database is seeded with a handful of test dispatcher and driver accounts at initialization for demo convenience; the app-of-signup role rule (CAP-1/CAP-5) governs any new sign-ups beyond the seed data.
- Auto-reassignment (CAP-12) draws from all currently active drivers, not a specific waitlist/interested pool, ranked by completed-rides count descending and excluding the cancelling driver — a simplification appropriate for demo scope.
- Concurrent-booking priority (CAP-7) is enforced via a database-level check at transaction time comparing driver completed-rides counts, not a distributed queue — true sub-second race conditions are unlikely in a live demo, but the rule still governs which write is accepted if two land in the same transaction window.
- "Completed" is a manual driver action (CAP-14) rather than automatic/date-triggered — the simplest lifecycle that still proves the priority-ranking concept.
