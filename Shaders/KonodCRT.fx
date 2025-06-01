#include "ReShade.fxh"

#define PI 3.1415926536
#define SQRT3 1.73205081f

uniform bool activateCurvature <
    ui_label = "Screen curvature";
    ui_tooltip = "Activate screen curvature.";
    > = true;

uniform float2 viewPortRatio <
    ui_type = "slider";
    ui_label = "Effective screen size(%)";
    ui_tooltip = "Indicate the part of the screen that is effective. This serves to adjust to specific aspect ratios with black bars. 100% by default.\n\
Set the values to the minimal numbers such that no part of the image is cropped.";
    ui_min = 0.0;
    ui_max = 100.0;
    ui_step = 0.05;
    > = float2(100.0, 100.0);

uniform bool showViewport <
    ui_label = "Effective screen adjustment helper";
    ui_tooltip = "Show the borders of the effective screen. This is just to facilitate the effective screen size adjustment.\n\
The color of the color mixing section is used as a reference.";
    > = false;

uniform float2 curvatureInt <
    ui_type = "slider";
    ui_label = "Curvature intensity";
    ui_min = 0.0;
    ui_max = 0.1;
    ui_step = 0.005;
    > = float2(0.025, 0.04);

uniform float2 curvatureExponent <
    ui_type = "slider";
    ui_label = "Curvature exponent";
    ui_min = 1.0;
    ui_max = 4.0;
    ui_step = 0.1;
    > = float2(2.0, 2.9);

uniform float screenBorderSmoothness <
    ui_type = "slider";
    ui_label = "Screen border smoothness";
    ui_min = 0.0;
    ui_max = 0.1;
    ui_step = 0.005;
    > = 0.025;

uniform bool activateMix <
    ui_label = "Color mixing";
    ui_tooltip = "Activate color mixing.";
    > = false;

uniform float3 sideColor <
    ui_type = "color";
    ui_label = "Color";
    ui_tooltip = "Choose the color which is mixed with the screen color.";
    > = float3(0.440359, 0.458021, 0.480392);

uniform float mixingRatio <
    ui_type = "slider";
    ui_label = "Mixing Ratio";
    ui_tooltip = "Mixing ratio. 0 will maximize screen color, 1 will maximize selected color.";
    ui_min = 0.0;
    ui_max = 0.2;
    ui_step = 0.001;
    > = 0.04;

uniform float gamma <
    ui_type = "slider";
    ui_label = "Gamma correction";
    ui_tooltip = "Gamma correction applied before color mixing. Set it to 0 in order to disable this option.\n\
Beware of small gamma values, as it will falsify screen color evaluation, resulting in darker and desaturated colors.";
    ui_mix = 0.0;
    ui_max = 4.0;
    ui_step = 0.1;
    > = 2.2;

uniform bool activateGrid <
    ui_label = "Aperture grid";
    ui_tooltip = "Display the aperture grid.";
    > = true;

uniform bool fitToGrid <
    ui_label = "Fit image to grid";
    ui_tooltip = "Sample the image along the grid apertures. Set it to false to have a \"cleaner\" image.";
    > = true;

uniform bool refinedSampling <
    ui_label = "Refined grid";
    ui_tooltip = "Increase the number of samplings. Better result, especially for low grid resolution, but double computation time.\n\
Note that it ONLY make a difference for refined grid.";
    > = true;

uniform float2 gridResolutionCoef <
    ui_type = "slider";
    ui_label = "Grid resolution coefficient";
    ui_tooltip = "Ratio between the resolution of the grid and the resolution of the screen.";
    ui_min = 0.01;
    ui_max = 2.0;
    ui_step = 0.005;
    > = float2(0.615, 0.285);

uniform float apertureLens <
    ui_type = "slider";
    ui_label = "Aperture lens";
    ui_tooltip = "Lens of the apertures of the grid.";
    ui_min = 0.0;
    ui_max = 5.0;
    ui_step = 0.05;
    > = 0.8;

uniform float radianceCorrection <
    ui_type = "slider";
    ui_label = "Radiance correction";
    ui_tooltip = "Correction of the radiance loss due to the grid layout.";
    ui_min = 0.1;
    ui_max = 5.0;
    ui_step = 0.1;
    > = 1.0;


float fmod(float a, float b) {
    const float c = frac(abs(a / b)) * abs(b);
    if (a < 0)
        return -c;
    else
        return c;
}

float2 fmod(float2 a, float2 b) {
    return float2(fmod(a.x, b.x), fmod(a.y, b.y));
}

float Gaussian(float2 P, float sigma, float amplitude) {
    return amplitude * exp(-dot(P, P) / sigma);
}

float UnitGaussianCircle(float2 uv, float2 center, float radius) {
    return Gaussian(uv - center, radius, SQRT3 / sqrt(PI * radius));
}

float HexagonGrid(float2 uv) {
    float len = apertureLens;
    float2 uvCentered = fmod(uv, float2(2.f, 2.f * SQRT3));
    if (uvCentered.x > 1.f) uvCentered.x = 2.f - uvCentered.x;
    if (uvCentered.y > SQRT3) uvCentered.y = 2.f * SQRT3 - uvCentered.y;
    float o = UnitGaussianCircle(uvCentered, float2(0.f, 0.f), len);
    o += UnitGaussianCircle(uvCentered, float2(1.f, SQRT3), len);
    return o;
}

float3 RGBHexagonGrid(float2 uv) {
    const float2 upStep = float2(0.f, 0.6666666f * SQRT3);

    float2 hexFactor = gridResolutionCoef * BUFFER_SCREEN_SIZE;
    float2 uvHex = uv * hexFactor;
    float3 o;
    o.r = HexagonGrid(uvHex);
    o.g = HexagonGrid(uvHex + upStep);
    o.b = HexagonGrid(uvHex - upStep);
    return o;
}

float3 RGBHexagonGridFitted(float2 uv) {
    const float2 upStep = float2(0.f, 0.6666666f * SQRT3);
    const float2 diagStep1 = float2(-1.f, -0.3333333f * SQRT3);
    const float2 diagStep2 = float2(1.f, -0.3333333f * SQRT3);
    const float2 hexFactor = gridResolutionCoef * BUFFER_SCREEN_SIZE;

    float2 uvHex = uv * hexFactor;
    float3 o;
    o.r = HexagonGrid(uvHex) * tex2D(ReShade::BackBuffer, uv).r;
    o.g = HexagonGrid(uvHex + diagStep1) * tex2D(ReShade::BackBuffer, uv + diagStep1 / hexFactor).g;
    o.b = HexagonGrid(uvHex - diagStep2) * tex2D(ReShade::BackBuffer, uv - diagStep2 / hexFactor).b;

    if (refinedSampling) {
        o.g += HexagonGrid(uvHex + upStep) * tex2D(ReShade::BackBuffer, uv + upStep / hexFactor).g;
        o.g += HexagonGrid(uvHex + diagStep2) * tex2D(ReShade::BackBuffer, uv + diagStep2 / hexFactor).g;
        o.g /= 3.f;
        o.b += HexagonGrid(uvHex - diagStep1) * tex2D(ReShade::BackBuffer, uv - diagStep1 / hexFactor).b;
        o.b += HexagonGrid(uvHex - upStep) * tex2D(ReShade::BackBuffer, uv - upStep / hexFactor).b;
        o.b /= 3.f;
    }
    return o;
}

float3 CRTScreenPass(float4 vpos : SV_POSITION, float2 texCoord : TEXCOORD) : SV_TARGET{
    float3 screenColor;
    float screenBorderStencil = 1.f;
    bool gammaCorrection = ((gamma != 0.0) && (activateGrid || activateMix));

    if (activateCurvature) {
        static const float halfScreenBorderSmoothness = screenBorderSmoothness * 0.5;
        float2 viewPort = viewPortRatio / 100.0;
        float2 texCoordCentered = (texCoord * 2.0 - 1.0) / viewPort;
        texCoordCentered *= 1.0 + curvatureInt * pow(abs(texCoordCentered.yx), curvatureExponent);
        texCoord = (texCoordCentered * viewPort + 1.0) * 0.5;
        float2 insideScreen = smoothstep(halfScreenBorderSmoothness, -halfScreenBorderSmoothness, abs(texCoordCentered) - float2(1.0, 1.0));
        screenBorderStencil *= insideScreen.x * insideScreen.y;
    }


    if (activateGrid) {
        float3 screenColorGrid;
        if (fitToGrid) {
            screenColorGrid = RGBHexagonGridFitted(texCoord);
        }
        else {
            screenColorGrid = RGBHexagonGrid(texCoord) * tex2D(ReShade::BackBuffer, texCoord).rgb;
        }

        screenColor = screenColorGrid * radianceCorrection;
    }
    else {
        screenColor = tex2D(ReShade::BackBuffer, texCoord).rgb;
    }

    screenColor *= screenBorderStencil;

    if (gammaCorrection) screenColor = pow(screenColor, gamma);

    if (showViewport) {
        screenColor += sideColor * step(screenBorderStencil, 0);
    }

    if (activateMix) {
        float3 mixedColor = (1 - mixingRatio) * screenColor + mixingRatio * sideColor;
        screenColor = activateMix ? mixedColor : screenColor;
    }
    if (gammaCorrection) screenColor = pow(screenColor, 1.0 / gamma);
    return screenColor;
}

technique HexagonalCRT{
    pass {
        VertexShader = PostProcessVS;
        PixelShader = CRTScreenPass;
    }
}