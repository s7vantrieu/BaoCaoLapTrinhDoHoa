Shader "Diorama/URP_Grass_3DVolume"
{
    Properties
    {
        _BaseMap("Grass Texture (RGBA)", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _BaseColor("Grass Tint", Color) = (0.5, 0.8, 0.3, 1)

        [Header(Wind Settings)]
        _WindSpeed("Wind Speed", Float) = 1.5
        _WindStrength("Wind Strength", Float) = 0.3
    }

    SubShader
    {
        // Quan trọng: Queue AlphaTest giúp cỏ không bị lỗi đè lên nhau
        Tags { "RenderType"="TransparentCutout" "RenderPipeline"="UniversalPipeline" "Queue"="AlphaTest" }
        LOD 200
        Cull Off // Vô hiệu hóa Culling để thấy cả 2 mặt của chữ X

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : NORMAL;
            };

            sampler2D _BaseMap;
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _Cutoff;
                float _WindSpeed;
                float _WindStrength;
            CBUFFER_END

            Varyings vert(Attributes IN) {
                Varyings OUT;
                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                
                // GIÓ THỔI: Chỉ thổi phần ngọn (uv.y > 0)
                float windX = sin(_Time.y * _WindSpeed + worldPos.x) * _WindStrength * IN.uv.y;
                float windZ = cos(_Time.y * _WindSpeed * 0.8 + worldPos.z) * _WindStrength * IN.uv.y;
                
                worldPos.x += windX;
                worldPos.z += windZ;
                
                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.positionWS = worldPos;
                OUT.uv = IN.uv;

                // Fix Normals cho mặt sau của lá cỏ (luôn hướng lên trên để đón ánh sáng mặt trời)
                OUT.normalWS = float3(0, 1, 0); 

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target {
                // 1. Lấy màu ảnh và cắt viền
                half4 texColor = tex2D(_BaseMap, IN.uv);
                clip(texColor.a - _Cutoff); 

                // 2. Tính ánh sáng sương sương cho nổi khối
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(IN.normalWS, mainLight.direction));
                float3 diffuse = mainLight.color * (NdotL + 0.3); // +0.3 Ambient để mặt khuất không bị đen

                // 3. Phối màu Texture gốc với màu Tint (để tự chỉnh cho đồng bộ với cảnh)
                float3 finalColor = (texColor.rgb * _BaseColor.rgb) * diffuse;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}