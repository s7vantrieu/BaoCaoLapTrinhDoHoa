Shader "Diorama/URP_Water_Optimized"
{
    Properties
    {
        _WaterColor ("Water Color", Color) = (0.1, 0.5, 0.7, 0.8)
        [Normal] _NormalMap ("Water Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Strength", Range(0, 2)) = 1.0

        [Header(Scrolling Animation)]
        _Scroll1 ("Scroll Layer 1 (X, Y)", Vector) = (0.05, 0.05, 0, 0)
        _Scroll2 ("Scroll Layer 2 (X, Y)", Vector) = (-0.03, 0.08, 0, 0)
        
        _Smoothness ("Water Specular", Range(0, 1)) = 0.9
    }

    SubShader
    {
        // Khai báo URP, chuyển sang chế độ Trong Suốt để nhìn xuyên thấu
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" } 

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float2 uv           : TEXCOORD1;
                float3 normalWS     : NORMAL;
                float3 tangentWS    : TANGENT;
                float3 bitangentWS  : TEXCOORD2;
            };

            sampler2D _NormalMap;

            CBUFFER_START(UnityPerMaterial)
                float4 _NormalMap_ST;
                float4 _WaterColor;
                float _BumpScale;
                float2 _Scroll1;
                float2 _Scroll2;
                float _Smoothness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // SIÊU TỐI ƯU: Không có bất kỳ thuật toán dịch chuyển đỉnh (vertex displacement) nào ở đây
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _NormalMap);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = normalInputs.tangentWS;
                OUT.bitangentWS = normalInputs.bitangentWS;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 1. Tạo hiệu ứng trượt UV theo thời gian (_Time.y)
                float2 uv1 = IN.uv + _Scroll1 * _Time.y;
                float2 uv2 = IN.uv * 1.5 + _Scroll2 * _Time.y; // Layer 2 nhân tỷ lệ 1.5 để sóng to nhỏ khác nhau

                // 2. Lấy mẫu 2 lớp Normal Map đang trượt
                float3 normal1 = UnpackNormalScale(tex2D(_NormalMap, uv1), _BumpScale);
                float3 normal2 = UnpackNormalScale(tex2D(_NormalMap, uv2), _BumpScale);

                // 3. Trộn (Blend) 2 lớp Normal lại để tạo sự nhiễu loạn tự nhiên
                float3 blendedNormalTS = normalize(float3(normal1.xy + normal2.xy, normal1.z * normal2.z));

                // 4. Chuyển về không gian Thế giới (World Space)
                float3x3 TBN = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
                float3 finalNormalWS = normalize(mul(blendedNormalTS, TBN));

                // 5. TÍNH TOÁN ÁNH SÁNG
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 viewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);

                // Độ sáng khuếch tán (Diffuse)
                float NdotL = saturate(dot(finalNormalWS, lightDir));
                float3 diffuse = mainLight.color * NdotL;

                // Độ chói lấp lánh của nước (Specular)
                float3 halfVector = normalize(lightDir + viewDir);
                float NdotH = saturate(dot(finalNormalWS, halfVector));
                float specularPower = exp2(10.0 * _Smoothness + 1.0); 
                float specular = pow(NdotH, specularPower) * _Smoothness;

                // Ánh sáng môi trường (để nước không bị tối đen)
                float3 ambient = float3(0.1, 0.15, 0.25); 

                // 6. TỔNG HỢP MÀU
                float3 finalRGB = _WaterColor.rgb * (diffuse + ambient) + (mainLight.color * specular);
                
                return half4(finalRGB, _WaterColor.a);
            }
            ENDHLSL
        }
    }
}