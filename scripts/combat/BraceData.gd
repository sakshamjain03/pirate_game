extends Resource
class_name BraceData

## Purpose: Data-driven Brace mechanic parameters.
## Responsibilities: Hold the reduction multipliers, timing windows, and cooldown.

## Fraction of damage prevented while bracing (0.0 to 1.0).
## damage_taken = damage * (1 - reduction)
@export var reduction: float = 0.4  # placeholder: tune in M31

## Duration of the brace effect in seconds.
@export var window: float = 1.0  # placeholder: tune in M31

## A Brace pressed while the soonest hostile wind-up aimed at you has at most
## this many seconds left is a Perfect Brace (requirement W1-1.3: "pressed in
## the last perfect_window"). Its Fury grant lives in FuryData.fury_on_perfect_brace.
@export var perfect_window: float = 0.2  # placeholder: tune in M31

## Extra reduction multiplier for a Perfect Brace (0.0 to 1.0).
## damage_taken = damage * (1 - perfect_reduction)
@export var perfect_reduction: float = 0.6  # placeholder: tune in M31

## Cooldown in seconds before Brace can be used again.
@export var cooldown: float = 3.0  # placeholder: tune in M31
