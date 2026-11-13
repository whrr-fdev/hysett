#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;
    vec4 u_bar_rect;
    vec4 u_drawer_rect;
    vec4 u_notif_rect;
    vec4 u_bg_color;
    vec4 u_notif_color;
    vec4 u_outline_color;
    vec3 u_glow_color;
    vec3 u_cursor_color;
    float u_bar_alpha;
    float u_radius;
    float u_fillet;
    float u_refraction;
    float u_time;
    float u_glow_intensity;
    float u_glow_spread;
    float u_glow_mode;
    float u_glow_dir;
    float u_cursor_strength;
    vec2 u_mouse;
    vec2 u_trail1;
    vec2 u_trail2;
    vec4 u_music_wave;
};

float sdRoundedBox(vec2 p, vec2 b, float r) {
    float rr = min(r, min(b.x, b.y));
    vec2 q = abs(p) - b + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rr;
}

float smin(float a, float b, float k) {
    if (k <= 0.05) return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec3 paletteColor(float mode, float phase, float depthFactor) {
    if (mode < 0.5) return mix(vec3(1.0), vec3(0.82, 0.88, 0.98), depthFactor * 0.45);
    if (mode < 1.5) return mix(mix(vec3(0.55, 0.88, 1.0), vec3(0.9, 0.97, 1.0), 0.5 + 0.5 * sin(phase)), vec3(0.32, 0.58, 0.98), depthFactor * 0.6);
    if (mode < 2.5) return vec3(0.65, 0.68, 0.78) + vec3(0.35, 0.32, 0.28) * cos(6.28318 * (vec3(phase * 0.16 + depthFactor * 0.2) + vec3(0.0, 0.33, 0.67)));
    if (mode < 3.5) return mix(vec3(1.0, 0.76, 0.45), vec3(1.0, 0.45, 0.62), 0.5 + 0.5 * sin(phase + depthFactor * 1.2));
    return mix(u_glow_color, u_glow_color * 0.75 + vec3(0.25), 0.3 * sin(phase));
}

// Вязкая ферромагнитная жидкость: плавные скорости и вытянутые жидкие пики с вогнутыми менисками
float ferroSpikeAmp(float k, float t) {
    float h1 = fract(sin(k * 127.1 + 1.9) * 43758.5453);
    float h2 = fract(sin(k * 269.5 + 7.3) * 18342.2317);
    float h3 = fract(sin(k * 419.2 + 3.1) * 91523.1143);
    // Медленное, вязкое дыхание каждого пика (в 7 раз медленнее прежнего)
    float w1 = 0.5 + 0.5 * sin(t * (0.55 + h1 * 0.65) + h2 * 6.2831853);
    float w2 = 0.5 + 0.5 * sin(t * (1.10 + h2 * 0.85) - h3 * 6.2831853);
    float slowWave = 0.5 + 0.5 * sin(k * 0.42 - t * 0.75 + sin(k * 0.18 + t * 0.45));
    float raw = (w1 * 0.52 + w2 * 0.48) * (0.45 + 0.55 * slowWave);
    return pow(clamp(raw, 0.0, 1.0), 1.45);
}

// Профиль одного жидкого магнитного шипа: узкий вытянутый пик с каплевидным кончиком и широким вогнутым мениском у основания
float ferroToothProfile(float distFromCenter) {
    float d = clamp(distFromCenter, 0.0, 1.0);
    // Вблизи d=0 скругленный кончик капли, дальше резкий вогнутый спад (как натянутая магнитом жидкость)
    float core = 1.0 / (1.0 + d * d * 9.5);
    float baseFade = (1.0 - d * d);
    return clamp(core * baseFade * 1.08, 0.0, 1.0);
}

float sceneSdf(vec2 p, out float outNotifBlend) {
    outNotifBlend = 0.0;
    float waveStretch = 0.0;
    if (u_music_wave.z > 0.05 && u_bar_rect.z > u_bar_rect.w * 1.5) {
        float edgePad = max(14.0, u_radius * 1.35);
        float edgeFade = smoothstep(u_bar_rect.x + edgePad * 0.4, u_bar_rect.x + edgePad * 1.5, p.x) *
                         smoothstep(u_bar_rect.x + u_bar_rect.z - edgePad * 0.4, u_bar_rect.x + u_bar_rect.z - edgePad * 1.5, p.x);

        // Если открыто выпадающее окошко, плавно гасим зубцы только внутри ширины стыка самого окошка, оставляя их на всей остальной панели
        float drawerOverlapMask = 1.0;
        if (u_drawer_rect.w > 1.0 && u_drawer_rect.z > 1.0) {
            float inDrwX = smoothstep(u_drawer_rect.x - 10.0, u_drawer_rect.x + 6.0, p.x) *
                           smoothstep(u_drawer_rect.x + u_drawer_rect.z + 10.0, u_drawer_rect.x + u_drawer_rect.z - 6.0, p.x);
            drawerOverlapMask = 1.0 - inDrwX;
        }
        edgeFade *= drawerOverlapMask;

        if (edgeFade > 0.001) {
            float t = u_music_wave.w;
            float barBottomY = u_bar_rect.y + u_bar_rect.w;

            // Реакция на мышь (курсор работает как магнит, стягивающий и вытягивающий пики ферромагнитной жидкости)
            float magField = 0.0;
            float magPullX = 0.0;
            if (u_mouse.x > 0.0 && u_mouse.y > -20.0) {
                float dxM = p.x - u_mouse.x;
                float dyM = max(0.0, abs(u_mouse.y - barBottomY));
                float vertReach = exp(-(dyM * dyM) / (150.0 * 150.0));
                magField = exp(-(dxM * dxM) / (95.0 * 95.0)) * vertReach;
                // Стягивание гребней жидкости к полюсу магнита (курсору)
                magPullX = clamp(dxM / 85.0, -1.0, 1.0) * magField * 9.5;
            }

            // Плавный вязкий дрейф жидкости + магнитное смещение к мыши
            float liquidDrift = 4.5 * sin((p.x - u_bar_rect.x) * 0.018 + t * 0.45);
            float xCoord = (p.x - u_bar_rect.x) - magPullX + liquidDrift;

            // Слой 1: основные ферромагнитные шипы
            float step1 = 19.0;
            float relX1 = xCoord / step1;
            float k1 = floor(relX1);
            float f1 = fract(relX1);

            float hShift = (fract(sin(k1 * 91.7) * 19452.1) - 0.5) * 0.22 * sin(t * 0.6 + k1);
            float dCenter1 = abs(f1 - (0.5 + hShift)) * 2.0;

            float ampPrev = ferroSpikeAmp(k1 - 1.0, t);
            float ampCur  = ferroSpikeAmp(k1, t);
            float ampNext = ferroSpikeAmp(k1 + 1.0, t);

            // Усиливаем высоту шипов рядом с магнитом-курсором
            float localMagBoost = 1.0 + magField * 0.85;
            float spikeMain = ampCur * ferroToothProfile(dCenter1);

            // Вогнутый жидкостный мениск между соседними пиками
            float neighborSpike = (f1 < 0.5)
                                  ? (ampPrev * ferroToothProfile((0.5 + f1) * 1.4))
                                  : (ampNext * ferroToothProfile((1.5 - f1) * 1.4));

            // Гладкое жидкостное слияние соседних пиков (мениск поверхностного натяжения)
            float hDiff = spikeMain - neighborSpike;
            float kMeniscus = 0.14;
            float hm = clamp(0.5 + 0.5 * hDiff / kMeniscus, 0.0, 1.0);
            float liquidProfile = mix(neighborSpike, spikeMain, hm) + kMeniscus * hm * (1.0 - hm);

            // Базовая тонкая пленка магнитной жидкости, поднимающаяся под курсором мыши
            float baseFilm = 0.08 + magField * 0.28;
            waveStretch = u_music_wave.z * edgeFade * clamp((baseFilm + liquidProfile * 0.92) * localMagBoost, 0.0, 1.65);
        }
    }
    vec2 bSize = vec2(u_bar_rect.z, u_bar_rect.w + waveStretch);
    vec2 bHalf = 0.5 * bSize;
    vec2 bCenter = vec2(u_bar_rect.x + bHalf.x, u_bar_rect.y + bHalf.y);
    float dBar = sdRoundedBox(p - bCenter, bHalf, u_radius);
    float d = dBar;

    if (u_drawer_rect.w > 0.5 && u_drawer_rect.z > 0.5) {
        vec2 dHalf = 0.5 * u_drawer_rect.zw;
        vec2 dCenter = u_drawer_rect.xy + dHalf;
        float rDrw = u_radius * 1.35;
        float dDrw = sdRoundedBox(p - dCenter, dHalf, rDrw);

        bool isVertBar = (u_bar_rect.w > u_bar_rect.z * 1.5);
        if (!isVertBar) {
            bool isTopBar = (u_drawer_rect.y >= u_bar_rect.y);
            float nx1 = max(u_bar_rect.x, u_drawer_rect.x);
            float nx2 = min(u_bar_rect.x + u_bar_rect.z, u_drawer_rect.x + u_drawer_rect.z);
            float ny1 = isTopBar ? (u_bar_rect.y + min(u_radius, u_bar_rect.w * 0.45)) : max(u_drawer_rect.y, u_drawer_rect.y + u_drawer_rect.w - rDrw - 4.0);
            float ny2 = isTopBar ? min(u_drawer_rect.y + u_drawer_rect.w, u_drawer_rect.y + rDrw + 4.0) : (u_bar_rect.y + u_bar_rect.w - min(u_radius, u_bar_rect.w * 0.45));
            if (nx2 > nx1 && ny2 > ny1) {
                vec2 nHalf = 0.5 * vec2(nx2 - nx1, ny2 - ny1);
                vec2 nCenter = vec2(nx1, ny1) + nHalf;
                dDrw = min(dDrw, sdRoundedBox(p - nCenter, nHalf, 0.0));
            }
            float leftStep  = abs(u_bar_rect.x - u_drawer_rect.x);
            float rightStep = abs((u_bar_rect.x + u_bar_rect.z) - (u_drawer_rect.x + u_drawer_rect.z));
            float sideStep  = (p.x < u_drawer_rect.x + 0.5 * u_drawer_rect.z) ? leftStep : rightStep;
            float innerEdgeMask = isTopBar
                                  ? smoothstep(u_bar_rect.y + 4.0, u_bar_rect.y + u_bar_rect.w - 1.0, p.y)
                                  : smoothstep(u_bar_rect.y + u_bar_rect.w - 4.0, u_bar_rect.y + 1.0, p.y);
            float k = u_fillet * innerEdgeMask * clamp((sideStep - 1.0) / 22.0, 0.0, 1.0) * clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 42.0, 0.0, 1.0);
            d = smin(d, dDrw, k);
        } else {
            bool isLeftBar = (u_drawer_rect.x >= u_bar_rect.x);
            float ny1 = max(u_bar_rect.y, u_drawer_rect.y);
            float ny2 = min(u_bar_rect.y + u_bar_rect.w, u_drawer_rect.y + u_drawer_rect.w);
            float nx1 = isLeftBar ? (u_bar_rect.x + min(u_radius, u_bar_rect.z * 0.45)) : max(u_drawer_rect.x, u_drawer_rect.x + u_drawer_rect.z - rDrw - 4.0);
            float nx2 = isLeftBar ? min(u_drawer_rect.x + u_drawer_rect.z, u_drawer_rect.x + rDrw + 4.0) : (u_bar_rect.x + u_bar_rect.z - min(u_radius, u_bar_rect.z * 0.45));
            if (nx2 > nx1 && ny2 > ny1) {
                vec2 nHalf = 0.5 * vec2(nx2 - nx1, ny2 - ny1);
                vec2 nCenter = vec2(nx1, ny1) + nHalf;
                dDrw = min(dDrw, sdRoundedBox(p - nCenter, nHalf, 0.0));
            }
            float topStep = abs(u_bar_rect.y - u_drawer_rect.y);
            float botStep = abs((u_bar_rect.y + u_bar_rect.w) - (u_drawer_rect.y + u_drawer_rect.w));
            float sideStep = (p.y < u_drawer_rect.y + 0.5 * u_drawer_rect.w) ? topStep : botStep;
            float innerEdgeMask = isLeftBar
                                  ? smoothstep(u_bar_rect.x + 4.0, u_bar_rect.x + u_bar_rect.z - 1.0, p.x)
                                  : smoothstep(u_bar_rect.x + u_bar_rect.z - 4.0, u_bar_rect.x + 1.0, p.x);
            float k = u_fillet * innerEdgeMask * clamp((sideStep - 1.0) / 22.0, 0.0, 1.0) * clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 42.0, 0.0, 1.0);
            d = smin(d, dDrw, k);
        }
    }

    if (u_notif_rect.w > 0.5 && u_notif_rect.z > 0.5) {
        vec2 nHalf = 0.5 * u_notif_rect.zw;
        vec2 nCenter = u_notif_rect.xy + nHalf;
        float dNotif = sdRoundedBox(p - nCenter, nHalf, u_radius * 1.25);
        bool barTouchesNotif = (u_notif_rect.y >= u_bar_rect.y + u_bar_rect.w - 2.0 || u_notif_rect.y + u_notif_rect.w <= u_bar_rect.y + 2.0) &&
                               (u_notif_rect.x < u_bar_rect.x + u_bar_rect.z - 2.0) && (u_notif_rect.x + u_notif_rect.z > u_bar_rect.x + 2.0);
        float neckZone = barTouchesNotif ? (1.0 - smoothstep(u_bar_rect.y + u_bar_rect.w, u_bar_rect.y + u_bar_rect.w + u_fillet * 1.5, p.y)) : 0.0;
        float nk = u_fillet * neckZone * smoothstep(u_bar_rect.y + 4.0, u_bar_rect.y + u_bar_rect.w, p.y) * clamp(u_notif_rect.w / 32.0, 0.0, 1.0);
        outNotifBlend = smoothstep(4.0, -4.0, dNotif - dBar);
        d = smin(d, dNotif, nk);
    }

    return d;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;

    float notifBlend = 0.0;
    float d = sceneSdf(p, notifBlend);
    float mask = 1.0 - smoothstep(-0.6, 0.6, d);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    float distInward = max(0.0, -d);
    float outlineMask = exp(-distInward * 1.65);

    float drwMix = clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 160.0, 0.0, 1.0);
    vec4 shellFill = vec4(u_bg_color.rgb, mix(u_bar_alpha, u_bg_color.a, drwMix));
    vec4 activeFill = mix(shellFill, u_notif_color, notifBlend);

    vec3 baseRgb = mix(activeFill.rgb, u_outline_color.rgb, outlineMask * u_outline_color.a);
    float baseAlpha = clamp(activeFill.a + outlineMask * 0.10, 0.05, 0.98);

    if (u_drawer_rect.w > 1.0 && u_drawer_rect.z > 1.0 && u_cursor_strength > 0.01 && u_mouse.x > -50.0) {
        float dm0 = length(p - u_mouse);
        float dm1 = length(p - u_trail1);
        float dm2 = length(p - u_trail2);
        float cGlow = (exp(-(dm0 * dm0) / 5200.0) * 0.25
                     + exp(-(dm1 * dm1) / 3800.0) * 0.11
                     + exp(-(dm2 * dm2) / 2600.0) * 0.06) * clamp(u_cursor_strength, 0.0, 1.0);
        baseRgb = clamp(baseRgb + u_cursor_color * cGlow, 0.0, 1.0);
    }

    float openFactor = clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 40.0, 0.0, 1.0);
    float effGlow = u_glow_intensity * openFactor;
    if (effGlow > 0.01) {
        float maxEdgePx = mix(6.0, 38.0, clamp(u_glow_spread, 0.05, 1.0));
        if (distInward < maxEdgePx * 2.2) {
            vec2 refCenter = u_drawer_rect.xy + 0.5 * u_drawer_rect.zw;
            vec2 normC = (p - refCenter) / max(vec2(1.0), 0.5 * res);
            float rawAngle = atan(normC.y, normC.x);
            float angle = (u_glow_dir > 1.5) ? abs(rawAngle) : rawAngle;
            float dirSign = (u_glow_dir > 0.5 && u_glow_dir < 1.5) ? 1.0 : -1.0;
            float phase = angle * 2.0 + dirSign * u_time * 1.5;
            float waveEnergy = pow((0.5 + 0.5 * sin(phase)) * 0.65 + (0.5 + 0.5 * cos(angle * 3.0 + dirSign * u_time * 2.1)) * 0.35, 1.5);
            float mouseDist = length(p - u_mouse);
            float mouseBoost = exp(-(mouseDist * mouseDist) / 25600.0) * 0.75 * clamp(u_cursor_strength, 0.0, 1.0);
            float totalEnergy = clamp(0.15 + waveEnergy * 0.85 + mouseBoost, 0.0, 1.4);
            float rimLine = exp(-distInward * 1.15) * (0.45 + 0.85 * totalEnergy);
            float edgeHalo = exp(-distInward / max(2.0, maxEdgePx * 0.38)) * smoothstep(maxEdgePx * 1.6, 0.0, distInward) * (0.12 + 0.42 * totalEnergy);
            float lightVal = (rimLine + edgeHalo) * clamp(effGlow, 0.0, 1.5);
            vec3 glowCol = paletteColor(u_glow_mode, phase, clamp(distInward / max(1.0, maxEdgePx), 0.0, 1.0));
            baseRgb = clamp(baseRgb + glowCol * lightVal, 0.0, 1.0);
            baseAlpha = clamp(baseAlpha + lightVal * 0.45, 0.0, 1.0);
        }
    }

    float finalAlpha = baseAlpha * mask * qt_Opacity;
    fragColor = vec4(baseRgb * finalAlpha, finalAlpha);
}
