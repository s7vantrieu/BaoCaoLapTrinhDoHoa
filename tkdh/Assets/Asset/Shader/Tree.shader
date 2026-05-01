Shader "Unlit/Tree"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _BaseColor("Tree Tint", Color) = (1, 1, 1, 1)
        _WindSpeed("Wind Speed", Float) = 1.0
        _WindStrength("Wind Strength", Float) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
        LOD 100
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _BaseColor;
            float _Cutoff;
            float _WindSpeed;
            float _WindStrength;

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                float3 centerWS = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                
                float3 lookDir = _WorldSpaceCameraPos - centerWS;
                lookDir.y = 0; 
                lookDir = normalize(lookDir);
                
                float3 upDir = float3(0, 1, 0); 
                float3 rightDir = cross(upDir, lookDir); 

                float scaleX = length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x));
                float scaleY = length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y));

                float3 worldPos = centerWS + rightDir * (v.vertex.x * scaleX) + upDir * (v.vertex.y * scaleY);

                float wind = sin(_Time.y * _WindSpeed + centerWS.x + centerWS.z) * _WindStrength * v.uv.y;
                worldPos.x += wind * rightDir.x; 
                worldPos.z += wind * rightDir.z;

                o.vertex = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                
                fixed4 col = tex2D(_MainTex, i.uv);
                clip(col.a - _Cutoff);
                
                col *= _BaseColor;
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}