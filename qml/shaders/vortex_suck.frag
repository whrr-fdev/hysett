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
    // РЕЖИМ 0: НАСТОЯЩЕЕ ЗАСАСЫВАНИЕ В ЦЕНТР ПО СПИРАЛЯМ (ГИДРОДИНАМИЧЕСКИЙ СТОК)
    // =========================================================================
    if (u_mode < 0.5) {
        vec2 delta = (qt_TexCoord0 - center) * aspect;
        float r = length(delta);
        float maxR = length(vec2(0.5, 0.5) * aspect);
        float rnScreen = r / maxR;

        // Спиральные рукава вихря, затягивающие края к центру
        float baseAngle = atan(delta.y, delta.x);
        float spiralArmWave = sin(baseAngle * 3.0 - u_direction * (14.0 * pow(1.0 - clamp(rnScreen, 0.0, 1.0), 1.6) + t * 10.0));

        // 1. Уравнение стока (drain sink): swallowedR(t) — радиус области окна, которая УЖЕ
        // всосалась в центральную точку r=0. Пиксели реально затекают в r=0 и поглощаются центром!
        float swallowedR = pow(t, 1.06) * maxR * 1.06;
        float outerPull = max(0.06, 1.0 - 0.72 * pow(t, 1.15));
        float rPulled = (r / outerPull) * (1.0 + 0.08 * t * spiralArmWave * exp(-1.8 * rnScreen));

        float srcR = sqrt(rPulled * rPulled + swallowedR * swallowedR);

        // 2. Гиперболическое закручивание (v_theta ~ 1/r): чем ближе пиксель подтянулся к точке стока (r -> 0),
        // тем сильнее он закручивается по спирали в саму воронку
        float swirlStrength = pow(t, 0.88);
        float swirlAngle = u_direction * swirlStrength * (2.75 / (rnScreen + 0.08) - 1.35 * rnScreen);

        float targetAngle = baseAngle + swirlAngle;
        vec2 sampleDelta = vec2(cos(targetAngle), sin(targetAngle)) * srcR;
        vec2 sampleUV = center + sampleDelta / aspect;

        // Антиалиасинг внешних границ окна, затягиваемых по спирали в центр
        vec2 px = (sampleUV - center) * res;
        float dBox = sdRoundRect(px, 0.5 * res - vec2(1.0), 16.0);
        float boxMask = 1.0 - smoothstep(-1.5, 1.5, dBox);
        if (boxMask <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }

        vec4 col = texture(source, clamp(sampleUV, 0.0, 1.0));

        // Глубокое затемнение внутри самой точки всасывания в центре (r -> 0)
        float drainHole = exp(-rnScreen * rnScreen / max(0.0006, 0.032 * (1.0 - t * 0.75)));
        float throatShadow = 1.0 - 0.76 * drainHole * sin(t * 3.14159265);
        float endFade = smoothstep(1.0, 0.88, t);
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
