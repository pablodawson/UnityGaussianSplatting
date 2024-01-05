// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats Stochastic"
{
	Properties
	{
		_SrcBlend("Src Blend", Float) = 8 // OneMinusDstAlpha
		_DstBlend("Dst Blend", Float) = 1 // One
		_ZWrite("ZWrite", Float) = 0  // Off
	}

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite [_ZWrite]
            //Blend One One
			//ZTest Always
			Blend [_SrcBlend] [_DstBlend]
            Cull Off
            
CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma require compute
#pragma use_dxc

#include "GaussianSplatting.hlsl"

StructuredBuffer<uint> _OrderBuffer;
uint _Sort;

struct v2f
{
    half4 col : COLOR0;
    float2 pos : TEXCOORD0;
    float4 vertex : SV_POSITION;
	uint idx : TEXCOORD1;
};

StructuredBuffer<SplatViewData> _SplatViewData;
ByteAddressBuffer _SplatSelectedBits;
uint _SplatBitsValid;
uint _SplatMSAASamples;
uint _UseBlueNoise;
Texture2DArray _HAT_BlueNoise;

// adapted from https://www.shadertoy.com/view/4djSRW
float hash13(float3 p3)
{
	p3  = frac(p3 * .1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return frac((p3.x + p3.y) * p3.z);
}

uint createStochasticMask(float alpha, float3 vertex, uint idx)
{
	uint mask = 0;

	for (uint i = 0; i < 8; i++)
	{
		float3 seed = 0;
		float cutoff = 0.5;

		if (_UseBlueNoise == 0){
			float3 seed = vertex + (idx + 1) * (i + 1);
			cutoff = hash13(seed);
		} else {

			float3 hatCoord;
			hatCoord.xy = vertex.xy;
			hatCoord.z = (idx + 1) * (i + 1);
			uint4 coord;
			coord.xyz = (uint3)hatCoord;
			coord.xyz &= 63;
			coord.w = 0;
			cutoff = _HAT_BlueNoise.Load(coord).r;
		}
		
		if (alpha > cutoff)
		{
			mask |= 1 << i;
		}
	}

	return mask;
}

v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
{
    v2f o = (v2f)0;
	
	if (_Sort==1){
		instID = _OrderBuffer[instID];
	}

	SplatViewData view = _SplatViewData[instID];
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
		o.idx = idx;
	}
	
    return o;
}

half4 frag (v2f i, out uint coverage : SV_Coverage) : SV_Target
{
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

	coverage = createStochasticMask(alpha, i.vertex.xyz, i.idx);

    half4 res = half4(i.col.rgb, 1);

    return res;
}
ENDCG
        }
    }
}
