extends SceneTree
func _initialize() -> void:
	var fails := 0
	for level in range(1, 6):
		var ok := false
		for seed in range(50):
			var lines := LevelData.make(level, 1000 + seed, false, 0)
			if LevelData._has_rescue_room(lines):
				ok = true
				break
		if ok:
			print("level %d: rescue room OK" % level)
		else:
			print("level %d: FAIL" % level)
			fails += 1
	quit(0 if fails == 0 else 1)
