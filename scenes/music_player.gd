extends Node2D

var current_bps
var current_phase

@onready var tracks = []
@onready var current_track_i = 0

func get_bps() -> float:
	return current_bps
	
func get_phase() -> float:
	return current_phase

func next_track() -> void:
	$StreamPlayer.stream = tracks[current_track_i][0]
	current_bps = tracks[current_track_i][1]
	current_phase = tracks[current_track_i][2]
	
	current_track_i += 1
	if current_track_i >= len(tracks):
		tracks.shuffle()
		current_track_i = 0

func _ready() -> void:
	const paths  = ["boring20s", "lonedigger", "busteretcharlie"]
	const BPS    = [2.0333, 2.0666, 2.15]
	const phases = [0.5, 0.2, 0.25]
	
	for i in range(len(BPS)):
		var tr = AudioStreamMP3.load_from_file("assets/" + paths[i] + ".mp3")
		tracks.append([tr, BPS[i], phases[i]])
	
	tracks.shuffle()
	next_track()
	


func _on_stream_player_finished() -> void:
	$WaitBeforeNext.start()

func _on_wait_before_next_timeout() -> void:
	next_track()
	get_node("../").update_rythm()
