#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

// The tray: the front edge of the workbench, an oak ledge the waiting pieces rest on.
uniform fs_uniforms
{
    // rect: x, y, width, height in window pixels; screen: window width and height
    mediump vec4 rect;
    mediump vec4 screen;
    // the wood's colour
    mediump vec4 fill;
};

float roundedBox(vec2 p, vec2 half_size, float radius)
{
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
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
    float d = roundedBox(local, half_size, 10.0);
    float body = 1.0 - smoothstep(-1.0, 1.0, d);

    // Long grain along the ledge: warped bands and fine fibres, in units of the ledge height.
    vec2 g = local / rect.w;
    float warp = noise(vec2(g.x * 0.7, g.y * 3.0)) * 1.5;
    float bands = 0.5 + 0.5 * sin((g.y * 9.0 + warp) * 6.2832);
    float fibre = noise(vec2(g.x * 4.0, g.y * 90.0));
    vec3 wood = fill.rgb * (0.93 + 0.04 * bands + 0.04 * fibre);

    // The lit top edge and a darker front face below it, as a ledge seen from above.
    float from_top = half_size.y - local.y;
    wood *= mix(1.0, 0.9, smoothstep(0.0, rect.w, from_top));
    wood = mix(wood * 1.25 + 0.03, wood, smoothstep(2.0, 7.0, from_top));

    float shadow = (1.0 - smoothstep(0.0, 26.0, d + 4.0)) * 0.3;
    float alpha = max(body, shadow);
    vec3 rgb = mix(vec3(0.1, 0.07, 0.05), wood, body);
    out_fragColor = vec4(rgb * alpha, alpha);
}
