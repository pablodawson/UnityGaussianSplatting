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
		o.col.a = f16tof32(view.color.y);

		uint idx = vtxID;
		float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0;
		quadPos *= 2;

		o.pos = quadPos;

		float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;
		o.vertex = centerClipPos;
		o.vertex.xy += deltaScreenPos * centerClipPos.w;
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
	alpha = saturate(alpha * i.col.a);
	
    if (alpha < 1.0/255.0)
        discard;


	float d = 0.3/i.z;
	//d = exp(d);
	//d=d*d;
	//d = exp(d-0.2) - 1;

	o.accum = float4(d, d, d, 1) * alpha * weight(i.z, alpha);
    o.revealage = float4(1, 1, 1, 1);
	
	return o;
}
ENDCG
        }
    }
}
