extends Node2D

@export var GAP_X = 73
@export var GAP_Y = 60

func _ready():
	# pas assez de leds, leds trop grosses, cadre moche et pas homogene selon y
	
	for i in range(1, 10):
		get_node("led" + str(i)).position.x = 342 - i * GAP_X
		get_node("led" + str(i)).position.y = -223
	for i in range(10, 19):
		get_node("led" + str(i)).position.x = 342 - (i - 9) * GAP_X
		get_node("led" + str(i)).position.y = -223 + 3 * GAP_Y
		
	$led19.position.x = 342 - 9 * GAP_X
	$led20.position.x = 342 - 9 * GAP_X
	$led21.position.x = 342 - GAP_X
	$led22.position.x = 342 - GAP_X
	
	$led19.position.y = -223 + GAP_Y
	$led20.position.y = -223 + 2 * GAP_Y
	$led21.position.y = -223 + GAP_Y
	$led22.position.y = -223 + 2 * GAP_Y
