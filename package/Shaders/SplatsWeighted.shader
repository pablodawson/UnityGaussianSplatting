// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats Weighted"
{
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite Off
            Blend 0 One One
			Blend 1 Zero OneMinusSrcAlpha
            Cull Off
            
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma require compute
#pragma use_dxc

#include "GaussianSplatting.hlsl"
#include "UnityCG.cginc"

StructuredBuffer<uint> _OrderBuffer;

struct v2f
{
    half4 col : COLOR0;
    float2 pos : TEXCOORD0;
    float4 vertex : SV_POSITION;
	float z: TEXCOORD1;
};

StructuredBuffer<SplatViewData> _SplatViewData;
ByteAddressBuffer _SplatSelectedBits;
uint _SplatBitsValid;
uint _Equation;
uint _Sort;

v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
{
    v2f o = (v2f)0;
	if (_Sort)
    	instID = _OrderBuffer[instID];
	
	SplatViewData view = _SplatViewData[instID];
	SplatData splat = LoadSplatData(instID);
	o.z = UnityObjectToViewPos(float4(splat.pos,1)).z;

	float4 centerClipPos = view.pos;
	bool behindCam = centerClipPos.w <= 0;	

	if (behindCam)
	{
		o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
	}
	else
	{
		o.col.r = f16tof32(view.color.x >> 16);
		o.col.g = f16tof32(view.color.x);
		o.col.b = f16tof32(view.color.y >> 16);
		o.col.a = f16tof32(view.color.y);

		uint idx = vtxID;
		float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0;
		quadPos *= 2;

		o.pos = quadPos;

		float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;
		o.vertex = centerClipPos;
		o.vertex.xy += deltaScreenPos * centerClipPos.w;

		// is this splat selected?
		if (_SplatBitsValid)
		{
			uint wordIdx = instID / 32;
			uint bitIdx = instID & 31;
			uint selVal = _SplatSelectedBits.Load(wordIdx * 4);
			if (selVal & (1 << bitIdx))
			{
				o.col.a = -1;				
			}
		}
	}
    return o;
}

float weight(float z, float alpha) {
	if (_Equation == 1)
		return pow(z, -2.5);
	else if (_Equation == 2)
		return max(1e-2, min(3 * 1e3, 10.0/(1e-5 + pow(z/5, 2) + pow(z/200, 6))));
	else if (_Equation == 3)
		return max(1e-2, min(3 * 1e3, 0.03/(1e-5 + pow(z/200, 4))));
	else
		return 1.0;
}

struct FragmentOutput
{
	float4 accum : SV_Target0;
	float4 revealage : SV_Target1;
};

FragmentOutput frag (v2f i) : SV_Target
{
	FragmentOutput o;

	float power = -dot(i.pos, i.pos);
	half alpha = exp(power);
	if (i.col.a >= 0)
	{
		alpha = saturate(alpha * i.col.a);
	}
	else
	{
		// "selected" splat: magenta outline, increase opacity, magenta tint
		half3 selectedColor = half3(1,0,1);
		if (alpha > 7.0/255.0)
		{
			if (alpha < 10.0/255.0)
			{
				alpha = 1;
				i.col.rgb = selectedColor;
			}
			alpha = saturate(alpha + 0.3);
		}
		i.col.rgb = lerp(i.col.rgb, selectedColor, 0.5);
	}
	
    if (alpha < 1.0/255.0)
        discard;

	o.accum = float4(i.col.rgb*alpha, alpha) * weight(i.z, alpha);
    o.revealage = float4(alpha, alpha, alpha, alpha);
	
	return o;
}
ENDCG
        }
    }
}
