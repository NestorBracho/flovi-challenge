# Reflection — Flovi AI Build Challenge

> **This is a scaffold, not a draft.** The structure below is the four presentation questions from `challenge-context.md`, verbatim. No reflection content is pre-written here — filling this in with honest, specific, first-person answers is Nestor's, after the actual build (including this story's own rehearsal and delivery) is complete. A pre-written reflection would be exactly the generic "AI is amazing" trap NFR8 and the evaluation criteria warn against, and it would be putting words in the operator's mouth about a lived experience this workflow doesn't have access to.
>
> Each section below carries only a pointer to where real source material for that specific question already exists in this build — not the answer itself.

---

## 1. Prompting strategy — how did you break the problem down?

*Source material to draw from:* `PROMPT_LOG.md` — the story-by-story build shows the actual decomposition used (backend contract fully specified epic-first, then two independently-built client apps, then cross-app verification last). Consider what made that sequencing work or not, and where a prompt/story needed a second pass.

---

## 2. Where did the AI produce something wrong or incomplete? How did you catch it?

*Source material to draw from:* `PROMPT_LOG.md`'s "Changed after review" and "Real bug found and fixed" entries — e.g. the `book_request` concurrency design that was silently wrong on first principle (Story 1.3), the three real bugs caught only by actually running the live rehearsal rather than by code review (Story 4.1), the `go_router` navigation bug in Story 3.2, the missing-driver-name/silent-error bugs in Story 4.1. This question is asking for the catch mechanism as much as the bug itself — what actually surfaced each one (adversarial code review pass vs. live testing vs. reading Supabase's own docs against an assumption).

---

## 3. If you had another hour, what would you improve first?

*Source material to draw from:* items flagged-but-not-fixed across the story files — e.g. Story 3.1's still-open keyboard-focus-reachability finding on the driver-mobile tab bar, and any residual test data left live in Supabase per Story 4.1's Completion Notes. Also worth weighing against anything cut for time that never got its own story.

---

## 4. What does this experience tell you about how software development is changing?

*No sourced pointer for this one* — it's the most personal of the four questions and the story material above is mostly instrumental to it, not a direct answer.

---

## Note on "debugging mindset" (a separate scored dimension from "Reflection")

`challenge-context.md`'s evaluation table lists **debugging mindset — "how did you diagnose and fix problems without touching the code directly"** as its own criterion, distinct from the reflection questions above. Story 4.1's fix-at-source loop (diagnose via live testing → fix in the owning story's own files → redeploy → re-run the whole verification, not just the failed step) is a concrete, ready-made example for this if asked about directly in the presentation, separate from however question 2 above ends up answered.
