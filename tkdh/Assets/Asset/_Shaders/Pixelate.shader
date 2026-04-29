Shader "Custom/URP_Pixelate"
{
    Properties
    {
        [Header(Pixelation Settings)]
        [Toggle] _EnablePixelation("Enable Pixelation", Float) = 1
        _PixelSize("Pixel Size", Range(0.001, 0.1)) = 0.004

        [Header(Dithering Settings)]
        [Toggle] _EnableDithering("Enable Dithering", Float) = 1
        _DitherColorSteps("Dither Color Steps", Range(2, 16)) = 8
        
        [Header(Scanline Settings)]
        [Toggle] _EnableScanlines("Enable Scanlines", Float) = 1
        _ScanlineCount("Scanline Count", Range(0, 1000)) = 500
        _ScanlineIntensity("Scanline Intensity", Range(0, 1)) = 0.4
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZTest Always 
        ZWrite Off Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float _PixelSize;
            float _DitherColorSteps;
            float _ScanlineCount;
            float _ScanlineIntensity;
            float _EnablePixelation;
            float _EnableDithering;
            float _EnableScanlines;


            v2f vert (appdata IN)
            {
                v2f OUT;
                OUT.positionCS = GetFullScreenTriangleVertexPosition(IN.vertexID);
                OUT.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                return OUT;
            }

            half4 frag (v2f IN) : SV_Target
            {
                float2 uv = IN.uv;

                //Pixelation Effect
                if(_EnablePixelation == 1)
                {
                    float pixelSize = max(_PixelSize, 0.0001);
                    uv = floor(uv / pixelSize) * pixelSize;
                }

                half4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);

                //Dithring Effect
                if(_EnableDithering == 1)
                {
                    float colorSteps = _DitherColorSteps;
                    col.rgb = floor(col.rgb * colorSteps) / colorSteps;
                }
                

                //CRT Scanline Effect
                if (_EnableScanlines == 1)
                {
                    float scanline = sin(IN.uv.y * _ScanlineCount) * 0.5 + 0.5;
                    col.rgb *= lerp(1.0, scanline, _ScanlineIntensity);
                }
                return col;
    }
            ENDHLSL
        }
    }
}