# 17_MONETIZATION.md

> Version: 1.0
> Status: Living Document — the monetization design of record
> Owner: Project Lead
> Created: 2026-08-27
>
> Reads on top of: `AGENTS.md` (the engineering constraints) → `docs/00_VISION.md` §19/§19.1
> (the philosophy and the committed model) → this document (the concrete SKUs, the entitlement
> model, and the rules a reviewer can actually test a pull request against).
>
> **Why this document exists.** Until 2026-08-27 the project had a monetization *philosophy*
> (`00_VISION.md` §19) and a blanket engineering *ban* (`AGENTS.md`: "Never introduce paid
> features"), and nothing in between. The two contradicted each other, and every milestone spec
> M9–M15 inherited the ban into its Non-Goals. This document is the missing middle: it names
> exactly what is sold, for how much, what it may never touch, and how an entitlement is stored
> and restored.

---

# 1. The one-sentence model

**Pirate Empire is free to play in full, and earns money from cosmetics, a single one-time
Supporter Pack, and advertisements the player chooses to watch.**

Nothing that affects gameplay is ever sold. There is no premium currency. There is no energy
meter. There is no timer whose removal is for sale.

---

# 2. What is sold

## 2.1 Cosmetics — recurring, low-value, high-volume

Purely visual items with no stat effect whatsoever. A cosmetic changes what a thing *looks
like* and nothing else.

| Category | Examples | Indicative price |
|---|---|---|
| Ship hull skins | Blackened Oak, Bone Hull, Royal Lacquer | ₹99 / $1.49 |
| Sail patterns | Crimson Cross, Storm-Torn, Gold Leaf | ₹79 / $0.99 |
| Flags and jolly rogers | 12+ authored designs | ₹79 / $0.99 |
| Figureheads | Kraken, Siren, Skull-and-Lantern | ₹99 / $1.49 |
| Island decorations | Braziers, banners, statues in existing decoration slots | ₹79 / $0.99 |
| Themed bundles | 4–6 matched items at a discount | ₹299 / $3.99 |

**Hard rules for every cosmetic:**

- It may not change a `ShipStats` value, a hitbox, a collision shape, a camera distance, or a
  damage-state readability cue.
- It may not make a ship harder for the player *or* an enemy to read at combat distance.
- A cosmetic sold for money may never replace a cosmetic that was previously earnable. If an
  earnable path existed, it stays.
- Every cosmetic is defined as a `CosmeticData` `.tres` resource. No cosmetic is ever hardcoded
  in a script (`AGENTS.md`: no hardcoded gameplay values, data-driven balance).

## 2.2 The Pirate King Supporter Pack — one-time, the anchor purchase

A **single, non-consumable, one-time** purchase. Indicative price **₹499 / $5.99**.

Contents:

1. **Permanently ad-free.** All rewarded-ad surfaces are replaced with the reward granted
   directly, at the same value, with no advertisement. This is the primary reason to buy it.
2. **A cosmetic bundle** — a distinctive hull skin, sail, flag and figurehead set not sold
   separately, plus any future supporter cosmetic drops.
3. **A supporter mark** in the credits screen and on the title screen.
4. **Early access to new cosmetic drops** — supporters see each new cosmetic one release before
   it enters the general catalogue. Still cosmetic-only, still never a stat.

> **Audit note (2026-08-27).** An earlier draft of this pack listed "extra save slots (3 to 6)".
> That benefit was removed because it does not exist and nothing plans it: `SaveManager` writes a
> single hardcoded `user://save_data.json` (`scripts/managers/SaveManager.gd:25`) with no slot
> concept anywhere in the codebase. Multi-slot saves would be a real feature in their own right,
> owned by no milestone. It is logged as gap #19 in `docs/15_MASTER_PLAN.md`. If multi-slot saves
> are ever built, extra slots may be reconsidered as a supporter benefit — until then the pack
> does not promise them.

It does **not** contain: resources, gold, experience, faster building, stronger ships, extra
captains, unlocked regions, or any gameplay advantage of any kind.

## 2.3 Rewarded advertisements — opt-in only

The player is *offered* an advertisement, always as a clearly-labelled optional choice, and
always in exchange for a bonus on something they have already earned.

**Permitted surfaces (the complete list — adding to it requires updating this document):**

| Surface | Reward | Cap |
|---|---|---|
| Offline-return panel | Double the offline income *already accrued* | 1 per return, 3 per day |
| World event resolution | Reroll the event once | 2 per day |
| Post-battle summary | Double the salvage *already earned* | 3 per day |

**Hard rules for advertisements:**

- **Never interstitial.** No advertisement ever appears without the player pressing a button
  whose label says it will play one.
- **Never nagged.** If the player declines, the offer is not re-presented for that surface until
  the next natural occurrence. No "are you sure" dialog.
- **Never a gate.** Declining costs the player nothing they had. The reward is always a *bonus
  on top of* an amount already granted, never the difference between a reduced and a full amount.
  Anything framed as "watch this or lose X" is a forced advertisement wearing a costume, and is
  banned.
- **Never on the critical path.** No advertisement in the tutorial, in the first session, or
  between a battle and its result.
- Hard daily caps as tabled above, so the game cannot degrade into an advertisement delivery
  mechanism for a heavy player.

---

# 3. What is never sold

Restating the `00_VISION.md` §19 never-list as rules a reviewer can check:

| Banned | Because |
|---|---|
| Hard / premium currency ("Doubloons") | Obscures real price, invites pay-to-win drift, and is banned outright in `AGENTS.md` |
| Any stat, ship, captain, island, tech, region or chapter | Pay-to-win |
| Speed-ups on building, research, or repair | Artificial waiting, monetized |
| Energy / stamina / fuel that gates play | Explicit §19 never |
| Loot boxes, gacha, randomized paid rewards | Gambling mechanics, and a regulatory problem in several markets |
| Forced, interstitial, or unskippable advertisements | Explicit §19 never |
| Timers introduced in order to sell their removal | Explicit §19 never |
| Selling player data, or sharing advertising IDs beyond what the ad SDK requires with consent | Privacy |

---

# 4. The entitlement model

## 4.1 What an entitlement is

An **entitlement** is a durable record that the player owns something. It is not a currency and
it is not a consumable. Entitlements are:

- **one-time** — bought once, owned forever;
- **non-consumable** — never spent, never decremented;
- **non-tradeable** — no gifting, no transfer, no marketplace;
- **account-scoped, not save-scoped** — starting a new save does not take away a cosmetic.

That last point matters architecturally: entitlements must **not** live inside a save slot's
data. They persist alongside it.

## 4.2 Where it lives

A new `EntitlementManager` autoload owns this domain, following the existing convention that
every manager exposes `get_save_data()` / `load_save_data()` for `SaveManager` to round-trip
(see `CLAUDE.md` and `docs/01_ARCHITECTURE.md`) — but writing to an account-level store rather
than the per-slot save, and emitting signals (`entitlement_granted`, `cosmetic_equipped`,
`ads_removed_changed`) rather than being polled.

## 4.3 Restoration — the obligation

If a player pays and then reinstalls, loses their phone, or switches device, they must get their
purchases back. Three layers, in order:

1. **Store restore.** Google Play Billing (and later StoreKit) is queried on launch for owned
   non-consumables. This is the authoritative source and works offline after first sync.
2. **Cloud entitlement sync** via the M15 Supabase backend, so entitlements follow the account
   across stores and platforms.
3. **Manual support path** — a purchase-support screen that surfaces the order ID and a contact
   route, for the cases the first two miss.

**Dependency note:** layer 2 depends on M15 shipping. If M15 slips past M17, M17 must ship with
layers 1 and 3 only, and that must be an explicit design decision in the M17 spec — not a silent
omission.

## 4.4 Verification posture

The game is single-player and offline-first. Entitlements are therefore verified **client-side,
against the store's own receipt**, not against an authoritative server. This is deliberate:

- A server-authoritative wallet would break the "playable offline forever" promise.
- The blast radius of a tampered entitlement is one player seeing a cosmetic they did not buy.
  There is no competitive integrity to protect, no economy to inflate, and no other player to
  harm — because nothing gameplay-affecting is ever sold.

Light integrity work (save tamper-resistance) is scheduled in M21 to keep casual tampering from
being trivial, but the project explicitly does **not** invest in anti-cheat. That is the correct
trade for a fair, single-player, cosmetics-only model.

---

# 5. Compliance obligations this creates

Shipping any of the above triggers obligations that did not previously exist. These are tracked
as M17 requirements:

- **Age gate**, before any advertisement is ever requested. Play Families / COPPA policy applies
  to a game with this art direction and audience.
- **Consent (UMP / GDPR / DMA)** for personalized advertising, with a genuine decline path that
  falls back to non-personalized ads.
- **Apple ATT** prompt on iOS (M20).
- **Privacy policy and Terms revision.** The M15 versions predate both advertising and purchase
  data, and will be inaccurate the moment M17 ships.
- **Play Console Data Safety form** must be updated to declare purchase history and advertising
  identifiers.
- **Refund handling** — Play and Apple both process refunds themselves; the game must revoke the
  entitlement when the store reports the refund, and must do so without corrupting the save.
- **Price localization** — store price tiers per market, distinct from the M12 string
  localization work.

---

# 6. Targets, and how success is judged

These exist so the model can be evaluated honestly rather than tuned by instinct. They are
measured with the M12 analytics pipeline.

| Metric | Target | Read as |
|---|---|---|
| Supporter Pack conversion | 2–4% of D7-retained players | The anchor purchase working |
| Cosmetic attach rate | 5–8% of players buy at least one | The catalogue being desirable |
| Rewarded-ad opt-in rate | 25–40% of offers accepted | Offers being genuinely worth it |
| Ads per daily player | 2 or fewer on average | Caps working; not an ad-delivery app |
| D1 / D7 retention | Unchanged after M17 versus before | **The one that matters most** |

**The retention guardrail is a kill switch, not a metric.** If D1 or D7 retention drops
measurably after monetization ships, the monetization is wrong and gets rolled back — revenue
does not get to win that argument. That is what "players should pay because they enjoy the game"
means in practice.

---

# 7. The reviewer's checklist

Any pull request touching monetization must answer "no" to all of these:

1. Does it put a stat, ship, captain, island, tech, region, or chapter behind money or an ad?
2. Does it introduce a currency, a wallet, or a balance the player can spend?
3. Does an advertisement play without the player pressing a button that said it would?
4. Is the player worse off for declining a purchase or an ad than they were before it was offered?
5. Does it introduce a timer whose removal is for sale?
6. Does it randomize a paid reward?
7. Does it remove an existing earnable path to something now sold?
8. Does it store an entitlement inside a save slot, where a new game would erase it?
9. Does it request an advertisement before the age gate and consent flow have resolved?
10. Does it hardcode a price, SKU, or cosmetic definition in a script instead of a Resource?

Any "yes" is a rejection.
