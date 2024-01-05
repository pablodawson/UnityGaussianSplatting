// SPDX-License-Identifier: MIT
Shader "Hidden/Gaussian Splatting/Composite Depth"
{
    SubShader
    {
        Pass
        {
            ZWrite On
            ZTest Always
            Cull Off
            Blend SrcAlpha Zero

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

half4 frag (v2f i, out float depth: SV_Depth) : SV_Target
{
    half4 col = _GaussianSplatRT.Load(int3(i.vertex.xy, 0));
    depth = 1/(col.r*0.3);
    //return 1/(col.r*0.3);
    return 1;
}
ENDCG
        }
    }
}
