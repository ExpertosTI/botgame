extends "res://tests/test_case.gd"

## Contrato anti-OOB WASM: los mismos fallos que petaron el hangar en móvil
## (vídeo + SubViewport 3D + GLB masivo) no deben volver a colarse.


func suite_name() -> String:
	return "web_safe"


func run() -> void:
	_web_safe_helper_exists()
	_intro_kills_video_on_web()
	_menu_frees_stage_on_web()
	_lobby_skips_shader_on_web()
	_map_skips_glb_props_on_lite()
	_bots_skip_catalog_mesh_on_web()
	_export_excludes_intro_video()
	_objective_strips_particles_on_web()


func _web_safe_helper_exists() -> void:
	ok(ResourceLoader.exists("res://scripts/util/web_safe.gd"), "WebSafe script existe")
	var src := FileAccess.get_file_as_string("res://scripts/util/web_safe.gd")
	ok(src.contains("class_name WebSafe"), "class_name WebSafe")
	ok(src.contains("kill_video_player"), "kill_video_player")
	ok(src.contains("should_attach_catalog_mesh"), "should_attach_catalog_mesh")
	ok(src.contains("flat_atmosphere"), "flat_atmosphere")


func _intro_kills_video_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/intro.gd")
	ok(src.contains("WebSafe.is_web()"), "intro usa WebSafe")
	ok(src.contains("kill_video_player"), "intro libera VideoStreamPlayer en Web")


func _menu_frees_stage_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/menu.gd")
	ok(src.contains("_fill_web_lite_stage"), "hangar web lite")
	ok(src.contains("StageView") and src.contains("queue_free"), "libera SubViewport en Web")
	ok(src.contains("WebSafe.flat_atmosphere") or src.contains("flat_atmosphere"), "menú sin shader animado en Web")


func _lobby_skips_shader_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/lobby.gd")
	ok(src.contains("WebSafe.is_web()"), "lobby usa WebSafe")
	ok(src.contains("flat_atmosphere"), "lobby sin shader en Web")


func _map_skips_glb_props_on_lite() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/maps/map_builder.gd")
	ok(src.contains("if _lite:") and src.contains("_box("), "props lite → cajas, no GLB")
	ok(src.contains("if _lite:\n\t\treturn") or src.contains("if _lite:\n\t\treturn\n\tfor existing"), "sin trimesh en lite")


func _bots_skip_catalog_mesh_on_web() -> void:
	var ex := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	var beast := FileAccess.get_file_as_string("res://scripts/player/beast.gd")
	ok(ex.contains("WebSafe.should_attach_catalog_mesh"), "explorer respeta WebSafe mesh")
	ok(beast.contains("WebSafe.should_attach_catalog_mesh"), "beast respeta WebSafe mesh")


func _export_excludes_intro_video() -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(cfg.contains("assets/video/intro/*"), "export Web excluye vídeo intro del PCK")


func _objective_strips_particles_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/objectives/beast_objective.gd")
	ok(src.contains("WebSafe.is_web()") and src.contains("particles.queue_free"), "núcleos sin GPUParticles en Web")
