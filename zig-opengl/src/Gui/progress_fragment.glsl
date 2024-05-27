#version 330 core

out vec4 FragColor;
in vec2 TexCoord;

uniform float progress = 0.0;

void main()
{
    vec2 coord = vec2(TexCoord.x, 1.0 - TexCoord.y);

    if (coord.y > 0.96 && 1 - step(progress, coord.x) > 0) {
        FragColor = vec4(1.0);
    } else {
        discard;
    }
}
