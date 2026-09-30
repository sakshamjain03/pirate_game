extends GutHookScript

## GUT pre-run hook, wired in res://.gutconfig.json (loaded by every
## gut_cmdln.gd run). Not a test: GUT only collects files prefixed "test_".
##
## CampaignManager pays each chapter's Eights once per install and records it in
## user://eights_ledger.json — the same user:// directory the real game uses. Any
## test that completes a real chapter would otherwise write the developer's own
## ledger and withhold their next real reward. The whole suite uses a scratch
## ledger instead, starting empty.

const TEST_LEDGER_PATH := "user://eights_ledger_suite.json"


func run() -> void:
	var campaign: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CampaignManager")
	if not campaign:
		return
	if FileAccess.file_exists(TEST_LEDGER_PATH):
		DirAccess.remove_absolute(TEST_LEDGER_PATH)
	campaign.eights_ledger_path = TEST_LEDGER_PATH
	campaign._chapter_eights_paid.clear()
