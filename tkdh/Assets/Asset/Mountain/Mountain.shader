Shader "Diorama/URP_TerrainEcosystem"
{
    Properties
    {
        _GrassTex("Grass Texture", 2D) = "white" {}
        _RockTex("Rock Texture", 2D) = "white" {}
        _SnowTex("Snow Texture", 2D) = "white" {}
        
        _HeightMap("Height Map", 2D) = "black" {}
        _Height("Mountain Height", Range(0, 50)) = 10
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            // Khai báo các biến thể bóng đổ cho URP
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD3; // Đổi semantic để tránh trùng
                float4 shadowCoord  : TEXCOORD4;
                float hValue        : TEXCOORD5;
            };

            sampler2D _GrassTex; sampler2D _RockTex; sampler2D _SnowTex; sampler2D _HeightMap;
            
            CBUFFER_START(UnityPerMaterial)
                float _Height;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // MESH ĐÃ CÓ CHIỀU CAO -> KHÔNG CỘNG THÊM Ở ĐÂY
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = input.uv;
                
                // Lấy độ cao từ HeightMap chỉ để phục vụ việc trộn màu (Material Blending)
                output.hValue = tex2Dlod(_HeightMap, float4(input.uv, 0, 0)).r;
                
                // TÍNH TOÁN TỌA ĐỘ BÓNG ĐỔ: Điểm mấu chốt để nhận bóng từ Player
                output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 1. Phân tầng sinh thái (Giữ nguyên logic của em)
                half4 colGrass = tex2D(_GrassTex, input.uv);
                half4 colRock = tex2D(_RockTex, input.uv);
                half4 colSnow = tex2D(_SnowTex, input.uv);
                float h = input.hValue;
                half4 baseColor = (h < 0.3) ? colGrass : (h < 0.5) ? lerp(colGrass, colRock, (h - 0.3) * 5.0) : (h < 0.7) ? colRock : (h < 0.9) ? lerp(colRock, colSnow, (h - 0.7) * 5.0) : colSnow;

                // 2. Tính toán ánh sáng và nhận bóng đổ
                Light mainLight = GetMainLight(input.shadowCoord); 
                float NdotL = saturate(dot(input.normalWS, mainLight.direction));
                
                // Nhân thêm shadowAttenuation để hiện bóng của Player
                half3 finalRGB = baseColor.rgb * mainLight.color * (NdotL * mainLight.shadowAttenuation) + (baseColor.rgb * 0.2);

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
        
        // --- PASS ĐỔ BÓNG (SHADOW CASTER) ---
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma vertex vertShadow
            #pragma fragment fragShadow

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            Varyings vertShadow(Attributes input)
            {
                Varyings output;
                // MESH ĐÃ CÓ CHIỀU CAO -> TUYỆT ĐỐI KHÔNG CỘNG THÊM Ở ĐÂY
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // Dùng ApplyShadowBias để bóng đổ mượt mà và không bị lỗi hiển thị
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));

                return output;
            }

            half4 fragShadow(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}