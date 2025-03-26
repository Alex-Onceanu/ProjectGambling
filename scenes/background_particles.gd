extends Node2D

const CYCLE_DURATION = 100

var disappearing

func set_frequency(f : float) -> void:
	for i in range(1, 9):
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("frequency", f)
	
func set_phase(phi : float) -> void:
	var new_phi
	for i in range(1, 9):
		new_phi = phi + 2.0 * fposmod(0.5 * (int((i - 1) / 2) % 2), 1.0)
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("phase", new_phi)
		
func disappear(who : int) -> void:
	if who < 1 or who > 8:
		return
	disappearing[who - 1] = true
	get_node("Timers/Fade" + str(who)).start()
	
func appear(who : int) -> void:
	if who < 1 or who > 8:
		return
	disappearing[who - 1] = false
	get_node("Timers/Fade" + str(who)).start()
	
func _ready() -> void:
	disappearing = []
	for i in range(8):
		disappearing.append(false)
		
func _process(delta):
	for i in range(1, 9):
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio += (0.0005 * i + delta) / CYCLE_DURATION
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio = fposmod(get_node("Path" + str(i) + "/PathFollow2D").progress_ratio, 1.0)
		var timer = get_node("Timers/Fade" + str(i))
		if not timer.is_stopped():
			var t = timer.time_left / timer.wait_time
			if not disappearing[i - 1]:
				t = 1.0 - t
			t **= 2
			get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("fade", t)
