extends "res://scripts/ui/ChoiceDialog.gd"
class_name EightsConfirmDialog

## Purpose: the one confirm step before any Pieces of Eight are spent — both M27
## sinks ("Finish now" on a running job, "Cover" a purchase's shortfall) go through
## it (Requirements 4.3, 5.4).
## Responsibilities: states exactly what the Eights buy, the price and the current
##   balance; Cancel is the first (focused) button, as ChoiceDialog's callers do for
##   any spend. No button is marked Primary — a coral CTA on a premium spend would
##   be the pushy affordance AGENTS.md's monetization rules exist to avoid.
##
## Usage: if await EightsConfirmDialog.new("Finish the Farm now", 3).confirm(self): ...

const CANCEL_INDEX := 0
const SPEND_INDEX := 1


func _init(action_text: String, price: int) -> void:
	var balance := ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY)
	super(tr("Spend Pieces of Eight?"),
		tr("%s for %s?\nYou have %d.") % [action_text, amount_text(price), balance],
		PackedStringArray([tr("Cancel"), tr("Spend %d") % price]))


## "1 Piece of Eight" / "3 Pieces of Eight" — for sentences.
static func amount_text(n: int) -> String:
	return TranslationServer.translate("1 Piece of Eight") if n == 1 \
		else TranslationServer.translate("%d Pieces of Eight") % n


## "1 Eight" / "3 Eights" — the short form buttons use.
static func short_amount(n: int) -> String:
	return TranslationServer.translate("1 Eight") if n == 1 \
		else TranslationServer.translate("%d Eights") % n


## Adds the dialog under `parent`; true only if the player chose to spend.
func confirm(parent: Node) -> bool:
	return await ask(parent) == SPEND_INDEX
