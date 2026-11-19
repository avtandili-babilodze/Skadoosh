shader_type canvas_item;
// Blends a fighter's sprite toward a flat colour: the white flash of a hit and
// the pale shimmer of a dodge. `flash` 0 leaves the art untouched; `alpha`
// fades the whole sprite (the blink of respawn invincibility).

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	COLOR = vec4(mix(art.rgb, flash_color.rgb, flash), art.a * alpha);
}
