extends Node
## Headless-раннер: находит tests/test_*.gd и выполняет каждый метод test_*.
## Запуск: Godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## Фильтр набора: -- --suite=test_case_data

const TEST_DIR: String = "res://tests/"

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	await get_tree().process_frame
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			only = arg.substr(8)
	var files: Array[String] = []
	for file: String in ResourceLoader.list_directory(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_runner.gd" and file != "test_suite.gd":
			if only == "" or file.get_basename() == only:
				files.append(file)
	files.sort()
	for file in files:
		await _run_suite(TEST_DIR + file)
	print("TESTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run_suite(path: String) -> void:
	var script: GDScript = load(path)
	var suite: TestSuite = script.new()
	suite.name = path.get_file().get_basename()
	suite.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(suite)
	print("--- ", path.get_file())
	for method in suite.get_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		suite.failures.clear()
		SaveManager.profile = SaveManager.default_profile()
		await suite.before_each()
		await suite.call(method_name)
		await suite.after_each()
		if suite.failures.is_empty():
			_passed += 1
			print("[PASS] ", method_name)
		else:
			_failed += 1
			print("[FAIL] ", method_name)
			for failure in suite.failures:
				print("       - ", failure)
	suite.queue_free()
	await get_tree().process_frame
