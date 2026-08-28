# 20_PLATFORM_MATRIX.md

> Version: 1.0
> Status: Living Document — target platforms, engine decision, and per-store obligations
> Owner: Project Lead
> Created: 2026-08-27
>
> **Why this document exists.** A gap audit on 2026-08-27 found that platform targeting lived
> only inside the M13 spec, which is Android-only, and that the engine-version question
> (4.3 versus a newer 4.x) was raised as an M13 task but had no home to be *decided* in. iOS —
> roughly half the addressable revenue for a paid-cosmetics model in most markets — appeared
> nowhere in the roadmap at all. This document is the single place platform decisions are
> recorded.

---

# 1. The matrix

| Platform | Status | Milestone | Notes |
|---|---|---|---|
| **Android (phone)** | 🎯 Primary launch target | M13 | The design target. Mobile-first means this. |
| **Android (tablet)** | 🎯 Supported at launch | M13 | Same build; needs the M19 responsive/text-scale work to look right. |
| **Windows (desktop)** | 🛠 Development only | — | How the project is built and tested. Not a shipping target, not store-listed. |
| **iOS (iPhone)** | 📋 Planned | M20 | Second platform. Roughly doubles addressable revenue. |
| **iPadOS** | 📋 Planned | M20 | Same build as iPhone. |
| **Steam / desktop store** | 🚫 Out of scope | — | Different genre expectations, different control scheme, different monetization. Not a v1 or v2 target. |
| **Web / HTML5** | 🚫 Out of scope | — | The ocean shader and buoyancy simulation are not viable targets for web export. |
| **Console** | 🚫 Out of scope | — | — |

---

# 2. The engine version decision

**Current state:** `project.godot` declares `config/features=PackedStringArray("4.3", "Forward Plus")`.
The M13 spec raises "resolve engine version (4.3 vs 4.7)" as an open task.

**Decision: stay on 4.3 through the M13 launch.**

Rationale:

- The project is 326 tests green on 4.3 (M10 baseline). An engine upgrade invalidates that
  baseline at exactly the moment it is most valuable.
- The renderer is **Forward+**, and the ocean is a GPU-wave shader with CPU buoyancy sampling
  that must stay in sync (defect D11 was precisely a wave-sync bug). Renderer and shader-compiler
  changes across a minor version are the highest-risk possible change to this specific codebase.
- Nothing currently on the roadmap through M13 requires a newer engine feature.

**Revisit point:** after M13 has shipped and is stable, and before M20 (iOS). The iOS export
pipeline is the strongest argument for a newer 4.x, and doing the upgrade *between* stores rather
than before the first one is the lower-risk ordering.

**When the upgrade happens, it is its own task with its own checkpoint** — never bundled into a
feature milestone. Required exit criteria: full GUT suite at or above the then-current baseline,
plus a headful visual pass on the ocean, ship damage visuals, and toon shading (which cannot be
verified headlessly, per `CLAUDE.md`).

---

# 3. Minimum device targets

| | Android | iOS |
|---|---|---|
| Minimum OS | Android 8.0 (API 26) | iOS 15 |
| Target API | Whatever Play currently mandates at submission | Current |
| Minimum RAM | 3 GB | — (device floor covers it) |
| Reference low-end device | A ~2020 midrange phone | iPhone SE (2nd gen) |
| Frame target | 30 fps sustained on the reference device, 60 where headroom exists | Same |
| Architectures | arm64-v8a (arm7 only if Play still requires it) | arm64 |

The reference low-end device is the one that matters. Performance profiling in M13 and the
spatial partitioning / culling work in M21 are both judged against it, not against a
development desktop.

---

# 4. Per-store obligations

## 4.1 Google Play (M13 launch, M17 monetization)

**At M13 (free, no monetization):**
- Signed release build, Play App Signing, AAB format.
- Store listing: title, short and full description, feature graphic, screenshots, category.
- Privacy policy URL (required even with no data collection).
- Data Safety form — accurate for a build with no ads and no purchases.
- Content rating questionnaire (IARC).
- Target API level compliance.

**Added at M17 (monetization):**
- Google Play Billing Library integration, and the products configured in Play Console.
- **Data Safety form re-submitted** to declare purchase history and advertising identifiers.
- Families policy compliance and an age gate, because the game will serve advertisements.
- UMP consent flow for personalized advertising in GDPR/DMA territories.
- Price tiers set per market.
- Refund handling that revokes the entitlement without corrupting the save.

## 4.2 Apple App Store (M20)

- Apple Developer Program membership, provisioning, and signing.
- StoreKit 2 for in-app purchase — behind the **same platform-abstracted billing interface**
  designed in M17, so M20 is an implementation of an existing seam rather than a second
  monetization system. This is the single most important architectural instruction in this
  document: `AGENTS.md` forbids duplicating systems, and a second parallel billing path is
  exactly that.
- App Tracking Transparency prompt before any personalized advertising.
- App Privacy nutrition labels.
- App Review guidelines — note that Apple reviews screenshots and metadata as well as the build.
- Export compliance declaration (encryption question).

## 4.3 Both stores, once monetized

- Purchase-support contact route (see `docs/17_MONETIZATION.md` §4.3, layer 3).
- Account deletion path — already scoped in M15 for the Supabase account, and required by both
  stores where an account exists.
- Terms and Privacy revised for advertising and purchase data.

---

# 5. Store presence assets (ASO)

The M13 spec covers listing *text*. It does not cover the assets that actually drive install
conversion. These land in **M20** alongside the iOS listing, so both stores are served by one
pass:

- A 30-second trailer showing the empire-building fantasy, not just ship combat.
- A repeatable screenshot pipeline — the project already has a `ScreenshotHarness`, which should
  be the source rather than hand-captured frames, so screenshots can be regenerated per release
  and per locale.
- Feature graphic and icon variants per store.
- A press kit: description, key art, logo, fact sheet, contact.
- Localized listing copy for the top markets, distinct from the M12 in-game string localization.

---

# 6. What is verifiable where

Per `CLAUDE.md`, the honest statement of what this environment can and cannot check:

| Verifiable headlessly in this repo | Requires a real device or store account |
|---|---|
| GUT test suite (`-gdir=res://tests -gexit`) | Billing purchase and restore flows |
| Script parsing and resource schema | Advertisement SDK behaviour and fill |
| Save round-trip and migration logic | Consent, ATT and age-gate dialogs |
| Entitlement state machine logic | iOS export and App Review |
| Notification scheduling rules | Actual notification delivery and quiet hours |
| — | Frame rate on the reference low-end device |
| — | Touch controls, camera feel, shader appearance |

Anything in the right-hand column is reported as **unverified** until someone runs it on
hardware. It is never claimed as passing on the strength of a headless run.
