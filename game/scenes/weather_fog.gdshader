shader_type canvas_item;
// Fog over the world viewport: soft noise that sticks to the world and drifts slowly, cut into
// a few flat steps of opacity, so it is made of whole art pixels like
// everything else and still reads as soft.

uniform vec2 view_size;
// The world position of the middle of the view, in whole art pixels.
uniform vec2 camera;
// How far the fog has drifted, in pixels.
uniform vec2 drift;
uniform float fog : hint_range(0.0, 1.0) = 0.0;
// The day tint, so that the fog darkens at night like the world.
uniform vec4 tint : source_color = vec4(1.0);

const vec3 FOG_COLOR = vec3(0.84, 0.87, 0.91);
// The opacity of the thickest fog, and the number of steps it is cut into.
const float MAX_OPACITY = 0.72;
const float STEPS = 7.0;

void fragment() {
	vec2 p = floor(UV * view_size);
	vec2 world = p + camera - view_size * 0.5 - drift;
	// Wide banks of fog with finer wisps in them: warped sine waves, whose curved edges
	// look softer than value noise cut into steps.
	float bank = sin(world.x / 53.0 + 1.7 * sin(world.y / 41.0));
	float stripe = sin(world.y / 47.0 + 1.3 * sin(world.x / 37.0 + 2.0));
	float wisp = sin((world.x + world.y) / 23.0 + sin(world.x / 19.0));
	float n = 0.5 + 0.5 * (0.45 * bank + 0.35 * stripe + 0.2 * wisp);
	float density = clamp(fog * (0.45 + 0.9 * n) , 0.0, 1.0);
	density = smoothstep(0.1, 1.0, density) * MAX_OPACITY;
	float alpha = floor(density / MAX_OPACITY * STEPS + 0.5) / STEPS * MAX_OPACITY;
	COLOR = vec4(FOG_COLOR * tint.rgb, alpha);
}
