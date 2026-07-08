# Story 4.2: Repo, Prompt Log & Reflection Delivery Artifacts

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator submitting the challenge,
I want the public repo, prompt log, and written reflection all in order,
so that the submission meets every delivery constraint in SPEC.md, not just the working software.

## Acceptance Criteria

1. **Given** the repository used across Epics 1-3, **when** its visibility and history are checked, **then** it is publicly visible (GitHub/GitLab) and its commit history shows incremental commits reflecting the project's evolution — not one squashed initial commit (NFR4).
2. **Given** the prompts used throughout the build, **when** the prompt log is compiled, **then** it captures key prompts, what came back, and what was changed and why, in written or recorded form (NFR6).
3. **Given** the completed build across all four epics, **when** the written reflection is authored, **then** it honestly and specifically addresses what worked, what broke, and where AI got in the way — not a generic "AI is amazing" statement (NFR8).
4. **Given** the challenge's submission logistics (`challenge-context.md`), **when** delivery is finalized, **then** live URLs and the repo link are ready to send at least 1 hour before the presentation slot, with prompt log and reflection ready to walk through if asked.

## Tasks / Subtasks

Like Story 4.1, this story produces documentation artifacts and a verification pass, not application code.

- [ ] Task 1 — Repo visibility and history (AC: #1)
  - [ ] Confirm the GitHub repo (`NestorBracho/flovi-challenge`) is set to **Public** in its repo settings — this environment has no `gh` CLI available to verify programmatically, so check it directly on github.com rather than assuming
  - [ ] Confirm commit history shows real incremental commits across the build (one commit per story or logical unit, landing as each Epic 1-3 story actually gets implemented) — not the whole project squashed into one commit at the end. This falls out naturally as long as commits happen throughout `dev-story` work rather than being deferred to a single end-of-project commit; worth a final `git log --oneline` sanity check before submission

- [ ] Task 2 — Compile the prompt log from material that already exists, don't reconstruct it from memory (AC: #2)
  - [ ] The 17 story files this sprint-planning/create-story process already produced are themselves a large part of the raw material NFR6 asks for — each one's **Dev Notes** section documents a real prompt-driven decision with its own "what came back, what was changed, why" (e.g., discovering the two-step booking sequence was required rather than optional, the Postgres/Dart timezone corrections, the Vercel SPA-rewrite gap). Compiling the log is substantially a curation task over material already produced during this build, not a from-scratch writing task after the fact.
  - [ ] Extend this same habit through the actual `dev-story`/`code-review` phases still ahead — capture prompts and outcomes as they happen rather than trying to reconstruct them at the very end from memory, which is where detail (and honesty) tends to get lost
  - [ ] Written or recorded form both satisfy NFR6 — pick whichever the operator can produce with the least friction given the time remaining

- [ ] Task 3 — Written reflection: a scaffold to fill in honestly, not pre-drafted content (AC: #3)
  - [ ] `challenge-context.md` gives four specific presentation questions to prepare for — use them as the reflection's actual structure rather than a generic essay:
    - Prompting strategy — how the problem was broken down
    - Where the AI produced something wrong or incomplete, and how it was caught
    - What would be improved first with another hour
    - What this experience says about how software development is changing
  - [ ] The evaluation criteria explicitly name **"debugging mindset — how did you diagnose and fix problems without touching the code directly"** as its own scored dimension, distinct from "reflection" generally. Story 4.1's own fix-at-source loop (AC #5 there) is a concrete, ready-made source for this specific question if anything actually breaks during that rehearsal — worth flagging now so it isn't lost by the time this story is written
  - [ ] **This story should not draft example reflection sentences.** A pre-written reflection is exactly the "generic AI is amazing" trap NFR8 and the evaluation criteria explicitly warn against — worse, it would be putting words in the operator's mouth about their own lived experience of a build that, as of this story's creation, hasn't happened yet. The honest, specific version can only be written after the actual `dev-story` work, using Task 2's compiled log as source material.

- [ ] Task 4 — Submission logistics (AC: #4)
  - [ ] `challenge-context.md`'s submission line has a literal unfilled placeholder — "`[hiring contact]`" — resolve who that actually is before send time, it isn't specified anywhere in this project's docs
  - [ ] Send live URLs (Stories 2.5/3.5) + repo link at least **1 hour** before the presentation slot — not at the presentation itself
  - [ ] Be ready to share screen and walk through both apps live — this is Story 4.1's rehearsal, already timed and proven, not a new thing to prepare separately

## Dev Notes

### The prompt log is mostly already being written, as a byproduct of this exact process
This is worth internalizing rather than treating as a late-stage documentation chore: every story file created during sprint-planning/create-story has a Dev Notes section built specifically to explain a real technical judgment call with its reasoning — that *is* NFR6's "what came back, what was changed, why," just not yet assembled into one place. The risk to actually manage here is losing the same discipline once `dev-story`/`code-review` sessions start moving faster than story-creation did — that's where the honest, specific material for both the log and the reflection actually gets generated.

### Why this story doesn't draft reflection content
Distinguishing this from every other story in the project: everywhere else, this workflow's job was to hand the dev agent everything needed for confident, disaster-free implementation. Here, doing that same thing — pre-writing plausible-sounding reflection content — would actively work against what's being evaluated (honest, specific, first-person reflection). The right kind of help here is structure (the four actual presentation questions) and a reminder of where good raw material will come from (Task 2's log, Story 4.1's fix loop), not a draft to edit.

### Testing standards summary
No automated test suite in scope, and no test in the conventional sense applies to this story either — its own AC #1 (repo/history) is directly checkable, and ACs #2-4 are judged by whether the actual artifacts exist and are honest/specific when the operator presents, not by any automated check.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 4.2: Repo, Prompt Log & Reflection Delivery Artifacts]
- [Source: _bmad-output/specs/spec-relocation-dispatch/challenge-context.md — evaluation criteria, the four presentation questions, submission logistics (read fresh for this story — not previously loaded in this build)]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#NFR4, NFR6, NFR8]
- [Source: _bmad-output/implementation-artifacts/4-1-cross-app-end-to-end-realtime-verification.md — the fix-at-source loop that's a concrete source for the "debugging mindset" evaluation dimension]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
