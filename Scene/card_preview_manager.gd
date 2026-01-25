extends Control

@export var collection_mode: bool = false
@onready var container: Control = $PreviewContainer
@onready var preview_image: TextureRect = $PreviewContainer/CardPreview
@onready var attack_label: RichTextLabel = $PreviewContainer/AttackPreview
@onready var health_label: RichTextLabel = $PreviewContainer/HealthPreview
@onready var spell_multiplier_label: RichTextLabel = $PreviewContainer/SpellMultiplierPreview
@onready var spell_duration_label: RichTextLabel = $PreviewContainer/SpellDurationPreview
# 🔹 Tooltip
@onready var tooltip_panel: Panel = $PreviewContainer/TooltipPanel
@onready var tooltip_label: RichTextLabel = $PreviewContainer/TooltipPanel/MarginContainer/TooltipText
@export var tooltip_offset: Vector2 = Vector2(195, 570)  # distanza sotto la carta

@onready var debuff_tooltip_panel: Panel = $PreviewContainer/DebuffTooltipPanel
@onready var debuff_tooltip_label: RichTextLabel = $PreviewContainer/DebuffTooltipPanel/MarginContainer/DebuffTooltipText
@export var debuff_tooltip_offset: Vector2 = Vector2(970, -400) # posizione sopra la carta


@export var collection_preview_position: Vector2 = Vector2(-150,-100)
@export var preview_position: Vector2 = Vector2(-17,-100)
@export var preview_scale: Vector2 = Vector2(0.47, 0.47)
@export var attack_label_offset: Vector2 = Vector2(90, 660)
@export var health_label_offset: Vector2 = Vector2(455, 660)
@export var spell_multiplier_label_offset: Vector2 = Vector2(545, 710)
@export var spell_duration_label_offset: Vector2 = Vector2(597, 910)

var preview_tween: Tween
var tooltip_tween: Tween
var debuff_tooltip_tween: Tween
var dragging: bool = false

var current_card_data: CardData = null
var current_card: Card = null
var showing_original_stats: bool = false

func show_preview(arg, show_original_stats: bool = false):
	print("SHOW-PREVIEW")
	if dragging:
		print("STO DRAGGANDO RETURN")
		return
	if not arg:
		return

	var card_data: CardData = null
	var card: Card = null

	# 👇 Gestisce sia Card che CardData
	if arg is Card:
		card = arg
		card_data = card.card_data
	elif arg is CardData:
		card_data = arg
	else:
		push_error("❌ show_preview() ha ricevuto un tipo non valido: " + str(arg))
		return

	if not card_data or not card_data.card_sprite:
		return
	current_card_data = card_data
	current_card = card
	set_process_input(true)
	# ✅ Da qui in poi il codice rimane IDENTICO
	preview_image.texture = card_data.card_sprite_preview
	preview_image.visible = true
	# ✅ Assegna immagine

	if preview_image.texture:
		var texture_size = preview_image.texture.get_size()
		container.pivot_offset = texture_size / 2

	# Mostra grafica base
	container.scale = Vector2(0.2, 0.2)
	if collection_mode:
		container.position = collection_preview_position
	else:
		container.position = preview_position
	container.z_index = 1000
	container.visible = true

	# Rimuovi tween precedente
	if preview_tween and is_instance_valid(preview_tween):
		preview_tween.kill()

	preview_tween = create_tween()
	preview_tween.tween_property(container, "scale", preview_scale, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Statistiche
	if card_data.card_type != "Creature": #E' SPELL
		
		var spell_multi: int = card_data.spell_multiplier
		var spell_dur: int = card_data.spell_duration
		
		attack_label.visible = false
		health_label.visible = false

		if show_original_stats:
			spell_multi = card_data.original_spell_multiplier
			spell_dur = card_data.original_spell_duration
			if card_data.original_spell_multiplier > 0:
				spell_multiplier_label.text = str(card_data.original_spell_multiplier)
				spell_multiplier_label.visible = true
			else:
				spell_multiplier_label.visible = false
			if card_data.original_spell_duration > 0 and card_data.original_spell_duration < 100:
				spell_duration_label.text = str(card_data.original_spell_duration)
				spell_duration_label.visible = true
			else:
				spell_duration_label.visible = false
			
		else:
			if card_data.spell_multiplier > 0:
				spell_multiplier_label.text = str(card_data.spell_multiplier)
				spell_multiplier_label.visible = true
			else:
				spell_multiplier_label.visible = false
			if card_data.spell_duration > 0 and card_data.spell_duration < 100:
				spell_duration_label.text = str(card_data.spell_duration)
				spell_duration_label.visible = true
			else:
				spell_duration_label.visible = false
			
		spell_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if collection_mode:
			spell_multiplier_label.modulate = Color(0, 0, 0)
			spell_duration_label.modulate = Color(0, 0, 0)
		else:
			spell_multiplier_label.modulate = get_stat_color(card_data.spell_multiplier, card_data.original_spell_multiplier, show_original_stats)
			spell_duration_label.modulate = get_stat_color(card_data.spell_duration, card_data.original_spell_duration, show_original_stats)
		spell_multiplier_label.position = spell_multiplier_label_offset
		spell_duration_label.position = spell_duration_label_offset
			
		#spell_multiplier_label.visible = true
		#spell_duration_label.visible = true
		
	else: # E' CREATURA
		var atk: int = card_data.attack
		var hp: int = card_data.health
		var max_atk: int = card_data.max_attack
		var max_hp: int = card_data.max_health
		
		spell_multiplier_label.visible = false
		spell_duration_label.visible = false
		
		if show_original_stats:
			atk = card_data.original_attack
			hp = card_data.original_health
			attack_label.text = str(card_data.original_attack)
			health_label.text = str(card_data.original_health)
		else:
			attack_label.text = str(card_data.attack)
			health_label.text = str(card_data.health)

		attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# 🎨 Colori con controllo su max_attack / max_health
	
		if collection_mode:
			attack_label.modulate = Color(0, 0, 0)
			health_label.modulate = Color(0, 0, 0)
		else:
			if max_atk < card_data.original_attack:
				attack_label.modulate = Color(0.69, 0.30, 0.90)
			elif atk > card_data.original_attack:
				attack_label.modulate = Color(0, 0.7, 0)
			elif atk < card_data.original_attack:
				attack_label.modulate = Color(0.8, 0, 0)
			else:
				attack_label.modulate = Color(0, 0, 0)

			if max_hp < card_data.original_health:
				health_label.modulate = Color(0.69, 0.30, 0.90)
			elif hp > card_data.original_health:
				health_label.modulate = Color(0, 0.7, 0)
			elif hp < card_data.original_health:
				health_label.modulate = Color(0.8, 0, 0)
			else:
				health_label.modulate = Color(0, 0, 0)

		attack_label.position = attack_label_offset
		health_label.position = health_label_offset
		attack_label.visible = true
		health_label.visible = true

	# ⏳ Timer per tooltip (1s)
	await get_tree().create_timer(0.3).timeout
	if container.visible: # se il mouse è ancora sulla carta
		show_tooltip(card_data)
		show_debuff_tooltip(card)


func show_tooltip(card_data: CardData):
	var text = build_tooltip_text(card_data)
	if text == "":
		return

	tooltip_label.text = text
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_label.custom_minimum_size = Vector2(250, 0) # larghezza fissa

	# 🔹 Forza il calcolo del contenuto
	await get_tree().process_frame

	# Imposta l’altezza della label in base al testo
	var needed_size = tooltip_label.get_content_height()
	# Ora il pannello si adatta
	tooltip_panel.custom_minimum_size = Vector2(750, needed_size + 50)
	tooltip_panel.reset_size()
	
	# 📍 Posizionamento sotto la preview
	var texture_size = preview_image.texture.get_size() * preview_scale
	tooltip_panel.position = Vector2(
		(texture_size.x - tooltip_panel.size.x) / 2 + tooltip_offset.x,
		texture_size.y + tooltip_offset.y
	)

	tooltip_panel.visible = true
	tooltip_panel.modulate.a = 0

	if tooltip_tween and is_instance_valid(tooltip_tween):
		tooltip_tween.kill()

	tooltip_tween = create_tween()
	tooltip_tween.tween_property(tooltip_panel, "modulate:a", 1.0, 0.2)

func show_debuff_tooltip(card: Card):
	var debuff_text = build_debuff_tooltip_text(card)
	var buff_text = build_buff_tooltip_text(card)

	# Se non ci sono né buff né debuff, non mostrare nulla
	if debuff_text == "" and buff_text == "":
		return

	var combined_text = ""
	
	# Se ci sono entrambi, separali con una linea o spazio
	if buff_text != "":
		combined_text += buff_text + "\n"
	if debuff_text != "":
		combined_text += debuff_text

	debuff_tooltip_label.text = combined_text
	debuff_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debuff_tooltip_label.custom_minimum_size = Vector2(250, 0)

	await get_tree().process_frame
	var needed_size = debuff_tooltip_label.get_content_height()
	debuff_tooltip_panel.custom_minimum_size = Vector2(750, needed_size + 50)
	debuff_tooltip_panel.reset_size()

	# 📍 Mantieni la stessa posizione di prima
	var texture_size = preview_image.texture.get_size() * preview_scale
	debuff_tooltip_panel.position = Vector2(
		(texture_size.x - debuff_tooltip_panel.size.x) / 2 + debuff_tooltip_offset.x,
		texture_size.y + debuff_tooltip_offset.y
	)

	debuff_tooltip_panel.visible = true
	debuff_tooltip_panel.modulate.a = 0

	if debuff_tooltip_tween and is_instance_valid(debuff_tooltip_tween):
		debuff_tooltip_tween.kill()

	debuff_tooltip_tween = create_tween()
	debuff_tooltip_tween.tween_property(debuff_tooltip_panel, "modulate:a", 1.0, 0.2)



func hide_preview():
	if preview_tween and is_instance_valid(preview_tween):
		preview_tween.kill()

	container.visible = false
	tooltip_panel.visible = false
	debuff_tooltip_panel.visible = false
	container.scale = preview_scale
	container.modulate.a = 1.0
	# 🔹 Nascondi tutte le label statistiche (creature e spell)
	attack_label.visible = false
	health_label.visible = false
	spell_multiplier_label.visible = false
	spell_duration_label.visible = false


	# 🔹 Reset stato preview
	current_card_data = null
	current_card = null
	showing_original_stats = false

	# 👇 Disattiva input ed eventi
	set_process(false)
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if not container.visible or not current_card_data:
		return

	if event is InputEventKey and event.keycode in [KEY_CTRL]:
		if event.pressed and not showing_original_stats:
			showing_original_stats = true
			update_stat_labels(true)
		elif not event.pressed and showing_original_stats:
			showing_original_stats = false
			update_stat_labels(false)


func get_stat_color(current: int, original: int, force_black: bool = false) -> Color:
	if force_black:
		return Color(0, 0, 0)
	if current > original:
		return Color(0, 0.7, 0)
	elif current < original:
		return Color(0.8, 0, 0)
	return Color(0, 0, 0)

func format_tooltip(title: String, body: String) -> String:
	return "[font_size=50][b][i]" + title + "[/i][/b][/font_size]\n[font_size=40]" + body + "[/font_size]"

		
func build_tooltip_text(card_data: CardData) -> String:
	var tooltip_text = ""

	# 🧩 1️⃣ Talenti nativi
	var all_talents: Array[String] = card_data.get_talents_array()

	# 🧩 2️⃣ Talenti aggiunti da buff logici (BuffTalent)
	for b in card_data.get_buffs_array():
		if typeof(b) == TYPE_DICTIONARY and b.get("type", "") == "BuffTalent" and b.has("talent"):
			var buff_talent = b["talent"]
			if buff_talent not in all_talents:
				all_talents.append(buff_talent)

	# 🧩 3️⃣ Talento da buff singolo (retrocompatibilità)
	if card_data.talent_from_buff != "None" and card_data.talent_from_buff not in all_talents:
		all_talents.append(card_data.talent_from_buff)

	# 🔹 4️⃣ Costruisci il testo tooltip per ogni talento
	for t in all_talents:
		match t:
			"Taunt":
				tooltip_text += format_tooltip("Taunt", "Your opponent can only attack minions with [b]Taunt[/b].") + "\n\n"
			"Lifesteal":
				tooltip_text += format_tooltip("Lifesteal", "Gain LP equal to the damage dealt by this minion.") + "\n\n"
			"Charge":
				tooltip_text += format_tooltip("Charge", "This minion cannot be retaliated during the turn it is summoned.") + "\n\n"
			"Berserker":
				tooltip_text += format_tooltip("Berserker", "When this minion is in defense position, destroy it.") + "\n\n"
			"Overkill":
				tooltip_text += format_tooltip("Overkill", "When this minion attacks another minion, it inflicts any excess damage to the enemy player.") + "\n\n"
			"Haste":
				tooltip_text += format_tooltip("Haste", "This minion can always attack first during the Battle Phase. If both players have one or more minions with [b]Haste[/b], the offensive player's one can attack first.") + "\n\n"
			"Assault":
				tooltip_text += format_tooltip("Assault", "This minion can attack instantly after being Normal Summoned, but it cannot attack for the rest of the turn. [i](If a minion is attacked this way, it still can retaliate.)[/i]") + "\n\n"
			"Regeneration":
				tooltip_text += format_tooltip("Regeneration", "At the end of the End Phase, this minion heals back to full Health.") + "\n\n"
			"Stun":
				tooltip_text += format_tooltip("Stun", "Minions damaged by this one are [b][color=#da72ff]Stunned[/color][/b].") + "\n\n"
				tooltip_text += "[font_size=40][b][color=#da72ff]Stunned[/color][/b] minions cannot attack or retaliate until they take damage.[/font_size]\n\n"
			"Flying":
				tooltip_text += format_tooltip("Flying", "This minion can always attack directly unless your opponent controls any [b]Flying[/b] minions.") + "\n\n"
			"Double Strike":
				tooltip_text += format_tooltip("Double Strike", "During the Battle Step, this minion can attack the same target twice.") + "\n\n"
			"Elusive":
				tooltip_text += format_tooltip("Elusive", "This minion in attack position can only be attacked if it attacked during the turn.") + "\n\n"
			"Mastery":
				tooltip_text += format_tooltip("Mastery", "This minion always deals damage first when it attacks another minon without [b]Mastery[/b].") + "\n\n"
			"Magic Veil":
				tooltip_text += format_tooltip("Magic Veil", "This minion is immune to the first opponent spell affecting it.") + "\n\n"
			"Phys Immune":
				tooltip_text += format_tooltip("Physical Immunity", "This minion is immune to combat damage.") + "\n\n"
			"Magical Taunt":
				tooltip_text += format_tooltip("Magical Taunt", "When targeting your minions with spells, your opponent can only choose ones with [b]Magical Taunt[/b].") + "\n\n"
			"Reactivity":
				tooltip_text += format_tooltip("Reactivity", "This minion can retaliate even when in attack position.") + "\n\n"
			"Ruthless":
				tooltip_text += format_tooltip("Ruthless", "This minion can attack each enemy minion.") + "\n\n"
			"Deathtouch":
				tooltip_text += format_tooltip("Deathtouch", "Destroy any unit damaged by this card.") + "\n\n"
			"Freeze":
				tooltip_text += format_tooltip("Freeze", "Minions damaged by this one are [b][color=#da72ff]Frozen[/color][/b].") + "\n\n"
				tooltip_text += "[font_size=40][b][color=#da72ff]Frozen[/color][/b] minions cannot attack or retaliate until the end of this turn.[/font_size]\n\n"
			_:
				pass

	# 🔸 5️⃣ Altri dettagli
	if card_data.tributes > 0:
		tooltip_text += format_tooltip("Tribute X", "You must sacrifice X minions you didn't summon from your hand this turn in order to summon this one.") + "\n\n"
	
	return tooltip_text



func build_debuff_tooltip_text(arg) -> String:
	var tooltip_text = ""
	var card_data: CardData = null
	var stun_timer: int = 0
	var freeze_timer: int = 0
	var root_timer: int = 0

	if arg is Card:
		card_data = arg.card_data
		stun_timer = arg.stun_timer
		freeze_timer = arg.freeze_timer
		root_timer = arg.root_timer
		
	elif arg is CardData:
		card_data = arg
	else:
		return ""

	if not card_data:
		return ""

	var debuffs = card_data.get_debuffs_array()
	if debuffs.is_empty() and not card_has_altered_stats(card_data):
		return ""

	var stat_lines: Array[String] = []
	var total_stat_debuffs := 0

	for d in debuffs:
		if typeof(d) != TYPE_DICTIONARY:
			continue

		var debuff_type: String = d.get("type", "None")
		var atk_red: int = d.get("magnitude_atk", 0)
		var hp_red: int = d.get("magnitude_hp", 0)
		var source_card = d.get("source_card", null)

		var expire_text: String = ""
		if is_instance_valid(source_card) and source_card.card_data:
			var src_data: CardData = source_card.card_data
			var temp_type = src_data.temp_effect

			# 🔹 Gestione visualizzazione sorgente/durata
			if debuff_type in ["Stunned", "Frozen","Rooted"]:
				expire_text = ""  # mai mostrare niente per status
			elif temp_type in ["EndPhase", "BattlePhase", "BattleStep"]:
				expire_text = "[font_size=35][i][color=#ffcc00](until " + temp_type.replace("Phase", " Phase") + ")[/color][/i][/font_size]"
			else:
				var src_tooltip: String = str(src_data.tooltip_name) if src_data.tooltip_name != null else ""
				var src_name: String = str(src_data.card_name) if src_data.card_name != null else "Unknown Card"
				var src_label: String = src_tooltip if src_tooltip != "" else src_name
				expire_text = "[font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]" % src_label
		else:
			expire_text = ""

		match debuff_type:
			"Debuff", "DebuffAtk", "DebuffHp":
				total_stat_debuffs += 1
				var line := ""
				match debuff_type:
					"Debuff":
						line = "-%d/-%d" % [atk_red, hp_red]
					"DebuffAtk":
						line = "-%d ATK" % atk_red
					"DebuffHp":
						line = "-%d HP" % hp_red
				if expire_text != "":
					line += "  " + expire_text
				stat_lines.append(line)
			_:
				continue

	# 🧊 FROZEN (solo turn counter)
	if freeze_timer > 0:
		tooltip_text += "[font_size=50][b][i][color=#da72ff]Frozen[/color][/i][/b][/font_size]\n"
		tooltip_text += "  [font_size=35][i][color=#ffcc00]Turns remaining: [b]" + str(freeze_timer) + "[/b][/color][/i][/font_size]\n"
		if stun_timer > 0 or total_stat_debuffs > 0:
			tooltip_text += "\n"

	# 💫 STUNNED (solo turn counter)
	if stun_timer > 0:
		tooltip_text += "[font_size=50][b][i][color=#da72ff]Stunned[/color][/i][/b][/font_size]\n"
		tooltip_text += "  [font_size=35][i][color=#ffcc00]Turns remaining: [b]" + str(stun_timer) + "[/b][/color][/i][/font_size]\n"
		if total_stat_debuffs > 0:
			tooltip_text += "\n"

	if root_timer > 0:
		tooltip_text += "[font_size=50][b][i][color=#da72ff]Rooted[/color][/i][/b][/font_size]\n"
		tooltip_text += "  [font_size=35][i][color=#ffcc00]Turns remaining: [b]" + str(root_timer) + "[/b][/color][/i][/font_size]\n"
		if total_stat_debuffs > 0:
			tooltip_text += "\n"

	# 📉 Stat debuffs
	if total_stat_debuffs > 0:
		var title = "[font_size=50][b][i][color=#da72ff]Reduced Stats"
		if total_stat_debuffs > 1:
			title += " (" + str(total_stat_debuffs) + ")"
		title += "[/color][/i][/b][/font_size]\n"
		tooltip_text += title

		for line in stat_lines:
			tooltip_text += "[font_size=40]- " + line + "[/font_size]\n"

	return tooltip_text







func build_buff_tooltip_text(arg) -> String:
	var tooltip_text = ""
	var card_data: CardData = null

	if arg is Card:
		card_data = arg.card_data
	elif arg is CardData:
		card_data = arg
	else:
		return ""

	if not card_data:
		return ""

	var all_groups = {
		"EndPhase": card_data.active_buffs_until_endphase,
		"BattlePhase": card_data.active_buffs_until_battlephase,
		"BattleStep": card_data.active_buffs_until_battlestep,
		"Permanent": card_data.active_buffs,
		"While": card_data.active_buffs_from_while_effects
	}

	var stat_lines: Array[String] = []
	var total_stat_buffs := 0
	var talent_sources := {}

	for phase_name in all_groups.keys():
		for b in all_groups[phase_name]:
			if typeof(b) != TYPE_DICTIONARY:
				continue

			var buff_type: String = b.get("type", "None")
			var atk_add: int = b.get("magnitude_atk", 0)
			var hp_add: int = b.get("magnitude_hp", 0)
			var armour_add: int = b.get("magnitude_armour", 0) # 🛡️ aggiunto
			var source_card = b.get("source_card", null)

			var expire_text: String = ""
			if is_instance_valid(source_card) and source_card.card_data:
				var src_data: CardData = source_card.card_data
				var temp_type = src_data.temp_effect

				if temp_type in ["EndPhase", "BattlePhase", "BattleStep"]:
					expire_text = "[font_size=35][i][color=#ffcc00](until " + temp_type.replace("Phase", " Phase") + ")[/color][/i][/font_size]"
				else:
					var src_tooltip: String = str(src_data.tooltip_name) if src_data.tooltip_name != null else ""
					var src_name: String = str(src_data.card_name) if src_data.card_name != null else "Unknown Card"
					var src_label: String = src_tooltip if src_tooltip != "" else src_name
					expire_text = "[font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]" % src_label
			else:
				expire_text = ""

			match buff_type:
				"Buff", "BuffAtk", "BuffHp", "BuffArmour":
					total_stat_buffs += 1
					var line = ""
					if atk_add != 0 and hp_add != 0:
						line = "+%d/+%d" % [atk_add, hp_add]
					elif atk_add != 0:
						line = "+%d ATK" % atk_add
					elif hp_add != 0:
						line = "+%d HP" % hp_add
					elif armour_add != 0:
						line = "+%d ARM" % armour_add
					else:
						line = "Stat increase"

					if expire_text != "":
						line += "  " + expire_text
					stat_lines.append(line)

				"BuffTalent":
					var t = b.get("talent", "None")
					if t != "None":
						if not talent_sources.has(t):
							talent_sources[t] = []
						if expire_text != "" and expire_text not in talent_sources[t]:
							talent_sources[t].append(expire_text)
				_:
					continue

	if not talent_sources.is_empty():
		tooltip_text += "[font_size=50][b][i][color=#7dff7d]Buff Talents[/color][/i][/b][/font_size]\n"
		for talent_name in talent_sources.keys():
			tooltip_text += "[font_size=40]- " + talent_name + "[/font_size]"
			for src in talent_sources[talent_name]:
				tooltip_text += "    " + src 
			if total_stat_buffs > 0:
				tooltip_text += "\n"

	if total_stat_buffs > 0:
		var title = "[font_size=50][b][i][color=#7dff7d]Increased Stats"
		if total_stat_buffs > 1:
			title += " (" + str(total_stat_buffs) + ")"
		title += "[/color][/i][/b][/font_size]\n"
		tooltip_text += title
		for line in stat_lines:
			tooltip_text += "[font_size=40]- " + line + "[/font_size]\n"
		tooltip_text += "\n"

	# -------------------------------------------------------------------------
	# 🔮 Empowered / Weakened Tooltip (Spell Power scaling)
	# -------------------------------------------------------------------------
	var total_SP = 0
	var elemental_SP := 0
	var empowered_lines: Array[String] = []
	var power_breakdown := ""

	var cm := $"../CombatManager"
	var is_enemy := false
	if arg is Card:
		if arg.has_method("is_enemy_card") and arg.is_enemy_card():
			is_enemy = true
		elif arg.get_parent() and arg.get_parent().name.contains("Enemy"):
			is_enemy = true
	elif card_data.has_method("is_enemy") and card_data.is_enemy():
		is_enemy = true

	# Ora assegni lo Spell Power corretto
	total_SP = cm.enemy_SP if is_enemy else cm.player_SP

	
	var attr = card_data.card_attribute
	if attr != "" and attr != "None":
		match attr:
			"Fire": elemental_SP = cm.enemy_FireSP if is_enemy else cm.player_FireSP
			"Water": elemental_SP = cm.enemy_WaterSP if is_enemy else cm.player_WaterSP
			"Earth": elemental_SP = cm.enemy_EarthSP if is_enemy else cm.player_EarthSP
			"Wind": elemental_SP = cm.enemy_WindSP if is_enemy else cm.player_WindSP

	var total_spell_power = total_SP + elemental_SP + card_data.base_spell_power

	# 🔧 Mostra sempre se ci sono fonti o modifiche anche se totale = 0
	var has_any_sp_change = (
		total_SP != 0 or
		elemental_SP != 0 or
		card_data.base_spell_power != 0
	)

	if (card_data.scaling_1 == "MagnitudeSpellPower" or card_data.scaling_2 == "MagnitudeSpellPower" or card_data.scaling_1 == "ThresholdSpellPower" or card_data.scaling_2 == "ThresholdSpellPower") and has_any_sp_change:
		var title_color := ""
		var value_color := ""
		var title_text := ""
		var effect_color := ""

		if total_spell_power > 0:
			title_color = "#7dff7d"   # ✅ verde come gli altri buff
			value_color = "#7dff7d"
			title_text = "Empowered"
			effect_color = "#7dff7d"
		elif total_spell_power < 0:
			title_color = "#A02B2B"
			value_color = "#ff6b6b"
			title_text = "Weakened"
			effect_color = "#ff6b6b"
		else:
			title_color = "#b175ff"    # 💜 viola chiaro e luminoso
			value_color = "#ffffff"    # 🤍 bianco puro per i numeri neutrali
			title_text = "Spell Power Modifiers"
			effect_color = "#ffffff"   # 🤍 bianco anche per i testi degli effetti

		if card_data.scaling_1 == "MagnitudeSpellPower":
			var empowered_total = card_data.effect_magnitude_1 + (total_spell_power * card_data.spell_multiplier)
			var label = str(card_data.effect_1)
			if card_data.effect_1 == "None":
				label = "Effect 1"
			empowered_lines.append("[font_size=40]" + label + ": [b][color=%s]%d[/color][/b][/font_size]" % [effect_color, empowered_total])

		if card_data.scaling_2 == "MagnitudeSpellPower":
			var empowered_total2 = card_data.effect_magnitude_2 + (total_spell_power * card_data.spell_multiplier)
			var label2 = str(card_data.effect_2)
			if card_data.effect_2 == "None":
				label2 = "Effect 2"
			empowered_lines.append("[font_size=40]" + label2 + ": [b][color=%s]%d[/color][/b][/font_size]" % [effect_color, empowered_total2])

		if card_data.scaling_1 == "ThresholdSpellPower":
			var empowered_total = card_data.effect_1_threshold + (total_spell_power * card_data.spell_multiplier)
			var label = str(card_data.effect_1)
			label = "Threshold"
			empowered_lines.append("[font_size=40]" + label + ": [b][color=%s]%d[/color][/b][/font_size]" % [effect_color, empowered_total])

		if card_data.scaling_2 == "ThresholdSpellPower":
			var empowered_total2 = card_data.effect_2_threshold + (total_spell_power * card_data.spell_multiplier)
			var label2 = str(card_data.effect_2)
			label2 = "Threshold"
			empowered_lines.append("[font_size=40]" + label2 + ": [b][color=%s]%d[/color][/b][/font_size]" % [effect_color, empowered_total2])
		# 🪄 Fonti di Spell Power
		if total_SP != 0:
			var col = "#7dff7d" if total_SP > 0 else "#ff6b6b"
			var generic_sources = cm.spell_power_sources.get("Generic", [])
			var relevant_sources: Array[String] = []
			for s in generic_sources:
				if s.get("enemy", false) == is_enemy and s.get("value", 0) != 0:
					var src_name = s.get("source", "")
					if src_name != "":
						relevant_sources.append(src_name)

			if relevant_sources.size() <= 1:
				var src_text = ""
				if relevant_sources.size() == 1:
					src_text = " [font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]" % relevant_sources[0]
				power_breakdown += "[font_size=35][color=%s]%+d Spell Power%s[/color][/font_size]\n" % [col, total_SP, src_text]
			else:
				power_breakdown += "[font_size=35][color=%s]%+d Spell Power:[/color][/font_size]\n" % [col, total_SP]
				for src in relevant_sources:
					power_breakdown += "    [font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]\n" % src

		if elemental_SP != 0 and attr != "" and attr != "None":
			var color_map = {
				"Fire": "#ffa31a",   # 🔥 arancione brillante, più chiaro e luminoso
				"Water": "#40c0ff",  # 💧 azzurro medio bilanciato
				"Earth": "#b47d32",  # 🌍 marrone caldo
				"Wind": "#00ffe5"    # 🌪️ turchese acceso e luminoso
			}
			var col_elem = color_map.get(attr, "#ffd27f")
			var col_value = "#7dff7d" if elemental_SP > 0 else "#ff6b6b"

			var elem_sources = cm.spell_power_sources.get(attr, [])
			var relevant_elem_sources: Array[String] = []
			for s in elem_sources:
				if s.get("enemy", false) == is_enemy and s.get("value", 0) != 0:
					var src_name = s.get("source", "")
					if src_name != "":
						relevant_elem_sources.append(src_name)

			var attr_colored = "[color=%s]%s[/color]" % [color_map.get(attr, "#ffd27f"), attr]

			if relevant_elem_sources.size() <= 1:
				var src_text2 = ""
				if relevant_elem_sources.size() == 1:
					src_text2 = " [font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]" % relevant_elem_sources[0]

				# ✅ +2 (verde) + parola elemento colorata + Spell Power (verde)
				power_breakdown += "[font_size=35][color=%s]%+d %s Spell Power[/color]%s\n" % [col_value, elemental_SP, attr_colored, src_text2]
			else:
				power_breakdown += "[font_size=35][color=%s]%+d %s Spell Power:[/color][/font_size]\n" % [col_value, elemental_SP, attr_colored]
				for src in relevant_elem_sources:
					power_breakdown += "    [font_size=35][i][color=#ffcc00](%s)[/color][/i][/font_size]\n" % src



		if card_data.base_spell_power != 0:
			var col_base = "#7dff7d" if card_data.base_spell_power > 0 else "#ff6b6b"
			power_breakdown += "[font_size=35][color=%s]%+d Spell Power [font_size=35][i][color=#ffcc00](Card)[/color][/i][/font_size]\n" % [col_base, card_data.base_spell_power]

		var total_bonus_value = total_spell_power * card_data.spell_multiplier
		var text_desc := "Spell Power modifiers applied.\n\n"

		var empowered_text = text_desc + power_breakdown + "\n"
		for line in empowered_lines:
			empowered_text += line + "\n"

		var title_colored = "[color=%s]%s[/color]" % [title_color, title_text]
		tooltip_text += format_tooltip(title_colored, empowered_text) + "\n\n"

	return tooltip_text











	
	# 🔻 Aggiungi "Original Stats" se le stats sono alterate
	#if card_has_altered_stats(card_data):
		#tooltip_text += build_original_stats_footer(card_data)





func build_original_stats_footer(card_data: CardData) -> String:
	if not card_data or card_data.card_type != "Creature":
		return ""

	var atk := card_data.original_attack
	var hp := card_data.original_health

	var footer := "[font_size=35][color=#888888]────────────────────[/color][/font_size]\n"
	footer +="[i][font_size=30][b]Original Stats:[/b][/font_size][/i]\n"
	footer += "[i][font_size=30]ATK: [b]" + str(atk) + "[/b]    HP: [b]" + str(hp) + "[/b][/font_size]\n"
	
	#var footer :="[i][font_size=30][b]Original Stats:[/b][/font_size][/i]\n"
	#footer += "[i][font_size=30]ATK: [b]" + str(atk) + "[/b]    HP: [b]" + str(hp) + "[/b][/font_size]\n"
	return footer


func card_has_altered_stats(card_data: CardData) -> bool:
	if not card_data or card_data.card_type != "Creature":
		return false

	return (
		card_data.attack != card_data.original_attack
		or card_data.health != card_data.original_health
	)


#-----------------------PEPPE
func update_stat_labels(show_original: bool = false) -> void:
	if not current_card_data:
		return

	if current_card_data.card_type != "Creature":
		# SPELL
		var mult = current_card_data.spell_multiplier
		var dur = current_card_data.spell_duration

		if show_original:
			mult = current_card_data.original_spell_multiplier
			dur = current_card_data.original_spell_duration

		if mult > 0:
			spell_multiplier_label.text = str(mult)
			if collection_mode:
				spell_multiplier_label.modulate = Color(0, 0, 0)
			else:
				spell_multiplier_label.modulate = get_stat_color(dur, current_card_data.original_spell_duration, show_original)
		if dur > 0 and dur < 100:
			spell_duration_label.text = str(dur)
			if collection_mode:
				spell_duration_label.modulate = Color(0, 0, 0)
			else:
				spell_duration_label.modulate = get_stat_color(dur, current_card_data.original_spell_duration, show_original)

	else:
		# CREATURE
		var atk = current_card_data.attack
		var hp = current_card_data.health
		var max_atk = current_card_data.max_attack
		var max_hp = current_card_data.max_health

		if show_original:
			atk = current_card_data.original_attack
			hp = current_card_data.original_health

		attack_label.text = str(atk)
		health_label.text = str(hp)

		# 🎨 Colori
		if max_atk < current_card_data.original_attack:
			if show_original:
				attack_label.modulate = Color(0, 0, 0)
			else:
				attack_label.modulate = Color(0.69, 0.30, 0.90)
		elif atk > current_card_data.original_attack:
			attack_label.modulate = Color(0, 0.7, 0)
		elif atk < current_card_data.original_attack:
			attack_label.modulate = Color(0.8, 0, 0)
		else:
			attack_label.modulate = Color(0, 0, 0)

		if max_hp < current_card_data.original_health:
			if show_original:
				health_label.modulate = Color(0, 0, 0)
			else:
				health_label.modulate = Color(0.69, 0.30, 0.90)
		elif hp > current_card_data.original_health:
			health_label.modulate = Color(0, 0.7, 0)
		elif hp < current_card_data.original_health:
			health_label.modulate = Color(0.8, 0, 0)
		else:
			health_label.modulate = Color(0, 0, 0)
