#version 140

in mediump vec2 var_uv;
in mediump float var_facing;

out vec4 out_fragColor;

// Digits 0-9 as a distance field, in slots 0-9 of a 16-slot strip.
uniform mediump sampler2D digits;
// Per cell, in 255ths: r the wanted count (count walls), g the cubes on the ray.
uniform mediump sampler2D counts;
// Per cell (one texel each): b wrong (cast but not as wanted), a contact.
uniform mediump sampler2D cells;
// The same texture, filtered, for soft contact shadows.
uniform mediump sampler2D soft;
// Per cell, what neighbouring cells merge by: r target, g judged coverage, b how strongly the
// selected piece casts onto it (outlined in `accent`), a the wanted light's id (255ths; 0 for
// darkness), so regions wanting different light stay apart.
uniform mediump sampler2D shape;
// Per cell, the light received and wanted: rgb a glass colour when a = 1, darkness when a = 0.
uniform mediump sampler2D received;
uniform mediump sampler2D target;

uniform fs_uniforms
{
    // xy: grid size in cells; zw: texture size in texels (the grid fills its low corner)
    mediump vec4 dims;
    // The panel's border beyond each side of the grid in cells: u0, u1, v0, v1
    mediump vec4 margins;
    // x: opacity, y: pulse (1 at the moment a wall is satisfied, fading), z: satisfied glow
    mediump vec4 opacity;
    // x: the wall's operator: 0 light, 1 count, 2 parity
    mediump vec4 operator;
    // the selected piece's colour
    mediump vec4 accent;
    mediump vec4 surface;
    mediump vec4 shadow;
    mediump vec4 line;
    mediump vec4 frame;
};

float roundedBox(vec2 p, vec2 half_size, float radius)
{
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

bool inGrid(vec2 c)
{
    return all(greaterThanEqual(c, vec2(0.0))) && all(lessThan(c, dims.xy));
}

vec4 shapeAt(vec2 c)
{
    return inGrid(c) ? texture(shape, (c + 0.5) / dims.zw) : vec4(0.0);
}

// Distance from a point to the edge of a region of cells, counting the nearer side along x and
// along y and the corner between them by how far that neighbour lies outside the region (0 to
// 1), so neighbouring cells merge seamlessly and smoothly as they come and go. `a` is the
// point's distance from the cell centre on each axis. The far sides and corners lie at least
// half a cell away, beyond every threshold this is compared with, so they are not read. Capped
// at 1.
float edgeDistance(vec2 a, vec3 out_xyc)
{
    float d = 1.0;
    d = min(d, mix(1.0, 0.5 - a.x, out_xyc.x));
    d = min(d, mix(1.0, 0.5 - a.y, out_xyc.y));
    d = min(d, mix(1.0, length(a - 0.5), out_xyc.z));
    return d;
}

// How far neighbour n lies outside each region of a cell `own`: target (split where the wanted
// light changes), coverage and focus.
vec3 outside(vec4 n, vec4 own)
{
    float differs = step(0.5 / 255.0, abs(n.a - own.a));
    return vec3(max(step(n.r, 0.5), differs), 1.0 - n.g, step(n.b, 0.5));
}

// Coverage of digit d drawn in a box of `size` cells centred at p (cell-local); aa is the
// pixel's size in cells. The field rises by 4 per slot width (8 px of spread in 64 px).
float digit(vec2 p, float d, float size, float aa)
{
    vec2 uv = p / size + 0.5;
    float in_box = step(0.0, min(uv.x, uv.y)) * step(max(uv.x, uv.y), 1.0);
    float dist = textureLod(digits, vec2((d + clamp(uv.x, 0.0, 1.0)) / 16.0, uv.y), 0.0).a;
    float w = 4.0 * aa / size;
    return in_box * smoothstep(0.5 - w, 0.5 + w, dist);
}

// Coverage of the number n (0-99) centred in a cell. `flip` mirrors it back when the wall is
// seen from behind.
float number(vec2 p, float n, float flip, float aa)
{
    p.x *= flip;
    if (n < 10.0)
    {
        return digit(p, n, 0.7, aa);
    }
    float size = 0.56;
    return max(digit(p + vec2(0.15, 0.0), floor(n / 10.0), size, aa), digit(p - vec2(0.15, 0.0), mod(n, 10.0), size, aa));
}

void main()
{
    vec2 grid = var_uv * dims.xy;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;

    // Panel body: a square slab filling the quad. Panels seen from behind fade out.
    vec2 body_lo = -margins.xz;
    vec2 body_hi = dims.xy + margins.yw;
    float body_d = roundedBox(grid - (body_lo + body_hi) * 0.5, (body_hi - body_lo) * 0.5, 0.02);
    float body_mask = (1.0 - smoothstep(-0.02, 0.02, body_d)) * smoothstep(0.0, 0.2, var_facing) * opacity.x;
    if (body_mask <= 0.0)
    {
        discard;
    }

    float aa = max(0.01, length(fwidth(grid)));
    bool inside = inGrid(cell);
    vec2 cell_uv = (cell + 0.5) / dims.zw;
    vec4 own = inside ? texture(shape, cell_uv) : vec4(0.0);
    vec4 s = inside ? texture(cells, cell_uv) : vec4(0.0);

    // Only the neighbours toward the pixel's quadrant can reach it: the side along x, the side
    // along y and the corner between them.
    vec2 toward = vec2(local.x < 0.0 ? -1.0 : 1.0, local.y < 0.0 ? -1.0 : 1.0);
    vec3 out_x = outside(shapeAt(cell + vec2(toward.x, 0.0)), own);
    vec3 out_y = outside(shapeAt(cell + vec2(0.0, toward.y)), own);
    vec3 out_c = outside(shapeAt(cell + toward), own);
    vec2 a = abs(local);
    vec4 received_t = inside ? texture(received, cell_uv) : vec4(0.0);
    vec4 want_t = inside ? texture(target, cell_uv) : vec4(0.0);
    vec3 received_color = mix(shadow.rgb, surface.rgb * received_t.rgb, received_t.a);
    vec3 want_color = mix(shadow.rgb, surface.rgb * want_t.rgb, want_t.a);
    float matches = 1.0 - smoothstep(0.04, 0.15, distance(received_color, want_color));

    // The surface, with a light grid so cells stay countable.
    vec3 color = surface.rgb;
    vec2 to_line = abs(fract(grid + 0.5) - 0.5);
    float grid_line = inside ? 1.0 - smoothstep(0.0, 1.5 * aa, min(to_line.x, to_line.y)) : 0.0;
    color = mix(color, line.rgb, 0.08 * grid_line);

    // Floor: soft contact under pieces.
    color *= 1.0 - 0.12 * texture(soft, grid / dims.zw).a;

    // Missing target cells keep a faint wash of the wanted light.
    float in_target = own.r * step(0.5, own.r);
    color = mix(color, mix(line.rgb, want_color, want_t.a), 0.07 * in_target * (1.0 - own.g));

    // Coverage: grows from each cell's centre; merged with covered neighbours.
    float g_edge = edgeDistance(a, vec3(out_x.y, out_y.y, out_c.y));
    float covered = inside ? smoothstep(-aa, aa, g_edge - 0.5 * (1.0 - own.g)) * smoothstep(0.0, 0.2, own.g) : 0.0;
    color = mix(color, received_color, covered);

    // Wrong coverage is crossed out with surface-coloured hatching.
    float stripe = abs(fract((grid.x + grid.y) * 3.0) - 0.5);
    float hatch = 1.0 - smoothstep(0.12, 0.12 + 3.0 * aa, stripe);
    color = mix(color, surface.rgb, 0.55 * hatch * covered * s.b);

    // Target contour: a line inside the region's edge, swallowed by a matching shadow,
    // turning to ink as the wall is satisfied.
    float t_edge = edgeDistance(a, vec3(out_x.x, out_y.x, out_c.x));
    float line_width = 0.045 + 0.02 * opacity.z;
    float contour = inside ? in_target * (1.0 - smoothstep(line_width, line_width + aa, t_edge)) : 0.0;
    vec3 ink = mix(line.rgb, line.rgb * 0.45, opacity.z);
    vec3 line_color = mix(ink, want_color * 0.8, want_t.a);
    color = mix(color, line_color, contour * (1.0 - 0.85 * own.g * matches * (1.0 - s.b)));

    vec2 n = inside ? floor(texture(counts, cell_uv).rg * 255.0 + 0.5) : vec2(0.0);
    // Count walls: the wanted count, in ink on the surface and in the surface's colour on a shadow.
    vec2 gx = dFdx(grid), gy = dFdy(grid);
    float flip = gx.x * gy.y - gx.y * gy.x < 0.0 ? -1.0 : 1.0;
    float digit_ink = operator.x == 1.0 && n.x > 0.0 ? number(local, n.x, flip, aa) * in_target : 0.0;
    color = mix(color, mix(line.rgb, surface.rgb, covered), digit_ink);

    // Parity walls: a ring where cubes cancel (an even number on the ray).
    float cancelled = operator.x == 2.0 && n.y > 0.0 && mod(n.y, 2.0) == 0.0 ? 1.0 : 0.0;
    float ring = 1.0 - smoothstep(0.035, 0.035 + aa, abs(length(local) - 0.26));
    color = mix(color, line.rgb, 0.6 * ring * cancelled);

    // The selected piece's cast: a tint and an outline in its colour.
    float f_own = own.b;
    float f_edge = edgeDistance(a, vec3(out_x.z, out_y.z, out_c.z));
    float f_line = f_own * (1.0 - smoothstep(0.06, 0.06 + aa, f_edge));
    color = mix(color, mix(color, accent.rgb, 0.3), f_own * step(0.5, f_own));
    color = mix(color, accent.rgb * 0.85, f_line);

    // A frame around the surface.
    // Only sides with a border carry it, so a wall's foot meets the floor's frame cleanly.
    vec4 to_edge = vec4(grid.x - body_lo.x, body_hi.x - grid.x, grid.y - body_lo.y, body_hi.y - grid.y);
    vec4 framed = mix(vec4(8.0), to_edge, step(0.1, margins));
    float frame_d = min(min(framed.x, framed.y), min(framed.z, framed.w));
    float frame_band = 1.0 - smoothstep(0.07, 0.07 + aa, frame_d);
    // Parity walls have a dashed frame.
    float along = min(framed.x, framed.y) < min(framed.z, framed.w) ? grid.y : grid.x;
    float dash = abs(fract(along * 3.0) - 0.5);
    frame_band *= operator.x == 2.0 ? smoothstep(0.2 - 3.0 * aa, 0.2 + 3.0 * aa, dash) : 1.0;
    color = mix(color, frame.rgb, frame_band);

    // A satisfied wall's light brightens for a moment.
    color = mix(color, vec3(1.0), 0.15 * opacity.y * (1.0 - frame_band));

    out_fragColor = vec4(color, body_mask);
}
