extends Resource
class_name FuryData

## Purpose: Data-driven Fury mechanic parameters.
## Responsibilities: Hold fill rates for different sources (hits, rakes, braces, kills).

## Fury fills from hits, rakes, Perfect Braces and kills.
## Fury is a 0–1 charge that, when full, makes the special broadside ready early.

## Fury granted per hull damage point from a standard hit.
@export var fury_per_hit: float = 0.01  # placeholder: tune in M31

## Multiplier for fury fill on rake hits (stern/bow facing).
@export var rake_multiplier: float = 2.0  # placeholder: tune in M31

## Fury granted on a Perfect Brace (as a fraction, 0.0-1.0).
@export var fury_on_perfect_brace: float = 0.25  # placeholder: tune in M31

## Fury granted when killing an enemy.
@export var fury_on_kill: float = 0.5  # placeholder: tune in M31

## Extra fill rate on the special timer when fury is active.
## This is an extra fill source independent of the cooldown timer.
@export var fury_fill_rate: float = 0.1  # placeholder: tune in M31
