extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")

var failures := 0

func _initialize() -> void:
	var main := MainScene.instantiate()
	_expect(main is Node2D, "main scene has a Node2D root")
	_expect(main.get_node_or_null("Character") is Sprite2D, "main scene has a Character Sprite2D")
	main.free()
	if failures == 0:
		print("Desktop Pet template smoke test passed.")
		quit(0)
	else:
		push_error("%d template test(s) failed." % failures)
		quit(1)

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Test failed: " + label)
