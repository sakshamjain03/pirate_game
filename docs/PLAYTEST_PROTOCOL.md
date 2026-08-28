# Playtest Protocol

> Created M12 ("Playtest & Instrumentation"), Requirement 5. Unnumbered like `docs/BALANCE_MODEL.md`
> — a living process doc, not part of the sequential `00`–`21` milestone-narrative numbering (which
> is already fully occupied by later milestones' own planning docs).

## Purpose

Every prior milestone's checkpoint has been verified by an AI agent reading code, running the GUT
suite, and — where a display is available — a single automated capture of the default boot
sequence. None of that answers the one question that actually matters before shipping: **can a
person who has never seen this game pick it up and get through Chapter 1 without help?** M7's own
exit criteria flagged this as "not verified, cannot be judged headlessly," and it still hasn't
been. This protocol is how a real human round gets run.

## What build to give them

The current `main` branch, built via the project's normal export path for whatever platform the
tester already has (desktop export is the lowest-friction choice for a first round — no device
sideloading). Do not hand-hold with an exported debug build unless a bug specifically needs
reproducing; the point is to see the *unassisted* first-run experience.

## Recruitment

Real, informal recruitment is legitimate for a first round — this does not need to be a formal
user-research panel:

- Friends/family/coworkers willing to spend 20–40 uninterrupted minutes.
- A small Discord/forum post ("looking for 5–10 min of feedback on a pirate strategy game I'm
  building") in any community the developer is already a member of.
- Anyone reachable who has **not** already seen the game's design docs or played a prior build —
  prior exposure defeats the "first-run, no wiki" test this protocol exists to run.

Target ≥10 participants per Requirement 5.2, but **log the real number reached, whatever it is** —
a round with 3 participants and honestly-logged findings is worth more than a fabricated or
extrapolated claim of 10. See "Logging findings honestly" below.

## Session structure

1. **No priming.** Hand over the build with only the same info a stranger on a store page would
   have (name, one-line pitch). Do not explain controls, mechanics, or goals unless the tester is
   fully stuck (see "when to intervene" below).
2. **Silent observation.** Watch (in person or via screen share) without narrating what you see —
   the goal is *their* unassisted path, not a guided tour.
3. **Session length: 20–40 minutes**, or until Chapter 1 completes, whichever comes first. Don't
   extend a session past the point the tester seems done/fatigued just to hit a time target.
4. **When to intervene:** only if the tester is stuck for over ~3 minutes with no forward progress
   and shows visible frustration (per Requirement 5's "does Chapter 1 complete without a wiki"
   framing — a *little* friction is expected and worth recording, not immediately rescued). Log the
   intervention itself as a finding; it's a stronger signal than anything that went smoothly.
5. **Debrief (5 min):** 2–3 open questions — "What were you trying to do just now?" / "What was
   confusing?" / "What would you do next if you kept playing?" Avoid leading questions ("did you
   find the tutorial helpful?") — ask what happened, not whether they liked what you built.

## What to observe

Per Requirement 5's own prioritization, the central question is: **does Chapter 1 complete without
external help (wiki, dev intervention, prior knowledge)?** Beyond that pass/fail, record:

- Where they got stuck, and for how long.
- What they clicked/tried that didn't do what they expected.
- What they said unprompted (not in response to a question) — this is the highest-signal data in
  the whole session; write it down close to verbatim.
- Whether they understood *why* they were doing something (goal-directed) vs. just clicking around.
- Any moment of visible delight or frustration, even brief.

## Logging findings

Use one copy of this template per participant. Keep raw notes even if they're messy — synthesis
happens after all sessions, not per-session.

```
### Participant N — <date>
- Platform/build:
- Session length:
- Reached: (e.g. "Chapter 1 complete" / "stuck in Chapter 1 at <objective>" / "quit before finishing")
- Completed Chapter 1 unassisted? Y/N (if N: where and why they stopped)
- Interventions: (what, when, why)
- Stuck points: (list, with approx. timestamp/duration each)
- Unprompted comments: (as close to verbatim as possible)
- Debrief answers:
- Anything else notable:
```

After all sessions, summarize:

```
### Round summary — <date range>
- Participants reached: N (report the real number — do not round up or assert ≥10 without evidence)
- Recruitment channel(s) used:
- Chapter 1 unassisted completion rate: N/M
- Top 3 recurring stuck points (by frequency across participants):
- Top 3 unprompted quotes:
- Recommended follow-ups (bugs, UX changes, tutorial gaps) — file these against the relevant
  milestone or `docs/09_VISUAL_BUG_TRACKER.md`, don't let them evaporate in this doc.
```

## Logging findings honestly

This is the one hard rule: **the round summary's participant count and completion rate must be the
real, observed numbers.** If only 3 people were reached instead of the ≥10 target, write "3." If a
session was cut short and inconclusive, log it as inconclusive rather than folding it into either
a pass or fail count. A milestone checkpoint that cites this protocol must be able to point at a
completed copy of the template above, not a paraphrased claim that testing "went well."

## Environment note

This protocol cannot be executed by an AI coding agent alone — it requires real external
participants and human observation, which is why M12's own checkpoint (Task 14) must log this
wave's status as either "run, with N real participants and a completed summary" or explicitly
"not yet run" rather than assumed done. See `docs/07_AI_AGENT_WORKFLOW.md` for this project's
broader discipline around claims that can't be verified in an automated environment.
