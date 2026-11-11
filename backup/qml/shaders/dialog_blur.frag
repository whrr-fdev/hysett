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
    // Шаг между соседними сэмплами <= 1.45 текселя (с учетом билинейной фильтрации GPU),
    // поэтому выборки полностью перекрываются и никогда не распадаются на крестики или сетку
    float stepScale = mix(0.35, 1.45, b);

    const float w[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

    vec4 acc = vec4(0.0);
    float weightSum = 0.0;

    for (int y = -4; y <= 4; ++y) {
        float wy = w[abs(y)];
        for (int x = -4; x <= 4; ++x) {
            float wx = w[abs(x)];
            float weight = wx * wy;
            vec2 uv = clamp(qt_TexCoord0 + vec2(float(x), float(y)) * stepScale * texel, vec2(0.001), vec2(0.999));
            acc += texture(source, uv) * weight;
            weightSum += weight;
        }
    }

    vec4 blurred = acc / max(weightSum, 0.0001);
    fragColor = blurred * qt_Opacity;
}
