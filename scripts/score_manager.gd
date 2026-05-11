extends Node

var scores: Dictionary = {}
var attempts: Dictionary = {}

func reset_all() -> void:
	scores.clear()
	attempts.clear()

func record_score(level_id: int, score: int) -> void:
	scores[level_id] = score

func get_score(level_id: int) -> int:
	return scores.get(level_id, 0)

func increment_attempts(level_id: int) -> void:
	attempts[level_id] = attempts.get(level_id, 0) + 1

func get_attempts(level_id: int) -> int:
	return attempts.get(level_id, 0)

func get_total_score() -> int:
	var total := 0
	for s in scores.values():
		total += s
	return total

func get_max_score() -> int:
	return LevelManager.level_scripts.size() * 100

func is_passing() -> bool:
	return get_total_score() >= int(get_max_score() * 0.7)
