using UnityEditor;
using UnityEngine;

/// <summary>
/// deferred aa editor
/// </summary>
[CustomEditor(typeof(DeferredMSAA))]
public class DeferredMSAAEditor : Editor
{
    [DrawGizmo(GizmoType.NotInSelectionHierarchy)]
    static void RenderCustomGizmo(Transform objectTransform, GizmoType gizmoType)
    {
        DeferredMSAA.isSceneView = true;
    }
}
