## Briefings de campaña (Tripulación / Bestia).
##
## Los 12 niveles ya existían como reglas (mapa, tiempo, núcleos). Esto añade
## la voz arcade: qué siente cada bando al entrar y al ganar. Sin cinemáticas.

class_name CampaignScript
extends RefCounted

## Acto por índice 0-based. Nombres = BIBLIA §5 (una sola fuente).
static func act_for(level_index: int) -> String:
	if level_index <= 3:
		return "I · Primer turno"
	if level_index <= 7:
		return "II · Lo que crece"
	return "III · Protocolo final"


static func briefing(level: Dictionary, role: String) -> String:
	## brief_crew / brief_beast: voz dual al jugar ese rol (sin cinemática).
	var key := "brief_beast" if role == "beast" else "brief_crew"
	var text := str(level.get(key, ""))
	if text.is_empty():
		return str(level.get("tip", ""))
	return text


static func outro(level: Dictionary, role: String, won: bool) -> String:
	if won:
		var key := "win_beast" if role == "beast" else "win_crew"
		var text := str(level.get(key, ""))
		if not text.is_empty():
			return text
		return "Protocolo cumplido."
	var key2 := "loss_beast" if role == "beast" else "loss_crew"
	var text2 := str(level.get(key2, ""))
	if not text2.is_empty():
		return text2
	return "Protocolo fallido. Reintenta."
