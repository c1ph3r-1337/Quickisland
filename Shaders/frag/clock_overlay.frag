#version 450
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D baseSource;
layout(binding = 2) uniform sampler2D textSource;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
} ubuf;

void main() {
    vec4 fg = texture(textSource, qt_TexCoord0);
    if (fg.a < 0.002) {
        discard;
    }
    vec4 bg = texture(baseSource, qt_TexCoord0);

    // Luminous Vibrancy Blend:
    // 78% base white luminance + 22% background chromatic bleed.
    // Solves black background visibility while preserving background translucency.
    vec3 blended = bg.rgb * 0.22 + vec3(0.78);

    fragColor = vec4(blended * fg.a, fg.a) * ubuf.qt_Opacity;
}
