#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

// The tray: a shelf the waiting pieces rest on. With grain it is the workshop's oak ledge, lit
// along its top edge; without, a flat key-like slab. It stands on a solid lip or casts a soft
// shadow.
uniform fs_uniforms
{
    // rect: x, y, width, height in window pixels; screen: window width and height
    mediump vec4 rect;
    mediump vec4 screen;
    // rgb: the shelf's colour, a: the strength of its wood grain
    mediump vec4 fill;
    // rgb: the colour of a solid lip under it, a: its height in pixels (0: a soft shadow instead)
    mediump vec4 lip;
    // x: corner radius, y: corner chamfer, in pixels
    mediump vec4 corner;
};

float shape(vec2 p, vec2 half_size)
{
    vec2 q = abs(p) - half_size + corner.x;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner.x;
    vec2 a = abs(p);
    float cut = (a.x + a.y - (half_size.x + half_size.y - corner.y)) * 0.7071;
    return corner.y > 0.0 ? max(d, cut) : d;
}

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main()
{
    vec2 half_size = rect.zw * 0.5;
    vec2 pixel = var_screen * screen.xy;
    vec2 local = pixel - (rect.xy + half_size);
    float d = shape(local, half_size);
    float body = 1.0 - smoothstep(-1.0, 1.0, d);

    // Long grain along the ledge, and its lit top edge over a darker front face.
    vec2 g = local / rect.w;
    float warp = noise(vec2(g.x * 0.7, g.y * 3.0)) * 1.5;
    float bands = 0.5 + 0.5 * sin((g.y * 9.0 + warp) * 6.2832);
    float fibre = noise(vec2(g.x * 4.0, g.y * 90.0));
    vec3 face = fill.rgb * (1.0 + fill.a * (0.04 * bands + 0.04 * fibre - 0.07));
    float from_top = half_size.y - local.y;
    face *= mix(1.0, mix(1.0, 0.9, smoothstep(0.0, rect.w, from_top)), fill.a);
    face = mix(face, mix(face * 1.25 + 0.03, face, smoothstep(2.0, 7.0, from_top)), fill.a);

    vec3 rgb;
    float alpha;
    if (lip.a > 0.0)
    {
        float under = 1.0 - smoothstep(-1.0, 1.0, shape(local + vec2(0.0, lip.a), half_size));
        alpha = max(body, under);
        rgb = mix(lip.rgb, face, body);
    }
    else
    {
        float shadow = (1.0 - smoothstep(0.0, 26.0, d + 4.0)) * 0.3;
        alpha = max(body, shadow);
        rgb = mix(vec3(0.1, 0.07, 0.05), face, body);
    }
    out_fragColor = vec4(rgb * alpha, alpha);
}
