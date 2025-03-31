extends Node2D

var initial_bag_pos

@onready var initial_scale = $MoneyBag1.scale
@onready var winners_pos = []
@onready var nb_winners = 0

func set_winners(__winners):
	nb_winners = len(__winners)
	winners_pos = __winners
	$WinAnim.start()

func easing(index, t):
	var index01 = 0.5 * index / 10.0
	if t <= index01:
		return 0.0
	elif t >= index01 + 0.5:
		return 1.0
	var new_t = 2.0 * (t - index01)
	return new_t ** 0.46

func _ready() -> void:
	initial_bag_pos = []
	for m in range(1, 11):
		initial_bag_pos.append(get_node("MoneyBag" + str(m)).global_position)

func _process(delta: float) -> void:
	if not $WinAnim.is_stopped():
		var t = 1.0 - $WinAnim.time_left / $WinAnim.wait_time
		for m in range(1, 11):
			var eased_t = easing(m, t)
			var bag = get_node("MoneyBag" + str(m))
			if bag.visible:
				bag.scale = initial_scale.lerp(Vector2(0.1, 0.1), eased_t)
				bag.global_position = lerp(initial_bag_pos[m - 1], winners_pos[m % nb_winners], eased_t)

func _on_win_anim_timeout() -> void:
	for m in range(1, 11):
		var bag = get_node("MoneyBag" + str(m))
		if bag.visible:
			bag.visible = false
			bag.scale = initial_scale
			bag.global_position = initial_bag_pos[m - 1]
