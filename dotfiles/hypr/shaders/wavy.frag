#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    vec2 uv = v_texcoord;
    
    // Добавляем синусоидальные смещения, привязанные ко времени
    uv.x += sin(uv.y * 15.0 + time * 3.0) * 0.003;
    uv.y += cos(uv.x * 15.0 + time * 2.0) * 0.003;
    
    // Слегка меняем цветовой тон (добавляем синевы для эффекта воды)
    vec4 color = texture(tex, uv);
    color.b = min(color.b + 0.1, 1.0);
    
    fragColor = color;
}
