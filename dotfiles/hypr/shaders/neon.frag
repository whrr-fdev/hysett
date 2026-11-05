#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    vec2 uv = v_texcoord;
    vec2 offset = vec2(0.002, 0.002);
    
    // Берем текущий пиксель и соседние
    vec4 center = texture(tex, uv);
    vec4 right = texture(tex, uv + vec2(offset.x, 0.0));
    vec4 up = texture(tex, uv + vec2(0.0, offset.y));
    
    // Вычисляем разницу (поиск границ)
    float diff = length(center - right) + length(center - up);
    
    // Генерируем плавно меняющийся неоновый цвет
    vec3 neon = vec3(sin(time)*0.5+0.5, cos(time*1.3)*0.5+0.5, sin(time*0.7)*0.5+0.5);
    
    // Закрашиваем только контуры
    fragColor = vec4(neon * diff * 5.0, 1.0);
}
