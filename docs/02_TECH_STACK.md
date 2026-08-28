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

Supabase — planned, M15 (`.kiro/specs/milestone-m15-backend-cloud-services/`)

Authentication (email/password + Google Sign-In, optional/opt-in — never required to play)

Cloud Save (mirrors the local save format; Row Level Security scoped per-user)

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
