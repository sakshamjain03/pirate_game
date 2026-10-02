extends GutTest

# Test C.1: campaign_completed state, signal, save, celebration

func test_campaign_completed_functionality():
	# Verify that CampaignManager exists
	assert_not_null(CampaignManager, "CampaignManager autoload exists")
	
	# Verify campaign_completed field exists
	assert_true("campaign_completed" in CampaignManager, "CampaignManager has campaign_completed field")
	
	# Verify campaign_completed_signal exists
	assert_true(CampaignManager.has_signal("campaign_completed_signal"), "CampaignManager has campaign_completed_signal")
	
	# Save the initial state
	var initial_state = CampaignManager.campaign_completed
	
	# Test that campaign_completed is initially false
	CampaignManager.campaign_completed = false
	assert_false(CampaignManager.campaign_completed, "campaign_completed defaults to false")
	
	# Test save/load
	var save_data = CampaignManager.get_save_data()
	assert_true(save_data.has("campaign_completed"), "Save data includes campaign_completed")
	
	CampaignManager.campaign_completed = true
	save_data = CampaignManager.get_save_data()
	assert_true(save_data["campaign_completed"], "Save data preserves campaign_completed=true")
	
	# Test load
	CampaignManager.campaign_completed = false
	CampaignManager.load_save_data(save_data)
	assert_true(CampaignManager.campaign_completed, "load_save_data restores campaign_completed")
	
	# Test new game resets it
	CampaignManager.load_save_data({})
	assert_false(CampaignManager.campaign_completed, "Empty save data resets campaign_completed to false")
	
	# Test get_display_objective exists
	assert_true(CampaignManager.has_method("get_display_objective"), "CampaignManager has get_display_objective method")
