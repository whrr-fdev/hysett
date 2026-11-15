#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;
    float u_time;
    float u_mode;    // 0 = day, 1 = twilight, 2 = night
    float u_is_rain;
    float u_is_snow;
    float u_radius;
    vec3 u_accent;
    vec3 u_surface;
};

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i + vec2(0.0, 0.0)), hash21(i + vec2(1.0, 0.0)), u.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.04 + vec2(11.7, 5.3);
        a *= 0.5;
    }
    return v;
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Настоящая 6-лучевая кристаллическая снежинка с боковыми веточками
float snowflakeCrystal(vec2 q, float radius) {
    float r = length(q);
    if (r > radius * 1.15) return 0.0;

    float sector = 1.04719755; // PI / 3 (6 лучей)
    float a = mod(atan(q.y, q.x) + sector * 0.5, sector) - sector * 0.5;
    vec2 p6 = vec2(cos(a), abs(sin(a))) * r;

    float thick = radius * 0.068;
    // Главный луч
    float mainStem = smoothstep(thick, thick * 0.15, p6.y) * smoothstep(radius, radius * 0.82, p6.x);

    // Внутренняя и внешняя пары веточек под углом 60 градусов
    vec2 brDir = vec2(0.5, 0.8660254);
    vec2 d1 = p6 - vec2(radius * 0.42, 0.0);
    float proj1 = clamp(dot(d1, brDir), 0.0, radius * 0.34);
    float br1 = smoothstep(thick * 0.85, thick * 0.12, length(d1 - brDir * proj1));

    vec2 d2 = p6 - vec2(radius * 0.68, 0.0);
    float proj2 = clamp(dot(d2, brDir), 0.0, radius * 0.22);
    float br2 = smoothstep(thick * 0.78, thick * 0.10, length(d2 - brDir * proj2));

    // Центральная шестигранная звездочка и мягкое свечение
    float hexCenter = smoothstep(radius * 0.24, radius * 0.10, p6.x + p6.y * 0.577);
    float softGlow = exp(-r / (radius * 0.42)) * 0.28;

    return clamp(max(max(mainStem, max(br1, br2)), hexCenter) + softGlow, 0.0, 1.0);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * res;
    float aspect = res.x / res.y;
    vec2 uvA = vec2(uv.x * aspect, uv.y);

    float dBox = sdRoundedBox(p - 0.5 * res, 0.5 * res, u_radius);
    float mask = 1.0 - smoothstep(-0.8, 0.8, dBox);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    // 1. Природное атмосферное небо с мягким оттенком темы (~18% примеси u_accent)
    vec3 skyTop, skyMid, skyBot;
    if (u_mode > 1.5) {
        skyTop = vec3(0.04, 0.06, 0.13);
        skyMid = vec3(0.08, 0.12, 0.23);
        skyBot = vec3(0.14, 0.20, 0.34);
    } else if (u_mode > 0.5) {
        skyTop = vec3(0.10, 0.11, 0.23);
        skyMid = vec3(0.28, 0.18, 0.31);
        skyBot = vec3(0.56, 0.31, 0.26);
    } else {
        skyTop = vec3(0.09, 0.22, 0.44);
        skyMid = vec3(0.17, 0.35, 0.58);
        skyBot = vec3(0.30, 0.50, 0.72);
    }

    // Деликатный оттенок темы поверх естественного неба
    skyTop = mix(skyTop, u_surface * 0.7 + u_accent * 0.18, 0.24);
    skyMid = mix(skyMid, u_surface * 0.5 + u_accent * 0.28, 0.20);
    skyBot = mix(skyBot, u_accent * 0.38 + skyBot * 0.62, 0.18);

    vec3 col = mix(skyTop, skyMid, smoothstep(0.0, 0.60, uv.y));
    col = mix(col, skyBot, smoothstep(0.52, 1.0, uv.y));

    if (u_is_rain > 0.5 || u_is_snow > 0.5) {
        vec3 stormTone = mix(vec3(0.11, 0.15, 0.22), u_accent * 0.22 + vec3(0.10, 0.13, 0.18), 0.22);
        col = mix(col, stormTone, 0.42);
    }

    // 2. Светило (3D-Луна со звездами ночью / Солнце с короной днем)
    vec2 orbPos = vec2(0.52 * aspect, 0.32);
    float dOrb = length(uvA - orbPos);
    float precipDim = (u_is_rain > 0.5 || u_is_snow > 0.5) ? 0.55 : 1.0;

    if (u_mode > 1.5) {
        for (int layer = 0; layer < 2; ++layer) {
            float sc = (layer == 0) ? 16.0 : 26.0;
            vec2 gUv = uvA * sc + float(layer) * 17.3;
            vec2 gid = floor(gUv);
            vec2 gf = fract(gUv) - 0.5;
            float h = hash21(gid);
            if (h > 0.79) {
                vec2 starOff = (vec2(hash21(gid + 1.7), hash21(gid + 5.3)) - 0.5) * 0.65;
                float ds = length(gf - starOff);
                float slowBreathing = 0.84 + 0.16 * sin(u_time * 0.60 + h * 40.0);
                float core = smoothstep(0.08, 0.0, ds);
                float halo = exp(-ds * 18.0) * 0.30;
                vec3 sCol = mix(vec3(0.84, 0.91, 1.0), u_accent, 0.18);
                float fadeHorizon = smoothstep(0.92, 0.20, uv.y) * smoothstep(0.08, 0.20, dOrb);
                col += sCol * (core + halo) * slowBreathing * fadeHorizon * precipDim * (layer == 0 ? 0.85 : 0.50);
            }
        }

        float moonR = 0.115;
        vec3 moonTint = mix(vec3(0.72, 0.84, 1.0), u_accent, 0.16);
        float moonHalo = exp(-dOrb * 5.0) * 0.28 + exp(-dOrb * 14.0) * 0.20;
        col += moonTint * moonHalo * precipDim;

        if (dOrb < moonR) {
            vec2 mUv = (uvA - orbPos) / moonR;
            float z = sqrt(max(0.0, 1.0 - dot(mUv, mUv)));
            vec3 norm = normalize(vec3(mUv, z));
            float diff = clamp(dot(norm, normalize(vec3(-0.35, -0.25, 0.9))), 0.18, 1.0);
            float maria = smoothstep(0.45, 0.68, fbm(mUv * 3.2 + 2.4));
            vec3 moonSurf = mix(vec3(0.95, 0.97, 1.0), vec3(0.68, 0.75, 0.86), maria * 0.52) * (0.68 + 0.34 * diff);
            float edgeAA = 1.0 - smoothstep(moonR - 0.012, moonR, dOrb);
            col = mix(col, moonSurf, edgeAA * precipDim);
        }
    } else {
        vec3 sunCol = (u_mode > 0.5) ? vec3(1.0, 0.66, 0.36) : vec3(1.0, 0.93, 0.76);
        sunCol = mix(sunCol, u_accent, 0.14);
        float sunGlow = exp(-dOrb * 4.0) * 0.42 + exp(-dOrb * 11.0) * 0.34;
        col += sunCol * sunGlow * precipDim;
        float sunDisc = 1.0 - smoothstep(0.085, 0.105, dOrb);
        col = mix(col, vec3(1.0, 0.98, 0.92), sunDisc * 0.78 * precipDim);
    }

    // 3. Объемные FBM-облака
    for (int cl = 0; cl < 2; ++cl) {
        float spd = (cl == 0) ? 0.028 : 0.048;
        vec2 cUv = vec2(uvA.x * 1.25 - u_time * spd + float(cl) * 4.2, (uv.y - 0.24 - float(cl) * 0.17) * 3.0);
        float n = fbm(cUv);
        float cMask = smoothstep(0.45, 0.78, n) * smoothstep(0.0, 0.32, uv.y) * smoothstep(1.0, 0.40, uv.y);
        vec3 cBright = (u_mode > 1.5) ? vec3(0.50, 0.60, 0.76) : ((u_mode > 0.5) ? vec3(0.94, 0.70, 0.60) : vec3(0.92, 0.96, 1.0));
        vec3 cDark   = (u_mode > 1.5) ? vec3(0.14, 0.18, 0.30) : vec3(0.38, 0.47, 0.60);
        vec3 cloudCol = mix(cDark, mix(cBright, u_accent, 0.15), smoothstep(0.45, 0.76, n));
        col = mix(col, cloudCol, cMask * (cl == 0 ? 0.36 : 0.24));
    }

    // 4. Реалистичный многослойный дождь (3 слоя глубины с наклоном и заостренным хвостом капли)
    if (u_is_rain > 0.5) {
        float angle = 0.20; // наклон капель по ветру
        mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
        vec2 rotUv = rot * uvA;
        vec3 rainTint = mix(vec3(0.74, 0.88, 1.0), u_accent, 0.20);

        for (int rl = 0; rl < 3; ++rl) {
            float fl = float(rl);
            vec2 gridScale = vec2(26.0 + fl * 12.0, 3.2 + fl * 1.1);
            float fallSpeed = 10.5 + fl * 4.2;

            vec2 rUv = rotUv * gridScale;
            rUv.y -= u_time * fallSpeed;
            vec2 rid = floor(rUv);
            vec2 rf = fract(rUv) - 0.5;

            float h = hash21(rid + fl * 31.7);
            if (h > 0.52) {
                float xJitter = (hash21(rid + 7.3) - 0.5) * 0.55;
                float dx = abs(rf.x - xJitter);
                // Заостренная форма падающей капли: яркая головка снизу и плавный хвост сверху
                float yNorm = clamp(rf.y + 0.5, 0.0, 1.0);
                float streakW = mix(0.018, 0.048, yNorm);
                float streak = smoothstep(streakW, 0.0, dx) * smoothstep(0.0, 0.25, yNorm) * smoothstep(1.0, 0.82, yNorm) * pow(yNorm, 0.85);
                float layerAlpha = (rl == 0) ? 0.62 : ((rl == 1) ? 0.42 : 0.26);
                col += rainTint * streak * layerAlpha;
            }
        }
        // Туманная водяная дымка у нижней кромки карточки во время дождя
        col += rainTint * smoothstep(0.68, 1.0, uv.y) * 0.09;
    }

    // 5. Настоящие вращающиеся шестиконечные снежинки в 3 слоях глубины
    if (u_is_snow > 0.5) {
        vec3 snowTint = mix(vec3(0.94, 0.98, 1.0), u_accent, 0.14);
        for (int sl = 0; sl < 3; ++sl) {
            float fl = float(sl);
            // Слой 0: крупные детальные снежинки, Слой 1: средние, Слой 2: мелкие фоновые
            float sc = (sl == 0) ? 5.8 : ((sl == 1) ? 9.5 : 15.0);
            float fallSpd = (sl == 0) ? 0.85 : ((sl == 1) ? 0.62 : 0.42);

            vec2 sUv = uvA * sc + vec2(fl * 11.3, fl * 7.1);
            sUv.y -= u_time * fallSpd;
            sUv.x += sin(u_time * (0.65 + fl * 0.2) + sUv.y * 0.75) * 0.22;

            vec2 sid = floor(sUv);
            vec2 sf = fract(sUv) - 0.5;
            float sh = hash21(sid + fl * 23.4);

            if (sh > 0.54) {
                vec2 sOff = (vec2(hash21(sid + 2.1), hash21(sid + 7.4)) - 0.5) * 0.36;
                vec2 q = sf - sOff;

                // Индивидуальное плавное вращение каждой снежинки
                float spin = u_time * (0.7 + fract(sh * 7.3) * 0.9) * ((fract(sh * 13.7) > 0.5) ? 1.0 : -1.0) + sh * 6.28318;
                float cs = cos(spin), sn = sin(spin);
                q = mat2(cs, -sn, sn, cs) * q;

                float flakeRadius = (sl == 0) ? 0.28 : ((sl == 1) ? 0.24 : 0.18);
                float flake = (sl < 2)
                              ? snowflakeCrystal(q, flakeRadius)
                              : smoothstep(flakeRadius, 0.0, length(q));

                float layerOp = (sl == 0) ? 0.82 : ((sl == 1) ? 0.56 : 0.34);
                col += snowTint * flake * layerOp;
            }
        }
    }

    float finalAlpha = 0.72 * mask * qt_Opacity;
    fragColor = vec4(col * finalAlpha, finalAlpha);
}
