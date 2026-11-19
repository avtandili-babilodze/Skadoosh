shader_type canvas_item;
// The material of a rigged fighter's CanvasGroup. The group first draws all the
// body parts into one image; this shader then draws that image, so the hit
// flash and the respawn blink apply to the body as a whole (overlapping parts
// never show through each other when it fades). Nothing is drawn below
// `floor_clip` (the group's own coordinates): a fighter lying on the ground
// never shows hair or fur sunk into it.

render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float floor_clip = 1.0e9;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	if (local_y > floor_clip) {
		discard;
	}
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	c.a *= alpha;
	COLOR *= c;
}
