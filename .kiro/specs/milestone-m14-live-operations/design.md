# Design Document — M14 Live Operations

## Sequencing

Requirement 1 (Chapters 6–10) and Requirement 2 (Regions 4/5) are independent of each other and of
everything else in this milestone — pure content authoring against systems M4/M7 already built.
Requirement 3 (seasonal events) needs its own small new system built before Ch8 can be authored
against it. Requirement 4 (authoring guide) should be written *alongside* Requirement 1, not after
— it's validated by Requirement 1's own authoring process, per Requirement 4 AC2. Requirement 5
(What's New) and Requirement 6 (remote-config consumption) are both small, disjoint additions that
can land at any point. Requirement 6 specifically has no ordering constraint relative to the rest
— it's designed to degrade gracefully regardless of when M15 lands, per its own AC2.

---

## Requirement 1 — Chapters 6–10

Mechanically identical to how Ch1–5 were authored (M7). The one real design attention point:
Ch9's gate is described in `docs/13_CAMPAIGN_LEVELS_1-5.md` §9 as "Ch8" (i.e. depends on the Spring
Crossing), but Ch8 is *repeatable*, not a normal one-time `is_chapter_completed()` chapter
(Requirement 3) — so Ch9's `required_previous_chapter`-equivalent gate can't be the standard
one-time-completion check. Resolve this explicitly when authoring Ch9: gate it on "the Spring
Crossing has been completed **at least once**" (a one-way flag separate from Requirement 3's
per-window repeat tracking — `SeasonalEventData`/`SeasonalEventManager` should expose both
"currently active" and "ever completed," and Ch9 reads only the latter) rather than inventing a
special case in `CampaignManager` for one chapter's gate.

## Requirement 2 — Regions 4/5, and the Ghost Fleet decision

**Design decision, made here rather than deferred:** confirm the Ghost Fleet as a *mechanically*
real faction in Region 5 — real ships, a real boss, real combat — while keeping the *supernatural
explanation* still ambiguous. Concretely: the Ghost Reaches' ships are real, crewed, and can be
boarded/looted like any other faction (closing the "rumour, not mechanic" gap entirely), but
whatever in-fiction dialogue explains their reputation (uncanny navigation, identical wrong charts
per `docs/06_NARRATIVE_AND_WORLD.md`'s existing Cartographer-arc flavor) stops short of confirming
or denying anything supernatural — matching how Pirates of the Caribbean-tone media typically
handles this (real, dangerous, *reads* as uncanny, never definitively magic). This resolves
Requirement 2.3 without over-committing a narrative answer this project's tone rules originally
protected on purpose, and leaves the Cartographer arc itself (`docs/13_CAMPAIGN_LEVELS_1-5.md`'s
own naming) as a real hook for whatever comes after M14, not spent here.

Region/island authoring otherwise follows M4's Imperial Waters precedent exactly — no new pattern.

## Requirement 3 — Seasonal repeatable events

```gdscript
# scripts/world/SeasonalEventData.gd (new Resource)
@export var event_id: String
@export var display_name: String
@export var objectives: Array[ObjectiveData]   # reuse the existing ObjectiveData schema — same
                                                 # condition/dispatch model chapters already use
@export var fallback_window_start_month_day: String   # e.g. "03-01", authored local fallback
@export var fallback_window_end_month_day: String      # e.g. "05-31"
@export var reward_gold: int
@export var reward_captain_id: String   # etc., same reward shape ChapterData already has
```

```gdscript
# scripts/managers/SeasonalEventManager.gd (new autoload, registered after CampaignManager)
# Loads resources/campaign/seasonal_events/*.tres the same DirAccess-scan pattern
# EmpireManager/CampaignManager already use for regions/chapters.
var _completed_windows: Dictionary = {}   # event_id -> Array[window_start_date_string], persisted

func is_active(event_id: String) -> bool:
    var window = LiveOpsConfig.get_seasonal_window(event_id)   # Requirement 6's wrapper
    return _date_in_window(Time.get_date_string_from_system(), window)

func is_completed_this_window(event_id: String) -> bool:
    var current_window_id = _window_identifier(event_id)   # e.g. "spring_crossing_2027"
    return _completed_windows.get(event_id, []).has(current_window_id)

func has_ever_completed(event_id: String) -> bool:
    return _completed_windows.get(event_id, []).size() > 0   # what Ch9's gate (Requirement 1) reads

func mark_completed(event_id: String) -> void:
    var current_window_id = _window_identifier(event_id)
    if not _completed_windows.has(event_id):
        _completed_windows[event_id] = []
    _completed_windows[event_id].append(current_window_id)   # append, never overwrite — history
                                                                 # of which windows were completed
    # get_save_data()/load_save_data() round-trip through SaveManager, same convention every
    # other manager follows.
```

Objective dispatch reuses `CampaignManager`'s existing signal-listening pattern rather than a
second implementation — `SeasonalEventManager` can either listen to the same gameplay signals
directly, or (preferred, less duplication) `CampaignManager` gains a thin extension point that
also checks `SeasonalEventManager.is_active(...)` events alongside chapter objectives, dispatching
through one shared piece of matching logic. Resolve which at implementation time by reading
`CampaignManager`'s actual current dispatch code — this design intentionally doesn't guess which
refactor is cleaner without looking.

**Reward re-granting (Requirement 3.4):** repeat completions grant the **same** reward as first
completion — simplest, most predictable, and avoids authoring a second reward tier for a feature
whose whole point is "the same good thing happens again next spring." A diminishing-returns reward
curve is a plausible future tuning knob, not something this milestone needs to invent.

## Requirement 4 — Content-authoring guide

Pure documentation, written against the real schemas (Requirements 1–3) as they're actually built,
not speculatively before them. Structure: one section per Resource type, each showing a real
annotated `.tres` example plus the corresponding script's `@export` list side-by-side — the
D3/D14 silent-failure lesson is exactly the kind of thing a "here's the actual field, here's what
happens if you typo it" callout prevents better than prose alone.

## Requirement 5 — What's New panel

`scripts/ui/WhatsNewScreen.gd`/`.tscn`, following `CaptainsLog`'s exact established pattern
(`PirateThemeBuilder.build()`, `WorldHUD`-owned button via the same dynamic-positioning helper).
Content: a flat array of `{version, date, notes}` entries, either a small `.tres`
(`PatchNotesData`) per release or a single append-only resource — either is fine at this
milestone's scale; prefer whichever needs less new schema (likely a single growing resource, since
patch notes are read, not queried/filtered). One-time-show logic reuses
`SaveManager`'s/`WorldHUD`'s existing "last seen version" comparison pattern (the same shape the M5
offline-catch-up notice already established: compare a stored value against the current one, show
once, persist the new value).

## Requirement 6 — Remote-config consumption

```gdscript
# scripts/managers/LiveOpsConfig.gd (new autoload, or a static helper — no state of its own beyond
# what it reads from RemoteConfigManager, so a lightweight non-autoload utility is also defensible;
# pick whichever this project's existing convention favors on inspection — most managers here are
# autoloads, so default to that for consistency unless there's a reason not to)

func get_seasonal_window(event_id: String) -> Dictionary:
    if Engine.has_singleton("RemoteConfigManager"):   # or however M15's autoload is actually
                                                          # detected present — confirm the real
                                                          # mechanism at implementation time
        var remote = RemoteConfigManager.get_value("seasonal_window_%s" % event_id, null)
        if remote != null:
            return remote
    # Local fallback — always available, this is what makes Requirement 6.2 true.
    var event_data = SeasonalEventManager.get_event_data(event_id)
    return {
        "start": event_data.fallback_window_start_month_day,
        "end": event_data.fallback_window_end_month_day,
    }

func is_content_enabled(content_id: String) -> bool:
    if Engine.has_singleton("RemoteConfigManager"):
        return RemoteConfigManager.get_value("kill_switch_%s" % content_id, true)   # default
                                                                                        # true = on
    return true   # no remote config at all = everything runs normally, per Requirement 6.1
```

This is the entire integration surface with M15 — one small wrapper, two functions, both with a
local answer that requires zero network/M15 presence. Nothing else in this milestone references
`RemoteConfigManager` directly; that keeps the M15 dependency contained to one file, easy to
verify (Requirement 6.3) by literally removing/renaming the file and confirming the rest of M14's
content still works.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Requirement 1's exit proof (Ch6 loads with zero script changes) should be verified the literal way
M7's was: temporarily note the pre-Ch6 script file list, author Ch6 for real, confirm nothing
outside `resources/`/`.tres` files changed to make it work. Requirement 3's seasonal window logic
needs a GUT test that can control "the current date" (inject a fake date rather than depending on
the real system clock, so the test isn't seasonally flaky) — establish this pattern if the project
doesn't already have one. Requirement 5/2 (regions, What's New) are visual/content and should get a
fresh headful `CaptureHarness` review per this project's now-standard discipline, same as every
milestone since M9.
