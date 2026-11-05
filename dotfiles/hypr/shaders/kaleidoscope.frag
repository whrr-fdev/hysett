#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    // Смещаем координаты, чтобы центр был в (0,0)
    vec2 uv = v_texcoord - 0.5; 
    
    float radius = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // Делим экран на 8 зеркальных кусков
    float segments = 8.0;
    float segmentAngle = 3.14159 * 2.0 / segments;
    
    angle = mod(angle, segmentAngle);
    angle = abs(angle - segmentAngle / 2.0);
    
    // Медленно вращаем весь этот ад
    angle += time * 0.3;
    
    // Возвращаем координаты обратно
    vec2 finalUV = radius * vec2(cos(angle), sin(angle)) + 0.5;
    
    fragColor = texture(tex, finalUV);
}
