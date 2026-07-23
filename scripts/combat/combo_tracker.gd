class_name ComboTracker
extends Node

## Racha de daño / KO para feedback local.

signal combo_changed(count: int, label: String)

var combo := 0
var _decay := 0.0
var _last_peer := 0


func _process(delta: float) -> void:
	if combo <= 0:
		return
	_decay -= delta
	if _decay <= 0.0:
		combo = 0
		combo_changed.emit(0, "")


func register_hit(from_peer: int, amount: float) -> void:
	if from_peer <= 0 or amount < 4.0:
		return
	var my_id := 1
	if multiplayer.has_multiplayer_peer():
		my_id = multiplayer.get_unique_id()
	if from_peer != my_id:
		return
	if _last_peer == from_peer and _decay > 0.0:
		combo += 1
	else:
		combo = 1
	_last_peer = from_peer
	_decay = 2.4
	var label := ""
	if combo >= 8:
		label = "OVERDRIVE x%d" % combo
	elif combo >= 5:
		label = "FRENESÍ x%d" % combo
	elif combo >= 3:
		label = "COMBO x%d" % combo
	combo_changed.emit(combo, label)


func register_ko(from_peer: int) -> void:
	register_hit(from_peer, 50.0)
	_decay = 3.2
