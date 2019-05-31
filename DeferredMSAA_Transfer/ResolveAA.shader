Shader "Custom/ResolveAA"
{
	Properties
	{

	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
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

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			Texture2DMS<float4, 2> _MsaaTex_2X;
			Texture2DMS<float4, 4> _MsaaTex_4X;
			Texture2DMS<float4, 8> _MsaaTex_8X;
			float _MsaaFactor;
			sampler2D _SkyTextureForResolve;
			float _IsNormal;

			float4 Resolve2X(v2f i)
			{
				float4 col = 0;
				float4 skyColor = tex2D(_SkyTextureForResolve, i.uv);
				skyColor.a = 1;
				float subCount = 0;

				[unroll]
				for (uint a = 0; a < 2; a++)
				{
					float4 data = _MsaaTex_2X.Load(i.vertex.xy, a);
					subCount = lerp(subCount, subCount + 1, length(data) == 0 && _IsNormal);
					data = lerp(data, skyColor, data.a < 0);
					col += data;
				}
				col /= (_MsaaFactor - subCount);

				return col;
			}

			float4 Resolve4X(v2f i)
			{
				float4 col = 0;
				float4 skyColor = tex2D(_SkyTextureForResolve, i.uv);
				skyColor.a = 1;
				float subCount = 0;

				[unroll]
				for (uint a = 0; a < 4; a++)
				{
					float4 data = _MsaaTex_4X.Load(i.vertex.xy, a);
					subCount = lerp(subCount, subCount + 1, length(data) == 0 && _IsNormal);
					data = lerp(data, skyColor, data.a < 0);
					col += data;
				}
				col /= (_MsaaFactor - subCount);

				return col;
			}

			float4 Resolve8X(v2f i)
			{
				float4 col = 0;
				float4 skyColor = tex2D(_SkyTextureForResolve, i.uv);
				skyColor.a = 1;
				float subCount = 0;

				[unroll]
				for (uint a = 0; a < 8; a++)
				{
					float4 data = _MsaaTex_8X.Load(i.vertex.xy, a);
					subCount = lerp(subCount, subCount + 1, length(data) == 0 && _IsNormal);
					data = lerp(data, skyColor, data.a < 0);
					col += data;
				}
				col /= (_MsaaFactor - subCount);

				return col;
			}

			float4 frag (v2f i) : SV_Target
			{
				float4 col = 0;

				[branch]
				if (_MsaaFactor == 2)
					col = Resolve2X(i);
				else if (_MsaaFactor == 4)
					col = Resolve4X(i);
				else if (_MsaaFactor == 8)
					col = Resolve8X(i);

				return col;
			}
			ENDCG
		}
	}
}
