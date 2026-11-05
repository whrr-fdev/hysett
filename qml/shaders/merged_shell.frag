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

float sceneSdf(vec2 p) {
    vec2 bHalf = 0.5 * u_bar_rect.zw;
    vec2 bCenter = u_bar_rect.xy + bHalf;
    float d = sdRoundedBox(p - bCenter, bHalf, u_radius);

    if (u_drawer_rect.w > 0.5 && u_drawer_rect.z > 0.5) {
        vec2 dHalf = 0.5 * u_drawer_rect.zw;
        vec2 dCenter = u_drawer_rect.xy + dHalf;
        float dDrw = sdRoundedBox(p - dCenter, dHalf, u_radius * 1.35);

        // Единая колонна от верха панели до низа окна в зоне пересечения: убирает внутренний шов и ореол на стыке!
        float nx1 = max(u_bar_rect.x, u_drawer_rect.x);
        float nx2 = min(u_bar_rect.x + u_bar_rect.z, u_drawer_rect.x + u_drawer_rect.z);
        float ny1 = min(u_bar_rect.y, u_drawer_rect.y);
        float ny2 = max(u_bar_rect.y + u_bar_rect.w, u_drawer_rect.y + u_drawer_rect.w);
        if (nx2 > nx1 && ny2 > ny1) {
            vec2 nHalf = 0.5 * vec2(nx2 - nx1, ny2 - ny1);
            vec2 nCenter = vec2(nx1, ny1) + nHalf;
            float dNeck = sdRoundedBox(p - nCenter, nHalf, u_radius);
            dDrw = min(dDrw, dNeck);
        }

        float leftStep  = abs(u_bar_rect.x - u_drawer_rect.x);
        float rightStep = abs((u_bar_rect.x + u_bar_rect.z) - (u_drawer_rect.x + u_drawer_rect.z));
        float sideStep  = (p.x < u_drawer_rect.x + 0.5 * u_drawer_rect.z) ? leftStep : rightStep;
        float k = u_fillet * clamp((sideStep - 1.5) / 24.0, 0.0, 1.0) * clamp(min(u_drawer_rect.z, u_drawer_rect.w) / 42.0, 0.0, 1.0);
        d = smin(d, dDrw, k);
    }

    if (u_notif_rect.w > 0.5 && u_notif_rect.z > 0.5) {
        vec2 nHalf = 0.5 * u_notif_rect.zw;
        vec2 nCenter = u_notif_rect.xy + nHalf;
        float dNotif = sdRoundedBox(p - nCenter, nHalf, u_radius * 1.25);
        float nk = u_fillet * clamp(u_notif_rect.w / 32.0, 0.0, 1.0);
        d = smin(d, dNotif, nk);
    }

    return d;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;

    float d = sceneSdf(p);
    float mask = 1.0 - smoothstep(-0.6, 0.6, d);
    if (mask <= 0.001) { fragColor = vec4(0.0); return; }

    float distInward = max(0.0, -d);
    float outlineMask = exp(-distInward * 1.65);

    bool inNotifZone = (u_notif_rect.w > 0.5 && p.x >= u_notif_rect.x - 8.0 && p.x <= u_notif_rect.x + u_notif_rect.z + 8.0 && p.y >= u_notif_rect.y - 4.0 && p.y <= u_notif_rect.y + u_notif_rect.w + 8.0);
    vec4 activeFill = inNotifZone ? u_notif_color : ((u_drawer_rect.w > 0.5) ? u_bg_color : vec4(u_bg_color.rgb, u_bar_alpha));

    vec3 baseRgb = mix(activeFill.rgb, u_outline_color.rgb, outlineMask * u_outline_color.a);
    float baseAlpha = clamp(activeFill.a + outlineMask * 0.10, 0.05, 0.98);

    // 1. Свет от курсора мыши и шлейф: освещает И окно настроек, И панель задач без обрезки!
    if (u_drawer_rect.w > 1.0 && u_cursor_strength > 0.01 && u_mouse.x > -50.0) {
        float dm0 = length(p - u_mouse);
        float dm1 = length(p - u_trail1);
        float dm2 = length(p - u_trail2);
        float cGlow = (exp(-(dm0 * dm0) / 5200.0) * 0.25
                     + exp(-(dm1 * dm1) / 3800.0) * 0.11
                     + exp(-(dm2 * dm2) / 2600.0) * 0.06) * clamp(u_cursor_strength, 0.0, 1.0);
        baseRgb = clamp(baseRgb + u_cursor_color * cGlow, 0.0, 1.0);
    }

    // 2. Свечение контура при открытом окне работает и вокруг окна, и вокруг самой панели задач!
    float openFactor = clamp(u_drawer_rect.w / 40.0, 0.0, 1.0);
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
