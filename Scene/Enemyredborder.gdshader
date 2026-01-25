shader_type canvas_item;

uniform float time_scale = 10.0; // Velocità del lampeggio
uniform vec4 base_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Rosso puro

void fragment() {
	float alpha = 0.5 + 0.5 * sin(TIME * time_scale); // da 0 a 1
	COLOR = vec4(base_color.rgb, alpha);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
