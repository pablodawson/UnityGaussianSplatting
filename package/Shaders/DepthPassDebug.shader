// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats Depth Weighted"
{
    SubShader
    {
        Tags { "RenderType"="Geometry" "Queue"="Geometry" }
        Pass
        {
            ZWrite On
            Blend Zero Zero
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
	uint idx: TEXCOORD2;
};

StructuredBuffer<SplatViewData> _SplatViewData;
ByteAddressBuffer _SplatSelectedBits;
uint _SplatBitsValid;
uint _Sort;

v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
{
    v2f o = (v2f)0;
	if (_Sort)
    	instID = _OrderBuffer[instID];
	
	SplatViewData view = _SplatViewData[instID];
	SplatData splat = LoadSplatData(instID);
	//o.z = UnityObjectToViewPos(float4(splat.pos,1)).z;

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
		o.idx = idx;
	}
    return o;
}



float4 frag (v2f i, out float depth: SV_Depth, out uint coverage: SV_Coverage) : SV_Target
{
	float power = -dot(i.pos, i.pos);
	half alpha = saturate(exp(power) * i.col.a);
	coverage = createStochasticMask(alpha, i.vertex.xyz, i.idx);
	//float mask = step(alpha, 0.2);
	depth = i.vertex.z; // * (1-mask);
	

	return half4(0,0,0,0);
}
ENDCG
        }
    }
}
