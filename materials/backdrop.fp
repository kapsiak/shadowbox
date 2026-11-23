#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

// The tray: a flat slab with chamfered corners, the shelf the waiting pieces rest on, standing
// on a solid lip.
uniform fs_uniforms
{
    // rect: x, y, width, height in window pixels; screen: window width and height
    mediump vec4 rect;
    mediump vec4 screen;
    // rgb: the slab's colour
    mediump vec4 fill;
    // rgb: the colour of the lip under it, a: its height in pixels
    mediump vec4 lip;
    // x: corner chamfer in pixels
    mediump vec4 corner;
};

float shape(vec2 p, vec2 half_size)
{
    vec2 q = abs(p) - half_size;
    float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    vec2 a = abs(p);
    float cut = (a.x + a.y - (half_size.x + half_size.y - corner.x)) * 0.7071;
    return max(box, cut);
}

void main()
{
    vec2 half_size = rect.zw * 0.5;
    vec2 local = var_screen * screen.xy - (rect.xy + half_size);
    float body = 1.0 - smoothstep(-1.0, 1.0, shape(local, half_size));
    float under = 1.0 - smoothstep(-1.0, 1.0, shape(local + vec2(0.0, lip.a), half_size));
    float alpha = max(body, under);
    vec3 rgb = mix(lip.rgb, fill.rgb, body);
    out_fragColor = vec4(rgb * alpha, alpha);
}
