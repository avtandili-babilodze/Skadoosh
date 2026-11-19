extends Node
## Lightweight, dependency-free regression suite. Run with:
## godot --headless --path . tests/test_runner.tscn
##
## Each suite in tests/suites/ checks one area and reports through check(); this
## node gives the suites a place in the scene tree, counts failures and exits
## with that count, so CI fails whenever a check does.

const SUITES := [
	"res://tests/suites/hero_data_suite.gd",
	"res://tests/suites/animation_suite.gd",
	"res://tests/suites/combat_suite.gd",
	"res://tests/suites/scene_suite.gd",
	"res://tests/suites/cpu_suite.gd",
	"res://tests/suites/rig_suite.gd",
]

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _run() -> void:
	# Suites load at run time so one that fails to compile is reported as a failure
	# instead of stopping the run before it can quit, which would hang CI.
	for path: String in SUITES:
		var suite: GDScript = load(path)
		if suite == null or not suite.can_instantiate():
			check(false, "%s compiles" % path.get_file())
			continue
		# A script error inside a suite ends its coroutine early without a value, so
		# only a suite that reaches its last line counts as having run.
		var finished = await suite.new().run(self)
		check(finished == true, "%s ran to completion" % path.get_file())
	if _failures == 0:
		print("All Skadoosh tests passed.")
	else:
		push_error("%d Skadoosh test(s) failed." % _failures)
	get_tree().quit(_failures)
