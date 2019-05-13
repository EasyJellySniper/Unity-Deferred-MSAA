using UnityEditor;

/// <summary>
/// deferred aa editor
/// </summary>
[CustomEditor(typeof(DeferredMSAA))]
public class DeferredMSAAEditor : Editor
{
    bool isSceneView = false;

    void OnEnable()
    {
        EditorApplication.update -= CheckSceneView;
        EditorApplication.update += CheckSceneView;
    }

    void OnDisable()
    {
        EditorApplication.update -= CheckSceneView;
    }

    void OnSceneGUI()
    {
        isSceneView = true;
    }

    void CheckSceneView()
    {
        DeferredMSAA deferredAA = target as DeferredMSAA;
        deferredAA.enabled = !isSceneView;
        isSceneView = false;
    }
}
