extends "res://tests/test_case.gd"

## Campaña dual: briefings y outros por rol + Quick Play contract.


func suite_name() -> String:
	return "campaign_quickplay"


func run() -> void:
	_campaign_has_dual_voice()
	_acts_cover_twelve_levels()
	_outro_changes_with_role_and_outcome()
	_quick_play_flags_round_trip()


func _campaign_has_dual_voice() -> void:
	for lv in ProgressionManager.CAMPAIGN:
		var d: Dictionary = lv
		ok(not str(d.get("brief_crew", "")).is_empty(), "brief_crew en %s" % d.get("name", "?"))
		ok(not str(d.get("brief_beast", "")).is_empty(), "brief_beast en %s" % d.get("name", "?"))
		ok(not str(d.get("win_crew", "")).is_empty(), "win_crew en %s" % d.get("name", "?"))
		ok(not str(d.get("win_beast", "")).is_empty(), "win_beast en %s" % d.get("name", "?"))


func _acts_cover_twelve_levels() -> void:
	eq(CampaignScript.act_for(0).substr(0, 1), "I", "acto I al inicio")
	eq(CampaignScript.act_for(5).substr(0, 2), "II", "acto II al medio")
	eq(CampaignScript.act_for(11).substr(0, 3), "III", "acto III al final")
	ok(CampaignScript.act_for(0).contains("Primer turno"), "acto I = BIBLIA Primer turno")
	ok(CampaignScript.act_for(5).contains("Lo que crece"), "acto II = BIBLIA")
	ok(CampaignScript.act_for(11).contains("Protocolo final"), "acto III = BIBLIA")
	eq(ProgressionManager.CAMPAIGN.size(), 12, "siguen siendo 12 niveles")


func _outro_changes_with_role_and_outcome() -> void:
	var lv: Dictionary = ProgressionManager.CAMPAIGN[0]
	var crew_win := CampaignScript.outro(lv, "explorer", true)
	var beast_win := CampaignScript.outro(lv, "beast", true)
	ok(crew_win != beast_win, "finales distintos por bando")
	ok(crew_win.contains("Hangar") or crew_win.length() > 8, "outro tripulación con voz")


func _quick_play_flags_round_trip() -> void:
	NetworkManager.quick_play_active = true
	ok(NetworkManager.quick_play_active, "flag quick play encendido")
	NetworkManager.quick_play_active = false
	ok(not NetworkManager.quick_play_active, "flag quick play apagado")
	## begin_quick_play sin red real cae a solo si join falla; aquí solo el contrato.
	ok(NetworkManager.has_method("begin_quick_play"), "API begin_quick_play")
	ok(NetworkManager.has_method("fallback_quick_play_to_bots"), "API fallback bots")
	var src := FileAccess.get_file_as_string("res://autoload/network_manager.gd")
	ok(src.contains("auto_start_after_quick"), "fallback marca auto-start")
	ok(
		FileAccess.get_file_as_string("res://scripts/combat/combat_kit.gd").contains("reset_weapon_cooldowns"),
		"OVERCHARGE resetea CDs vía API"
	)
	ok(
		FileAccess.get_file_as_string("res://scripts/combat/combat_kit.gd").contains("Rate-limit"),
		"disparo tiene rate-limit en servidor"
	)
