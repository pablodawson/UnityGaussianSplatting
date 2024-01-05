// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Depth Write"
{
SubShader
{
    Tags { "RenderType"="Geometry" "Queue"="Geometry" }

    // Depth write only shader
    Pass
    {
        ZWrite On
        ZTest Always
        Cull Off
        
        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag

        #include "GaussianSplatting.hlsl"

        struct v2f
        {
            float4 vertex : SV_POSITION;
        };

        v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
        {
            v2f o;
            uint splatIndex = instID;
            SplatData splat = LoadSplatData(splatIndex);

            float3 centerWorldPos = splat.pos;
            centerWorldPos = mul(unity_ObjectToWorld, float4(centerWorldPos,1)).xyz;
            float4 centerClipPos = mul(UNITY_MATRIX_VP, float4(centerWorldPos, 1));

            o.vertex = centerClipPos;
            return o;
        }

        half4 frag (v2f i, out float depth: SV_Depth) : SV_Target
        {   
			depth = i.vertex.z;
            return half4(1,1,1,1);
        }
        ENDCG
    }
}
}
