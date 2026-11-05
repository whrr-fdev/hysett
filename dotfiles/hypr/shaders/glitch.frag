#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = v_texcoord;
    float t = mod(time, 100.0);
    
    // Создаем случайные горизонтальные полосы-помехи
    float glitchBand = step(0.98, sin(uv.y * 40.0 + t * 15.0)) * step(0.9, sin(uv.y * 10.0 - t * 5.0));
    
    // Сдвигаем координаты по X внутри этих полос
    vec2 offsetUV = uv;
    offsetUV.x += (hash(vec2(t, uv.y)) - 0.5) * 0.05 * glitchBand;

    // Расслаиваем цвета на краях глитча
    float r = texture(tex, offsetUV + vec2(0.005 * glitchBand, 0.0)).r;
    float g = texture(tex, offsetUV).g;
    float b = texture(tex, offsetUV - vec2(0.005 * glitchBand, 0.0)).b;
    
    fragColor = vec4(r, g, b, 1.0);
}
