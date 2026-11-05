#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;
uniform float time;

void main() {
    vec2 uv = v_texcoord;
    float t = time * 2.0;
    
    // Расслаиваем RGB по синусоидам, чтобы цвета "дышали"
    float r = texture(tex, uv + vec2(sin(t + uv.y * 5.0) * 0.015, 0.0)).r;
    float g = texture(tex, uv + vec2(cos(t + uv.x * 5.0) * 0.015, 0.0)).g;
    float b = texture(tex, uv + vec2(sin(t - uv.y * 5.0) * 0.015, 0.0)).b;
    
    vec3 color = vec3(r, g, b);
    
    // Динамически меняем яркость и тон всей картинки
    color += vec3(sin(t)*0.1, cos(t*1.5)*0.1, sin(t*0.5)*0.1);
    
    fragColor = vec4(color, 1.0);
}
