#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    vec2 uv = v_texcoord;
    
    // Создаем эффект марева (миража) над асфальтом
    uv.x += sin(uv.y * 30.0 + time * 5.0) * 0.015;
    uv.x += sin(uv.y * 60.0 - time * 3.0) * 0.005;
    
    // Добавляем легкое расслоение цветов, чтобы казалось, что экран плавится
    float r = texture(tex, uv + vec2(0.004, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(0.004, 0.0)).b;
    
    fragColor = vec4(r, g, b, 1.0);
}
