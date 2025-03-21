extends Node2D

var old_bet_pos

const MAX_NB_CARDS = 2
@onready var GAP_SIZE = (80 if name == "Player1" else 72) * $Card_1.scale.x
@onready var nb_cards = 0

func begin_scale_anim():
	$scale_anim_timer.start()

func end_scale_anim():
	scale = Vector2(1.0, 1.0)
	$scale_anim_timer.stop()

func get_card_from(from : Vector2, colval : String, frontface = true, cd = -1.0):
	if nb_cards >= MAX_NB_CARDS:
		# on peut pas avoir 3 cartes au poker
		return
		
	nb_cards += 1
	var new_card = get_node("Card_" + str(nb_cards))
	new_card.global_position = from
	
	if colval != "":
		new_card.set_card_type(colval)
	
	if frontface:
		new_card.flip_frontface()
	else:
		new_card.flip_backface()
	
	new_card.visible = true
	$name_label.visible = true

	var left_or_right = (nb_cards - 1) * 2 - 1
	new_card.go_to(global_position + Vector2(left_or_right * GAP_SIZE / 2, 0.0), 0.2, cd)
	
func animate_bet(how_much):
	if how_much == 0:
		$bet_anim.set("theme_override_colors/font_color", Color(0.75, 0.75, 0.75))
		$bet_anim.text = "check"
	elif how_much == -1:
		$bet_anim.set("theme_override_colors/font_color", Color(1.0, 0.1, 0.1))
		$bet_anim.text = "fold"
	elif how_much == -2:
		$bet_anim.set("theme_override_colors/font_color", Color(0.4, 0.4, 0.4))
		$bet_anim.text = "fold par afk"
	elif how_much == -3:
		$bet_anim.set("theme_override_colors/font_color", Color(0.15, 0.44, 0.7))
		$bet_anim.text = "petite blinde"
	elif how_much == -4:
		$bet_anim.set("theme_override_colors/font_color", Color(0.15, 0.44, 0.7))
		$bet_anim.text = "grosse blinde"
	elif int($money_left.text) <= 0:
		$bet_anim.set("theme_override_colors/font_color", Color(1.0, 0.4, 0.3))
		$bet_anim.text = "all-in"
	else:
		$bet_anim.set("theme_override_colors/font_color", Color(0.15, 0.74, 1.0))
		$bet_anim.text = "-" + str(how_much) + "€"
	$bet_anim.visible = true
	old_bet_pos = $bet_anim.position
	$bet_anim_timer.start()
	
func send_card_to(which : int, target : Vector2, cd : float):
	nb_cards -= 1
	get_node("Card_" + str(which)).go_to(target, 0.4, cd)

func _process(delta: float) -> void:
	if not $scale_anim_timer.is_stopped():
		var t = 1.0 - $scale_anim_timer.time_left / $scale_anim_timer.wait_time
		var eased_t = 0.5 + 0.5 * sin(2.0 * PI * t)
		scale = lerp(Vector2(1.0, 1.0), Vector2(1.15, 1.15), eased_t)
	if not $bet_anim_timer.is_stopped():
		var t = $bet_anim_timer.time_left / $bet_anim_timer.wait_time
		t **= 2
		$bet_anim.modulate = Color(1.0, 1.0, 1.0, t)
		$bet_anim.position = lerp(old_bet_pos, old_bet_pos + Vector2(0.0, +30.0), t)

func _on_bet_anim_timer_timeout() -> void:
	$bet_anim.visible = false
	$bet_anim.position = old_bet_pos
