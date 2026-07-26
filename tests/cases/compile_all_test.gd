extends "res://tests/test_case.gd"

## Compila todos los .gd del proyecto.
##
## Existe por un caso real: `var idx := abs(peer_id) % n` en player_base.gd no
## infería tipo, así que ese script no compilaba y se llevaba con él a beast,
## explorer, projectile, combat_kit y combat_fx. El juego arrancaba al menú y
## moría al entrar en partida, y nada en el pipeline lo detectaba.

const ROOTS := ["res://autoload", "res://scripts", "res://tests", "res://modes"]

## La suite corre sin `--import` (reimportar ~190 MB tardaría minutos en CI),
## así que un preload de una escena con texturas no puede resolverse aquí. Solo
## se excluye por eso, no por código roto.
const NEEDS_IMPORTED_ASSETS: PackedStringArray = [
	"res://modes/fps/objects/player.gd",  # preload de impact.tscn → sprites/hit.png
]


func suite_name() -> String:
	return "compile_all"


func run() -> void:
	var files := _collect()
	gt(float(files.size()), 30.0, "se esperaban muchos más scripts que %d" % files.size())
	for path in files:
		var script: Script = load(path)
		if not ok(script != null, "%s: load() devolvió null" % path):
			continue
		if path in NEEDS_IMPORTED_ASSETS:
			continue
		ok(script.can_instantiate(), "%s no compila" % path)


func _collect() -> PackedStringArray:
	var out: PackedStringArray = []
	for root in ROOTS:
		_walk(root, out)
	out.sort()
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		_walk("%s/%s" % [dir_path, sub], out)
