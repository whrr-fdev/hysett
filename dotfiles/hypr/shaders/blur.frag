#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec2 uv = v_texcoord;
    
    // Радиус размытия (сделал чуть шире для эффекта софт-фокуса)
    vec2 offset = vec2(2.5 / 1920.0, 2.5 / 1080.0);
    
    vec4 color = vec4(0.0);
    
    // Матрица Гауссова размытия (3x3)
    color += texture(tex, uv + vec2(-offset.x, -offset.y)) * 0.0625;
    color += texture(tex, uv + vec2( 0.0,      -offset.y)) * 0.125;
    color += texture(tex, uv + vec2( offset.x, -offset.y)) * 0.0625;
    color += texture(tex, uv + vec2(-offset.x,  0.0     )) * 0.125;
    color += texture(tex, uv + vec2( 0.0,       0.0     )) * 0.25;
    color += texture(tex, uv + vec2( offset.x,  0.0     )) * 0.125;
    color += texture(tex, uv + vec2(-offset.x,  offset.y)) * 0.0625;
    color += texture(tex, uv + vec2( 0.0,       offset.y)) * 0.125;
    color += texture(tex, uv + vec2( offset.x,  offset.y)) * 0.0625;
    
    fragColor = color;
}
