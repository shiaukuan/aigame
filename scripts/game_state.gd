extends Node

signal action_recorded(action_name: String, detail: Variant)
signal wrong_action_recorded(action_name: String, detail: Variant)
signal email_selection_changed(index: int, selected: bool)

var selected_emails: Array[int] = []
var actions_taken: Array[Dictionary] = []
var wrong_actions: Array[Dictionary] = []

func reset() -> void:
	selected_emails.clear()
	actions_taken.clear()
	wrong_actions.clear()

func record_action(action: String, detail: Variant = null) -> void:
	actions_taken.append({"action": action, "detail": detail})
	action_recorded.emit(action, detail)

func record_wrong_action(action: String, detail: Variant = null) -> void:
	wrong_actions.append({"action": action, "detail": detail})
	wrong_action_recorded.emit(action, detail)

func toggle_email_selected(index: int) -> void:
	if index in selected_emails:
		selected_emails.erase(index)
		email_selection_changed.emit(index, false)
	else:
		selected_emails.append(index)
		email_selection_changed.emit(index, true)

func is_email_selected(index: int) -> bool:
	return index in selected_emails
