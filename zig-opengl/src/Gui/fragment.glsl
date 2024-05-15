#version 330 core

out vec4 FragColor;
in vec2 TexCoord;

uniform sampler2D luma;
uniform sampler2D cb;
uniform sampler2D cr;

void main()
{
    vec2 coord = vec2(TexCoord.x, 1.0 - TexCoord.y);

    float y = texture(luma, coord).r;
    float u = texture(cb, coord).r - 0.5;
    float v = texture(cr, coord).r - 0.5;

    float r = y + 1.28033 * v;
    float g = y - 0.21482 * u - 0.38059 * v;
    float b = y + 2.12789 * u;

    FragColor = vec4(r, g, b, 1.0);
}
