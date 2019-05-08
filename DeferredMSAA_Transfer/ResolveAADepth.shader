Shader "Custom/ResolveAADepth"
{
	Properties
	{

	}
	SubShader
	{
		// No culling but need depth
		Cull Off ZWrite On ZTest Always
		ColorMask 0

		Pass
		{
			Stencil
			{
				Ref 192
				Comp always
				Pass replace
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
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
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			Texture2DMS<float, 2> _MsaaTex_2X;
			Texture2DMS<float, 4> _MsaaTex_4X;
			Texture2DMS<float, 8> _MsaaTex_8X;
			float _MsaaFactor;

			float Resolve2X(v2f i)
			{
				float col = 1;

				[unroll]
				float baseCol = _MsaaTex_2X.Load(i.vertex.xy, 0).r;
				for (uint a = 0; a < 2; a++)
				{
					float depth = _MsaaTex_2X.Load(i.vertex.xy, a).r;
					col = min(depth, col);
					baseCol = max(depth, baseCol);
				}
				
				col = lerp(col, baseCol, col == 0.0f);

				return col;
			}

			float Resolve4X(v2f i)
			{
				float col = 1;

				[unroll]
				float baseCol = _MsaaTex_4X.Load(i.vertex.xy, 0).r;
				for (uint a = 0; a < 4; a++)
				{
					float depth = _MsaaTex_4X.Load(i.vertex.xy, a).r;
					col = min(depth, col);
					baseCol = max(depth, baseCol);
				}
				
				col = lerp(col, baseCol, col == 0.0f);

				return col;
			}

			float Resolve8X(v2f i)
			{
				float col = 1;

				[unroll]
				float baseCol = _MsaaTex_8X.Load(i.vertex.xy, 0).r;
				for (uint a = 0; a < 8; a++)
				{
					float depth = _MsaaTex_8X.Load(i.vertex.xy, a).r;
					col = min(depth, col);
					baseCol = max(depth, baseCol);
				}
				
				col = lerp(col, baseCol, col == 0.0f);

				return col;
			}

			float frag(v2f i, out float oDepth : SV_Depth) : SV_Target
			{
				float col = 1;

				[branch]
				if (_MsaaFactor == 2)
					col = Resolve2X(i);
				else if (_MsaaFactor == 4)
					col = Resolve4X(i);
				else if (_MsaaFactor == 8)
					col = Resolve8X(i);

				oDepth = col;

				return col;
			}
			ENDCG
		}
	}
}
