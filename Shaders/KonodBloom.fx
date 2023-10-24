#include "ReShade.fxh"

#ifndef NUMBER_LOD
 #define NUMBER_LOD 8
#endif

uniform float bloomingAttenuation <
	ui_type = "slider";
	ui_label = "Blooming attenuation";
	ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.5;

uniform bool mamximumBrigthness <
    ui_label = "Thresholding on the maximum color";
    ui_tooltip = "If enabled, the threshold will occur on the brightest color.\n\
                    Else, the threshold will occur on the color norm (vector length).\n\
                    You might probably want to adjust the threshold when changing this parameter.";
    > = true;

uniform float lightThresholding <
    ui_type = "slider";
    ui_label = "Light intensity threshold";
    ui_tooltip = "If thresholding on the maximum color, should range from 0 to 1.\n\
Else, should range from 0 to sqrt(3).";
    ui_min = 0.0;
    ui_max = 1.74;
    ui_step = 0.001;
    > = 0.5;

uniform float attenuationLOD <
    ui_type = "slider";
    ui_label = "LOD attenuation";
    ui_tooltip = "Attenuation coefficient between LODs. 0 = total attenuation, 1 = no attenuation.";
    ui_min = 0.001;
    ui_max = 1.0;
    ui_step = 0.001;
    > = 0.9;

uniform bool applyPreThreshold <
    ui_label = "Pre-downsampling thresholding";
    ui_label = "Apply thresholding before the downsampling of the screen.";
> = false;

uniform bool onlyBloom <
    ui_label = "Only bloom";
    ui_label = "Will only display the bloom on the screen.";
> = false;


texture mipmappedScreen { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; MipLevels = NUMBER_LOD; };

sampler samplerMipmappedScreen { Texture = mipmappedScreen; };


float4 PS_Mipmap(in float4 position : SV_POSITION, in float2 texCoord : TEXCOORD) : SV_TARGET {
    float4 pixel = tex2D(ReShade::BackBuffer, texCoord);
    if (applyPreThreshold) {
        float brightness = mamximumBrigthness ?
                        max(max(pixel.r, pixel.g), pixel.b) :
                        length(pixel.rgb);
        return (brightness >= lightThresholding) ? pixel : 0;
    } else {
        return pixel;
    }
}

float4 PS_Bloom(in float4 position : SV_Position, in float2 texCoord : TEXCOORD) : SV_TARGET {
    
    float4 pixel = tex2D(ReShade::BackBuffer, texCoord);
    float4 bloomedPixel = 0;
    float weight = 0;
    
    for (int i = 1; i < NUMBER_LOD; ++i) {
        bloomedPixel += tex2Dlod(samplerMipmappedScreen, float4(texCoord, 0, i));
        bloomedPixel *= attenuationLOD;
        weight++;
        weight *= attenuationLOD;
    }
    bloomedPixel /= max(0.001, weight);

    float brightness = mamximumBrigthness ?
                        max(max(bloomedPixel.r, bloomedPixel.g), bloomedPixel.b) :
                        length(bloomedPixel.rgb);
    float contribution = max(0, brightness - lightThresholding)/max(0.0001, brightness);
    bloomedPixel *= contribution;

    return (onlyBloom ? 0 : pixel) + bloomedPixel * bloomingAttenuation;
}

technique KonodBloom {

    pass {
        VertexShader = PostProcessVS;
        PixelShader = PS_Mipmap;
        RenderTarget = mipmappedScreen;
    }
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Bloom;
	}
}
