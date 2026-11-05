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
    vec4 color = texture(tex, uv);
    
    // Переводим в монохром и красим в ярко-зеленый
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 green = vec3(0.1, 0.95, 0.2) * lum;
    
    // Мощный шум
    float noise = hash(uv + mod(time, 100.0));
    green += (noise - 0.5) * 0.4;
    
    // Жесткая виньетка по краям (линза прибора)
    vec2 vigUV = uv * (1.0 - uv.yx);
    float vig = vigUV.x * vigUV.y * 20.0;
    vig = pow(vig, 0.4);
    
    fragColor = vec4(green * vig, 1.0);
}
