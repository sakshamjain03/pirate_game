> Read-only audit inputs (2026-10-05), workflows wf_95a5d2d8-2d0 (coverage) and wf_4b855b7f-477 (flow edge cases, schema/RLS/security). Source of Wave 0.13/0.14 tasks.

# 1. Save coverage audit
**Scope mismatch.** The relayed user request asks for loot and ship-strength balance for an "intern player mode". The computed task asks for a save-coverage audit, so that is what this report covers. No mode with "intern" in its name exists in the code. The only game modes are `SceneManager.GameMode { CAMPAIGN, MAELSTROM }` (scripts/managers/SceneManager.gd:30). The only difficulty setting is AI difficulty: Relaxed/Normal/Hard/Brutal (scripts/managers/SettingsManager.gd:88-92, scripts/combat/AIDifficultyData.gd). The intern-mode balance question is still open.

# Save coverage audit — Pirate Empire

**How the cloud copy works.** The cloud payload is the same `save_dict` as the local save (SaveManager.gd:355-356 calls `_sync_to_cloud(save_dict)`). So "cloud synced" means "in the local save, the player is signed in, and the push succeeded". A failed push is only retried by the next `save_game()` (:692). Anything kept in a separate `user://` file never reaches the cloud, except entitlements, which have their own table.

## Coverage table

| System | Field | Local | Cloud | Evidence | Risk |
|---|---|---|---|---|---|
| Player ship | pos/rot | Y | Y | SaveManager.gd:242-246, 420-427 | Low |
| Player ship | hull/sails/crew (ShipDamage) | Y | Y | :252-254, 451-458 | Low |
| Player ship | equipped cosmetics | Y | Y | :258-260, 474-476 | Low |
| Player ship | captain_id | written, never read | Y | :268-269 (load uses FleetManager index) | Low |
| Islands | buildings | Y, only for islands in the tree | Y | :276-285, 478-493 | **Med**: disabled islands drop out of the save |
| Islands | discovered | Y | Y | :284, 493 | Low |
| Islands | **island_type / owner_faction (ownership)** | **N** | **N** | Island.gd:201-202 writes them; nothing serializes them; PortRoyal.tres has no `island_type` (NEUTRAL) | **CRITICAL** |
| Economy | resources incl. `eights` | Y | Y | ResourceManager.gd:195-205 | Med (see the cloud-conflict bugs) |
| Fleet | ships: path/level/modules/components | Y | Y | OwnedShipData.gd:154-198 | Low; an unresolvable path writes `""` next save |
| Fleet | active/defend indices, missions | Y | Y | FleetManager.gd:298-347 | Low |
| Captains | owned list | Y (resource paths only) | Y | FleetManager.gd:305-306, 331-334 | Low |
| Captains | **level / current_xp** | **N** | **N** | CaptainData.gd:26-27, 63-69 changes the shared .tres; only `resource_path` is saved | **HIGH** |
| Tech | unlocked techs | Y | Y | TechManager.gd:110-127 | Low |
| Factions | reputation, tribute cooldowns | Y | Y | FactionManager.gd:233-253 | Low |
| Factions | `_event_hunter_cooldown` | N | N | FactionManager.gd:30 | Low (transient) |
| Empire | notoriety, region_active, home_island_id, last_raid_check, pending_raid_report | Y | Y | EmpireManager.gd:348-372 | Low |
| Empire | heat tier | derived | – | :370-372 | none |
| Empire | `_last_gain_unix` (decay grace) | N | N | EmpireManager.gd:35, 100-101 | Low (grace resets to 0, so decay starts right after load) |
| Campaign | chapter index, completed chapters, objective progress/ids, campaign_completed | Y | Y | CampaignManager.gd:798-818 | Low |
| Campaign | chapter-Eights ledger | separate file `user://eights_ledger.json` | **N** | CampaignManager.gd:32, 825-840 | **Med**: tied to the device, not the account |
| Tutorial | active, unlocked_ui, lessons, seen, openings | Y | Y | TutorialManager.gd:175-200 | Low |
| Tutorial | completion flag | `user://tutorial_state.json` | N | TutorialManager.gd:17, 245-249 | Low (device-scoped) |
| ScheduleManager | jobs, completed_ids | Y (omitted when no jobs) | Y | ScheduleManager.gd:195-230; SaveManager.gd:322-324, 528-529 | Low |
| SeasonalEventManager | windows, objective progress | Y | Y | SeasonalEventManager.gd:402-419 | Low |
| EventManager | active_events, discovered_islands, timers | N | N | EventManager.gd:16-24 (`discovered_islands` is never read elsewhere) | none (transient/dead) |
| Maelstrom | best-run record | Y (optional section) | Y | SaveManager.gd:318-319, 522 | Low |
| Maelstrom / store | pending Eights + record | `user://maelstrom_pending.json` | N until claimed | :80, 943-952, 984-1000 | Low |
| What's New | last_seen version | Y | Y | :217, 399-400 | none |
| Settings | everything incl. ai_difficulty | `user://settings.cfg` | N (correct: device-scoped) | SettingsManager.gd:294-352 | none |
| Entitlements | owned cosmetics, ad_free | `user://account_data.json` | Y, `player_entitlements` union | EntitlementManager.gd:18, 248-300 | **Med**: file not keyed by user_id |
| Store | orders | `user://store_orders.json` | N | StoreManager.gd:29 | Low |
| Ads | consent, caps | `user://ad_permission_data.json` | N | AdManager.gd:37 | none (device-scoped is correct) |
| Analytics | consent | none (local-only telemetry, no consent state) | – | AnalyticsManager.gd:10, 14 | none |
| Auth | session | `user://auth_session.json` | – | AuthManager.gd:33, 233-239 | none |

Autoloads with no persistent progress, all fine: StoreManager (orders only), AdManager, SceneManager, InputManager, AudioManager, LiveOpsConfig, RemoteConfigManager, CrashReporter, LocalNotificationManager, MobileLayoutManager, HapticFeedbackManager.

## Progress-loss bugs, ranked

**1. CONFIRMED, critical: island ownership is never saved.** The reviewer's finding is correct.
- `capture_island()` sets `island_type = FRIENDLY` and `owner_faction` on IslandData (Island.gd:201-202).
- `save_game()` writes only `buildings` and `discovered` (SaveManager.gd:279-285). `load_game()` restores only those two (:489-493).
- Every authored island starts NEUTRAL or ENEMY. Port Royal is NEUTRAL; tests/test_cold_start.gd:30-34 checks this.
- Nothing rebuilds ownership: CampaignManager `_catch_up` does not, and `home_island_id` is restored as a string only.
- Effects after a reload: `on_economy_tick` produces nothing (Island.gd:217), so offline catch-up (SaveManager.gd:540-543) earns nothing too. `build_structure` refuses (Island.gd:310). Raid targeting and lying-low (WorldManager.gd:213) treat the empire as having no islands. The Colonize button reappears, so the player pays again.
- Repro: New Game → colonize Port Royal (gold) → build a Warehouse → dock to save → quit the app → Continue. Port Royal is NEUTRAL again, the Colonize button is back, the Warehouse is visible but produces nothing, and building is blocked.

**2. CONFIRMED, high: choosing "Keep Cloud" at launch is overwritten by the next autosave.**
- `check_cloud_save_on_launch` runs deferred from World.gd:55-56, after `load_game` has already applied the local save in memory.
- `_apply_cloud_save` writes only the file (:819-856). Its comment admits it does not apply the save to the live World.
- `_process` autosaves every 60 s (:205-212) and docking also saves (DockingSystem.gd:145). Both serialize the old in-memory local state over the file and push it to the cloud (:355-356).
- Repro: play on device A; play further on device B so the cloud is newer → open A → "Cloud Save Found" → Keep Cloud → keep sailing for 60 s or dock. The file and the cloud row now hold A's older empire, and B's progress is gone for good. Only Eights survive, through the max-merge at :851-853.

**3. CONFIRMED, high: nothing saves when you leave the World, so Pause→Settings→Back throws away progress.**
- There is no `NOTIFICATION_APPLICATION_PAUSED` or `WM_CLOSE_REQUEST` save handler anywhere. The only one is a mute handler at SettingsManager.gd:476.
- PauseMenu "Settings" and "Quit" (PauseMenu.gd:60-70) change scene without calling `save_game()`. SettingsMenu Back goes back to World.tscn, which runs `load_game()` from disk (SettingsManager.gd:165-171; World.gd:50).
- Repro: dock (this saves) → buy a building and colonize an island → within 60 s, open Pause → Settings → Back. The purchases are rolled back, and the resources spent are restored to the old amounts. On Android, swiping the app away loses the same 60-second window.

**4. CONFIRMED, high: captain XP and level reset on every restart.**
- `add_xp` changes `level`/`current_xp` on the shared CaptainData .tres (CaptainData.gd:63-69). It is called from missions (FleetManager.gd:103) and encounters (EncounterManager.gd:564-567).
- FleetManager saves only `c.resource_path` (:305-306) and reloads the authored .tres (:333-334).
- Repro: send a captain on trade missions until they level up → restart the app → the captain is back to level 1, 0 XP.
- Possible within a single session (not verified): the cached resource keeps its XP through New Game, so the leak also runs the other way.

**5. CONFIRMED, medium-high: "Keep This Device" overwrites Eights bought on another device.**
- With choice 0, :809-812 pushes the local file as-is. Unlike Keep Cloud (:830-833), there is no `max()` merge of Eights.
- Repro: buy 500 Eights on device B (synced) → open device A with an older local save → Keep This Device. The cloud `economy.eights` falls back to A's balance, so the purchased currency is lost.

**6. CONFIRMED, medium: timestamps come from the device clock, so a stale device silently overwrites newer progress.**
- `client_updated_at` comes from the device's `last_saved_unix` (:667). The launch check only prompts when cloud is newer than local (:783). The upsert has no server-side guard (supabase/schema.sql:11-31, no trigger).
- Repro: device B's clock runs 1 h behind. Play on B (synced) → open A, whose local save is newer by A's clock → no prompt → A's autosave overwrites B's progress in the cloud.

**7. CONFIRMED, medium: account-scoped data is not keyed by account.**
- `sign_out()` clears only the session (AuthManager.gd:89-100, 233-239). The local save, `account_data.json` and `eights_ledger.json` remain.
- When user B signs in on the same device, `_on_signed_in` either prompts or, if B has no cloud row, returns at :789. The next autosave then uploads A's empire and Eights into B's row.
- EntitlementManager's union push (EntitlementManager.gd:286-300) copies A's cosmetics into B's account.
- The ledger kept per device stops B from ever earning chapter Eights that A already collected on that device. It also lets New Game on a fresh device pay them out a second time.

**8. PLAUSIBLE, medium: islands switched off by content gating lose their saved buildings.**
- A disabled island calls `queue_free()` before `add_to_group("islands")` (Island.gd:38-40).
- `save_game()` rebuilds `islands` from live nodes only (:276-285), so that island's previous entry is erased on the next save.
- Repro: a beta save that has buildings on Volcano Island → update to the MVP build (`content_enabled = false`) → play and autosave → re-enable the island in a later build. Its buildings are gone.

**9. LOW: smaller losses.**
- An unresolvable ship path is saved as `""` and lost on the following save (OwnedShipData.gd:157, 165-168).
- Unresolvable captain paths are dropped silently (FleetManager.gd:333).
- `_last_gain_unix` is not saved, so heat decay starts immediately after a load.
- Keep Cloud keeps the cloud's `last_saved_unix`, which grants offline income (up to 4 h) for time already spent playing elsewhere (:532-545). This is an exploit rather than a loss.

## Fix priorities
1. Save `island_type` and `owner_faction.faction_id` in each island entry, and restore them before buildings and the offline catch-up. Add a migration that marks islands with buildings, or the `home_island_id`, as FRIENDLY.
2. After `_apply_cloud_save`, reload the World instead of writing only the file.
3. Call `save_game()` on PauseMenu quit/settings and on Android pause or close.
4. Save captain `level`/`current_xp` alongside the path, and use `duplicate()` on load.
5. Apply the Eights max-merge on Keep This Device too.
6. On sign-in, if the local save's owner differs from the new account, ask before uploading.

### Critical Files for Implementation
- D:\Pirate-game\scripts\managers\SaveManager.gd
- D:\Pirate-game\scripts\world\Island.gd
- D:\Pirate-game\scripts\managers\FleetManager.gd
- D:\Pirate-game\scripts\world\CaptainData.gd
- D:\Pirate-game\scripts\ui\PauseMenu.gd
# 2. Sync-flow edge cases
I couldn't save anything to disk because this run is read-only. The caller should write this output to a file right away so it survives a session-limit cutoff.

# Sync-flow audit (items 1-8)

## 1. Access-token expiry and refresh

**What happens now:**
- `refresh_token` is used. The access token is never refreshed ahead of time. The app waits for a 401, refreshes, then retries once (`SaveManager.gd:681-690`, `703-709`; `EntitlementManager.gd:316`, `343`). A 401 can't loop.
- **CRITICAL: a network failure deletes the session.** `AuthManager.refresh_session()` (`AuthManager.gd:135-139`) calls `_clear_session()` on any non-2xx result. That includes code 0 (DNS failure, offline, timeout), 5xx, and a paused project. `_clear_session()` deletes `auth_session.json` (`:237-239`).
- On launch, `_load_session()` calls `refresh_session()` (`:231`). So one launch while offline, or while Supabase is paused, signs the player out for good.
- A mid-session 401 followed by a failed refresh ends the same way.
- `refresh_session()` doesn't emit `signed_out`, so the Account tab keeps showing the player as signed in.
- After that, `is_signed_in()` is false and `save_game()` skips sync (`SaveManager.gd:355`). Cloud sync stops with no message until the player signs in again by hand.
- `delete_account()` (`AuthManager.gd:115-123`) has no 401 refresh-and-retry. With an expired token it just shows an error.
- `SaveManager`, `EntitlementManager` and `sign_out` can all call `refresh_session()` at the same time with the same refresh token. Supabase's refresh-token reuse window probably covers this. That's an assumption I haven't checked, so treat it as low risk.

**Can progress be lost?** Not locally. All cloud backup stops silently, so a lost device means lost progress.

**Fix:**
- Only call `_clear_session()` when the server rejects the refresh token itself: a 400 or 401 with `error` = `invalid_grant` or "refresh_token_not_found".
- On code 0 or 5xx, keep the session and return false. Add a `session_degraded` state and retry with backoff.
- Emit `signed_out` whenever `_clear_session()` runs.
- Refresh ahead of time: track `expires_at` from `_apply_session` and refresh 60 seconds before it.
- Run only one refresh at a time: store the in-flight refresh and have other callers wait on it.

## 2. A bad cloud row overwriting good local data

**What happens now:**
- `_apply_cloud_save` (`SaveManager.gd:820-822`) only checks that the value is a non-empty Dictionary. It never checks `save_schema_version`, `last_saved_unix` or that required sections exist, so a partial row like `{"economy":{}}` gets written over the local save.
- **Newer-schema row (HIGH):** the row is written to disk, then `load_game` refuses it (`:387-391`) and emits `game_loaded` with default state. The World autosave runs every 60 seconds (`:42`, `:210`) and writes that default state over the file. Two autosaves rotate the good copy out of the backup too.
  - The default state is then uploaded and replaces the newer cloud row. Example: a v1 tablet wipes progress made on a v2 phone.
  - A v1 device also uploads over a v2 row in normal play. The upsert has no version guard (`:668-678`).
- **Corrupt local save (HIGH):** if both the primary and backup files fail to load (`:379-383`), the same autosave-of-defaults spreads the empty state to the cloud.
- **Response parse failure:** an unparseable HTTP body becomes `{}` (`:741-747`). `_fetch_cloud_save` then returns `{}` (`:710-715`), so "request failed" looks exactly like "no cloud save". This feeds into item 4.
- **The conflict dialog doesn't stop autosave.** `ChoiceDialog` doesn't pause the tree (`ChoiceDialog.gd:98-100`), and `_process` keeps autosaving (`SaveManager.gd:205-212`). Within 60 seconds of "Cloud Save Found" appearing, the local save is uploaded over the cloud row the player is still deciding about. This is separate from the confirmed "Keep Cloud overwritten by autosave" bug: here the cloud copy itself is destroyed before the player answers.
- If the scene changes while the dialog is open, the dialog is freed with its parent (`:858-862`). The coroutine waits forever and the conflict is never resolved, because `_did_launch_cloud_check` stays true.

**Fix:**
- Validate before applying: schema must be `<= SAVE_SCHEMA_VERSION`, and `economy`, `islands`, `last_saved_unix` and `campaign` must exist. Run `_migrate` on older rows.
- Add a `_load_blocked` flag, set on any `load_failed` path, that turns off `save_game()` and `_sync_to_cloud`.
- Pause autosave and sync while a conflict dialog is open.
- Parent the dialog to `get_tree().root`.
- On the server, add an RLS check or trigger that rejects an upsert whose `save_schema_version` is lower than the stored one.

## 3. Retries, backoff, paused or unreachable project

**What happens now:**
- There's no retry or backoff. "Retry" just means the next autosave tries again (`SaveManager.gd:61-66`).
- `_cloud_sync_pending` is in memory only. The only places that touch it are `:66` and `:692`, so it's never shown to the player and is gone after a restart. The player is never told anything.
- The response's result field (`result[0]`, e.g. `RESULT_CANT_RESOLVE` or `RESULT_TIMEOUT`) is ignored. Everything becomes code 0.
- `HTTPRequest.timeout` is never set (Godot 4.3's default is 0, meaning no timeout), so a stuck connection waits forever.
- Uploads fire every 60 seconds without waiting for the previous one (`:356`). Requests can overlap and finish out of order. The upsert is last-write-wins (`:677`), so a slower, older payload can overwrite a newer one.
- **While the project is paused:** every launch kills the session (item 1). Local data is never lost, but every player's cloud backup stops until they sign in again by hand, even after the project is restored.

**Fix:**
- Set `http.timeout = 15`.
- Store a pending-upload flag on disk (`user://cloud_pending.json`).
- Run uploads one at a time: if one is in flight, mark the latest snapshot as dirty and upload it when the current one finishes.
- Back off 30s → 2m → 10m after failures, and retry on resume.
- Make the server ignore a write whose `client_updated_at` is older than the stored one (`... where excluded.client_updated_at >= player_saves.client_updated_at` via an RPC).
- Add a HUD or Account-tab line: "Cloud sync failing since X".

## 4. First sign-in on a fresh device (cloud save exists, no local save)

**What happens now:**
- `_on_signed_in` (`:751-756`) fetches the cloud save and writes it to the local file. Nothing loads it into the running game (`:816-818`).
- **CRITICAL path 1:** the player signs in from World during a New Game, before the first autosave. The next autosave (60 seconds or less) writes the new-game state over the cloud-derived file and uploads it, overwriting the cloud row.
- **CRITICAL path 2:** the fetch fails (paused project, offline, timeout, parse error). It returns `{}`, which is treated as "no cloud save". The player starts a new game and the first autosave replaces their real cloud save with an empty game.
- Signing in from the main menu writes the file, but the menu's Continue state is probably not refreshed. I didn't check this.
- With no local save, `check_cloud_save_on_launch` (`:777-784`) uses `local_unix` = 0 and shows a "differ" prompt for a device that has nothing on it.

**Fix:**
- Make `_fetch_cloud_save` return `{status: ok|none|error, row}`.
- Block uploads until a fetch has succeeded at least once for this user (`_cloud_baseline_known`).
- If the fetch succeeds while in World, offer "Load cloud empire now?" and call `load_game()`. With no local save, apply the cloud save without a prompt.

## 5. Sign-up waiting for email confirmation

**What happens now:**
- `sign_up` (`AuthManager.gd:69-75`) emits `sign_up_pending_confirmation`, and `SettingsMenu.gd:1040-1041` shows a toast.
- Nothing is kept: no pending email and no auto sign-in after the player confirms. They have to type their credentials again.
- Supabase returns the same session-less response when the email is already registered (anti-enumeration), so an existing user is told to "check your email" and nothing arrives.
- The confirmation link's redirect URL isn't configured for a game client in `docs/SUPABASE_SETUP.md:48-50`. I haven't checked where it goes.
- No progress is lost (the player is signed out, so the local save is untouched). Severity: LOW.

**Fix:**
- Remember the pending email and offer "I've confirmed, sign in".
- Word the toast as "If this email is new, check your inbox; otherwise sign in".
- Point the redirect to a static "confirmed, return to the game" page.

## 6. Delete account, then reuse the device

**HIGH:** `player_entitlements.user_id` references `auth.users(id)` with no `ON DELETE CASCADE` (`schema.sql`). The Edge Function deletes only `player_saves` (`delete-account/index.ts:57-60`) before calling `auth.admin.deleteUser` (`:68`).
- For any user who has an entitlements row, `deleteUser` should fail on the foreign key. This is inferred and not yet confirmed against the live database.
- The player gets "Failed to delete account". Their cloud save is already gone, the account still exists, and the client stays signed in.
- The next autosave re-uploads the local save, so the deletion is silently undone. That's a GDPR/store-policy failure.

**Afterwards:** the local save is kept by design (`AuthManager.gd:119`). If the player signs up again, the fetch returns `{}` and the old local save uploads to the new account. That's intended. Account-scoped cosmetics carrying over is the already-confirmed "not keyed by user" issue.

**Fix:**
- Delete `player_entitlements` in the function, or add `on delete cascade` to both foreign keys.
- Do the deletes in one transaction or RPC.
- Refresh and retry on 401.

## 7. Upload payload size

**What happens now:**
- Each upload is the full snapshot (`:666-678`), compact JSON, sent every 60 seconds whether or not anything changed. That's about 60 uploads per hour per player, adding up against free-tier egress and database writes. Nothing is lost.
- The snapshot is bounded by content, so it's probably small (a few KB). I didn't measure it; no save file exists right now.
- There's no size check and no `body_size_limit`. Any manager whose save data grows without limit (logs, history) would grow the payload. A per-manager growth check is still needed.

**Fix:**
- Skip the upload when a hash of the snapshot matches the last uploaded one.
- Upload at most every 5 minutes, plus on dock or pause.
- Log an error when the payload exceeds 256 KB.

## 8. HTTPRequest node lifecycle

**What happens now:**
- Every request node is a child of an autoload: `AuthManager.gd:182-190`, `SaveManager.gd:729-737`, `EntitlementManager.gd:363`, `RemoteConfigManager.gd:52`. Scene changes don't free them, and `queue_free` runs after each one completes. Safe.
- Because there's no timeout, a stuck connection leaves the node and the waiting coroutine around forever, one per autosave. That's a slow leak.
- The real lifecycle bug is the conflict dialog, which is parented to the current scene (item 2). Severity: MEDIUM.

**Fix:** set a timeout, and parent the dialog to `get_tree().root`.

## Priority order

1. Stop network failures deleting the session (item 1).
2. Make fetch report errors separately from "no row", and block uploads until a fetch has succeeded (items 2, 4).
3. Block autosave and sync after a failed load or during a pending conflict (item 2).
4. Fix the delete-account foreign keys (item 6).
5. Add a server-side version/time guard on the upsert and run uploads one at a time (items 2, 3).
6. Persist the pending flag, add a timeout and backoff, and show sync status to the player (item 3).
7. Skip unchanged uploads (item 7).

### Critical Files for Implementation
- d:\Pirate-game\scripts\managers\AuthManager.gd
- d:\Pirate-game\scripts\managers\SaveManager.gd
- d:\Pirate-game\supabase\functions\delete-account\index.ts
- d:\Pirate-game\supabase\schema.sql
- d:\Pirate-game\scripts\ui\ChoiceDialog.gd
# 3. Schema / RLS / security
# Supabase schema, RLS and security audit: Pirate-game (Godot 4.3)

The most serious problem: the cloud tables let a signed-in player write their own entitlements, ad_free and Eights with no server check, and since M17 account deletion most likely fails partway for every account. One limit on that second point: I read the code and did not run it, and no network calls were made, so live behaviour is inferred.

## 1. Every network call

| # | Caller (file:line) | Method and endpoint | Headers | Body |
|---|---|---|---|---|
| 1 | AuthManager.gd:66 | POST `/auth/v1/signup` | apikey, Content-Type | `{email,password}` |
| 2 | AuthManager.gd:80 | POST `/auth/v1/token?grant_type=password` | same | `{email,password}` |
| 3 | AuthManager.gd:98 | POST `/auth/v1/logout` (fire-and-forget) | apikey, Bearer | empty |
| 4 | AuthManager.gd:103 | POST `/auth/v1/recover` | apikey, Content-Type | `{email}` |
| 5 | AuthManager.gd:116 | POST `/functions/v1/delete-account` | apikey, Bearer | empty |
| 6 | AuthManager.gd:132 | POST `/auth/v1/token?grant_type=refresh_token` | apikey, Content-Type | `{refresh_token}` |
| 7 | SaveManager.gd:674-689 | POST `/rest/v1/player_saves?on_conflict=user_id` (retried once on 401) | apikey, Bearer, `Prefer: resolution=merge-duplicates,return=minimal` | `{user_id, save_data, save_schema_version, client_updated_at}` |
| 8 | SaveManager.gd:698-708 | GET `/rest/v1/player_saves?select=save_data,save_schema_version,client_updated_at` | apikey, Bearer | none |
| 9 | EntitlementManager.gd:313-318 | GET `/rest/v1/player_entitlements?select=entitlements` | apikey, Bearer | none |
| 10 | EntitlementManager.gd:338-348 | POST `/rest/v1/player_entitlements?on_conflict=user_id` | apikey, Bearer, same Prefer header | `{user_id, entitlements:{id:{source,granted_at,order_id}}}` |
| 11 | RemoteConfigManager.gd:54 | GET `/rest/v1/remote_config?select=key,value` | apikey only | none |

`_put_auth` (AuthManager.gd:167) is defined but never called. `AuthManager.gd:31-32` holds `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The key is the `sb_publishable_` kind, which is meant to ship in clients, so that is fine. No RPCs are called and no other edge functions exist.

## 2. Mismatches between code, schema and docs

| Item | Code expects | schema.sql / docs | Status |
|---|---|---|---|
| `player_saves` columns and the unique `user_id` for on_conflict | #7 and #8 | schema.sql:11-18, unique at :13 | Match |
| Upsert needs both an INSERT and an UPDATE policy | #7, #10 | :26-32, :59-65 | Present. The UPDATE policies have no `WITH CHECK`, so Postgres reuses `USING`. Safe, but should be explicit. |
| `player_entitlements(entitlements jsonb)` | #9, #10 | schema.sql:46-65 | Matches schema.sql. **Missing from docs/SUPABASE_SETUP.md:26**, which says "Two tables". |
| Foreign key behaviour when a user is deleted | delete-account deletes the user | schema.sql:13 and :48: `references auth.users(id)` with **no `on delete cascade`** | **Broken** (finding S1) |
| delete-account cleanup | should remove every user table | index.ts:57-60 deletes only `player_saves` | **Missing `player_entitlements`** |
| Doc's claim that deletion was "verified for real" | — | SUPABASE_SETUP.md:68-77 | Out of date: tested at M15, before `player_entitlements` existed |
| `remote_config` | read only | :73-85, select policy only | Match |
| Eights balance | `save_data.economy.eights` (SaveManager.gd:832, :890-924) | no server column, ledger or constraint | Client-authoritative |
| Purchase or order records | `user://store_orders.json`, local only (StoreManager.gd:29, :226-233) | no table | No server ledger |
| `updated_at` | meant to be set by the server | :17 and :50 are only `default now()` | The client can overwrite it in the upsert body |
| Migrations | — | one hand-applied, non-idempotent `schema.sql` | No `supabase/migrations/` folder |

## 3. Security findings, most severe first

**S1 (Critical): account deletion most likely fails for any account with an entitlements row, and leaves it half-deleted.** Every signed-in player gets a row in `player_entitlements`: `_pull_and_push_union` (EntitlementManager.gd:287-300) always pushes the seeded default cosmetics.
- The foreign key at schema.sql:48 does not cascade, so `auth.admin.deleteUser` (index.ts:68) should fail with a foreign-key violation and return a 500.
- By then index.ts:57-60 has already deleted the save row.
- Result: the save is gone, the account and entitlements remain, and the player sees an error. This also undermines Play Store and GDPR deletion compliance.

**S2 (Critical): entitlements, including ad_free, are fully client-writable and spread to other devices.**
- INSERT and UPDATE are open to the row's owner (schema.sql:59-65).
- A player can POST any catalogue id, or `ad_free`, using their own token.
- Every device then grants it locally: the union pull checks only `_is_grantable_id` (EntitlementManager.gd:150-151, :292-295).
- `source` and `order_id` are whatever the client sends.
- No server ever verifies a purchase.

**S3 (Critical): desktop and web builds give away every product, and those grants sync to Android.**
- `_create_backend` (StoreManager.gd:114-117) uses `StoreBackendStub` on any platform that isn't Android.
- The stub reports a price of `"$0.00 (stub)"` (StoreBackendStub.gd:42), so StoreScreen.gd:166-168 enables the Buy button.
- `begin_purchase` succeeds by default (StoreBackendStub.gd:57-61).
- So a release PC or web build grants paid bundles, ad_free and Eights packs for free. These reach a phone through S2's union sync and the player_saves Eights.

**S4 (High): the Eights balance is whatever the client says.**
- `economy.eights` lives inside `save_data` jsonb, and the owner can write it at will (SaveManager.gd:666-678).
- There is no server balance, no append-only ledger and no spend RPC.
- The duplicate-grant guard is a local file (`store_orders.json`), which a reinstall or file edit resets.

**S5 (High): refunds don't stick.** `revoke()` (EntitlementManager.gd:104-114) uploads the smaller set. But any other device still holding the item re-uploads the union the next time it launches or signs in (:287-300), so a refunded item comes back. Only a server ledger with `revoked_at` can fix this.

**S6 (Medium): there is no server-side purchase verification path.**
- `RAZORPAY_KEY_SECRET` and `GOOGLE_CLIENT_SECRET` exist in the local `.env`.
- Nothing server-side uses them: no `verify-purchase` function and no Play refund-notification webhook.
- They must only ever be set as edge-function secrets, never in client code.

**S7 (Low): hygiene gaps.**
- The client can set `updated_at` (:17, :50).
- `save_data` has no size limit, so storage can be abused.
- The UPDATE policies don't have explicit `WITH CHECK`.
- The default table grants to `anon`/`authenticated` were never narrowed (TRUNCATE, DELETE, REFERENCES). RLS covers DELETE, and TRUNCATE isn't reachable through REST, but the grants should be revoked for defence in depth.

**Secrets check: nothing leaked.**
- `git ls-files` plus a grep for `service_role|sk_live|sk_test|rzp_live|rzp_test|eyJhbGci|sb_secret` found no secret values in tracked files.
- The only `service_role` matches are comments and `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")` (index.ts:3-4, :35, :53; schema.sql:35).
- "secret" hits in `.kiro/`, `docs/` and `claude design outputs/...html` are prose, and SettingsMenu.gd:934 is a password field's `.secret` property.
- `.env` is ignored (`.gitignore:17`), and `git log --all -- .env` shows it was never committed.
- `.env` variable names only: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`, `ANDROID_PACKAGE_ID`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`.

## 4. SQL migrations needed (proposed `supabase/migrations/`)

1. **`0001_fk_on_delete_cascade.sql`** (fixes S1)
   - On `player_saves` and `player_entitlements`: `drop constraint ..._user_id_fkey`, then re-add `foreign key (user_id) references auth.users(id) on delete cascade`.
   - Every new user table below also gets `on delete cascade`.
   - Also update `delete-account` to explicitly delete `player_entitlements`, `entitlement_grants`, `player_wallet`, `eights_ledger` and `purchases` before calling `deleteUser`, or rely on the cascade and drop the separate save delete so the operation is atomic.

2. **`0002_entitlement_ledger.sql`** (fixes S2, S5)
   - `create table entitlement_grants(id uuid pk, user_id uuid fk cascade, entitlement_id text not null, source text check (source in ('default','play','purchase','admin')), order_id text, platform text, granted_at timestamptz default now(), revoked_at timestamptz, unique(user_id, entitlement_id, order_id))`.
   - Enable RLS with a select-own policy only.
   - Make `player_entitlements` read-only for clients: `drop policy` for insert and update, and `revoke insert, update, delete on player_entitlements from anon, authenticated`.
   - Rebuild its `entitlements` from the ledger with a trigger that excludes rows with `revoked_at`.
   - Add RPC `claim_play_entitlement(p_id text)`: `security definer`, `set search_path=''`, a fixed allow-list (`sail_storm_torn`, `flag_golden_standard`, `figurehead_golden_eagle`, plus defaults), never `ad_free`. Run `grant execute ... to authenticated`.

3. **`0003_purchases.sql`** (fixes S3, S6)
   - `create table purchases(order_id text pk, user_id uuid fk cascade, platform text, sku text, token_hash text, state text, verified_at timestamptz, refunded_at timestamptz)`.
   - Enable RLS with no client policies, so only the service role can write.
   - Writes come only from new edge functions: `verify-purchase` (Play Developer API, or a Razorpay HMAC check using `RAZORPAY_KEY_SECRET` from function secrets) and `play-rtdn` (refunds, which set `revoked_at`).

4. **`0004_wallet.sql`** (fixes S4)
   - `player_wallet(user_id pk fk cascade, eights bigint not null default 0 check (eights >= 0))`.
   - `eights_ledger(id bigserial, user_id, delta int, reason text, idempotency_key text unique, created_at)`, append-only: `revoke update, delete` and add a trigger that blocks them.
   - RLS select-own on both tables.
   - RPCs `spend_eights(amount, reason, key)` and `credit_earned_eights(amount, reason, key)`, both `security definer`, with per-day caps on earned credits. Purchase credits come only from `verify-purchase`.
   - The client must treat `save_data.economy.eights` as a display cache only.

5. **`0005_player_saves_hardening.sql`** (fixes S7)
   - Recreate the UPDATE policies on `player_saves` and `player_entitlements` with explicit `with check (auth.uid() = user_id)`.
   - Add a `before insert or update` trigger that sets `updated_at := now()`.
   - Add `check (pg_column_size(save_data) < 1048576)`.

6. **`0006_grant_hygiene.sql`**
   - `revoke truncate, references, trigger on all tables in schema public from anon, authenticated`.
   - `revoke insert, update, delete on remote_config from anon, authenticated`.

These are client-side fixes, not SQL, and are needed alongside the migrations:
- Restrict `StoreBackendStub` to `OS.is_debug_build()`, and show "Unavailable" in release builds that aren't on Android.
- Make `EntitlementManager` pull-only.
- Route `StoreManager` grants through `verify-purchase`.
- Update `docs/SUPABASE_SETUP.md:26` and `:68-77`.

### Critical Files for Implementation
- d:\Pirate-game\supabase\schema.sql
- d:\Pirate-game\supabase\functions\delete-account\index.ts
- d:\Pirate-game\scripts\managers\EntitlementManager.gd
- d:\Pirate-game\scripts\managers\StoreManager.gd
- d:\Pirate-game\scripts\managers\SaveManager.gd