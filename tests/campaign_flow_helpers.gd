extends RefCounted

const Campaigns := preload("res://game/campaigns.gd")


## Map and camp tests enter through the same resume path used by Continue and Load.
static func resume_at_map(title: Node, campaign_id: String) -> void:
	for campaign in Campaigns.ALL:
		if campaign.id == campaign_id:
			title._open_campaign(campaign)
			return
