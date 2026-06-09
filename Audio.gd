extends Node

# Gestionnaire audio centralisé (autoload "Audio").
# - SFX : pool de lecteurs sur le bus "SFX" (sons courts, superposables).
# - Musique : un lecteur en boucle sur le bus "Music".
# Tous les sons sont générés (assets/audio/*.wav, voir assets/CREDITS.md).

const SFX := {
	"click":      preload("res://assets/audio/click.wav"),
	"hit_melee":  preload("res://assets/audio/hit_melee.wav"),
	"hit_ranged": preload("res://assets/audio/hit_ranged.wav"),
	"crit":       preload("res://assets/audio/crit.wav"),
	"skill":      preload("res://assets/audio/skill.wav"),
	"heal":       preload("res://assets/audio/heal.wav"),
	"death":      preload("res://assets/audio/death.wav"),
	"victory":    preload("res://assets/audio/victory.wav"),
	"defeat":     preload("res://assets/audio/defeat.wav"),
}
const MUSIC := {
	"menu":   preload("res://assets/audio/music_menu.wav"),
	"battle": preload("res://assets/audio/music_battle.wav"),
}
const SFX_VOICES := 6

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _current_music := ""


func _ready() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	# Les musiques bouclent (boucles générées sans clic).
	for key in MUSIC:
		MUSIC[key].loop_mode = AudioStreamWAV.LOOP_FORWARD


# Joue un effet court (tourniquet de voix pour permettre la superposition).
func play_sfx(name: String) -> void:
	if not SFX.has(name):
		return
	var p := _voices[_next]
	_next = (_next + 1) % SFX_VOICES
	p.stream = SFX[name]
	p.play()


# Lance une musique en boucle (ne redémarre pas si déjà en cours).
func play_music(name: String) -> void:
	if name == _current_music and _music.playing:
		return
	if not MUSIC.has(name):
		return
	_current_music = name
	_music.stream = MUSIC[name]
	_music.play()


func stop_music() -> void:
	_current_music = ""
	_music.stop()
