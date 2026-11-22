#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

uniform fs_uniforms
{
    mediump vec4 top;
    mediump vec4 bottom;
};

void main()
{
    vec2 p = var_screen - vec2(0.5, 0.62);
    float glow = 1.0 - smoothstep(0.0, 0.9, length(p * vec2(1.0, 1.3)));
    vec3 color = mix(bottom.rgb, top.rgb, smoothstep(0.0, 1.0, var_screen.y));
    color += vec3(0.05) * glow;
    vec2 v = var_screen - 0.5;
    color *= 1.0 - 0.12 * smoothstep(0.35, 0.85, length(v * vec2(1.2, 1.0)));
    out_fragColor = vec4(color, 1.0);
}
