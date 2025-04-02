extends Node2D

var backs_copy

@onready var current_selected = null
@onready var current_equiped = null

func _ready() -> void:
	$"CanvasLayer/SkinList".set_fixed_icon_size(Vector2(46., 52.))

func init_skin_list(l : Array, backs=null) -> void:
	const names = ["Deck de base", "Balatro", "Luigi's casino"]
	if backs_copy == null and backs != null:
		backs_copy = backs
	
	for s in l:
		var i = int(s) - 1
		if s == "2":
			$"CanvasLayer/SkinList".add_item(names[1], backs_copy[1][0])
		else:
			$"CanvasLayer/SkinList".add_item(names[i], backs_copy[i])

func _on_close_shop_pressed() -> void:
	get_node("../")._on_close_shop_pressed(current_equiped)
	$CanvasLayer/Equip.disabled = true
	$CanvasLayer/SkinList.deselect_all()

func _on_equip_pressed() -> void:
	current_equiped = current_selected

func _on_skin_list_item_selected(index: int) -> void:
	current_selected = index
	$CanvasLayer/Equip.disabled = false

func _on_invoc_pressed() -> void:
	if get_node("../").current_money < 150:
		return
	get_node("../").current_money -= 50
	const proba_per_rarity = [5, 20, 100]
	const skins_per_rarity = [["3"], ["2"], ["1"]]

	var dice = randi_range(1, 100)
	for i in range(len(proba_per_rarity)):
		if dice <= proba_per_rarity[i]:
			var new_skin = skins_per_rarity[i][randi_range(0, len(skins_per_rarity[i]) - 1)]
			
			# animation de fou ici
			
			if new_skin in get_node("../").purchased_skins:
				get_node("../").current_money += 25
			else:
				get_node("../").purchased_skins.push_back(new_skin)
				init_skin_list([new_skin])
			break
	$"CanvasLayer/MoneyLeft".text = "Vous avez "+ str(get_node("../").current_money) + "€"
	if get_node("../").current_money < 150:
		$"CanvasLayer/Invoc".disabled = true
