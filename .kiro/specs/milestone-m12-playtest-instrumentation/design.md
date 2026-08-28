# Design Document — M12 Playtest & Instrumentation

## Architecture direction by requirement

Unlike M9–M11, several requirements here are infrastructure/process rather than gameplay systems
— the design bar is "integrates cleanly with existing managers and doesn't regress anything," not
"introduces a new mechanic."

## Implementation decisions — 2026-08-28

M11 is active while M12 is implemented, so M12 uses existing signals and small additive autoloads
instead of rewriting M11-owned systems.

**Analytics:** no maintained Firebase/Godot integration is configured in this repository. M12 uses
an append-only, size-rotated JSON-lines funnel log in `user://telemetry/`. It stores only event
names, timestamps, and allow-listed non-identifying gameplay parameters. This is the documented
local-log fallback allowed by Requirement 1.2; a future Firebase Android plugin can forward the
same `AnalyticsManager.log_event()` contract without changing callers.

**Crash reports:** without a configured support endpoint, a crash cannot honestly be claimed as
remotely delivered. `CrashReporter` detects an unclean prior session and writes a bounded,
opt-in-ready report bundle under `user://crash_reports/`; the UI will disclose its availability
without blocking play. Remote delivery requires a maintainer-owned endpoint and privacy notice.

**Notifications:** Godot 4 provides Android integration through a plugin/`AndroidRuntime`, not a
core cross-platform local-notification API. `LocalNotificationManager` is therefore a no-op-safe
adapter for an optional `PirateLocalNotifications` Android singleton. Building is instantaneous and
fleet missions are recurring, not return-timed, so neither is an offline completion to schedule;
the adapter is used for resolved raids and preserves a mission-completion hook for future timed
missions. Android plugin/export configuration and device verification remain explicit release
evidence, not assumptions.

### Requirement 1 — Analytics

A thin `AnalyticsManager` autoload (new — no existing manager owns this axis) that exposes a single
`log_event(event_name: String, params: Dictionary = {})` call, subscribed to the same signals
`WorldHUD`/`CampaignManager`/`EmpireManager` already emit for their own UI purposes (
`chapter_started`, `chapter_completed`, `island_captured`, `raid_resolved`, etc.) — this reuses
existing signal wiring rather than instrumenting call sites throughout the codebase a second time.
Firebase vs. a lighter alternative: evaluate Firebase's GDExtension/plugin maturity for Godot 4.7 at
implementation time; if integration friction is high relative to this project's current single-
developer-plus-two-AI-agents scale, a simple JSON-lines local log (rotated, periodically upload-able
manually) is an honest, documented fallback — better than an abandoned half-integration.

### Requirement 2 — Crash reporting

Godot's own crash handler output (stack traces to `stdout`/log files) already exists; the gap is
getting that off the player's device. Simplest viable: on next launch after an abnormal previous
exit (detectable via a "clean shutdown" flag written on normal quit, checked on next boot), prompt
to optionally send the last session's log — consistent with `AGENTS.md`'s "never introduce
[unwanted] paid features" spirit applied to privacy: opt-in, not silent automatic upload, since this
project has no existing backend/consent flow to silently pipe data through.

### Requirement 3 — Save versioning, backup, migration

`SaveManager` already has `SAVE_SCHEMA_VERSION`/`save_schema_version` from M10. Migration: a
`_migrate(data: Dictionary, from_version: int) -> Dictionary` function with one `match` arm per
version transition, called from `load_game()` before the data is consumed — the same shape most
schema-migration systems use, kept as simple as this project's actual version count (likely just
`0 → 1` at this point) warrants; don't build a generic migration framework for a single transition.
Backup: on `save_game()`, before overwriting `user://save_data.json`, copy the existing file to
`user://save_data.json.bak` first (a single rotating backup, not a full history — matches the
project's "simple, expandable" economy-principles philosophy applied to save infrastructure).
Recovery: extend the existing `save_load_failed` signal path (M2 Task 12.3) to attempt loading
`.bak` before giving up and starting fresh.

### Requirement 4 — Localization

Godot's built-in translation system (`.csv` import, `tr()`/`tr_n()`) is the standard tool — no
custom localization pipeline needed. Highest-traffic surfaces first (per the requirement's own
prioritization): extract literals to a base `en.csv`, wrap every `.text =` assignment and
`String % [...]` template in `tr()`. Dynamic strings: `tr("Notoriety: %.1f") % new_val` (translate
the template, interpolate after) rather than `tr("Notoriety: %.1f" % new_val)` (which would try to
look up a different key for every possible numeric value) — this distinction is the one place a
naive find-replace pass would get it wrong, worth calling out explicitly in the task breakdown.

### Requirement 5 — Playtest protocol

Pure documentation deliverable (`docs/PLAYTEST_PROTOCOL.md` or similar, following this project's
established `docs/NN_NAME.md` numbering convention if it fits the existing sequence, or a
dedicated non-numbered doc if it's process rather than product documentation — match whichever
convention `docs/07_AI_AGENT_WORKFLOW.md`/`docs/08_PROMPT_LIBRARY.md` (also process docs) already
established). Structure: how to recruit (even informally — friends/family/a small Discord/forum
post is legitimate for a first round), what build to give them, what to observe (does Chapter 1
complete without a wiki — the exact question M7's own exit criteria flagged as "not verified,
cannot be judged headlessly"), how to log findings (a simple structured template: session length,
where they got stuck, what they said unprompted).

### Requirement 6 — Balance spreadsheet

Extends M11's artifact rather than creating a second one. Audit every `.tres` file under
`resources/` with a cost/reward field (buildings, ships, captains, loot tables, techs, raid theft
fractions) and add each to the model with its rationale — this is a comprehensive documentation
pass, not new code.

### Requirement 7 — Codex/lore browser

New `scenes/ui/CodexScreen.tscn`/`.gd`, following the established themed-screen pattern
(`PirateThemeBuilder.build()` in `_ready()`, opened via a `WorldHUD`-owned dynamically-positioned
button per the `CaptainsLog`/`WorldMapScreen` precedent). Data source: `CaptainsLog`'s existing
`log_summary`-per-chapter data, `CaptainData`'s existing identity fields (home island, allegiance,
unlock chapter — authored in M7), and `FactionData`. Gating: an entry becomes visible the same way
`CaptainsLog`'s chapter list already gates on `CampaignManager.is_chapter_completed()`, and a
captain entry the same way `IslandMenu`'s Tavern already gates on `unlock_chapter_id` — reuse both
existing gate checks rather than inventing a third "have I met this" tracking mechanism.

### Requirement 8 — Push notifications

Godot 4 exposes local notification scheduling via platform-specific plugins/singletons on Android
(there is no built-in cross-platform local-notification API in core Godot as of 4.7 — confirm the
current state of Android notification plugin support at implementation time, since this is a fast-
moving area of the Android export ecosystem). Scheduling call sites: wherever a timer already
starts for the relevant event —
`EmpireManager`'s raid-check timer (`_last_raid_check_unix`), `Island.build_structure()`/
`upgrade_structure()`'s known completion time (if construction has a duration — verify against
current `Island.gd`, since today's build/upgrade may be instant-on-purchase per `AGENTS.md`'s "no
artificial waiting," in which case this notification class may not apply and Requirement 8 AC1's
"building complete" event should be re-scoped to whatever *does* have a real time delay, e.g. a
`FleetManager` mission's return time, which already ticks on a timer). Reuse
`WorldHUD.announce_event()`'s existing message-composition logic for the notification body text so
the two surfaces (in-session banner, offline notification) never drift out of sync in wording.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Requirement 5 (playtest) and Requirement 8 (push notifications, platform permission flow) are the
two items in this milestone genuinely unverifiable by GUT or a headless capture — the first needs
real external humans, the second needs a real Android device with notification permission granted/
denied in both states. Both should be explicitly logged as "verified on device" or "not yet
verified, needs hardware" at checkpoint rather than assumed passing, consistent with this project's
established discipline around claims that can't be checked in this development environment.
