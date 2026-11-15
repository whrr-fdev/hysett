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

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * res;
    float aspect = res.x / res.y;
    vec2 uvA = vec2(uv.x * aspect, uv.y);

    float dBox = sdRoundedBox(p - 0.5 * res, 0.5 * res, u_radius);
    float mask = 1.0 - smoothstep(-0.8, 0.8, dBox);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    // Тональный градиент в палитре текущей темы (без чужеродного ярко-синего фона)
    vec3 baseDark = mix(u_surface * 0.85, u_accent * 0.16 + u_surface * 0.84, 0.5);
    vec3 skyTop = baseDark * 0.78;
    vec3 skyMid = mix(baseDark, u_accent * 0.24 + baseDark * 0.76, (u_mode > 1.5) ? 0.35 : 0.65);
    vec3 skyBot = mix(baseDark, u_accent * 0.36 + baseDark * 0.64, 0.75);

    vec3 col = mix(skyTop, skyMid, smoothstep(0.0, 0.62, uv.y));
    col = mix(col, skyBot, smoothstep(0.50, 1.0, uv.y));

    // Мягкое атмосферное светило на фоне справа от центра
    vec2 orbPos = vec2(0.46 * aspect, 0.36);
    float dOrb = length(uvA - orbPos);
    float orbGlow = exp(-dOrb * 3.4) * 0.28 + exp(-dOrb * 9.5) * 0.18;
    col += u_accent * orbGlow;

    if (u_mode > 1.5) {
        for (int layer = 0; layer < 2; ++layer) {
            float sc = (layer == 0) ? 16.0 : 26.0;
            vec2 gUv = uvA * sc + float(layer) * 17.3;
            vec2 gid = floor(gUv);
            vec2 gf = fract(gUv) - 0.5;
            float h = hash21(gid);
            if (h > 0.80) {
                vec2 starOff = (vec2(hash21(gid + 1.7), hash21(gid + 5.3)) - 0.5) * 0.65;
                float ds = length(gf - starOff);
                float slowBreathing = 0.82 + 0.18 * sin(u_time * 0.55 + h * 40.0);
                float core = smoothstep(0.08, 0.0, ds);
                float fadeHorizon = smoothstep(0.92, 0.20, uv.y);
                col += mix(vec3(1.0), u_accent, 0.45) * core * slowBreathing * fadeHorizon * (layer == 0 ? 0.55 : 0.32);
            }
        }
    }

    // Дымка облаков FBM в цвет темы
    for (int cl = 0; cl < 2; ++cl) {
        float spd = (cl == 0) ? 0.025 : 0.045;
        vec2 cUv = vec2(uvA.x * 1.15 - u_time * spd + float(cl) * 4.2, (uv.y - 0.22 - float(cl) * 0.16) * 2.8);
        float n = fbm(cUv);
        float cMask = smoothstep(0.45, 0.80, n) * smoothstep(0.0, 0.30, uv.y) * smoothstep(1.0, 0.35, uv.y);
        vec3 cloudCol = mix(baseDark * 1.15, mix(vec3(1.0), u_accent, 0.55), smoothstep(0.45, 0.78, n) * 0.42);
        col = mix(col, cloudCol, cMask * (cl == 0 ? 0.34 : 0.22));
    }

    // Осадки (дождь / снег) в цвет акцента
    if (u_is_rain > 0.5) {
        vec2 rUv = uvA * vec2(20.0, 5.0);
        rUv.x += rUv.y * 0.22;
        rUv.y -= u_time * 3.2;
        vec2 rid = floor(rUv);
        vec2 rf = fract(rUv) - 0.5;
        float rh = hash21(rid);
        if (rh > 0.64) {
            float drop = smoothstep(0.055, 0.0, abs(rf.x)) * smoothstep(0.45, -0.2, rf.y) * (0.5 + 0.5 * rf.y);
            col += mix(vec3(1.0), u_accent, 0.5) * drop * 0.38;
        }
    } else if (u_is_snow > 0.5) {
        for (int sl = 0; sl < 2; ++sl) {
            float sc = (sl == 0) ? 11.0 : 17.0;
            vec2 sUv = uvA * sc;
            sUv.y -= u_time * (0.48 + float(sl) * 0.22);
            sUv.x += sin(u_time * 0.7 + sUv.y * 0.6) * 0.25;
            vec2 sid = floor(sUv);
            vec2 sf = fract(sUv) - 0.5;
            float sh = hash21(sid + float(sl) * 19.0);
            if (sh > 0.70) {
                vec2 sOff = (vec2(hash21(sid + 2.1), hash21(sid + 7.4)) - 0.5) * 0.5;
                float flake = smoothstep(0.13, 0.0, length(sf - sOff));
                col += mix(vec3(1.0), u_accent, 0.3) * flake * (sl == 0 ? 0.50 : 0.32);
            }
        }
    }

    float finalAlpha = 0.52 * mask * qt_Opacity;
    fragColor = vec4(col * finalAlpha, finalAlpha);
}
