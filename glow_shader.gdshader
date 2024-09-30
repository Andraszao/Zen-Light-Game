shader_type canvas_item;

uniform vec4 glow_color : source_color;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float distance = length(UV - center);
    float alpha = smoothstep(0.5, 0.0, distance);
    
    COLOR = glow_color;
    COLOR.a *= alpha;
}