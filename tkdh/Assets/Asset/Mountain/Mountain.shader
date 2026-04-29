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
            // Hỗ trợ thư viện ánh sáng cốt lõi của URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

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
                float3 normalWS     : NORMAL;
                float hValue        : TEXCOORD3; // Truyền độ cao xuống Fragment
            };

            // Khai báo Texture
            sampler2D _GrassTex;
            sampler2D _RockTex;
            sampler2D _SnowTex;
            sampler2D _HeightMap;
            
            CBUFFER_START(UnityPerMaterial)
                float _Height;
            CBUFFER_END

            // --- VERTEX SHADER: Đẩy núi lên ---
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // Đọc HeightMap để lấy độ cao (Dùng tex2Dlod trong Vertex)
                float4 heightData = tex2Dlod(_HeightMap, float4(input.uv, 0, 0));
                float h = heightData.r;
                
                // Đẩy trục Y của mô hình gốc lên
                input.positionOS.y += h * _Height;

                // Tính toán vị trí World Space để tính ánh sáng
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                
                // Chuyển Normal từ Object Space sang World Space (quan trọng để nhận bóng tối chuẩn)
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                output.uv = input.uv;
                output.hValue = h; // Truyền chiều cao xuống để phân tầng màu
                
                return output;
            }

            // --- FRAGMENT SHADER: Phân tầng màu & Tính ánh sáng ---
            half4 frag(Varyings input) : SV_Target
            {
                // 1. PHÂN TẦNG SINH THÁI DỰA VÀO ĐỘ CAO (Giống hệt logic cũ của em)
                half4 colGrass = tex2D(_GrassTex, input.uv);
                half4 colRock = tex2D(_RockTex, input.uv);
                half4 colSnow = tex2D(_SnowTex, input.uv);

                half4 baseColor = colSnow;
                float h = input.hValue;

                if(h < 0.3) {
                    baseColor = colGrass;
                } 
                else if(h < 0.5) {
                    baseColor = lerp(colGrass, colRock, (h - 0.3) * 5.0);
                } 
                else if(h < 0.7) {
                    baseColor = colRock;
                } 
                else if(h < 0.9) {
                    baseColor = lerp(colRock, colSnow, (h - 0.7) * 5.0);
                }

                // 2. TÍNH TOÁN ÁNH SÁNG MẶT TRỜI TRONG URP
                Light mainLight = GetMainLight(); // Lấy nguồn sáng chính (Directional Light)
                
                // Công thức Lambert (N.L): Góc giữa ánh sáng và bề mặt
                // saturate() giới hạn giá trị từ 0 đến 1 để sườn núi khuất nắng không bị âm màu
                float NdotL = saturate(dot(input.normalWS, mainLight.direction));
                
                // Tính màu cuối cùng = Màu gốc * Màu Mặt Trời * Cường độ nắng + Ánh sáng môi trường (Ambient)
                half3 finalRGB = baseColor.rgb * mainLight.color * NdotL + (baseColor.rgb * 0.2); // + 0.2 để mặt tối không bị đen kịt

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }
        
        // --- PASS ĐỔ BÓNG (SHADOW CASTER) ---
        // Bắt buộc phải có đoạn này để ngọn núi tạo ra cái bóng in xuống mặt nước hoặc các ngọn núi khác
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
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            sampler2D _HeightMap;
            float _Height;

            Varyings vertShadow(Attributes input)
            {
                Varyings output;
                
                // 1. Vẫn đọc HeightMap để đẩy đỉnh núi lên (để bóng in đúng hình núi lồi lõm)
                float4 heightData = tex2Dlod(_HeightMap, float4(input.uv, 0, 0));
                input.positionOS.y += heightData.r * _Height;

                // 2. CÁCH MỚI: Tự tính toán không gian thủ công thay vì nhờ URP
                // Chuyển từ không gian Object (mô hình) sang không gian World (thế giới)
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // Chuyển từ World sang Clip Space (để vẽ cái bóng ra màn hình)
                output.positionCS = TransformWorldToHClip(positionWS);

                return output;
            }

            half4 fragShadow(Varyings input) : SV_Target
            {
                return 0; // Shadow Caster không cần trả về màu, nó chỉ ghi độ sâu
            }
            ENDHLSL
        }
    }
}