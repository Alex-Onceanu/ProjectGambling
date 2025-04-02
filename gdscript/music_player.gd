extends Node2D

var current_bps
var current_phase

@onready var tracks = []
@onready var current_track_i = 0
@onready var current_card_sfx = 1

func get_bps() -> float:
	return current_bps
	
func get_phase() -> float:
	return current_phase

func next_track() -> void:
	current_track_i += 1
	if current_track_i >= len(tracks):
		var current_ost = tracks[-1]
		tracks.shuffle()
		while current_ost == tracks[0]:
			tracks.shuffle()
		current_track_i = 0
	
	$StreamPlayer.stream = tracks[current_track_i][0]
	current_bps = tracks[current_track_i][1]
	current_phase = tracks[current_track_i][2]

func previous_track() -> void:
	current_track_i = posmod(current_track_i - 1, len(tracks))
	
	$StreamPlayer.stream = tracks[current_track_i][0]
	current_bps = tracks[current_track_i][1]
	current_phase = tracks[current_track_i][2]


func _ready() -> void:
	const paths  = ["boring20s", "lonedigger", "busteretcharlie", "bowser3d"]
	const BPS    = [2.0333, 2.0666, 2.15, 1.76533]
	const phases = [0.6, 0.7, 0.8, 0.8]
	
	for i in range(len(BPS)):
		var tr = AudioStreamMP3.load_from_file("assets/music/" + paths[i] + ".mp3")
		tracks.append([tr, BPS[i], phases[i]])
	
	tracks.shuffle()
	
	$StreamPlayer.stream = tracks[0][0]
	current_bps = tracks[0][1]
	current_phase = tracks[0][2]

func _on_stream_player_finished() -> void:
	print("finished !")
	$WaitBeforeNext.start()

func _on_wait_before_next_timeout() -> void:
	next_track()
	get_node("../").update_rythm()

func card_sfx() -> void:
	get_node("CardSFX/" + str(current_card_sfx)).pitch_scale = randf_range(0.65, 1.35)
	get_node("CardSFX/" + str(current_card_sfx)).play()
	current_card_sfx = 1 + current_card_sfx % 8

func button_sfx() -> void:
	$ButtonSFX.play()


func _on_shop_music_finished() -> void:
	$ShopMusic.play()
