````md
# Technology Stack

Version: 1.0

---

# Engine

Godot 4.x

Reason

Open Source

Excellent 2D support

Growing 3D ecosystem

GDScript productivity

Strong scene architecture

---

# Programming Language

Primary

GDScript

Future

C#

Only if performance requires it.

Avoid premature optimization.

---

# Version Control

Git

GitHub

Git LFS for large assets.

---

# IDE

Primary

VS Code

Extensions

Godot Tools

GitHub Copilot

Codex

Claude

---

# Art

Blender

Aseprite

Figma

---

# Audio

Audacity

Bfxr

Future

FMOD (optional)

---

# Backend

Supabase — integrated M15 (`.kiro/specs/milestone-m15-backend-cloud-services/`), the project's
first outbound network dependency. Direct REST calls via Godot's `HTTPRequest` (no third-party
SDK), against a real project (`docs/SUPABASE_SETUP.md` documents the actual configuration).

Authentication — email/password shipped (`AuthManager` autoload). Google Sign-In deferred: Godot
4.3 has no native Android deep-link API, and M13 hasn't produced a working Android export yet
either; both optional/opt-in, never required to play.

Cloud Save — mirrors the local save format exactly; Row Level Security scoped per-user
(`player_saves` table, verified with two real signed-in test accounts that neither could read nor
overwrite the other's row).

Remote config — a flat public key/value table (`remote_config`), fetched once per session with a
safe local default on any failure; consumed by M14's seasonal-event scheduling and content
kill-switch once that milestone defines real keys.

Account deletion — a Supabase Edge Function (`delete-account`) holds the only `service_role` key
usage in this project, entirely server-side.

Leaderboards — still future, out of scope; would require amending `AGENTS.md`'s no-social-features
rule, not just adding a backend

Analytics — still M12 (`docs/15_MASTER_PLAN.md`)

---

# Analytics

Firebase Analytics

Crashlytics

Only after Alpha.

---

# CI/CD

GitHub Actions

Future

Automated Builds

Linting

Export Verification

---

# Platforms

Primary

Android

Secondary

Steam

Future

iOS

---

# Coding Standards

Style Guide

snake_case

Meaningful names

Signals over polling

Composition

Small scripts

Documentation required

---

# Third-Party Libraries

Keep dependencies minimal.

Avoid plugins unless necessary.

Every dependency increases maintenance cost.
