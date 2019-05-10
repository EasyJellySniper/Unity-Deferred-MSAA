// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Custom-DeferredShading" {
Properties {
    _LightTexture0 ("", any) = "" {}
    _LightTextureB0 ("", 2D) = "" {}
    _ShadowMapTexture ("", any) = "" {}
    _SrcBlend ("", Float) = 1
    _DstBlend ("", Float) = 1
}
SubShader {

// Pass 1: Lighting pass
//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
//  HDR case - Lighting additively blended into floating point buffer
Pass {
    ZWrite Off
    Blend [_SrcBlend] [_DstBlend]

CGPROGRAM
#pragma target 5.0
#pragma vertex vert_deferred
#pragma fragment frag
#pragma multi_compile_lightpass
#pragma multi_compile ___ UNITY_HDR_ON

#pragma exclude_renderers nomrt

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardBRDF.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

Texture2DArray<float4> _GBuffer0;
Texture2DArray<float4> _GBuffer1;
Texture2DArray<float4> _GBuffer2;

uint _MsaaFactor;
float _MsaaThreshold;
float _DebugMsaa;

half4 CalculateLight (unity_v2f_deferred i)
{
    float3 wpos;
    float2 uv;
    float atten, fadeDist;
    UnityLight light;
    UNITY_INITIALIZE_OUTPUT(UnityLight, light);
    UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);

    light.color = _LightColor.rgb * atten;

    // unpack Gbuffer
	half4 gbuffer0 = tex2D(_CameraGBufferTexture0, uv);
    half4 gbuffer1 = tex2D(_CameraGBufferTexture1, uv);
    half4 gbuffer2 = tex2D(_CameraGBufferTexture2, uv);

	half4 col = 0;

	[branch]
	if (_MsaaFactor > 1)
	{
		// edge detect (normal difference)
		float3 n0 = _GBuffer2.Load(uint4(uv * _ScreenParams.xy, 0, 0)).xyz;
		bool needMSAA = false;
		for (uint a = 1; a < _MsaaFactor; a++)
		{
			float3 n1 = _GBuffer2.Load(uint4(uv * _ScreenParams.xy, a, 0)).xyz;
			needMSAA = needMSAA || abs(dot(abs(n0.xyz - n1.xyz), float3(1, 1, 1))) > _MsaaThreshold;
		}
		uint msaaCount = lerp(1, _MsaaFactor, needMSAA);
		
		[branch]
		if (_DebugMsaa && needMSAA)
			return float4(1, 0, 0, 1);
		
		for (a = 0; a < msaaCount; a++)
		{
			gbuffer0 = _GBuffer0.Load(uint4(uv * _ScreenParams.xy, a, 0));
			gbuffer1 = _GBuffer1.Load(uint4(uv * _ScreenParams.xy, a, 0));
			gbuffer2 = _GBuffer2.Load(uint4(uv * _ScreenParams.xy, a, 0));
			UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

			float3 eyeVec = normalize(wpos - _WorldSpaceCameraPos);
			half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

			UnityIndirect ind;
			UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
			ind.diffuse = 0;
			ind.specular = 0;

			col += UNITY_BRDF_PBS(data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);
		}
		col /= msaaCount;
	}
	else
	{
		UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

		float3 eyeVec = normalize(wpos - _WorldSpaceCameraPos);
		half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

		UnityIndirect ind;
		UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
		ind.diffuse = 0;
		ind.specular = 0;

		col = UNITY_BRDF_PBS(data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);
	}

    return col;
}

#ifdef UNITY_HDR_ON
half4
#else
fixed4
#endif
frag (unity_v2f_deferred i) : SV_Target
{
    half4 c = CalculateLight(i);
    #ifdef UNITY_HDR_ON
    return c;
    #else
    return exp2(-c);
    #endif
}

ENDCG
}


// Pass 2: Final decode pass.
// Used only with HDR off, to decode the logarithmic buffer into the main RT
Pass {
    ZTest Always Cull Off ZWrite Off
    Stencil {
        ref [_StencilNonBackground]
        readmask [_StencilNonBackground]
        // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
        compback equal
        compfront equal
    }

CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

#include "UnityCG.cginc"

sampler2D _LightBuffer;
struct v2f {
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.texcoord = texcoord.xy;
#ifdef UNITY_SINGLE_PASS_STEREO
    o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
#endif
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    return -log2(tex2D(_LightBuffer, i.texcoord));
}
ENDCG
}

}
Fallback Off
}
