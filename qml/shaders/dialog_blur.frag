#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;
    float u_blur;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float b = clamp(u_blur, 0.0, 1.0);
    if (b <= 0.005) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }

    vec2 texel = 1.0 / max(u_resolution, vec2(1.0));
    float rad = mix(0.4, 1.35, b);

    // Изотропное круговое размытие (3 концентрических кольца с перекрытием билинейных выборок без крестообразных лучей)
    vec4 acc = texture(source, qt_TexCoord0) * 0.16;
    float wSum = 0.16;

    // Кольцо 1 (8 точек, r = 1.0 * rad)
    const vec2 ring1[8] = vec2[](
        vec2( 1.0000,  0.0000), vec2( 0.7071,  0.7071),
        vec2( 0.0000,  1.0000), vec2(-0.7071,  0.7071),
        vec2(-1.0000,  0.0000), vec2(-0.7071, -0.7071),
        vec2( 0.0000, -1.0000), vec2( 0.7071, -0.7071)
    );
    for (int i = 0; i < 8; ++i) {
        vec2 uv = clamp(qt_TexCoord0 + ring1[i] * (1.0 * rad) * texel, vec2(0.001), vec2(0.999));
        acc += texture(source, uv) * 0.11;
        wSum += 0.11;
    }

    // Кольцо 2 (12 точек, r = 2.15 * rad)
    const vec2 ring2[12] = vec2[](
        vec2( 0.9659,  0.2588), vec2( 0.7071,  0.7071), vec2( 0.2588,  0.9659),
        vec2(-0.2588,  0.9659), vec2(-0.7071,  0.7071), vec2(-0.9659,  0.2588),
        vec2(-0.9659, -0.2588), vec2(-0.7071, -0.7071), vec2(-0.2588, -0.9659),
        vec2( 0.2588, -0.9659), vec2( 0.7071, -0.7071), vec2( 0.9659, -0.2588)
    );
    for (int i = 0; i < 12; ++i) {
        vec2 uv = clamp(qt_TexCoord0 + ring2[i] * (2.15 * rad) * texel, vec2(0.001), vec2(0.999));
        acc += texture(source, uv) * 0.065;
        wSum += 0.065;
    }

    // Кольцо 3 (16 точек, r = 3.35 * rad)
    const vec2 ring3[16] = vec2[](
        vec2( 1.0000,  0.0000), vec2( 0.9239,  0.3827), vec2( 0.7071,  0.7071), vec2( 0.3827,  0.9239),
        vec2( 0.0000,  1.0000), vec2(-0.3827,  0.9239), vec2(-0.7071,  0.7071), vec2(-0.9239,  0.3827),
        vec2(-1.0000,  0.0000), vec2(-0.9239, -0.3827), vec2(-0.7071, -0.7071), vec2(-0.3827, -0.9239),
        vec2( 0.0000, -1.0000), vec2( 0.3827, -0.9239), vec2( 0.7071, -0.7071), vec2( 0.9239, -0.3827)
    );
    for (int i = 0; i < 16; ++i) {
        vec2 uv = clamp(qt_TexCoord0 + ring3[i] * (3.35 * rad) * texel, vec2(0.001), vec2(0.999));
        acc += texture(source, uv) * 0.032;
        wSum += 0.032;
    }

    fragColor = (acc / wSum) * qt_Opacity;
}
