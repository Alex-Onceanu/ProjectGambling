extends Node2D

const CYCLE_DURATION = 100

func _process(delta):
	for i in range(1, 9):
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio += delta / CYCLE_DURATION
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio = fposmod(get_node("Path" + str(i) + "/PathFollow2D").progress_ratio, 1.0)
