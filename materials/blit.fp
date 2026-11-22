#version 140

in mediump vec2 var_screen;

out vec4 out_fragColor;

uniform mediump sampler2D frame;

void main()
{
    out_fragColor = texture(frame, var_screen);
}
