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

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * res;
    float aspect = res.x / res.y;
    vec2 uvA = vec2(uv.x * aspect, uv.y);

    float dBox = sdRoundedBox(p - 0.5 * res, 0.5 * res, u_radius);
    float mask = 1.0 - smoothstep(-0.8, 0.8, dBox);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    // 1. Атмосферный градиент неба
    vec3 skyTop, skyMid, skyBot;
    if (u_mode > 1.5) {
        skyTop = vec3(0.03, 0.05, 0.11);
        skyMid = vec3(0.07, 0.11, 0.22);
        skyBot = vec3(0.13, 0.19, 0.34);
    } else if (u_mode > 0.5) {
        skyTop = vec3(0.11, 0.10, 0.24);
        skyMid = vec3(0.36, 0.20, 0.34);
        skyBot = vec3(0.76, 0.38, 0.25);
    } else {
        skyTop = vec3(0.10, 0.28, 0.56);
        skyMid = vec3(0.22, 0.44, 0.72);
        skyBot = vec3(0.42, 0.64, 0.86);
    }
    vec3 col = mix(skyTop, skyMid, smoothstep(0.0, 0.62, uv.y));
    col = mix(col, skyBot, smoothstep(0.55, 1.0, uv.y));

    if (u_is_rain > 0.5 || u_is_snow > 0.5) {
        vec3 overcast = mix(col, vec3(0.14, 0.18, 0.26), 0.45);
        col = overcast;
    }

    // 2. Звезды и Луна (ночь) / Солнце (день)
    vec2 orbPos = vec2(0.64 * aspect, 0.32);
    float dOrb = length(uvA - orbPos);

    if (u_mode > 1.5) {
        // Мягкое свечение туманности
        float milky = fbm(uvA * 2.2 + vec2(0.4, -0.2));
        col += vec3(0.06, 0.10, 0.20) * smoothstep(0.42, 0.85, milky) * (1.0 - uv.y * 0.7);

        // Спокойные звезды в двух слоях сетки (без резкого мигания!)
        for (int layer = 0; layer < 2; ++layer) {
            float sc = (layer == 0) ? 18.0 : 28.0;
            vec2 gUv = uvA * sc + float(layer) * 17.3;
            vec2 gid = floor(gUv);
            vec2 gf = fract(gUv) - 0.5;
            float h = hash21(gid);
            if (h > 0.78) {
                vec2 starOff = (vec2(hash21(gid + 1.7), hash21(gid + 5.3)) - 0.5) * 0.65;
                float ds = length(gf - starOff);
                float slowBreathing = 0.86 + 0.14 * sin(u_time * 0.65 + h * 40.0);
                float core = smoothstep(0.09, 0.0, ds);
                float halo = exp(-ds * 18.0) * 0.35;
                vec3 sCol = mix(vec3(0.82, 0.90, 1.0), vec3(1.0, 0.96, 0.88), fract(h * 13.0));
                float fadeHorizon = smoothstep(0.95, 0.25, uv.y) * smoothstep(0.06, 0.18, dOrb);
                col += sCol * (core + halo) * slowBreathing * fadeHorizon * (layer == 0 ? 0.95 : 0.60);
            }
        }

        // Объемная Луна с кратерами и гало
        float moonR = 0.125;
        float moonHalo = exp(-dOrb * 5.2) * 0.34 + exp(-dOrb * 14.0) * 0.25;
        col += vec3(0.65, 0.78, 1.0) * moonHalo;

        if (dOrb < moonR) {
            vec2 mUv = (uvA - orbPos) / moonR;
            float z = sqrt(max(0.0, 1.0 - dot(mUv, mUv)));
            vec3 norm = normalize(vec3(mUv, z));
            float diff = clamp(dot(norm, normalize(vec3(-0.35, -0.25, 0.9))), 0.15, 1.0);
            float maria = smoothstep(0.45, 0.68, fbm(mUv * 3.2 + 2.4));
            vec3 moonSurf = mix(vec3(0.96, 0.97, 1.0), vec3(0.70, 0.76, 0.86), maria * 0.55) * (0.65 + 0.38 * diff);
            float edgeAA = 1.0 - smoothstep(moonR - 0.012, moonR, dOrb);
            col = mix(col, moonSurf, edgeAA);
        }
    } else {
        // Солнце и атмосферная корона
        vec3 sunCol = (u_mode > 0.5) ? vec3(1.0, 0.68, 0.38) : vec3(1.0, 0.95, 0.82);
        float sunGlow = exp(-dOrb * 4.2) * 0.55 + exp(-dOrb * 12.0) * 0.45;
        col += sunCol * sunGlow;
        float sunDisc = 1.0 - smoothstep(0.095, 0.115, dOrb);
        col = mix(col, vec3(1.0, 0.99, 0.94), sunDisc * 0.92);
    }

    // 3. Многослойные объемные FBM-облака с подсветкой краев
    for (int cl = 0; cl < 2; ++cl) {
        float spd = (cl == 0) ? 0.035 : 0.060;
        vec2 cUv = vec2(uvA.x * 1.4 - u_time * spd + float(cl) * 4.2, (uv.y - 0.25 - float(cl) * 0.18) * 3.2);
        float n = fbm(cUv);
        float cMask = smoothstep(0.46, 0.78, n) * smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.45, uv.y);
        vec3 cBright = (u_mode > 1.5) ? vec3(0.52, 0.62, 0.80) : ((u_mode > 0.5) ? vec3(0.98, 0.72, 0.62) : vec3(0.96, 0.98, 1.0));
        vec3 cDark   = (u_mode > 1.5) ? vec3(0.14, 0.19, 0.32) : vec3(0.45, 0.54, 0.68);
        vec3 cloudCol = mix(cDark, cBright, smoothstep(0.45, 0.75, n));
        col = mix(col, cloudCol, cMask * (cl == 0 ? 0.38 : 0.26));
    }

    // 4. Осадки (дождь / снег) в шейдере
    if (u_is_rain > 0.5) {
        vec2 rUv = uvA * vec2(22.0, 5.5);
        rUv.x += rUv.y * 0.22;
        rUv.y -= u_time * 3.6;
        vec2 rid = floor(rUv);
        vec2 rf = fract(rUv) - 0.5;
        float rh = hash21(rid);
        if (rh > 0.62) {
            float drop = smoothstep(0.06, 0.0, abs(rf.x)) * smoothstep(0.45, -0.2, rf.y) * (0.5 + 0.5 * rf.y);
            col += vec3(0.65, 0.82, 1.0) * drop * 0.45;
        }
    } else if (u_is_snow > 0.5) {
        for (int sl = 0; sl < 2; ++sl) {
            float sc = (sl == 0) ? 12.0 : 18.0;
            vec2 sUv = uvA * sc;
            sUv.y -= u_time * (0.55 + float(sl) * 0.25);
            sUv.x += sin(u_time * 0.8 + sUv.y * 0.6) * 0.25;
            vec2 sid = floor(sUv);
            vec2 sf = fract(sUv) - 0.5;
            float sh = hash21(sid + float(sl) * 19.0);
            if (sh > 0.68) {
                vec2 sOff = (vec2(hash21(sid + 2.1), hash21(sid + 7.4)) - 0.5) * 0.5;
                float flake = smoothstep(0.14, 0.0, length(sf - sOff));
                col += vec3(0.92, 0.96, 1.0) * flake * (sl == 0 ? 0.65 : 0.42);
            }
        }
    }

    float finalAlpha = 0.86 * mask * qt_Opacity;
    fragColor = vec4(col * finalAlpha, finalAlpha);
}
