Shader "Custom/TransferAA"
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
			
			Texture2DMS<float4> _MsaaTex;
			uint _TransferAAIndex;

			float4 frag (v2f i) : SV_Target
			{
				return _MsaaTex.Load(i.vertex.xy, _TransferAAIndex);
			}
			ENDCG
		}
	}
}
