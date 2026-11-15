#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;
    float u_progress;
    float u_direction;
    float u_mode;
};

layout(binding = 1) uniform sampler2D source;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float t = clamp(u_progress, 0.0, 1.0);
    if (t <= 0.001) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }
    if (t >= 0.995) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 res = max(u_resolution, vec2(1.0));
    vec2 aspect = vec2(res.x / res.y, 1.0);
    vec2 center = vec2(0.5, 0.5);

    // =========================================================================
    // РЕЖИМ 0: ПОЛНОЕ СПИРАЛЬНОЕ СКРУЧИВАНИЕ В ВОРОНКУ (УГЛЫ + ОКНО ЦЕЛИКОМ)
    // =========================================================================
    if (u_mode < 0.5) {
        vec2 delta = (qt_TexCoord0 - center) * aspect;
        float r = length(delta);
        float maxR = length(vec2(0.5, 0.5) * aspect);

        // Сжатие радиуса к центру так, чтобы при закручивании углы прямоугольного окна
        // полностью помещались внутри холста и скручивались вместе с содержимым
        float collapse = max(0.0015, pow(1.0 - t, 1.65) / (1.0 + 0.90 * t));
        float rScaled = r / collapse;
        float rn = rScaled / maxR;

        // Плавное воронкообразное натяжение от центра к краям без отрыва углов от контента
        float funnelPull = 1.0 + 0.72 * pow(t, 0.85) * exp(-2.1 * rn);
        float srcR = rScaled * funnelPull;

        // Полное скручивание всего окна: и внешние углы, и центр закручиваются в единую спираль,
        // при этом к центру горловины спираль закручена сильнее
        float outerTwist = 4.8 * pow(t, 1.15);
        float innerTwist = 9.2 * pow(t, 1.05) * exp(-2.05 * rn);
        float swirlAngle = u_direction * (outerTwist + innerTwist);

        vec2 dir = (r > 1e-5) ? (delta / r) : vec2(0.0);
        float s = sin(swirlAngle);
        float c = cos(swirlAngle);
        vec2 rotDir = vec2(dir.x * c - dir.y * s, dir.x * s + dir.y * c);
        vec2 sampleUV = center + (rotDir * srcR) / aspect;

        // Антиалиасинг внешних скруглённых границ скручиваемого окна
        vec2 px = (sampleUV - center) * res;
        float dBox = sdRoundRect(px, 0.5 * res - vec2(1.0), 16.0);
        float boxMask = 1.0 - smoothstep(-1.5, 1.5, dBox);
        if (boxMask <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }

        vec4 col = texture(source, clamp(sampleUV, 0.0, 1.0));

        // 3D-затемнение в глубине горловины в центре
        float vortexCore = exp(-3.2 * rn);
        float throatShadow = 1.0 - 0.52 * vortexCore * sin(t * 3.14159265);
        float endFade = smoothstep(1.0, 0.85, t);
        float outA = col.a * boxMask * endFade * qt_Opacity;
        fragColor = vec4(col.rgb * throatShadow * boxMask * endFade * qt_Opacity, outA);
        return;
    }

    // =========================================================================
    // РЕЖИМ 1: СФЕРИЧЕСКИЙ ПОРТАЛ
    // =========================================================================
    if (u_mode < 1.5) {
        vec2 delta = (qt_TexCoord0 - center) * aspect;
        float r = length(delta);
        float maxR = length(vec2(0.5, 0.5) * aspect) * 1.05;

        float apertureR = max(0.005, (1.0 - pow(t, 1.25)) * maxR);
        float circleMask = 1.0 - smoothstep(apertureR - 0.035, apertureR + 0.01, r);
        if (circleMask <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }

        float normR = clamp(r / apertureR, 0.0, 1.0);
        float sphereLens = mix(1.0, 0.55 + 0.65 * normR * normR, t * 0.85);
        float wave = sin(normR * 18.0 - t * 14.0) * t * 0.035;

        vec2 warpedDelta = delta * (sphereLens + wave) / max(0.08, 1.0 - t * 0.65);
        vec2 uvBase = center + warpedDelta / aspect;

        vec2 edge = smoothstep(vec2(0.0), vec2(0.02), uvBase) * smoothstep(vec2(0.0), vec2(0.02), vec2(1.0) - uvBase);
        float bounds = edge.x * edge.y * circleMask;
        if (bounds <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }

        vec2 radialShift = (delta / aspect) * (pow(normR, 2.0) * t * 0.055);
        vec4 cR = texture(source, clamp(uvBase - radialShift, 0.0, 1.0));
        vec4 cG = texture(source, clamp(uvBase, 0.0, 1.0));
        vec4 cB = texture(source, clamp(uvBase + radialShift, 0.0, 1.0));

        float endFade = smoothstep(1.0, 0.88, t);
        vec3 rgb = vec3(cR.r, cG.g, cB.b) * bounds;
        float alpha = clamp(cG.a * bounds, 0.0, 1.0) * endFade * qt_Opacity;
        fragColor = vec4(rgb * endFade * qt_Opacity, alpha);
        return;
    }

    // =========================================================================
    // РЕЖИМ 2: ТЕЛЕПОРТ
    // =========================================================================
    float numSlices = 26.0;
    float sliceIdx = floor(qt_TexCoord0.y * numSlices);
    float rnd = hash11(sliceIdx + 17.0);
    float dirSign = (mod(sliceIdx, 2.0) < 0.5) ? 1.0 : -1.0;

    float localT = clamp((t - rnd * 0.25) / 0.75, 0.0, 1.0);
    float slideShift = pow(localT, 1.7) * 0.55 * dirSign * u_direction;

    vec2 uv = qt_TexCoord0;
    uv.x += slideShift;

    float bounds = step(0.0, uv.x) * step(uv.x, 1.0);
    if (bounds <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float chroma = pow(localT, 1.3) * 0.038 * dirSign;
    vec4 colR = texture(source, clamp(uv + vec2(chroma, 0.0), 0.0, 1.0));
    vec4 colG = texture(source, clamp(uv, 0.0, 1.0));
    vec4 colB = texture(source, clamp(uv - vec2(chroma, 0.0), 0.0, 1.0));

    vec3 rgb = vec3(colR.r, colG.g, colB.b);
    float flash = pow(sin(localT * 3.14159), 2.0) * 0.38;
    float fade = 1.0 - pow(localT, 1.8);

    vec3 outCol = (rgb + vec3(0.9, 0.96, 1.0) * flash) * fade;
    float outAlpha = clamp(colG.a + flash * 0.5, 0.0, 1.0) * fade * qt_Opacity;
    fragColor = vec4(outCol * qt_Opacity, outAlpha);
}
