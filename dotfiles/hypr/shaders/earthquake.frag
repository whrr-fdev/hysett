#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

float hash(float n) { 
    return fract(sin(n) * 43758.5453123); 
}

void main() {
    vec2 uv = v_texcoord;
    
    // Дергаем кадр 20 раз в секунду
    float t = time * 20.0;
    
    // Генерируем случайное смещение по осям X и Y
    float offsetX = (hash(floor(t)) - 0.5) * 0.04;
    float offsetY = (hash(floor(t + 123.45)) - 0.5) * 0.04;
    
    uv.x += offsetX;
    uv.y += offsetY;
    
    // Случайные сильные разрывы цветов в некоторых кадрах
    float tear = step(0.9, hash(floor(t + uv.y * 10.0)));
    float r = texture(tex, uv + vec2(0.03 * tear, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(0.03 * tear, 0.0)).b;
    
    // Случайная инверсия цвета при сильных ударах
    vec3 color = vec3(r, g, b);
    if (hash(floor(t + 77.0)) > 0.95) {
        color = 1.0 - color;
    }
    
    fragColor = vec4(color, 1.0);
}
