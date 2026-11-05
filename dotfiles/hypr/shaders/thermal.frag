#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    // Получаем общую яркость пикселя (от 0.0 до 1.0)
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    vec3 heat;
    // Градиент тепловизора: Синий -> Зеленый -> Желтый -> Красный
    if (lum < 0.33) {
        heat = mix(vec3(0.0, 0.0, 0.5), vec3(0.0, 1.0, 1.0), lum / 0.33);
    } else if (lum < 0.66) {
        heat = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 1.0, 0.0), (lum - 0.33) / 0.33);
    } else {
        heat = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), (lum - 0.66) / 0.34);
    }
    
    fragColor = vec4(heat, 1.0);
}
