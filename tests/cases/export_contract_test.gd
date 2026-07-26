extends "res://tests/test_case.gd"

## Contrato entre project.godot y export_presets.cfg.
##
## La suite corre desde fuente, donde todo el repositorio existe; la build de
## producción corre desde un PCK del que se han recortado carpetas enteras
## (`modes/*`, packs de assets…). Un autoload alojado en una de esas carpetas
## pasa todos los tests y luego mata el arranque en el navegador.
##
## Pasó de verdad: el autoload `Audio` se registró apuntando a
## `res://modes/shared/audio_pool.gd` y `modes/*` está excluido del export.


func suite_name() -> String:
	return "export_contract"


func run() -> void:
	var patterns := _exclude_patterns()
	ok(not patterns.is_empty(), "no se pudo leer exclude_filter de export_presets.cfg")
	_autoloads_survive_the_export(patterns)
	_main_scene_survives_the_export(patterns)
	_tests_do_not_ship(patterns)


## Mismas reglas que aplica Godot al exportar: comodines sobre la ruta sin
## `res://`, sin distinguir mayúsculas.
func _is_excluded(res_path: String, patterns: PackedStringArray) -> bool:
	var path := res_path.trim_prefix("res://")
	for p in patterns:
		if path.matchn(p):
			return true
	return false


func _exclude_patterns() -> PackedStringArray:
	var out: PackedStringArray = []
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if not line.begins_with("exclude_filter="):
			continue
		var raw := line.trim_prefix("exclude_filter=").strip_edges().trim_prefix("\"").trim_suffix("\"")
		for chunk in raw.split(",", false):
			var pattern := chunk.strip_edges()
			if not pattern.is_empty() and not out.has(pattern):
				out.append(pattern)
	return out


func _autoload_paths() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		return out
	var in_section := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("["):
			in_section = line == "[autoload]"
			continue
		if not in_section or line.is_empty() or not line.contains("="):
			continue
		var name := line.get_slice("=", 0).strip_edges()
		var path := line.substr(line.find("=") + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		# El '*' inicial solo marca que el autoload es un singleton.
		out[name] = path.trim_prefix("*")
	return out


func _autoloads_survive_the_export(patterns: PackedStringArray) -> void:
	var autoloads := _autoload_paths()
	ok(autoloads.size() >= 5, "se esperaban varios autoloads y se leyeron %d" % autoloads.size())
	for name in autoloads:
		var path: String = autoloads[name]
		ok(
			ResourceLoader.exists(path),
			"el autoload %s apunta a %s y ese archivo no existe" % [name, path]
		)
		ok(
			not _is_excluded(path, patterns),
			"el autoload %s vive en %s, que el export excluye: la build de producción no arrancaría" % [name, path]
		)


func _main_scene_survives_the_export(patterns: PackedStringArray) -> void:
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	neq(main, "", "el proyecto no declara escena principal")
	ok(not _is_excluded(main, patterns), "la escena principal (%s) está excluida del export" % main)


func _tests_do_not_ship(patterns: PackedStringArray) -> void:
	## Los .gd son recursos, así que sin excluirlos la suite entera viaja dentro
	## del PCK que descarga cada jugador.
	ok(
		_is_excluded("res://tests/test_runner.gd", patterns),
		"la suite de tests debería quedar fuera del PCK (añade tests/* a exclude_filter)"
	)
