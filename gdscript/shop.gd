extends Node2D

var fronts_copy
var backs_copy
var tween : Tween
var fade_tween : Tween

@onready var current_selected = null
@onready var current_equipped = null
@onready var last_pull = []

const names = ["Deck de base", "Balatro", "Luigi's casino", "Négatif", "Sepia", "Noir et blanc", "Girly uwu", "Abysses", "Spectre", "Joyeux Noël !", "Acheron", "Froid", "Chaleur", "Feuille", "Turquoise", "Magenta", "Terre à terre", "zeste de citron", "crabe ?!"]


func _ready() -> void:
	$"CanvasLayer/SkinList".set_fixed_icon_size(Vector2(46., 52.))

func set_fronts_copy(f : Array) -> void:
	fronts_copy = f

func init_skin_list(l : Array, backs=null) -> void:
	if backs_copy == null and backs != null:
		backs_copy = backs
	
	for s in l:
		var i = int(s) - 1
		if s == "2":
			$"CanvasLayer/SkinList".add_item(names[1], backs_copy[1][6])
		else:
			$"CanvasLayer/SkinList".add_item(names[i], backs_copy[i])

func _on_close_shop_pressed() -> void:
	get_node("../")._on_close_shop_pressed(current_equipped)
	$CanvasLayer/Equip.disabled = true
	$CanvasLayer/SkinList.deselect_all()

func _on_equip_pressed() -> void:
	current_equipped = current_selected

func _on_skin_list_item_selected(index: int) -> void:
	current_selected = index
	$CanvasLayer/Equip.disabled = false

func set_fade(value: float):
	$CanvasLayer/PulledCard/Card/rect.material.set_shader_parameter("fade", value);

func start_anim(rarity : int, skin : String) -> void:
	const rarity_color = [Vector3(1.0, 0.8, 0.0), Vector3(0.5, 0.0, 1.0), Vector3(0.0, 0.5, 1.0)]
	
	$CanvasLayer/PulledCard/Aura.material.set_shader_parameter("clr", rarity_color[rarity])
	$CanvasLayer/PulledCard.global_position = Vector2(392.0, -50.0);
	$CanvasLayer/PulledCard.visible = true
	
	reset_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property($CanvasLayer/PulledCard, "global_position", Vector2(392.0, 300.0), 1.5)
	
	$CanvasLayer/PulledCard/Explosion.start()
	$CanvasLayer/PulledCard/Levitate.stop()
	$CanvasLayer/PulledCard/Card.flip_backface()
	
	var back
	if skin == "2":
		back = backs_copy[int(skin) - 1][6]
	else:
		back = backs_copy[int(skin) - 1]
		
	$CanvasLayer/PulledCard/Card/rect.material.set_shader_parameter("fade", 0.0)
	$CanvasLayer/PulledCard/Card.change_skin(skin, fronts_copy[int(skin) - 1], back)
	$CanvasLayer/PulledCard/Card.visible = false
	$CanvasLayer/PulledCard/Card.scale = Vector2(0.0, 0.0)

func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	
func reset_fade_tween() -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()

func _on_invoc_pressed() -> void:
	if get_node("../").current_money < 140:
		return
	get_node("../").current_money -= 40
	const proba_per_rarity = [5, 20, 100]
	const skins_per_rarity = [["3", "2"], ["4", "5", "7", "8", "9", "11"], ["6", "10", "12", "13", "14", "15", "16", "17", "18", "19"]]

	var dice = randi_range(1, 100)
	for i in range(len(proba_per_rarity)):
		if dice <= proba_per_rarity[i]:
			var new_skin = skins_per_rarity[i][randi_range(0, len(skins_per_rarity[i]) - 1)]
			
			start_anim(i, new_skin)
			var rarity_text = ["Légendaire", "Épique", "Rare"][i]
			$CanvasLayer/PullName.visible = false
			$CanvasLayer/PullName.text = names[int(new_skin) - 1] + " (" + rarity_text + ")"
			
			if new_skin in get_node("../").purchased_skins:
				get_node("../").current_money += 20
				last_pull = []
			else:
				get_node("../").purchased_skins.push_back(new_skin)
				last_pull = [new_skin]
			break
	$"CanvasLayer/MoneyLeft".visible = false
	$CanvasLayer/Invoc.disabled = true

func _process(delta: float) -> void:
	if not $CanvasLayer/PulledCard/Explosion.is_stopped():
		var t = $CanvasLayer/PulledCard/Explosion.time_left / $CanvasLayer/PulledCard/Explosion.wait_time
		if t < 0.6 and not $CanvasLayer/PulledCard/Card.visible:
			reset_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property($CanvasLayer/PulledCard/Card, "scale", Vector2(1.2, 1.2), 0.6 * $CanvasLayer/PulledCard/Explosion.wait_time)
			
			reset_fade_tween()
			fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
			fade_tween.tween_method(set_fade, 0.0, 1.0, 0.6 * $CanvasLayer/PulledCard/Explosion.wait_time)
			
			$CanvasLayer/PulledCard/Levitate.start()
			$CanvasLayer/PulledCard/Card.visible = true
				
		t **= 0.5
		$CanvasLayer/PulledCard/Aura.material.set_shader_parameter("modulate", t)
	if not $CanvasLayer/PulledCard/Levitate.is_stopped():
		var t = $CanvasLayer/PulledCard/Levitate.time_left / $CanvasLayer/PulledCard/Levitate.wait_time
		t = 0.5 + 0.5 * sin(2.0 * PI * t)
		$CanvasLayer/PulledCard/Card.global_position = lerp(Vector2(392.0, 300.0), Vector2(392.0, 260.0), t)


func _on_explosion_timeout() -> void:
	$CanvasLayer/PulledCard/Card.reveal()
	$CanvasLayer/PullName.visible = true
	
	$"CanvasLayer/MoneyLeft".text = "Il te reste "+ str(get_node("../").current_money) + "€"
	$"CanvasLayer/MoneyLeft".visible = true
	init_skin_list(last_pull)
	if get_node("../").current_money >= 150:
		$"CanvasLayer/Invoc".disabled = false
