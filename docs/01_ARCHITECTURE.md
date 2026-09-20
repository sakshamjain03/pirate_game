# System Architecture & Tech Stack

Version: 1.1 — merged with the former `docs/02_TECH_STACK.md` during the 2026-09-20 docs
consolidation pass (they were two thin, overlapping "how is this built" docs).

---

# Purpose

High-level architecture and technology choices for Pirate Empire. This document intentionally
avoids implementation detail and does not restate the non-negotiable rules already stated in
`AGENTS.md` (the constitution) and `CLAUDE.md` (data-driven balance, composition over inheritance,
signals over direct references, naming conventions) — those own the rules; this doc only covers
what they don't: the actual system shape and the concrete tools/services in use.

---

# High-level system flow

```
Player → Empire → Fleet → Exploration → Combat → Rewards → Progression → Save
```

Every gameplay system (Combat, Buildings, Economy, Exploration, Fleets, Save) is meant to be
independently replaceable; a real, current component breakdown (e.g. Ship → `ShipController` /
`ShipMovement` / `ShipVisuals` / `ShipCombat` / `ShipDamage` / `BuoyancySimulator` /
`DockingSystem` / `CameraRig`) lives in `CLAUDE.md`'s Architecture section — that list changes
every few milestones, so `CLAUDE.md` is the place to check, not this doc.

---

# Engine & language

**Godot 4.3** (GDScript). Chosen for open-source licensing, mature 3D since 4.x, GDScript
productivity for a small/solo team, and a scene architecture that maps well onto composition over
inheritance. C# is a future option only if profiling shows a genuine performance need — not a
default, and not premature optimization.

# Version control

Git + GitHub. Git LFS for large binary assets.

# Backend

**Supabase** — integrated M15 (`.kiro/specs/milestone-m15-backend-cloud-services/`), the project's
first outbound network dependency. Direct REST calls via Godot's `HTTPRequest` (no third-party
SDK), against a real, deployed project (`docs/SUPABASE_SETUP.md` documents the actual
configuration).

- **Authentication** — email/password shipped (`AuthManager` autoload). Google Sign-In deferred:
  Godot 4.3 has no native Android deep-link API, and the Android export pipeline itself wasn't
  working until M13's resolution — both optional/opt-in, never required to play.
- **Cloud save** — mirrors the local save format exactly; Row Level Security scoped per-user
  (`player_saves` table, verified with two real signed-in test accounts that neither could read
  nor overwrite the other's row).
- **Remote config** — a flat public key/value table (`remote_config`), fetched once per session
  with a safe local default on any failure; consumed by seasonal-event scheduling and a content
  kill-switch (M14+).
- **Account deletion** — a Supabase Edge Function (`delete-account`) holds the only `service_role`
  key usage in this project, entirely server-side.
- **Analytics** — Firebase Analytics + Crashlytics, gated to after Alpha (not yet live as of this
  writing — see `docs/05_CURRENT_SYSTEMS.md` for current status).
- **Leaderboards** — out of scope; would require amending `AGENTS.md`'s no-social-features rule,
  not just adding a backend.

# Platforms

Primary: Android. Secondary: Windows desktop (actively maintained, not just the dev environment —
see `docs/20_PLATFORM_MATRIX.md`). Future: iOS (M20).

# CI/CD

GitHub Actions is the intended home for automated builds/linting/export verification, not yet set
up as of this writing.

# Tooling

VS Code (Godot Tools extension) + Claude Code. Blender/Aseprite/Figma for art; Audacity/Bfxr for
audio, with FMOD as an optional future upgrade if adaptive audio is ever needed.

# Third-party dependencies

Keep minimal. Avoid plugins unless necessary — every dependency is a maintenance cost, and this
project already had to remove one broken one (the gdscript LSP plugin, non-functional on Windows).
