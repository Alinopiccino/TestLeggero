extends Control

signal filters_changed(filters: Dictionary)

@onready var filter_type: OptionButton = $FilterType
@onready var condition_option: OptionButton = $ConditionContainer/ConditionOption
@onready var value_spin: SpinBox = $ConditionContainer/ValueSpin

var active_filters: Dictionary = {}  # {"Mana": { "condition": ">", "value": 3 }, ...}

func _ready():
	_populate_filter_type()

	filter_type.item_selected.connect(_on_filter_type_selected)
	condition_option.item_selected.connect(_on_filter_value_changed)
	value_spin.value_changed.connect(_on_filter_value_changed)

	_update_condition_controls()

func _populate_filter_type():
	filter_type.clear()
	filter_type.add_item("Race")
	filter_type.add_item("Class")
	filter_type.add_item("Mana")
	filter_type.add_item("ATK")
	filter_type.add_item("HP")

func _on_filter_type_selected(index):
	_update_condition_controls()

func _update_condition_controls():
	var selected = filter_type.get_item_text(filter_type.get_selected_id())

	condition_option.clear()
	if selected in ["Race", "Class"]:
		value_spin.visible = false
		if selected == "Race":
			for race in ["Beast", "Human", "Spirit", "Demon"]:
				condition_option.add_item(race)
		elif selected == "Class":
			for cls in ["Warrior", "Mage", "Archer", "Assassin"]:
				condition_option.add_item(cls)
	else:
		value_spin.visible = true
		condition_option.add_item(">")
		condition_option.add_item("<")

func _on_filter_value_changed(_value = null):
	var selected_type = filter_type.get_item_text(filter_type.get_selected_id())

	if selected_type in ["Race", "Class"]:
		var selected_value = condition_option.get_item_text(condition_option.get_selected_id())
		active_filters[selected_type] = { "condition": "=", "value": selected_value }
	else:
		var cond = condition_option.get_item_text(condition_option.get_selected_id())
		var val = int(value_spin.value)
		active_filters[selected_type] = { "condition": cond, "value": val }

	emit_signal("filters_changed", active_filters)
