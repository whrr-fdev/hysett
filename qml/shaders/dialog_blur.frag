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
    if (u_blur <= 0.005) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }

    vec2 texel = 1.0 / max(u_resolution, vec2(1.0));
    float maxRadius = mix(1.5, 18.0, clamp(u_blur, 0.0, 1.0));

    vec4 acc = vec4(0.0);
    float weightSum = 0.0;

    // 36-точечный диск Фогеля (Золотой угол 2.39996323 рад) — идеально круглое размытие без крестов
    const int SAMPLES = 36;
    const float GOLDEN_ANGLE = 2.39996323;

    for (int i = 0; i < SAMPLES; ++i) {
        float fi = float(i);
        float rFrac = sqrt((fi + 0.5) / float(SAMPLES));
        float theta = fi * GOLDEN_ANGLE;
        vec2 offset = vec2(cos(theta), sin(theta)) * (rFrac * maxRadius) * texel;
        float w = exp(-2.2 * rFrac * rFrac);
        acc += texture(source, clamp(qt_TexCoord0 + offset, vec2(0.001), vec2(0.999))) * w;
        weightSum += w;
    }

    fragColor = (acc / max(weightSum, 0.0001)) * qt_Opacity;
}
