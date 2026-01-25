extends VBoxContainer
class_name ManaSlotManager


# Dizionario che mappa il tipo di mana al percorso della texture
const MANA_TEXTURES = {
	"Fire": preload("res://Assets/Mana/Fuoco.png"),
	"FireUsing": preload("res://Assets/Mana/FuocoUsing.png"),
	"Earth": preload("res://Assets/Mana/Terra.png"),
	"EarthUsing": preload("res://Assets/Mana/TerraUsing.png"),
	"Water": preload("res://Assets/Mana/Acqua.png"),
	"WaterUsing": preload("res://Assets/Mana/AcquaUsing.png"),
	"Wind": preload("res://Assets/Mana/Vento.png"),
	"WindUsing": preload("res://Assets/Mana/VentoUsing.png"),
	"Spent": preload("res://Assets/Mana/Spento.png"),
	"Spent2": preload("res://Assets/Mana/Spento2.png"),  # 👈 nuovo
	"Colorless": preload("res://Assets/Mana/Colorless.png"),
	"ColorlessUsing": preload("res://Assets/Mana/ColorlessUsing.png"),
	"Side": preload("res://Assets/Mana/Side.png"),
}

@export var is_extra: bool = false
@export var is_enemy: bool = false
var last_spent_types: Array[String] = []   # 👈 buffer per i tipi spesi

func _ready():
	add_to_group("ManaManagers")
	print("ManaSlotManager ready | name:", name, 
		  " | is_enemy:", is_enemy, 
		  " | is_extra:", is_extra,
		  " | peer:", multiplayer.get_unique_id())

func set_mana_slots(mana_slots: Array[String]) -> void:
	for child in get_children():
		child.queue_free()

	for slot_type in mana_slots:
		var tex_rect := TextureRect.new()
		
		tex_rect.texture = MANA_TEXTURES.get(slot_type, null)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		tex_rect.pivot_offset = tex_rect.custom_minimum_size / 2

		# Salva stato priority
		tex_rect.set_meta("priority", false)
		tex_rect.set_meta("slot_type", slot_type)
		tex_rect.set_meta("spent", false)              # 👈 QUI inizializzi a false
		tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # 👈 e abiliti interazioni

		# 👇 Shader per bordo
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

uniform bool hover = false;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_thickness = 0.03;

/* 🔴 NUOVO */
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered);
	float radius = 0.35;

	vec4 final_color = tex;

	if (hover && dist > radius - border_thickness && dist < radius + border_thickness) {
		final_color = border_color;
	}

	// ✅ flash_color applicato QUI
	COLOR = final_color * flash_color;
}

"""
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("border_color", Color.html("#FCE7C1")) # giallino
		tex_rect.material = mat
		mat.set_shader_parameter("flash_color", Color.WHITE)

		# Interazioni
		if not is_enemy:
			tex_rect.gui_input.connect(_on_slot_clicked.bind(slot_type, tex_rect))
			tex_rect.mouse_entered.connect(_on_slot_hover_entered.bind(tex_rect))
			tex_rect.mouse_exited.connect(_on_slot_hover_exited.bind(tex_rect))

		add_child(tex_rect)


func _on_slot_clicked(event: InputEvent, slot_type: String, tex_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var in_priority: bool = tex_rect.get_meta("priority")
		var mat := tex_rect.material as ShaderMaterial

		if not in_priority:
			# 🔹 Attiva PRIORITY → bordo acceso fisso
			tex_rect.set_meta("priority", true)
			if mat:
				mat.set_shader_parameter("hover", true)
			print("⭐ Slot", slot_type, "in modalità PRIORITY (solo bordo acceso)")
		else:
			# 🔹 Disattiva PRIORITY → bordo spento
			tex_rect.set_meta("priority", false)
			if mat:
				mat.set_shader_parameter("hover", false)
			print("⬅️ Slot", slot_type, "tornato normale (bordo spento)")



func _on_slot_hover_entered(tex_rect: TextureRect) -> void:
	if not tex_rect.get_meta("priority"):
		(tex_rect.material as ShaderMaterial).set_shader_parameter("hover", true)


func _on_slot_hover_exited(tex_rect: TextureRect) -> void:
	if not tex_rect.get_meta("priority"):
		(tex_rect.material as ShaderMaterial).set_shader_parameter("hover", false)
		

func set_all_slots_using(using: bool) -> void:
	# 🔍 Combina slot standard ed extra
	var all_slots: Array = []
	all_slots.append_array(get_children())

	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container:
		all_slots.append_array(extra_container.get_children())

	# 🔦 Applica stato a tutti gli slot
	for child in all_slots:
		if child is TextureRect:
			var slot_type: String = child.get_meta("slot_type")
			if using:
				# Mostra texture "Using" se non è spent
				var tex = MANA_TEXTURES.get(slot_type + "Using", null)
				if tex and not child.get_meta("spent", false):
					child.texture = tex
			else:
				# 👇 Se è spent → rimani spent
				if child.get_meta("spent", false):
					child.texture = MANA_TEXTURES.get("Spent2", null)
				else:
					var tex = MANA_TEXTURES.get(slot_type, null)
					if tex:
						child.texture = tex
					
					
func highlight_required_slots(required_mana: Array[String]) -> void:
	# 🔍 Combina gli slot standard e quelli extra in un unico array
	var all_slots: Array = []
	all_slots.append_array(get_children())

	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container:
		all_slots.append_array(extra_container.get_children())

	# Reset prima tutti gli slot
	for child in all_slots:
		if child is TextureRect:
			var slot_type: String = child.get_meta("slot_type")
			if child.get_meta("spent", false):
				child.texture = MANA_TEXTURES.get("Spent2", null)
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE  # spent → non interattivo
			else:
				child.texture = MANA_TEXTURES.get(slot_type, null)
				child.mouse_filter = Control.MOUSE_FILTER_STOP

	# Copia dei costi da soddisfare
	var mana_left := required_mana.duplicate()
	var contains_colorless := "Colorless" in mana_left

	# --------------------------
	# 1️⃣ Prima passata → usa PRIORITY manuali
	# --------------------------
	for child in all_slots:
		if mana_left.is_empty():
			break
		if child is TextureRect and not child.get_meta("spent") and child.get_meta("priority"):
			var slot_type: String = child.get_meta("slot_type")
			if slot_type in mana_left:
				child.texture = MANA_TEXTURES.get(slot_type + "Using", null)
				mana_left.erase(slot_type)
			elif "Colorless" in mana_left:
				child.texture = MANA_TEXTURES.get(slot_type + "Using", null)
				mana_left.erase("Colorless")

	# --------------------------
	# 2️⃣ Seconda passata → usa automaticamente gli slot COLORLESS se richiesto
	# --------------------------
	if contains_colorless and not mana_left.is_empty():
		for child in all_slots:
			if mana_left.is_empty():
				break
			if not (child is TextureRect):
				continue
			if child.get_meta("spent") or child.get_meta("priority"):
				continue

			var slot_type: String = child.get_meta("slot_type")
			# Usa solo per quanti colorless rimangono
			if slot_type == "Colorless" and "Colorless" in mana_left:
				child.texture = MANA_TEXTURES.get(slot_type + "Using", null)
				mana_left.erase("Colorless")

	# --------------------------
	# 3️⃣ Terza passata → usa gli altri slot normali
	# --------------------------
	for child in all_slots:
		if mana_left.is_empty():
			break
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or child.get_meta("priority"):
			continue

		var slot_type: String = child.get_meta("slot_type")

		if slot_type in mana_left:
			child.texture = MANA_TEXTURES.get(slot_type + "Using", null)
			mana_left.erase(slot_type)
		elif "Colorless" in mana_left:
			child.texture = MANA_TEXTURES.get(slot_type + "Using", null)
			mana_left.erase("Colorless")


func spend_highlighted_slots() -> void:
	var standard_indices: Array = []
	var extra_indices: Array = []
	var spent_types: Array[String] = [] # per overlay su carta coperta

	var mana_slots := get_children()
	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	var extra_slots := extra_container.get_children() if extra_container else []

	# ------------------------------
	# 🔹 1️⃣ Scansiona standard slots
	# ------------------------------
	for i in range(mana_slots.size()):
		var child = mana_slots[i]
		if child is TextureRect:
			var slot_type: String = child.get_meta("slot_type")
			if child.texture == MANA_TEXTURES.get(slot_type + "Using", null):
				child.set_meta("spent", true)
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
				standard_indices.append(i)
				spent_types.append(slot_type)

				# Reset priority e hover (senza spostamento)
				if child.get_meta("priority", false):
					child.set_meta("priority", false)
				if child.material is ShaderMaterial:
					(child.material as ShaderMaterial).set_shader_parameter("hover", false)

				# Flip animato
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(child, "scale:x", 0.0, 0.08)
				tween.tween_callback(func():
					child.texture = MANA_TEXTURES.get("Spent2", null)
				)
				tween.tween_property(child, "scale:x", 1.0, 0.08)
				
				# --- dentro ciclo standard ---
				if child.texture == MANA_TEXTURES.get(slot_type + "Using", null):
					print("🧩 [CLIENT", multiplayer.get_unique_id(), "] Consumo slot STANDARD idx:", i, "| type:", slot_type)

	# ------------------------------
	# 🔹 2️⃣ Scansiona extra slots
	# ------------------------------
	for i in range(extra_slots.size()):
		var child = extra_slots[i]
		if child is TextureRect:
			var slot_type: String = child.get_meta("slot_type")
			if child.texture == MANA_TEXTURES.get(slot_type + "Using", null):
				child.set_meta("spent", true)
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
				extra_indices.append(i)
				spent_types.append(slot_type)

				# Reset priority e hover (senza spostamento)
				if child.get_meta("priority", false):
					child.set_meta("priority", false)
				if child.material is ShaderMaterial:
					(child.material as ShaderMaterial).set_shader_parameter("hover", false)

				# Flip animato
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(child, "scale:x", 0.0, 0.08)
				tween.tween_callback(func():
					child.texture = MANA_TEXTURES.get("Spent2", null)
				)
				tween.tween_property(child, "scale:x", 1.0, 0.08)
				# --- dentro ciclo extra ---
				if child.texture == MANA_TEXTURES.get(slot_type + "Using", null):
					print("🧩 [CLIENT", multiplayer.get_unique_id(), "] Consumo slot EXTRA idx:", i, "| type:", slot_type)

	# 👇 Salva i tipi spesi
	last_spent_types = spent_types.duplicate()

	# ------------------------------
	# 🔹 3️⃣ Invia RPC al peer
	# ------------------------------
	if (standard_indices.size() > 0 or extra_indices.size() > 0) and not is_enemy:
		var player_id = multiplayer.get_unique_id()
		print("🚀 Invio RPC spend_mana | std:", standard_indices, "| extra:", extra_indices, "| types:", spent_types)
		rpc("rpc_spend_mana", player_id, standard_indices, extra_indices, spent_types)



@rpc("any_peer")
func rpc_spend_mana(player_id: int, standard_indices: Array, extra_indices: Array, spent_types: Array):
	print("📩 rpc_spend_mana | player_id:", player_id,
		  " | std:", standard_indices, " | extra:", extra_indices)

	for node in get_tree().get_nodes_in_group("ManaManagers"):
		if not (node is ManaSlotManager):
			continue

		if player_id == multiplayer.get_unique_id() and not node.is_enemy:
			node.rpc_spend_slots(standard_indices, extra_indices)
		elif player_id != multiplayer.get_unique_id() and node.is_enemy:
			node.rpc_spend_slots(standard_indices, extra_indices)


func rpc_spend_slots(standard_indices: Array, extra_indices: Array):
	# 🧩 Evita doppia esecuzione tra standard / extra
	if is_extra:
		# Se siamo nel manager degli slot extra, ignora quelli standard
		if extra_indices.is_empty():
			return
	else:
		# Se siamo nel manager standard, ignora quelli extra
		if standard_indices.is_empty():
			return

	# ------------------------------
	# 🔹 1️⃣ Flippa gli slot standard
	# ------------------------------
	if not is_extra:
		for i in standard_indices:
			if i >= 0 and i < get_child_count():
				var slot = get_child(i)
				if slot is TextureRect:
					slot.set_meta("spent", true)
					slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
					if slot.get_meta("priority", false):
						slot.set_meta("priority", false)
					if slot.material is ShaderMaterial:
						(slot.material as ShaderMaterial).set_shader_parameter("hover", false)
					var tween = create_tween()
					tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tween.tween_property(slot, "scale:x", 0.0, 0.08)
					tween.tween_callback(func(): slot.texture = MANA_TEXTURES.get("Spent2", null))
					tween.tween_property(slot, "scale:x", 1.0, 0.08)
					print("🎯 [CLIENT", multiplayer.get_unique_id(), "] rpc_spend_slots → STANDARD idx:", i, "| tipo:", slot.get_meta("slot_type"), "| nuovo stato: SPENT")

	# ------------------------------
	# 🔹 2️⃣ Flippa gli slot extra
	# ------------------------------
	if is_extra:
		for i in extra_indices:
			if i >= 0 and i < get_child_count():
				var slot = get_child(i)
				if slot is TextureRect:
					slot.set_meta("spent", true)
					slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
					if slot.get_meta("priority", false):
						slot.set_meta("priority", false)
					if slot.material is ShaderMaterial:
						(slot.material as ShaderMaterial).set_shader_parameter("hover", false)
					var tween = create_tween()
					tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tween.tween_property(slot, "scale:x", 0.0, 0.08)
					tween.tween_callback(func(): slot.texture = MANA_TEXTURES.get("Spent2", null))
					tween.tween_property(slot, "scale:x", 1.0, 0.08)
					print("🎯 [CLIENT", multiplayer.get_unique_id(), "] rpc_spend_slots → EXTRA idx:", i, "| tipo:", slot.get_meta("slot_type"), "| nuovo stato: SPENT")

	print("🔄 rpc_spend_slots completato | std:", standard_indices, "| extra:", extra_indices)



func debug_print_slots() -> void:
	print("🔎 Stato attuale dei mana slots:")
	for i in range(get_child_count()):
		var child = get_child(i)
		if child is TextureRect:
			var slot_type: String = child.get_meta("slot_type")
			var is_spent: bool = child.get_meta("spent", false)
			var is_priority: bool = child.get_meta("priority", false)
			print("- Slot %d | Tipo: %s | Spent: %s | Priority: %s" % [
				i, slot_type, str(is_spent), str(is_priority)
			])
@rpc("any_peer")
func rpc_reset_mana(player_id: int):
	print("📩 rpc_reset_mana | player_id:", player_id,
		  " | this_peer:", multiplayer.get_unique_id(),
		  " | is_enemy:", is_enemy)

	# Ciclo su tutti i manager nella scena
	for node in get_tree().get_nodes_in_group("ManaManagers"):
		if not (node is ManaSlotManager):
			continue

		# Se è il player che ha mandato → resetto la sua barra player
		if player_id == multiplayer.get_unique_id() and not node.is_enemy:
			node.reset_spent_slots()

		# Se è l’altro player → resetto la barra enemy
		elif player_id != multiplayer.get_unique_id() and node.is_enemy:
			node.reset_spent_slots()

func reset_spent_slots() -> void:
	for child in get_children():
		if child is TextureRect and child.get_meta("spent", false):
			child.set_meta("spent", false)
			child.set_meta("priority", false)

			## Reset eventuale posizione priority
			#if child.position.x != 0:
				#var tween_back = create_tween()
				#tween_back.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				#tween_back.tween_property(child, "position:x", child.position.x - 20, 0.10)

			var slot_type: String = child.get_meta("slot_type")
			var base_tex = MANA_TEXTURES.get(slot_type, null)
			var using_tex = MANA_TEXTURES.get(slot_type + "Using", null)

			# 👇 Flip animazione per tornare alla base
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# 1️⃣ chiusura
			tween.tween_property(child, "scale:x", 0.0, 0.08)

			# 2️⃣ cambio texture → base
			tween.tween_callback(func():
				if base_tex:
					child.texture = base_tex
			)

			# 3️⃣ apertura
			tween.tween_property(child, "scale:x", 1.0, 0.08)

			# 4️⃣ flash USING sopra al base
			if using_tex:
				tween.tween_callback(func():
					var overlay := TextureRect.new()
					overlay.texture = using_tex
					overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					overlay.custom_minimum_size = child.custom_minimum_size
					overlay.anchor_left = 0
					overlay.anchor_top = 0
					overlay.anchor_right = 1
					overlay.anchor_bottom = 1
					overlay.size_flags_horizontal = Control.SIZE_FILL
					overlay.size_flags_vertical = Control.SIZE_FILL
					overlay.modulate = Color(1, 1, 1, 0) # 👈 trasparente
					child.add_child(overlay)

					var flash := create_tween()
					flash.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					flash.tween_property(overlay, "modulate:a", 1.0, 0.1) # fade in veloce
					flash.tween_property(overlay, "modulate:a", 0.0, 0.15) # fade out
					flash.tween_callback(func():
						overlay.queue_free()
					)
				)

			# Riabilita interazione
			child.mouse_filter = Control.MOUSE_FILTER_STOP

func get_last_spent_types() -> Array[String]:
	return last_spent_types.duplicate()


func add_extra_mana_slots(new_slots: Array[String], temp_effect: String = "None") -> void:
	# 🔍 Cerca il VBoxContainer "ExtraManaSlots" nel parent (PlayerFieldScene)
	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container == null:
		push_error("❌ Nodo ExtraManaSlots non trovato nel parent di ManaSlotManager!")
		return

	print("💠 [EXTRA MANA] Aggiungo nuovi slot extra:", new_slots, "| TempEffect:", temp_effect)

	for slot_type in new_slots:
		var tex_rect := TextureRect.new()
		tex_rect.texture = MANA_TEXTURES.get(slot_type, null)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		tex_rect.pivot_offset = tex_rect.custom_minimum_size / 2

		# Metadati
		tex_rect.set_meta("priority", false)
		tex_rect.set_meta("slot_type", slot_type)
		tex_rect.set_meta("spent", false)
		tex_rect.set_meta("temp_effect", temp_effect)

		# Shader bordo
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

uniform bool hover = false;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_thickness = 0.03;

/* 🔴 NUOVO */
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 uv_centered = UV - vec2(0.5);
	float dist = length(uv_centered);
	float radius = 0.35;

	vec4 final_color = tex;

	if (hover && dist > radius - border_thickness && dist < radius + border_thickness) {
		final_color = border_color;
	}

	// ✅ flash_color applicato QUI
	COLOR = final_color * flash_color;
}

"""
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("border_color", Color.html("#FCE7C1"))
		tex_rect.material = mat
		mat.set_shader_parameter("flash_color", Color.WHITE)

		# Interazioni
		if not is_enemy:
			tex_rect.gui_input.connect(_on_slot_clicked.bind(slot_type, tex_rect))
			tex_rect.mouse_entered.connect(_on_slot_hover_entered.bind(tex_rect))
			tex_rect.mouse_exited.connect(_on_slot_hover_exited.bind(tex_rect))

		# 👇 Animazione Flip + Glow
		tex_rect.scale = Vector2(0.0, 1.0)
		extra_container.add_child(tex_rect)

		var using_tex = MANA_TEXTURES.get(slot_type + "Using", null)
		if using_tex:
			# 🔹 Flip + Glow
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(tex_rect, "scale:x", 0.0, 0.08)
			tween.tween_callback(func():
				var overlay := TextureRect.new()
				overlay.texture = using_tex
				overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				overlay.custom_minimum_size = tex_rect.custom_minimum_size
				overlay.modulate = Color(1, 1, 1, 0)
				tex_rect.add_child(overlay)

				var flash := create_tween()
				flash.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				flash.tween_property(overlay, "modulate:a", 1.0, 0.15)
				flash.tween_property(overlay, "modulate:a", 0.0, 0.25)
				flash.tween_callback(func(): overlay.queue_free())
			)
			tween.tween_property(tex_rect, "scale:x", 1.0, 0.08)

			# 🔹 Aggiunge animazione "pulse" in parallelo
			var pulse_tween = create_tween()
			pulse_tween.set_trans(Tween.TRANS_SINE)
			pulse_tween.set_ease(Tween.EASE_IN_OUT)
			pulse_tween.parallel().tween_property(tex_rect, "scale", Vector2(1.3, 1.3), 0.12)
			pulse_tween.tween_property(tex_rect, "scale", Vector2(1.0, 1.0), 0.12)

	print("✨ [EXTRA MANA] Slot extra aggiunti con animazione flip + pulse + temp_effect =", temp_effect)



func remove_temporary_mana_slots(phase_name: String) -> void:
	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container == null:
		return

	var to_remove := []
	for child in extra_container.get_children():
		if child is TextureRect:
			var temp_effect = child.get_meta("temp_effect", "None")
			if temp_effect == phase_name:
				to_remove.append(child)

	if to_remove.is_empty():
		return

	print("💨 [TEMP MANA] Rimuovo", to_remove.size(), "slot scaduti per fase:", phase_name)

	for slot in to_remove:
		if slot is TextureRect:
			# animazione flip out
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(slot, "scale:x", 0.0, 0.1)
			tween.tween_callback(func():
				slot.queue_free()
			)

@rpc("any_peer")
func rpc_remove_temporary_mana_slots(player_id: int, phase_name: String) -> void:
	var is_owner = multiplayer.get_unique_id() == player_id

	var mana_manager: Node = null

	if is_owner:
		print("SONO OWNER DIOCANE")
		# 🟢 Sei già dentro PlayerField, quindi basta puntare direttamente
		mana_manager = get_parent().get_node_or_null("ExtraManaSlots")
	else:
		# 🔴 Campo avversario → risali al parent di PlayerField (Main)
		var enemy_field = get_parent().get_parent().get_node_or_null("EnemyField/ExtraManaSlots")
		if enemy_field:
			mana_manager = enemy_field

	if mana_manager:
		print("💧 [RPC] Rimozione mana temporaneo per fase:", phase_name, "| Owner:", is_owner)
		mana_manager.remove_temporary_mana_slots(phase_name)
	else:
		push_error("❌ ManaSlotManager non trovato per rpc_remove_temporary_mana_slots (Owner:" + str(is_owner) + ")")


func remove_temporary_mana_slots_for_phase(phase_name: String) -> void:
	# 💧 Esegui localmente
	print("💧 [LOCAL] Rimozione mana temporaneo per fase:", phase_name)
	remove_temporary_mana_slots(phase_name)

	# 💫 Poi replica all’altro peer
	var my_id = multiplayer.get_unique_id()
	rpc("rpc_remove_temporary_mana_slots", my_id, phase_name)


func can_pay_cost(required_mana: Array[String]) -> bool:
	var mana_left := required_mana.duplicate()

	# 🔍 Combina standard + extra
	var all_slots: Array = []
	all_slots.append_array(get_children())

	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container:
		all_slots.append_array(extra_container.get_children())

	# 1️⃣ PRIORITY prima
	for child in all_slots:
		if mana_left.is_empty():
			return true
		if not (child is TextureRect):
			continue
		if child.get_meta("spent"):
			continue
		if not child.get_meta("priority"):
			continue

		var t = child.get_meta("slot_type")
		if t in mana_left:
			mana_left.erase(t)
		elif "Colorless" in mana_left:
			mana_left.erase("Colorless")

	# 2️⃣ COLORLESS automatici
	for child in all_slots:
		if mana_left.is_empty():
			return true
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or child.get_meta("priority"):
			continue
		if child.get_meta("slot_type") == "Colorless" and "Colorless" in mana_left:
			mana_left.erase("Colorless")

	# 3️⃣ Altri slot normali
	for child in all_slots:
		if mana_left.is_empty():
			return true
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or child.get_meta("priority"):
			continue

		var t = child.get_meta("slot_type")
		if t in mana_left:
			mana_left.erase(t)
		elif "Colorless" in mana_left:
			mana_left.erase("Colorless")

	return mana_left.is_empty()

func flash_required_slots(required_mana: Array[String]) -> void:
	print("🚨 FLASH MANA | richiesti:", required_mana)

	var mana_left := required_mana.duplicate()

	# 🔍 Combina standard + extra
	var all_slots: Array = []
	all_slots.append_array(get_children())

	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container:
		all_slots.append_array(extra_container.get_children())

	# --------------------------
	# 1️⃣ PRIORITY
	# --------------------------
	for child in all_slots:
		if mana_left.is_empty():
			return
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or not child.get_meta("priority"):
			continue

		var t = child.get_meta("slot_type")
		if t in mana_left:
			mana_left.erase(t)
		elif "Colorless" in mana_left:
			mana_left.erase("Colorless")

	# --------------------------
	# 2️⃣ COLORLESS automatici
	# --------------------------
	for child in all_slots:
		if mana_left.is_empty():
			return
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or child.get_meta("priority"):
			continue
		if child.get_meta("slot_type") == "Colorless" and "Colorless" in mana_left:
			mana_left.erase("Colorless")

	# --------------------------
	# 3️⃣ Altri slot normali
	# --------------------------
	for child in all_slots:
		if mana_left.is_empty():
			return
		if not (child is TextureRect):
			continue
		if child.get_meta("spent") or child.get_meta("priority"):
			continue

		var t = child.get_meta("slot_type")
		if t in mana_left:
			mana_left.erase(t)
		elif "Colorless" in mana_left:
			mana_left.erase("Colorless")

	# --------------------------
	# 🔴 FLASH SOLO CIÒ CHE MANCA DAVVERO
	# --------------------------
	if mana_left.is_empty():
		return

	print("❌ Mana mancante reale:", mana_left)

	for missing in mana_left:
		for child in all_slots:
			if not (child is TextureRect):
				continue

			var slot_type = child.get_meta("slot_type")

			# Flash slot coerenti col tipo mancante
			if missing == "Colorless" or slot_type == missing:
				var mat := child.material as ShaderMaterial
				if mat:
					var tween := create_tween()
					tween.set_loops(2)
					tween.tween_property(
						mat,
						"shader_parameter/flash_color",
						Color(4, 1, 1),
						0.08
					)
					tween.tween_property(
						mat,
						"shader_parameter/flash_color",
						Color.WHITE,
						0.08
					)
				break

func count_available_mana() -> int: #serve per cosnumo mana a fine turn
	var count := 0

	# Combina standard + extra
	var all_slots: Array = []
	all_slots.append_array(get_children())

	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	if extra_container:
		all_slots.append_array(extra_container.get_children())

	for child in all_slots:
		if not (child is TextureRect):
			continue
		if child.get_meta("spent", false):
			continue
		count += 1

	return count


func spend_all_available_mana() -> void:  #serve per consumo mana fine turn
	var standard_indices: Array = []
	var extra_indices: Array = []

	var mana_slots := get_children()
	var extra_container := get_parent().get_node_or_null("ExtraManaSlots")
	var extra_slots := extra_container.get_children() if extra_container else []

	# STANDARD
	for i in range(mana_slots.size()):
		var child = mana_slots[i]
		if child is TextureRect and not child.get_meta("spent", false):
			standard_indices.append(i)

	# EXTRA
	for i in range(extra_slots.size()):
		var child = extra_slots[i]
		if child is TextureRect and not child.get_meta("spent", false):
			extra_indices.append(i)

	if standard_indices.is_empty() and extra_indices.is_empty():
		return

	var player_id = multiplayer.get_unique_id()
	print("🔥 [END TURN] Consumo automatico mana residuo | std:", standard_indices, "| extra:", extra_indices)
	
	rpc_spend_mana(player_id, standard_indices, extra_indices, [])
	# 🔁 Usa la pipeline già esistente
	rpc("rpc_spend_mana", player_id, standard_indices, extra_indices, [])
