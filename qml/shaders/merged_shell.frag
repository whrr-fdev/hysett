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
    vec4 u_music_wave2;
    float u_drawer_wave_amp;
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

float ferroSpikeAmp(float k, float t) {
    float h1 = fract(sin(k * 127.1 + 1.9) * 43758.5453);
    float h2 = fract(sin(k * 269.5 + 7.3) * 18342.2317);
    float h3 = fract(sin(k * 419.2 + 3.1) * 91523.1143);

    float bass = u_music_wave2.y;
    float mid  = u_music_wave2.z;
    float treb = u_music_wave2.w;
    float hasRealAudio = clamp((bass + mid + treb) * 1.6, 0.0, 1.0);

    float bandSelect = fract(k * 0.37 + h1);
    float audioEnergy = (bandSelect < 0.36)
                        ? (bass * 1.40 + mid * 0.15)
                        : ((bandSelect < 0.70) ? (mid * 1.35 + treb * 0.20) : (treb * 1.40 + bass * 0.15));

    float w1 = 0.5 + 0.5 * sin(t * (2.60 + h1 * 3.40) + h2 * 6.2831853 - k * 0.45);
    float w2 = 0.5 + 0.5 * sin(t * (4.40 + h2 * 4.10) - h3 * 6.2831853 + k * 0.70);
    float procWave = pow(clamp(w1 * 0.54 + w2 * 0.46, 0.0, 1.0), 1.25);

    return clamp(mix(procWave * 0.85, procWave * (0.20 + audioEnergy * 1.40), hasRealAudio), 0.0, 2.2);
}

float ferroToothProfile(float distFromCenter, float sharpness, float needleMix) {
    float d = clamp(distFromCenter, 0.0, 1.0);
    float drop = 1.0 / (1.0 + d * d * sharpness);
    float needle = exp(-d * (4.0 + needleMix * 7.5));
    float zeroAtBase = (1.0 - d * d) * (1.0 - d);
    return clamp(mix(drop, needle, needleMix) * zeroAtBase * 1.14, 0.0, 1.0);
}

float smaxLiquid(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / max(0.001, k), 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

float evalFerroCell(float k, float localF, float t, float sharpCfg) {
    float h1 = fract(sin(k * 91.7 + 0.3) * 19452.1);
    float h2 = fract(sin(k * 311.3 + 4.1) * 63819.7);
    float hSharp = fract(sin(k * 517.9 + 2.7) * 38192.3);

    float amp = ferroSpikeAmp(k, t);
    float center = 0.5 + (h1 - 0.5) * 0.28 * sin(t * 2.6 + k * 1.3);

    float needleMix = clamp(pow(hSharp, 0.8) * sharpCfg * 1.15, 0.10, 0.98);
    float sharpness = 8.0 + (hSharp * 18.0 + 10.0) * sharpCfg;

    float bassHit = u_music_wave2.y;
    float splitPhase = sin(t * (2.60 + h2 * 2.40) + h1 * 6.2831853) + bassHit * 0.45;
    float splitOffset = clamp((splitPhase - (0.45 - sharpCfg * 0.32)) * 0.26 * sharpCfg, 0.0, 0.21);

    if (splitOffset > 0.015) {
        float dLeft  = abs(localF - (center - splitOffset)) * 2.15;
        float dRight = abs(localF - (center + splitOffset)) * 2.15;
        float asym = 0.16 * sin(t * 4.2 + k * 1.9);
        float pLeft  = amp * (0.94 + asym) * ferroToothProfile(dLeft, sharpness * 1.15, min(1.0, needleMix + 0.14));
        float pRight = amp * (0.94 - asym) * ferroToothProfile(dRight, sharpness * 1.15, min(1.0, needleMix + 0.14));
        return smaxLiquid(pLeft, pRight, 0.08);
    } else {
        float dCenter = abs(localF - center) * 2.0;
        return amp * ferroToothProfile(dCenter, sharpness, needleMix);
    }
}

float computeFerroStretchForRect(vec2 p, vec4 rect, float ampPx, float edgeRad, bool maskDrawerOverlap) {
    if (u_music_wave.x > 0.5 || ampPx <= 0.05 || rect.z <= rect.w * 1.2) return 0.0;
    float bottomHalfMask = smoothstep(rect.y + rect.w * 0.35, rect.y + rect.w * 0.85, p.y);
    if (bottomHalfMask <= 0.001) return 0.0;

    float edgePad = max(14.0, edgeRad * 1.35);
    float edgeFade = smoothstep(rect.x + edgePad * 0.4, rect.x + edgePad * 1.5, p.x) *
                     smoothstep(rect.x + rect.z - edgePad * 0.4, rect.x + rect.z - edgePad * 1.5, p.x) * bottomHalfMask;

    if (maskDrawerOverlap && u_drawer_rect.w > 1.0 && u_drawer_rect.z > 1.0) {
        float inDrwX = smoothstep(u_drawer_rect.x - 10.0, u_drawer_rect.x + 6.0, p.x) *
                       smoothstep(u_drawer_rect.x + u_drawer_rect.z + 10.0, u_drawer_rect.x + u_drawer_rect.z - 6.0, p.x);
        edgeFade *= (1.0 - inDrwX);
    }
    if (edgeFade <= 0.001) return 0.0;

    float t = u_music_wave.w;
    float sharpCfg = clamp(u_music_wave.y, 0.1, 1.0);
    float totalCount = clamp(u_music_wave2.x, 20.0, 220.0);
    float step1 = max(6.0, 1904.0 / totalCount);

    float relX1 = (p.x - rect.x) / step1;
    float k1 = floor(relX1);
    float f1 = fract(relX1);

    float spikeCur  = evalFerroCell(k1, f1, t, sharpCfg);
    float spikePrev = evalFerroCell(k1 - 1.0, f1 + 1.0, t, sharpCfg);
    float spikeNext = evalFerroCell(k1 + 1.0, f1 - 1.0, t, sharpCfg);

    float liquidProfile = smaxLiquid(spikeCur, max(spikePrev, spikeNext), 0.07);
    return ampPx * edgeFade * clamp(liquidProfile, 0.0, 2.2);
}

float sceneSdf(vec2 p, out float outNotifBlend, out float outDrwBlend) {
    outNotifBlend = 0.0;
    outDrwBlend = 0.0;
    float bigOpen = clamp((u_drawer_rect.z - 520.0) / 220.0, 0.0, 1.0) * clamp(u_drawer_rect.w / 180.0, 0.0, 1.0);
    float barVis = clamp(max(u_bar_alpha * 10.0, bigOpen), 0.0, 1.0);
    float waveStretch = (barVis > 0.01) ? computeFerroStretchForRect(p, u_bar_rect, u_music_wave.z, u_radius, true) : 0.0;
    vec2 bSize = vec2(u_bar_rect.z, u_bar_rect.w + waveStretch);
    vec2 bHalf = 0.5 * bSize;
    vec2 bCenter = vec2(u_bar_rect.x + bHalf.x, u_bar_rect.y + bHalf.y);
    float dBar = (barVis > 0.01) ? sdRoundedBox(p - bCenter, bHalf, u_radius) : 1e5;
    float d = dBar;

    if (u_drawer_rect.w > 0.5 && u_drawer_rect.z > 0.5) {
        float rDrw = u_radius * 1.35;
        float drwWaveStretch = computeFerroStretchForRect(p, u_drawer_rect, u_drawer_wave_amp, rDrw, false);
        vec2 dSize = vec2(u_drawer_rect.z, u_drawer_rect.w + drwWaveStretch);
        vec2 dHalf = 0.5 * dSize;
        vec2 dCenter = vec2(u_drawer_rect.x + dHalf.x, u_drawer_rect.y + dHalf.y);
        float dDrw = sdRoundedBox(p - dCenter, dHalf, rDrw);

        if (barVis > 0.05) {
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
                float k = u_fillet * barVis * innerEdgeMask * clamp((sideStep - 1.0) / 22.0, 0.0, 1.0) * clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 42.0, 0.0, 1.0);
                outDrwBlend = smoothstep(4.0, -4.0, dDrw - dBar);
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
                float k = u_fillet * barVis * innerEdgeMask * clamp((sideStep - 1.0) / 22.0, 0.0, 1.0) * clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 42.0, 0.0, 1.0);
                outDrwBlend = smoothstep(4.0, -4.0, dDrw - dBar);
                d = smin(d, dDrw, k);
            }
        } else {
            outDrwBlend = 1.0;
            d = dDrw;
        }
    }

    if (u_notif_rect.w > 0.5 && u_notif_rect.z > 0.5) {
        vec2 nHalf = 0.5 * u_notif_rect.zw;
        vec2 nCenter = u_notif_rect.xy + nHalf;
        float dNotif = sdRoundedBox(p - nCenter, nHalf, u_radius * 1.25);
        bool barTouchesNotif = (barVis > 0.05) &&
                               (u_notif_rect.y >= u_bar_rect.y + u_bar_rect.w - 2.0 || u_notif_rect.y + u_notif_rect.w <= u_bar_rect.y + 2.0) &&
                               (u_notif_rect.x < u_bar_rect.x + u_bar_rect.z - 2.0) && (u_notif_rect.x + u_bar_rect.z > u_bar_rect.x + 2.0);
        float neckZone = barTouchesNotif ? (1.0 - smoothstep(u_bar_rect.y + u_bar_rect.w, u_bar_rect.y + u_bar_rect.w + u_fillet * 1.5, p.y)) : 0.0;
        float nk = u_fillet * barVis * neckZone * smoothstep(u_bar_rect.y + 4.0, u_bar_rect.y + u_bar_rect.w, p.y) * clamp(u_notif_rect.w / 32.0, 0.0, 1.0);
        outNotifBlend = smoothstep(4.0, -4.0, dNotif - dBar);
        d = smin(d, dNotif, nk);
    }

    return d;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;

    float notifBlend = 0.0;
    float drwBlend = 0.0;
    float d = sceneSdf(p, notifBlend, drwBlend);
    float gradLen = clamp(length(vec2(dFdx(d), dFdy(d))), 1.0, 6.0);
    float trueD = d / gradLen;
    float mask = 1.0 - smoothstep(-0.75, 0.75, trueD);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    float distInward = max(0.0, -trueD);
    float outlineMask = exp(-distInward * 1.55);

    float bigSettingsMix = clamp((u_drawer_rect.z - 520.0) / 220.0, 0.0, 1.0) * clamp(u_drawer_rect.w / 180.0, 0.0, 1.0);
    vec3 darkBgRgb = u_bg_color.rgb * mix(0.42, 1.0, bigSettingsMix);

    // При открытии большого окна настроек ВСЯ панель задач целиком принимает прозрачность и цвет окна настроек
    float barBaseAlpha = mix(u_bar_alpha, u_bg_color.a, bigSettingsMix);
    float popupOrSettingsAlpha = mix(u_bar_alpha, u_bg_color.a, bigSettingsMix);
    float effAlpha = mix(barBaseAlpha, popupOrSettingsAlpha, drwBlend);
    float outlineVis = clamp(effAlpha * 3.0, 0.0, 1.0);

    vec4 shellFill = vec4(darkBgRgb, effAlpha);
    vec4 activeFill = mix(shellFill, vec4(u_notif_color.rgb * 0.50, max(0.88, u_notif_color.a)), notifBlend);

    vec3 baseRgb = mix(activeFill.rgb, u_outline_color.rgb, outlineMask * u_outline_color.a * outlineVis);
    float baseAlpha = clamp(activeFill.a + outlineMask * 0.10 * outlineVis, 0.0, 0.98);

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
