# Unity-Deferred-MSAA
Test on Unity 2017.4.3f1 PRO <br>

Limits: <br>
No AA on transparent objects and emission objects (using posteffect aa for them) <br>
Light culling mask only works with "Everything" <br>

Code Setup: <br>
1. Copy [SetGBufferTarget.dll] to Plugins/x86_64
2. Attach [DeferredMSAA.cs] to your camera, and it will set rendering path to deferred shading.
3. Create materials for [ResolveAA]、[ResolveAADepth]、[TransferAA shaders], and set them to DeferredMSAA inspector.
4. Select msaa factor.
5. In GraphicsSettings, set deferred shading shader to [Custom-DeferredShading] or imitate the modification in [Custom-DeferredShading] shader. 
6. In GraphicsSettings, set deferred shading shader to [Custom-DeferredReflections] or imitate the modification in [Custom-DeferredReflections] shader. 
<br> <br>
