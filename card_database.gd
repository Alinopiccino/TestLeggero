extends Node

var cards_by_tooltip: Dictionary = {}

func _ready():
	print("📚 CardDatabase loading...")
	_load_all_cards("res://CardResources")
	print("✅ Carte caricate:", cards_by_tooltip.size())

func _load_all_cards(path: String):
	var dir := DirAccess.open(path)
	if not dir:
		push_error("❌ Impossibile aprire: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_load_all_cards(path + "/" + file_name)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var card: CardData = load(path + "/" + file_name)
			if card:
				if cards_by_tooltip.has(card.tooltip_name):
					push_warning("⚠️ Tooltip duplicato: " + card.tooltip_name)
				cards_by_tooltip[card.tooltip_name] = card
		file_name = dir.get_next()

	dir.list_dir_end()

func get_card(tooltip_name: String) -> CardData:
	return cards_by_tooltip.get(tooltip_name, null)
