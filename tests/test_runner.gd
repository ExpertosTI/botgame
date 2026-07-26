extends Node

## Runner headless de CHADRINE.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Sale con código 1 si algún caso falla, para que el gate de CI corte antes
## de tocar producción. Un solo argumento opcional filtra por nombre:
##   godot --headless --path . res://tests/test_runner.tscn -- --only=progression

const CASES_DIR := "res://tests/cases"


func _ready() -> void:
	# Un frame para que los autoloads terminen su _ready().
	await get_tree().process_frame
	get_tree().quit(_run_all())


## Los casos son síncronos a propósito: nada de esperar frames, para que el
## gate de CI tarde segundos y falle de forma determinista.
func _run_all() -> int:
	var only := _only_filter()
	var paths := _discover_cases()
	if paths.is_empty():
		printerr("[tests] No se encontró ningún caso en %s" % CASES_DIR)
		return 1

	var total_checks := 0
	var failed_suites := 0
	var all_failures: PackedStringArray = []
	var started := Time.get_ticks_msec()

	print("[tests] CHADRINE · %d suites" % paths.size())
	for path in paths:
		var script: Script = load(path)
		# Un caso con error de parseo devuelve un Script inutilizable, no null:
		# sin este guardia el runner muere y las suites siguientes no corren.
		if script == null or not script.can_instantiate():
			print("  FAIL  %-24s no compila" % path.get_file().get_basename())
			all_failures.append("%s — el script no compila" % path)
			failed_suites += 1
			continue
		var case_obj: Object = script.new()
		var suite: String = case_obj.suite_name()
		if not only.is_empty() and not suite.contains(only):
			continue

		var t0 := Time.get_ticks_msec()
		case_obj.call("run")
		var ms := Time.get_ticks_msec() - t0
		total_checks += int(case_obj.checks)
		var case_failures: PackedStringArray = case_obj.failures
		if case_failures.is_empty():
			print("  PASS  %-24s %3d checks  %4d ms" % [suite, int(case_obj.checks), ms])
		else:
			failed_suites += 1
			print("  FAIL  %-24s %3d checks  %4d ms" % [suite, int(case_obj.checks), ms])
			for f in case_failures:
				print("        · %s" % f)
				all_failures.append("%s: %s" % [suite, f])

	var elapsed := Time.get_ticks_msec() - started
	print("[tests] %d checks · %d suites con fallos · %d ms" % [total_checks, failed_suites, elapsed])
	if failed_suites > 0:
		printerr("[tests] FALLARON %d asserts" % all_failures.size())
		return 1
	print("[tests] OK")
	return 0


func _only_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=")
	return ""


func _discover_cases() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		# En export los .gd llegan como .gdc/.remap; aquí siempre corremos desde fuente.
		if f.ends_with(".gd"):
			out.append("%s/%s" % [CASES_DIR, f])
	out.sort()
	return out
