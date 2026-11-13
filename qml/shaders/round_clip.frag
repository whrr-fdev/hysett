#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;
    float u_radius;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;
    vec2 b = res * 0.5;
    float r = min(u_radius, min(b.x, b.y));
    vec2 q = abs(p - b) - b + r;
    float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
    float mask = 1.0 - smoothstep(-0.75, 0.75, d);
    fragColor = texture(source, qt_TexCoord0) * (mask * qt_Opacity);
}
