﻿using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// deferred msaa
/// </summary>
[RequireComponent(typeof(Camera))]
public class DeferredMSAA : MonoBehaviour
{
    [DllImport("SetGBufferTarget")]
    static extern bool SetGBufferColor(int _index, int _msaaFactor, IntPtr _colorBuffer);

    [DllImport("SetGBufferTarget")]
    static extern bool SetGBufferDepth(int _msaaFactor, IntPtr _depthBuffer);

    [DllImport("SetGBufferTarget")]
    static extern void Release();

    [DllImport("SetGBufferTarget")]
    static extern IntPtr GetRenderEventFunc();

    /// <summary>
    /// msaa factor
    /// </summary>
    public int msaaFactor = 2;

    /// <summary>
    /// resolve aa material
    /// </summary>
    public Material resolveAA;

    /// <summary>
    /// transfer aa instead resolve
    /// </summary>
    public Material transferAA;

    /// <summary>
    /// resolve aa depth material
    /// </summary>
    public Material resolveAADepth;

    RenderTexture diffuseRT;
    RenderTexture specularRT;
    RenderTexture normalRT;
    RenderTexture emissionRT;
    RenderTexture depthRT;
    RenderTexture skyTexture;

    RenderTexture diffuseAry;
    RenderTexture specularAry;
    RenderTexture normalAry;

    Camera attachedCam;
    CommandBuffer msGBuffer;
    CommandBuffer copyGBuffer;

    bool initSucceed = true;
    string[] texName = { "_MsaaTex_2X", "_MsaaTex_4X", "_MsaaTex_8X" };
    int lastWidth;
    int lastHeight;
    int lastMsaa;

    void Awake()
    {
        attachedCam = GetComponent<Camera>();

        if (attachedCam.actualRenderingPath == RenderingPath.DeferredShading)
        {
            CreateMapAndColorBuffer("Custom diffuse", 0, RenderTextureFormat.ARGB32, 0, msaaFactor, ref diffuseRT);
            CreateMapAndColorBuffer("Custom specular", 0, RenderTextureFormat.ARGB32, 1, msaaFactor, ref specularRT);
            CreateMapAndColorBuffer("Custom normal", 0, RenderTextureFormat.ARGB2101010, 2, msaaFactor, ref normalRT);
            CreateMapAndColorBuffer("Custom emission", 0, attachedCam.allowHDR ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.ARGB2101010, 3, msaaFactor, ref emissionRT);
            CreateMapAndColorBuffer("Cutsom depth", 32, RenderTextureFormat.Depth, -1, msaaFactor, ref depthRT);
            CreateMapAndColorBuffer("Sky Texture", 0, RenderTextureFormat.ARGB32, -1, 1, ref skyTexture);

            CreateAryMap("Diffuse Ary", RenderTextureFormat.ARGB32, ref diffuseAry);
            CreateAryMap("Specular Ary", RenderTextureFormat.ARGB32, ref specularAry);
            CreateAryMap("Normal Ary", RenderTextureFormat.ARGB2101010, ref normalAry);

            initSucceed = initSucceed && SetGBufferDepth(msaaFactor, depthRT.GetNativeDepthBufferPtr());

            if (!initSucceed)
            {
                Debug.Log("MainGraphic : [DeferredModifier] detph native failed.");
                enabled = false;
                OnDestroy();
                return;
            }

            msGBuffer = new CommandBuffer();
            msGBuffer.name = "Bind MS GBuffer";
            msGBuffer.IssuePluginEvent(GetRenderEventFunc(), 0);

            copyGBuffer = new CommandBuffer();
            copyGBuffer.name = "Copy MS GBuffer";

            if (msaaFactor <= 1)
            {
                copyGBuffer.Blit(diffuseRT, BuiltinRenderTextureType.GBuffer0);
                copyGBuffer.Blit(specularRT, BuiltinRenderTextureType.GBuffer1);
                copyGBuffer.Blit(normalRT, BuiltinRenderTextureType.GBuffer2);
                copyGBuffer.Blit(emissionRT, BuiltinRenderTextureType.CameraTarget);
                copyGBuffer.IssuePluginEvent(GetRenderEventFunc(), 1);
                copyGBuffer.SetGlobalFloat("_MsaaFactor", msaaFactor);
            }
            else
            {
                copyGBuffer.SetGlobalFloat("_MsaaFactor", msaaFactor);
                copyGBuffer.SetGlobalTexture("_SkyTextureForResolve", skyTexture);

                int texIdx = 0;
                texIdx = (msaaFactor == 4) ? 1 : texIdx;
                texIdx = (msaaFactor == 8) ? 2 : texIdx;

                copyGBuffer.SetGlobalTexture(texName[texIdx], emissionRT);
                copyGBuffer.Blit(null, BuiltinRenderTextureType.CameraTarget, resolveAA);

                copyGBuffer.SetGlobalTexture(texName[texIdx], depthRT);
                copyGBuffer.Blit(null, BuiltinRenderTextureType.CameraTarget, resolveAADepth);

                for (int i = 0; i < msaaFactor; i++)
                {
                    copyGBuffer.SetGlobalFloat("_TransferAAIndex", i);

                    copyGBuffer.SetRenderTarget(diffuseAry, 0, CubemapFace.Unknown, i);
                    copyGBuffer.SetGlobalTexture("_MsaaTex", diffuseRT);
                    copyGBuffer.Blit(null, BuiltinRenderTextureType.CurrentActive, transferAA);

                    copyGBuffer.SetRenderTarget(specularAry, 0, CubemapFace.Unknown, i);
                    copyGBuffer.SetGlobalTexture("_MsaaTex", specularRT);
                    copyGBuffer.Blit(null, BuiltinRenderTextureType.CurrentActive, transferAA);

                    copyGBuffer.SetRenderTarget(normalAry, 0, CubemapFace.Unknown, i);
                    copyGBuffer.SetGlobalTexture("_MsaaTex", normalRT);
                    copyGBuffer.Blit(null, BuiltinRenderTextureType.CurrentActive, transferAA);
                }

                copyGBuffer.SetGlobalTexture("_GBuffer0", diffuseAry);
                copyGBuffer.SetGlobalTexture("_GBuffer1", specularAry);
                copyGBuffer.SetGlobalTexture("_GBuffer2", normalAry);
            }
        }

        lastWidth = Screen.width;
        lastHeight = Screen.height;
        lastMsaa = msaaFactor;
    }

    void OnEnable()
    {
        if (msGBuffer != null)
        {
            attachedCam.AddCommandBuffer(CameraEvent.BeforeGBuffer, msGBuffer);
        }

        if (copyGBuffer != null)
        {
            attachedCam.AddCommandBuffer(CameraEvent.AfterGBuffer, copyGBuffer);
        }
    }

    void OnDisable()
    {
        if (msGBuffer != null)
        {
            attachedCam.RemoveCommandBuffer(CameraEvent.BeforeGBuffer, msGBuffer);
        }

        if (copyGBuffer != null)
        {
            attachedCam.RemoveCommandBuffer(CameraEvent.AfterGBuffer, copyGBuffer);
        }
    }

    void OnDestroy()
    {
        if (msGBuffer != null)
        {
            attachedCam.RemoveCommandBuffer(CameraEvent.BeforeGBuffer, msGBuffer);
            msGBuffer.Release();
        }

        if (copyGBuffer != null)
        {
            attachedCam.RemoveCommandBuffer(CameraEvent.AfterGBuffer, copyGBuffer);
            copyGBuffer.Release();
        }

        DestroyMap(diffuseRT);
        DestroyMap(specularRT);
        DestroyMap(normalRT);
        DestroyMap(emissionRT);
        DestroyMap(depthRT);
        DestroyMap(skyTexture);

        DestroyMap(diffuseAry);
        DestroyMap(specularAry);
        DestroyMap(normalAry);

        Release();
    }

    void OnPreCull()
    {
        Graphics.SetRenderTarget(skyTexture);
        if (attachedCam.clearFlags == CameraClearFlags.Skybox)
        {
            GL.ClearWithSkybox(false, attachedCam);
        }
        else
        {
            GL.Clear(false, true, attachedCam.backgroundColor);
        }
        Graphics.SetRenderTarget(null);
    }

    void Update()
    {
#if DEBUG
        bool needResize = Screen.width != lastWidth || Screen.height != lastHeight || lastMsaa != msaaFactor;
        if (needResize)
        {
            OnDestroy();
            Awake();
            OnEnable();
        }

        lastWidth = Screen.width;
        lastHeight = Screen.height;
        lastMsaa = msaaFactor;
#endif
    }

    void CreateMapAndColorBuffer(string _rtName, int _depth, RenderTextureFormat _format, int _gBufferIdx, int _msaaFactor, ref RenderTexture _rt)
    {
        _rt = new RenderTexture(Screen.width, Screen.height, _depth, _format, RenderTextureReadWrite.Linear);
        _rt.name = _rtName;
        _rt.antiAliasing = _msaaFactor;
        _rt.bindTextureMS = (_msaaFactor > 1);
        _rt.Create();   // create rt so that we have native ptr

        if (_gBufferIdx >= 0)
        {
            bool nativeSucceed = SetGBufferColor(_gBufferIdx, _msaaFactor, _rt.GetNativeTexturePtr());
            if (!nativeSucceed)
            {
                Debug.Log("MainGraphic : [DeferredModifier] " + _rtName + " native failed.");
                initSucceed = false;
            }
        }
    }

    void CreateAryMap(string _rtName, RenderTextureFormat _format, ref RenderTexture _rt)
    {
        _rt = new RenderTexture(Screen.width, Screen.height, 0, _format, RenderTextureReadWrite.Linear);
        _rt.name = _rtName;
        _rt.dimension = TextureDimension.Tex2DArray;
        _rt.volumeDepth = msaaFactor;
    }

    void DestroyMap(RenderTexture _rt)
    {
        if (_rt)
        {
            _rt.Release();
            DestroyImmediate(_rt);
        }
    }
}
