#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec2 uv = v_texcoord;
    
    // Примерный размер одного пикселя (для FullHD экрана)
    // Если у тебя 2K или 4K монитор, цифры 1920.0 и 1080.0 можно увеличить
    vec2 offset = vec2(1.0 / 1920.0, 1.0 / 1080.0);

    // Берем цвет текущего пикселя и его ближайших соседей (сверху, снизу, слева, справа)
    vec4 center = texture(tex, uv);
    vec4 up    = texture(tex, uv + vec2(0.0, offset.y));
    vec4 down  = texture(tex, uv - vec2(0.0, offset.y));
    vec4 left  = texture(tex, uv - vec2(offset.x, 0.0));
    vec4 right = texture(tex, uv + vec2(offset.x, 0.0));

    // Смешиваем их: центру даем вес 4, а соседям по 1 (в сумме 8)
    // Это смягчает острые края "лесенок", не превращая текст в мыло
    fragColor = (center * 4.0 + up + down + left + right) / 8.0;
}
