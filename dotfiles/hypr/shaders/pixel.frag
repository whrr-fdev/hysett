#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    // Сетка пикселизации (160x90 для сильного эффекта). 
    // Чем больше цифры, тем мельче пиксели.
    vec2 grid = vec2(160.0, 90.0);
    vec2 uv = floor(v_texcoord * grid) / grid;
    
    vec4 color = texture(tex, uv);
    
    // Сокращаем палитру цветов для стиля 8-bit (постеризация)
    color.rgb = floor(color.rgb * 5.0) / 5.0;
    
    fragColor = color;
}
