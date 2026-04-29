Shader "Unlit/Shader2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Value ("Value", Range(0, 1)) = 1
        _Color ("Color", Color) = (1,1,1,1)
        _Slider ("Slider", Range(0, 2)) = 1
        _SpikeHeight ("Spike Height", Float) = 0.5 // Thêm biến này để không bị lỗi unrecognized
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
                //float3 viewDir : TEXCOORD1;
            };
            struct g2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;

                //float3 viewDir : TEXCOORD1;
            };

            sampler2D _MainTex;
            float _Value;
            float4 _MainTex_ST;
            float4 _Color;
            float _Slider;
            float _SpikeHeight;

            v2g vert (appdata v)
            {
                v2g o;
                if(v.vertex.y < 0)
                {
                    v.vertex.x *= _Slider;
                    v.vertex.z *= _Slider;
                }
                o.vertex = (v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //UNITY_TRANSFER_FOG(o,o.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            [maxvertexcount(9)]
            void geom(triangle v2g input[3], inout TriangleStream<g2f> outStream)
            {
                if(input[0].vertex.y > 0 && input[1].vertex.y > 0 && input[2].vertex.y > 0){
                    g2f center;
                    center.vertex = UnityObjectToClipPos(float4(0,input[0].vertex.y+_SpikeHeight,0,1));
                    center.uv = float2(0.5, 0.5);
                    center.normal = input[0].normal;
                    for (float i = 0; i < 3; i++)
                    {
                        g2f o;
                        o.uv = input[i].uv;
                        o.normal = input[i].normal;
                        o.vertex = UnityObjectToClipPos(input[i].vertex);

                        g2f o2;
                        o2.uv = input[(i+1)%3].uv;
                        o2.normal = input[(i+1)%3].normal;
                        o2.vertex = UnityObjectToClipPos(input[(i+1)%3].vertex);

                        outStream.Append(o);
                        outStream.Append(o2);
                        outStream.Append(center);
                    }
                }
                else{
                    for (float i = 0; i < 3; i++)
                    {
                        g2f o;
                        o.uv = input[i].uv;
                        o.normal = input[i].normal;
                        o.vertex = UnityObjectToClipPos(input[i].vertex);
                        outStream.Append(o);
                    }
                }
            }

            fixed4 frag (g2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float4 normalContribution;
                if(i.uv.x > _Value && i.uv.y > _Value && i.uv.x < 1-_Value && i.uv.y < 1-_Value)
                {
                    normalContribution = abs(float4(i.normal,1));
                }else
                {
                    normalContribution = float4(i.uv,0,1);
                }
                col *= normalContribution;
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}