extends Resource
class_name FuryData

## Purpose: Data-driven Fury mechanic parameters.
## Responsibilities: Hold fill rates for different sources (hits, rakes, braces, kills).

## Fury fills from hits, rakes, Perfect Braces and kills.
## Fury is a 0–1 charge that, when full, makes the special broadside ready early:
## it is the "extra fill on the existing special timer" (W1-2.4). The timer still
## runs on its own; whichever finishes first readies the special, and firing the
## special on the Fury path spends all of it. Filled by ShipCombat from
## ShipDamage.hit_resolved (outgoing hits), its own brace_started signal and kills.
## The single source for the Perfect Brace grant (BraceData holds none).

## Fury granted per hull damage point from a standard hit.
@export var fury_per_hit: float = 0.01  # placeholder: tune in M31

## Multiplier for fury fill on rake hits (stern/bow facing).
@export var rake_multiplier: float = 2.0  # placeholder: tune in M31

## Fury granted on a Perfect Brace (as a fraction, 0.0-1.0).
@export var fury_on_perfect_brace: float = 0.25  # placeholder: tune in M31

## Fury granted when killing an enemy.
@export var fury_on_kill: float = 0.5  # placeholder: tune in M31
