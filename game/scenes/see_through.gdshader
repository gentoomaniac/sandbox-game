shader_type canvas_item;
// Makes a sprite translucent inside a soft-edged circle (in world pixels), so what stands
// behind it shows. `fade` blends the effect in and out (0 = the plain sprite).

uniform vec2 circle_centre;
uniform float radius = 24.0;
uniform float inner_opacity = 0.35;
uniform float edge_softness = 4.0;
uniform float fade = 0.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float inside = 1.0 - smoothstep(radius - edge_softness, radius, distance(world_position, circle_centre));
	COLOR.a *= mix(1.0, inner_opacity, inside * fade);
}
