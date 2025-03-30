extends Node2D

const CYCLE_DURATION = 100

@onready var disappearing = [false, false, false, false, false, false, false, false]
@onready var is_particle_visible = [false, false, false, false, false, false, false, false]
@onready var morph_targets = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
@onready var should_dance = true

func set_frequency(f : float) -> void:
	for i in range(1, 9):
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("my_time", 0.0)
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
	is_particle_visible[who - 1] = false
	get_node("Timers/Fade" + str(who)).start()
	
func appear(who : int) -> void:
	if who < 1 or who > 8:
		return
	disappearing[who - 1] = false
	is_particle_visible[who - 1] = true
	get_node("Timers/Fade" + str(who)).start()

func set_particle_color(who : int, col : float) -> void:
	if who < 1 or who > 8:
		return
	get_node("Path" + str(who) + "/PathFollow2D/Particle").material.set_shader_parameter("which_figure", col)

func become_particle_color(who : int, to : float) -> void:
	if who < 1 or who > 8:
		return
	var from = get_node("Path" + str(who) + "/PathFollow2D/Particle").material.get("shader_parameter/which_figure")
	morph_targets[who - 1] = [to, from]
	get_node("Timers/Morph" + str(who)).start()

func set_colors(l) -> void:
	var color_to_which = { 'C' : 0.0, 'H' : 1.0, 'S': 2.0, 'D' : 3.0 }
	var color_to_list = { 'C' : [], 'H' : [], 'S': [], 'D' : [] }
	for i in range(7):
		if i >= len(l):
			if is_particle_visible[i]:
				disappear(i + 1)
		else:
			color_to_list[l[i][0]].append(i + 1)
			if is_particle_visible[i]:
				become_particle_color(i + 1, color_to_which[l[i][0]])
			else:
				set_particle_color(i + 1, color_to_which[l[i][0]])
				appear(i + 1)
	for c in color_to_list.keys():
		if len(color_to_list[c]) >= 5:
			# Il y a couleur
			for j in range(8):
				if color_to_list[c].find(j + 1) == -1:
					if is_particle_visible[j]:
						become_particle_color(j + 1, c)
					else:
						set_particle_color(j + 1, c)
						appear(j + 1)
			break

func pause_particles(toggled_on : bool) -> void:
	should_dance = toggled_on

func _ready() -> void:
	for i in range(1, 9):
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("fade", 0.0)
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("my_time", 0.0)

func _process(delta):
	for i in range(1, 9):
		var new_time = int(should_dance) * delta + get_node("Path" + str(i) + "/PathFollow2D/Particle").material.get("shader_parameter/my_time")
		get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("my_time", new_time)
		
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio += (0.0005 * i + delta) / CYCLE_DURATION
		get_node("Path" + str(i) + "/PathFollow2D").progress_ratio = fposmod(get_node("Path" + str(i) + "/PathFollow2D").progress_ratio, 1.0)
		
		var timer_fade = get_node("Timers/Fade" + str(i))
		if not timer_fade.is_stopped():
			var t = timer_fade.time_left / timer_fade.wait_time
			if not disappearing[i - 1]:
				t = 1.0 - t
			t **= 2
			get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("fade", t)
		
		var timer_morph = get_node("Timers/Morph" + str(i))
		if not timer_morph.is_stopped():
			var t = timer_morph.time_left / timer_morph.wait_time
			t = 0.5 * (1.0 + tanh(10.0 * (t - 0.5)))
			var mt = morph_targets[i - 1]
			get_node("Path" + str(i) + "/PathFollow2D/Particle").material.set_shader_parameter("which_figure", lerpf(mt[0], mt[1], t))
		
