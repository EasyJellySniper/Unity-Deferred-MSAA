# Unity-Deferred-MSAA

Preprocess: <br>
Test on Unity 2017.4.3f1 PRO <br>
Set Camera to Allow HDR <br>
Disable Deferred Reflection in GraphcisSettings <br>

Limits: <br>
Still no AA on transparent objects (using posteffect aa for them) <br>
Light culling mask only works with "Everything" <br>

Code Setup: <br>
1. Build native plugin project SetGBufferPluginSource, and copy [SetGBufferTarget.dll] to Plugins/x86_64
2. Attach [DeferredMSAA.cs] to your camera, and set rendering path to deferred.
3. Create materials for [ResolveAA]、[ResolveAADepth]、[TransferAA shaders], and set them to DeferredMSAA inspector.
4. Set msaa factor, and only 1, 2, 4, 8 is valid.
5. In GraphicsSettings, set deferred shading shader to [Custom-DeferredShading] or imitate the modification in [Custom-DeferredShading] shader.
