#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    vec2 uv = v_texcoord;
    vec2 center = vec2(0.5, 0.5);
    vec2 d = uv - center;
    float r = length(d);
    
    // Чем ближе к центру, тем сильнее закручивается изображение
    float angle = exp(-r * 4.0) * time * 3.0; 
    
    float s = sin(angle);
    float c = cos(angle);
    
    // Матрица поворота
    vec2 rotated = vec2(
        d.x * c - d.y * s,
        d.x * s + d.y * c
    );
    
    // Добавляем пульсацию, чтобы дыра "дышала"
    vec2 finalUV = center + rotated * (1.0 + exp(-r * 3.0) * sin(time * 2.0) * 0.3);
    
    if (finalUV.x < 0.0 || finalUV.y < 0.0 || finalUV.x > 1.0 || finalUV.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0); // Закрашиваем пустоты черным
    } else {
        fragColor = texture(tex, finalUV);
    }
}
