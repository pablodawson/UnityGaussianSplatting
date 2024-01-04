// SPDX-License-Identifier: MIT
Shader "Hidden/Gaussian Splatting/CompositeWeighted"
{
    SubShader
    {
        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off
            Blend OneMinusSrcAlpha SrcAlpha 

CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma require compute
#pragma use_dxc
#include "UnityCG.cginc"

struct v2f
{
    float4 vertex : SV_POSITION;
};

v2f vert (uint vtxID : SV_VertexID)
{
    v2f o;
    float2 quadPos = float2(vtxID&1, (vtxID>>1)&1) * 4.0 - 1.0;
	o.vertex = float4(quadPos, 1, 1);
    return o;
}

Texture2D _GaussianSplatRT;

Texture2D _AccumulationRT;
Texture2D _RevealageRT;

half4 frag (v2f i) : SV_Target
{
    float4 accum = _AccumulationRT.Load(int3(i.vertex.xy, 0));
    float revealage = _RevealageRT.Load(int3(i.vertex.xy, 0)).r;
    half4 col = half4(accum.rgb / clamp(accum.a, 1e-3, 5e4), revealage);

    col.rgb = GammaToLinearSpace(col.rgb);
    col.a = saturate(col.a * 1.5);
    return col;
}
ENDCG
        }
    }
}
