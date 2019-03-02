/*
CrossHair PS v1.3.2 (c) 2018 Jacob Maximilian Fober

This work is licensed under the Creative Commons 
Attribution-ShareAlike 4.0 International License. 
To view a copy of this license, visit 
http://creativecommons.org/licenses/by-sa/4.0/.
*/

  ////////////////////
 /////// MENU ///////
////////////////////

#ifndef ZOOMKEY
	#define ZOOMKEY 0x5A
#endif

uniform float Opacity <
	ui_label = "Crosshair opacity";
	#if __RESHADE__ < 40000
		ui_type = "drag";
	#else
		ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 1.0;
	ui_category = "Crosshair";
> = 1.0;

uniform int Coefficients <
	ui_label = "Crosshair contrast mode";
	ui_tooltip = "YUV coefficients\nFor digital connection (HDMI/DVI/DisplayPort) use BT.709\nFor analog connection (VGA) use BT.601";
	ui_type = "combo";
	ui_items = "BT.709\0BT.601\0";
	ui_category = "Crosshair";
> = 0;

uniform bool Stroke <
	ui_label = "Enable black stroke";
	ui_category = "Crosshair";
> = true;

uniform bool PreviewZoom <
	ui_label = "Zoom preview";
	ui_tooltip = "Preview zooming function (Press Z to toggle)\nYou can change default button by declaring preprocessor definition\n(URL encoded hex value)  ZOOMKEY 0x5A";
	ui_category = "Zooming";
> = false;

uniform float Zoom <
	ui_label = "Zoom amout";
	ui_tooltip = "Adjust zoom factor, to disable effect, set to 1.0";
	#if __RESHADE__ < 40000
		ui_type = "drag";
	#else
		ui_type = "slider";
	#endif
	ui_min = 1.0; ui_max = 4.0;
	ui_category = "Zooming";
> = 2.0;

uniform float Radius <
	ui_label = "Zoom radius";
	ui_tooltip = "Adjust size for zoom view";
	#if __RESHADE__ < 40000
		ui_type = "drag";
	#else
		ui_type = "slider";
	#endif
	ui_min = 0.1; ui_max = 1.0;
	ui_category = "Zooming";
> = 0.4;

uniform bool Fixed <
	ui_label = "Fixed position";
	ui_tooltip = "Crosshair will move with the mouse on OFF";
	ui_category = "Position";
> = true;

uniform int2 OffsetXY <
	ui_label = "Offset in Pixels";
	ui_tooltip = "Offset Crosshair position in pixels";
	ui_type = "drag";
	ui_min = -16; ui_max = 16;
	ui_category = "Position";
> = int2(0, 0);


uniform bool ZoomKeyDown <
	source = "key";
	keycode = ZOOMKEY;
	mode = "";
>;

  //////////////////////
 /////// SHADER ///////
//////////////////////

#include "ReShade.fxh"

// RGB to YUV709
static const float3x3 ToYUV709 =
float3x3(
	float3(0.2126, 0.7152, 0.0722),
	float3(-0.09991, -0.33609, 0.436),
	float3(0.615, -0.55861, -0.05639)
);
// RGB to YUV601
static const float3x3 ToYUV601 =
float3x3(
	float3(0.299, 0.587, 0.114),
	float3(-0.14713, -0.28886, 0.436),
	float3(0.615, -0.51499, -0.10001)
);
// YUV709 to RGB
static const float3x3 ToRGB709 =
float3x3(
	float3(1, 0, 1.28033),
	float3(1, -0.21482, -0.38059),
	float3(1, 2.12798, 0)
);
// YUV601 to RGB
static const float3x3 ToRGB601 =
float3x3(
	float3(1, 0, 1.13983),
	float3(1, -0.39465, -0.58060),
	float3(1, 2.03211, 0)
);

// Get mouse position
uniform float2 MousePoint < source = "mousepoint"; >;

// Define CrossHair texture
texture CrossHairTex < source = "crosshair.png"; > {Width = 17; Height = 17; Format = RG8;};
sampler CrossHairSampler { Texture = CrossHairTex; };

// Overlay blending mode
float Overlay(float LayerA, float LayerB)
{
	float MinA = min(LayerA, 0.5);
	float MinB = min(LayerB, 0.5);
	float MaxA = max(LayerA, 0.5);
	float MaxB = max(LayerB, 0.5);
	return 2 * (MinA * MinB + MaxA + MaxB - MaxA * MaxB) - 1.5;
}

// Draw CrossHair
void CrossHairPS(float4 vois : SV_Position, float2 texcoord : TexCoord, out float3 Display : SV_Target)
{
	float2 Pixel = ReShade::PixelSize;
	float2 Screen = ReShade::ScreenSize;
	float Aspect = ReShade::AspectRatio;
	float2 Offset = Pixel * float2(-OffsetXY.x, OffsetXY.y);
	float2 Position = Fixed ? float2(0.5, 0.5) : MousePoint / ReShade::ScreenSize;

	if(Zoom!=1.0 && (ZoomKeyDown || PreviewZoom))
	{
		float2 ZoomCoord = texcoord-Position+Offset; // Center coordinates
		// Correct aspect ratio and generate radial mask
		float RadialMask = length( float2(ZoomCoord.x*Aspect, ZoomCoord.y)*2 );
		float RadialPixel = fwidth(RadialMask); // Get pixel size for Anti-aliasing
		RadialMask = smoothstep(Radius+RadialPixel, Radius-RadialPixel, RadialMask); // Generate AA mask
		ZoomCoord = ZoomCoord / Zoom + Position-Offset; // Apply zoom and move center back to origin
		// Sample display image
		Display = lerp(
			tex2D(ReShade::BackBuffer, texcoord).rgb, // Background image
			tex2D(ReShade::BackBuffer, ZoomCoord).rgb, // Zoom image
			RadialMask
		);
	}
	else Display = tex2D(ReShade::BackBuffer, texcoord).rgb; // Background image

	// CrossHair texture size
	int2 Size = tex2Dsize(CrossHairSampler, 0);

	float3 StrokeColor;

	// Calculate CrossHair image coordinates relative to the center of the screen
	float2 CrossHairHalfSize = Size / Screen * 0.5;
	float2 texcoordCrossHair = (texcoord - Pixel * 0.5 + Offset - Position + CrossHairHalfSize) * Screen / Size;

	// Sample CrossHair image
	float2 CrossHair = tex2D(CrossHairSampler, texcoordCrossHair).rg;

	if (CrossHair.r != 0 || CrossHair.g != 0)
	{
		// Get behind-crosshair color
		float3 Color = tex2D(ReShade::BackBuffer, Position + Offset).rgb;

		// Convert to YUV
		Color = bool(Coefficients) ? mul(ToYUV709, Color) : mul(ToYUV601, Color);

		// Invert Luma with high-contrast gray
		Color.r = (Color.r > 0.75 || Color.r < 0.25) ? 1.0 - Color.r : Color.r > 0.5 ? 0.25 : 0.75;
		// Invert Chroma
		Color.gb *= -1.0;

		float StrokeValue = 1 - Color.r;

		// Convert YUV to RGB
		Color = bool(Coefficients) ? mul(ToRGB709, Color) : mul(ToRGB601, Color);

		// Overlay blend stroke with background
		StrokeColor = float3(
			Overlay(Display.r, StrokeValue),
			Overlay(Display.g, StrokeValue),
			Overlay(Display.b, StrokeValue)
		);
		StrokeColor = lerp(Display, StrokeColor, 0.75); // 75% opacity

		// Color the stroke
		Color = lerp(StrokeColor, Color, CrossHair.r);
		// Opacity
		CrossHair *= Opacity;

		// Paint the crosshair
		Display = lerp(Display, Color, Stroke ? CrossHair.g : CrossHair.r);
	}
}


technique CrossHair < ui_label = "Crosshair"; >
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = CrossHairPS;
	}
}
