Shader "URP_ProceduralClouds"
{
    Properties
    {
        _CloudColor ("Cloud Color", Color) = (1, 1, 1, 0.8)
        _Density ("Cloud Density", Range(0, 1)) = 0.45
        _Softness ("Cloud Fluffiness", Range(0.01, 0.5)) = 0.2
        _Speed ("Wind Speed", Float) = 0.5
        _Scale ("Cloud Scale", Float) = 4.0
    }
    
    SubShader
    {
        // Khai báo là vật thể trong suốt
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off // Không ghi đè Z-buffer để mây hòa quyện với nước/cỏ
        Cull Off   // Nhìn được mây từ cả trên lẫn dưới

        Pass
        {
            Name "UnlitCloud"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _CloudColor;
                float _Density;
                float _Softness;
                float _Speed;
                float _Scale;
            CBUFFER_END

            // --- THUẬT TOÁN TẠO NHIỄU (NOISE) KHÔNG CẦN ẢNH TEXTURE ---
            float hash(float2 p) {
                float h = dot(p, float2(127.1, 311.7));
                return frac(sin(h) * 43758.5453123);
            }
            
            float noise(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                
                return lerp(
                    lerp(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), f.x),
                    lerp(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), f.x),
                    f.y);
            }

            // Fractal Brownian Motion (FBM) để làm mây cuộn nhiều lớp
            float fbm(float2 p) {
                float f = 0.0;
                float amp = 0.5;
                for(int i = 0; i < 4; i++) {
                    f += amp * noise(p);
                    p *= 2.0;
                    amp *= 0.5;
                }
                return f;
            }

            Varyings vert(Attributes IN) {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target {
                // 1. Trượt tọa độ UV theo thời gian để mây trôi
                float2 scrolledUV = IN.uv * _Scale + float2(_Time.y * _Speed, _Time.y * (_Speed * 0.7));
                
                // 2. Tạo hình dáng mây
                float cloudNoise = fbm(scrolledUV);
                
                // 3. Cắt bớt phần mây thưa để tạo thành từng cụm bồng bềnh
                float alpha = smoothstep(_Density - _Softness, _Density + _Softness, cloudNoise);
                
                // 4. BÍ QUYẾT: Làm mờ viền xung quanh để không bị lộ hình vuông của tấm lưới (Mesh)
                // Tâm là (0.5, 0.5). Càng xa tâm càng mờ đi.
                float distFromCenter = distance(IN.uv, float2(0.5, 0.5));
                float radialFade = 1.0 - smoothstep(0.2, 0.5, distFromCenter); 
                
                // Trộn độ trong suốt cuối cùng
                float finalAlpha = alpha * _CloudColor.a * radialFade;
                
                return half4(_CloudColor.rgb, finalAlpha);
            }
            ENDHLSL
        }
    }
}