#version 300 es
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time; // Hyprland передает сюда время для анимаций

const vec2 curvature = vec2(3.5, 3.5);

vec2 curveRemapUV(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / curvature;
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

// Функция генерации шума
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 remappedUV = curveRemapUV(v_texcoord);

    if (remappedUV.x < 0.0 || remappedUV.y < 0.0 || remappedUV.x > 1.0 || remappedUV.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Хроматическая аберрация
    float r = texture(tex, remappedUV + vec2(0.0015, 0.0)).r;
    float g = texture(tex, remappedUV).g;
    float b = texture(tex, remappedUV - vec2(0.0015, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // Полосы развертки
    float scanline = sin(remappedUV.y * 800.0) * 0.06;
    col -= scanline;

    // Динамический шум (завязан на переменную time)
    float noise = hash(remappedUV + mod(time, 100.0)); 
    col += (noise - 0.5) * 0.08;

    // Виньетка
    vec2 vigUV = remappedUV * (1.0 - remappedUV.yx);
    float vig = vigUV.x * vigUV.y * 15.0;
    vig = pow(vig, 0.25);
    col *= vig;

    fragColor = vec4(col, 1.0);
}
