extends Node

signal show_intro_requested(level_data: Resource)
signal level_started(level_id: int)
signal show_result_requested(level_id: int, score: int, passed: bool)

const SETTINGS_PATH := "user://settings.cfg"
const DEV_PASSWORD := "217313"
const DEFAULT_PLAYER_PASSWORD := "play"

var level_scripts := {
	1: preload("res://scripts/levels/level_01_phishing.gd"),
	2: preload("res://scripts/levels/level_02_password.gd"),
	3: preload("res://scripts/levels/level_03_extensions.gd"),
	4: preload("res://scripts/levels/level_04_files.gd"),
	5: preload("res://scripts/levels/level_05_wifi.gd"),
	6: preload("res://scripts/levels/level_06_usb.gd"),
	7: preload("res://scripts/levels/level_07_data_classification.gd"),
	8: preload("res://scripts/levels/level_08_ai_compliance.gd"),
	9: preload("res://scripts/levels/level_09_hallucination.gd"),
	10: preload("res://scripts/levels/level_10_prompt_injection.gd"),
	11: preload("res://scripts/levels/level_11_ai_usage.gd"),
	12: preload("res://scripts/levels/level_12_code_review.gd"),
	13: preload("res://scripts/levels/level_13_git_security.gd"),
	14: preload("res://scripts/levels/level_14_email_misuse.gd"),
	15: preload("res://scripts/levels/level_15_data_leak.gd"),
}

var current_level: int = 0
var current_level_data: Resource = null
var current_handler: RefCounted = null
var level_active: bool = false

var level_order: Array = []
var current_index: int = 0
var play_mode: String = "linear"
var player_password: String = ""

func _ready() -> void:
	load_settings()
	if player_password == "":
		player_password = DEFAULT_PLAYER_PASSWORD
	level_order = level_scripts.keys()
	level_order.sort()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		player_password = cfg.get_value("auth", "player_password", "")

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "player_password", player_password)
	cfg.save(SETTINGS_PATH)

func set_player_password(pwd: String) -> void:
	player_password = pwd if pwd != "" else DEFAULT_PLAYER_PASSWORD
	save_settings()

func start_random_run() -> void:
	play_mode = "random"
	level_order = level_scripts.keys()
	level_order.shuffle()
	current_index = 0
	ScoreManager.reset_all()
	GameState.reset()
	print("[LevelManager] Random run order: ", level_order)
	load_level(level_order[0])

func load_level(level_id: int) -> void:
	current_level = level_id
	var idx := level_order.find(level_id)
	if idx >= 0:
		current_index = idx
	if level_id in level_scripts:
		current_handler = level_scripts[level_id].new()
		current_level_data = current_handler.get_level_data()
	else:
		current_handler = null
		current_level_data = null
	GameState.reset()
	ScoreManager.attempts.erase(level_id)
	ScoreManager.scores.erase(level_id)
	show_intro_requested.emit(current_level_data)

func start_level() -> void:
	level_active = true
	level_started.emit(current_level)

func complete_level(score: int) -> void:
	level_active = false
	ScoreManager.record_score(current_level, score)
	show_result_requested.emit(current_level, score, true)

func fail_level() -> void:
	level_active = false
	ScoreManager.record_score(current_level, 30)
	show_result_requested.emit(current_level, 30, false)

func has_next_level() -> bool:
	return current_index + 1 < level_order.size()

func next_level_id() -> int:
	return level_order[current_index + 1]
