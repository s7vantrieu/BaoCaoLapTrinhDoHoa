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
            // Bật GPU Instancing: mỗi instance tự mang matrix riêng
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                // Bắt buộc: Unity dùng slot này để inject per-instance ID
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : NORMAL;
                float4 shadowCoord : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
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

                // Thiết lập instance ID để Unity biết đang xử lý instance nào
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);

                // TransformObjectToWorld tự dùng per-instance matrix từ grassBatches[]
                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);

                // GIÓ THỔI: Chỉ thổi phần ngọn (uv.y > 0)
                float windX = sin(_Time.y * _WindSpeed + worldPos.x) * _WindStrength * IN.uv.y;
                float windZ = cos(_Time.y * _WindSpeed * 0.8 + worldPos.z) * _WindStrength * IN.uv.y;

                worldPos.x += windX;
                worldPos.z += windZ;

                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.positionWS = worldPos;
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(worldPos);

                // Fix Normals cho mặt sau của lá cỏ (luôn hướng lên trên để đón ánh sáng mặt trời)
                OUT.normalWS = float3(0, 1, 0);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(IN);

                // 1. Lấy màu ảnh và cắt viền
                half4 texColor = tex2D(_BaseMap, IN.uv);
                clip(texColor.a - _Cutoff);

                // 2. Tính ánh sáng sương sương cho nổi khối (có bóng đổ)
                Light mainLight = GetMainLight(IN.shadowCoord);
                float NdotL = saturate(dot(IN.normalWS, mainLight.direction));
                float3 diffuse = mainLight.color * (NdotL + 0.3) * mainLight.shadowAttenuation; // Nhân bóng đổ

                // 3. Phối màu Texture gốc với màu Tint (để tự chỉnh cho đồng bộ với cảnh)
                float3 finalColor = (texColor.rgb * _BaseColor.rgb) * diffuse;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // --- PASS ĐỔ BÓNG (SHADOW CASTER) ---
        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}

            HLSLPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _BaseMap;
            CBUFFER_START(UnityPerMaterial)
                float _Cutoff;
                float _WindSpeed;
                float _WindStrength;
            CBUFFER_END

            Varyings vertShadow(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                // Áp dụng wind effect
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                float windX = sin(_Time.y * _WindSpeed + worldPos.x) * _WindStrength * input.uv.y;
                float windZ = cos(_Time.y * _WindSpeed * 0.8 + worldPos.z) * _WindStrength * input.uv.y;

                worldPos.x += windX;
                worldPos.z += windZ;

                output.positionCS = TransformWorldToHClip(worldPos);
                output.uv = input.uv;

                return output;
            }

            half4 fragShadow(Varyings input) : SV_Target
            {
                // Cắt viền alpha như forward pass
                half4 texColor = tex2D(_BaseMap, input.uv);
                clip(texColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }
}