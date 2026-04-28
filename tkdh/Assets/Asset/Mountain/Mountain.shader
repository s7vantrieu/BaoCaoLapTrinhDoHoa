Shader "Unlit/TextureShader"
{
    Properties
    {
        _GrassTex("Grass Texture", 2D) = "white"{}
        _RockTex("Rock Texture", 2D) = "white"{}
        _SnowTex("Snow Texture", 2D) = "white"{}

        _HeightMap ("Height Map", 2D) = "white" {}
        _Height("Mountain Height", Range(1, 3)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float h : TEXCOORD1;
            };

            sampler2D _HeightMap;
            sampler2D _GrassTex;
            sampler2D _RockTex;
            sampler2D _SnowTex;
            float4 _HeightMap_ST;
            float4 _GrassTex_ST;
            float4 _RockTex_ST;
            float4 _SnowTex_ST;
            float _Height;
            //


            v2f vert (appdata v)
            {
                v2f o;

                float4 height = tex2Dlod(_HeightMap, float4(v.uv, 0, 0));
                float4 vert = v.vertex;
                vert.y = vert.y + height.x * _Height;

                o.vertex = UnityObjectToClipPos(vert);
                o.uv = v.uv;
                o.h = height.x;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 colGrass = tex2D(_GrassTex, i.uv);
                float4 colRock = tex2D(_RockTex, i.uv);
                float4 colSnow = tex2D(_SnowTex, i.uv);

                if(i.h < 0.3)
                {
                    return colGrass;
                } else if(i.h < 0.5)
                {
                    return lerp(colGrass, colRock, (i.h - 0.3) * 5);
                } else if(i.h < 0.7)
                {
                    return colRock;
                } else if(i.h < 0.9)
                {
                    return lerp(colRock, colSnow, (i.h - 0.7) * 5);
                }


                return colSnow;
            }
            ENDCG
        }
    }
}
