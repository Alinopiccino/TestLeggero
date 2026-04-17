#extends Node
#
#var cards_by_tooltip: Dictionary = {}
#
#func _ready():
	#print("📚 CardDatabase loading...")
	#_load_all_cards("res://CardResources")
	#print("✅ Carte caricate:", cards_by_tooltip.size())
#
#func _load_all_cards(path: String):
	#var dir := DirAccess.open(path)
	#if not dir:
		#push_error("❌ Impossibile aprire: " + path)
		#return
#
	#dir.list_dir_begin()
	#var file_name := dir.get_next()
#
	#while file_name != "":
		#if dir.current_is_dir() and not file_name.begins_with("."):
			#_load_all_cards(path + "/" + file_name)
		#elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			#print("Carico:", path + "/" + file_name)  # 👈 QUI
#
			#var card: CardData = load(path + "/" + file_name)
#
			#if card:
				#print("OK:", card.tooltip_name)  # 👈 AGGIUNGI ANCHE QUESTO
#
				#if cards_by_tooltip.has(card.tooltip_name):
					#push_warning("⚠️ Tooltip duplicato: " + card.tooltip_name)
#
				#cards_by_tooltip[card.tooltip_name] = card
			#else:
				#print("❌ ERRORE load:", path + "/" + file_name)  # 👈 IMPORTANTISSIMO
		#file_name = dir.get_next()
#
	#dir.list_dir_end()
#
#func get_card(tooltip_name: String) -> CardData:
	#return cards_by_tooltip.get(tooltip_name, null)
extends Node

var cards_by_tooltip: Dictionary = {}

func _ready():
	print("📚 CardDatabase loading...")
	_load_all_cards("res://CardResources")
	print("✅ Carte caricate:", cards_by_tooltip.size())

func _load_all_cards(path: String):
	var entries: PackedStringArray = ResourceLoader.list_directory(path)

	for entry in entries:
		var full_path := path.path_join(entry)

		if entry.ends_with("/"):
			_load_all_cards(full_path.trim_suffix("/"))
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			if not ResourceLoader.exists(full_path):
				continue

			var card: CardData = load(full_path)
			if card:
				if cards_by_tooltip.has(card.tooltip_name):
					push_warning("⚠️ Tooltip duplicato: " + card.tooltip_name)
				cards_by_tooltip[card.tooltip_name] = card
			else:
				push_warning("❌ ERRORE load: " + full_path)

func get_card(tooltip_name: String) -> CardData:
	return cards_by_tooltip.get(tooltip_name, null)
