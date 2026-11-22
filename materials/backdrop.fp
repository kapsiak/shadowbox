#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

uniform fs_uniforms
{
    // rect: x, y, width, height in window pixels; screen: window width and height
    mediump vec4 rect;
    mediump vec4 screen;
    mediump vec4 fill;
};

float roundedBox(vec2 p, vec2 half_size, float radius)
{
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main()
{
    vec2 half_size = rect.zw * 0.5;
    float radius = min(half_size.y, 48.0);
    vec2 pixel = var_screen * screen.xy;
    float d = roundedBox(pixel - (rect.xy + half_size), half_size, radius);
    float body = 1.0 - smoothstep(-1.0, 1.0, d);
    float shadow = (1.0 - smoothstep(0.0, 28.0, d + 6.0)) * 0.12;
    float edge = (1.0 - smoothstep(0.0, 2.0, abs(d + 1.5))) * 0.5;
    vec3 color = mix(fill.rgb, vec3(1.0), edge);
    float alpha = max(body * fill.a, shadow);
    vec3 rgb = mix(vec3(0.3, 0.32, 0.45), color, body);
    out_fragColor = vec4(rgb * alpha, alpha);
}
