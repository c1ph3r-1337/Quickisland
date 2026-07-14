#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 surfaceColor;
    vec4 borderColor;
    float effectWidth;
    float effectHeight;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float stepX = 1.0 / effectWidth;
    float stepY = 1.0 / effectHeight;
    float sum = 0.0;
    
    // 13x13 box blur for smooth gooey droplet blending
    for (int x = -6; x <= 6; x++) {
        for (int y = -6; y <= 6; y++) {
            sum += texture(source, qt_TexCoord0 + vec2(float(x)*stepX, float(y)*stepY)).a;
        }
    }
    sum /= 169.0;
    
    // Thresholding to make a sharp gooey droplet shape
    float inside = smoothstep(0.48, 0.52, sum);
    // Draw a thin border on the boundary of the merged shape
    float edge = inside - smoothstep(0.50, 0.54, sum);
    
    vec4 col = mix(surfaceColor, borderColor, edge);
    fragColor = col * inside * qt_Opacity;
}
