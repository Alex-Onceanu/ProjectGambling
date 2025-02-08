extends Node2D

var pos_before_goto
var target
var initial_scale_x

@onready var WIDTH = $front.region_rect.size.x
@onready var HEIGHT = $front.region_rect.size.y
@onready var should_move = false
@onready var is_anim_before_halfway = false

func region_of_string(colval : String) -> Vector2i:
	assert(len(colval) == 2)
	var line_of_col = { 'H' : 0, 'C' : 1, 'D' : 2, 'S' : 3 }
	var column_of_val = { 'J' : 9, 'Q' : 10, 'K' : 11, 'A' : 12 }
	
	var line = line_of_col[colval[0]]
	var column = 0
	if colval[1] <= '9':
		column = int(colval[1]) - 1
	else:
		column = column_of_val[colval[1]]
	
	return Vector2i(column * WIDTH, line * HEIGHT)

func set_card_type(colval : String):
	var region = region_of_string(colval)
	$front.region_rect.position.x = region.x
	$front.region_rect.position.y = region.y

func flip_frontface():
	$back.region_rect.position.x = 71
	$back.region_rect.position.y = 0
	$front.visible = true
	
func flip_backface():
	$back.region_rect.position.x = 0
	$back.region_rect.position.y = 0
	$front.visible = false
	
func go_to(__target : Vector2, time = 0.4, wait = 0):
	target = __target
	$goto_anim.wait_time = time
	if wait <= 0:
		_on_goto_wait_timeout()
	else:
		$goto_wait.wait_time = wait
		$goto_wait.start()

func reveal(wait = 0):
	if $front.visible:
		return
	if wait <= 0:
		_on_reveal_wait_timeout()
	else:
		$reveal_wait.wait_time = wait
		$reveal_wait.start()

func _process(delta: float) -> void:
	if should_move:
		var t = $goto_anim.time_left / $goto_anim.wait_time
		t **= 1.5
		global_position = (1.0 - t) * target + t * pos_before_goto
	if not $reveal_anim.is_stopped():
		var t = 0.5 - $reveal_anim.time_left / ($reveal_anim.wait_time * 2.0)
		
		if not is_anim_before_halfway:
			t += 0.5
			
		scale.x = abs(2.0 * t - 1.0)

func _on_goto_anim_timeout() -> void:
	should_move = false
	global_position = target

func _on_goto_wait_timeout() -> void:
	$goto_anim.start()
	pos_before_goto = global_position
	should_move = true

func _on_reveal_wait_timeout() -> void:
	$reveal_anim.start()
	is_anim_before_halfway = true
	initial_scale_x = scale.x

func _on_reveal_anim_timeout() -> void:
	if is_anim_before_halfway:
		flip_frontface()
		is_anim_before_halfway = false
		$reveal_anim.start()
	else:
		scale.x = initial_scale_x
	
