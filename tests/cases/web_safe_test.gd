extends "res://tests/test_case.gd"

## Contrato anti-OOB WASM: los mismos fallos que petaron el hangar en móvil
## (vídeo + SubViewport 3D + buses de audio + GLB masivo + GPUParticles) no
## deben volver a colarse.


func suite_name() -> String:
	return "web_safe"


func run() -> void:
	_web_safe_helper_exists()
	_intro_has_no_video_node()
	_menu_scene_has_no_subviewport()
	_menu_web_lite_hangar()
	_audio_web_master_only()
	_mode_audio_pool_stream()
	_no_glb_on_web()
	_core_scene_has_no_particles()
	_lobby_skips_shader_on_web()
	_map_skips_glb_props_on_lite()
	_bots_skip_catalog_mesh_on_web()
	_export_web_guards()


func _web_safe_helper_exists() -> void:
	ok(ResourceLoader.exists("res://scripts/util/web_safe.gd"), "WebSafe script existe")
	var src := FileAccess.get_file_as_string("res://scripts/util/web_safe.gd")
	ok(src.contains("class_name WebSafe"), "class_name WebSafe")
	ok(src.contains("kill_video_player"), "kill_video_player")
	ok(src.contains("should_attach_catalog_mesh"), "should_attach_catalog_mesh")
	ok(src.contains("flat_atmosphere"), "flat_atmosphere")


func _intro_has_no_video_node() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/intro.gd")
	ok(src.contains("WebSafe.is_web()"), "intro usa WebSafe")
	ok(src.contains("_show_keyart_fallback"), "intro web → splash, no vídeo")
	var tscn := FileAccess.get_file_as_string("res://scenes/main/intro.tscn")
	ok(not tscn.contains("VideoStreamPlayer"), "intro.tscn sin VideoStreamPlayer")


func _menu_scene_has_no_subviewport() -> void:
	var tscn := FileAccess.get_file_as_string("res://scenes/main/menu.tscn")
	ok(not tscn.contains("SubViewport"), "menu.tscn sin SubViewport (no World3D al boot web)")


func _menu_web_lite_hangar() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/menu.gd")
	ok(src.contains("_fill_web_lite_stage"), "hangar web lite")
	ok(src.contains("_ensure_desktop_stage_view"), "SubViewport solo en desktop")
	ok(src.contains("WebSafe.flat_atmosphere") or src.contains("flat_atmosphere"), "menú sin shader animado en Web")


func _audio_web_master_only() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/audio_director.gd")
	ok(src.contains("_web_bus"), "AudioDirector._web_bus")
	ok(src.contains("PLAYBACK_TYPE_STREAM"), "playback STREAM en Web")
	ok(src.contains("if not web:") and src.contains("_ensure_buses"), "no add_bus en Web")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	## En ProjectSettings: 0=Stream, 1=Sample (no el enum AudioServer).
	ok(proj.contains("default_playback_type.web=0"), "project.godot fuerza Stream en web")


func _mode_audio_pool_stream() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/mode_audio_pool.gd")
	ok(src.contains("PLAYBACK_TYPE_STREAM"), "ModeAudioPool STREAM en Web")
	ok(src.contains("WebSafe.is_web()"), "ModeAudioPool usa WebSafe")


func _no_glb_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/util/web_safe.gd")
	ok(src.contains("return not is_web()"), "Web: cero GLB (ni humano local)")


func _core_scene_has_no_particles() -> void:
	var tscn := FileAccess.get_file_as_string("res://scenes/objectives/beast_objective.tscn")
	ok(not tscn.contains("GPUParticles"), "núcleo.tscn sin GPUParticles (alloc al instantiate)")
	var src := FileAccess.get_file_as_string("res://scripts/objectives/beast_objective.gd")
	ok(src.contains("_emit_desktop_destroy_particles") or src.contains("not WebSafe.is_web()"), "partículas solo desktop")


func _lobby_skips_shader_on_web() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/lobby.gd")
	ok(src.contains("WebSafe.is_web()"), "lobby usa WebSafe")
	ok(src.contains("flat_atmosphere"), "lobby sin shader en Web")


func _map_skips_glb_props_on_lite() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/maps/map_builder.gd")
	ok(src.contains("if _lite:") and src.contains("_box("), "props lite → cajas, no GLB")
	ok(src.contains("BG_COLOR"), "mapa lite sin ProceduralSky")
	ok(src.contains("if _lite:\n\t\treturn") or src.contains("if _lite:\n\t\treturn\n\tfor existing"), "sin trimesh en lite")


func _bots_skip_catalog_mesh_on_web() -> void:
	var ex := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	var beast := FileAccess.get_file_as_string("res://scripts/player/beast.gd")
	ok(ex.contains("WebSafe.should_attach_catalog_mesh"), "explorer respeta WebSafe mesh")
	ok(beast.contains("WebSafe.should_attach_catalog_mesh"), "beast respeta WebSafe mesh")


func _export_web_guards() -> void:
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(cfg.contains("assets/video/intro/*"), "export Web excluye vídeo intro del PCK")
	ok(cfg.contains("assets/characters/roster/*.glb"), "export Web excluye GLB roster (peso)")
	ok(cfg.contains("assets/kenney/props/*"), "export Web excluye props Kenney")
	ok(cfg.contains("assets/audio/music/*"), "export Web excluye ambience.ogg (1MB+)")
	ok(cfg.contains("progressive_web_app/enabled=true"), "PWA habilitado (workaround OOB audio)")
	var bust := FileAccess.get_file_as_string("res://scripts/cache_bust_web.sh")
	ok(bust.contains("Solo limpia caché") or bust.contains("no en cada visita"), "cache-bust no borra caché cada load")
	var ngx := FileAccess.get_file_as_string("res://deploy/nginx-web.conf")
	ok(ngx.contains("immutable"), "nginx cachea wasm/pck versionados")
