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
    // Режим антиалиасной SDF-маски скругленных углов для превью обоев (когда u_blur передан отрицательным = -radius)
    if (u_blur < -0.1) {
        float r = -u_blur;
        vec2 res = max(u_resolution, vec2(1.0));
        vec2 halfSize = 0.5 * res;
        vec2 p = qt_TexCoord0 * res - halfSize;
        float rr = min(r, min(halfSize.x, halfSize.y));
        vec2 q = abs(p) - halfSize + rr;
        float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rr;
        float mask = 1.0 - smoothstep(-0.65, 0.65, d);
        if (mask <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }
        fragColor = texture(source, qt_TexCoord0) * (mask * qt_Opacity);
        return;
    }

    float b = clamp(u_blur, 0.0, 1.0);
    if (b <= 0.005) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }

    vec2 texel = 1.0 / max(u_resolution, vec2(1.0));
    float maxRadiusPx = mix(2.0, 18.0, b);

    vec4 acc = texture(source, qt_TexCoord0) * 1.0;
    float wSum = 1.0;

    const int SAMPLES = 64;
    const float GOLDEN_ANGLE = 2.39996323;

    for (int i = 1; i <= SAMPLES; ++i) {
        float fi = float(i);
        float rNorm = sqrt(fi / float(SAMPLES));
        float theta = fi * GOLDEN_ANGLE;
        vec2 dir = vec2(cos(theta), sin(theta));
        vec2 offset = dir * (rNorm * maxRadiusPx) * texel;
        float w = exp(-2.2 * rNorm * rNorm);
        vec2 uv = clamp(qt_TexCoord0 + offset, vec2(0.001), vec2(0.999));
        acc += texture(source, uv) * w;
        wSum += w;
    }

    vec4 col = acc / wSum;
    fragColor = col * qt_Opacity;
}
