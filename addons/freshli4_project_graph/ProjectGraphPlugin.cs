#if TOOLS
using Godot;
using System;
using System.Linq;
namespace FreshLi4.ProjectGraph;

[Tool]
public partial class ProjectGraphPlugin : EditorPlugin
{
    private ProjectGraphPanel? _panel;
    public override void _EnterTree()
    {
        _panel = new ProjectGraphPanel { Name = "FreshLi4ProjectGraph" };
        _panel.AssetActivated += OpenAsset; _panel.AssetRevealRequested += ShowAssetInFileSystem;
        EditorInterface.Singleton.GetEditorMainScreen().AddChild(_panel); _MakeVisible(false);
        if (OS.GetCmdlineUserArgs().Contains("--project-graph-smoke")) Callable.From(_panel.RunEditorSmoke).CallDeferred();
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_panel)) { _panel!.AssetActivated -= OpenAsset; _panel.AssetRevealRequested -= ShowAssetInFileSystem; _panel.QueueFree(); }
        _panel = null;
    }
    public override bool _HasMainScreen() => true;
    public override void _MakeVisible(bool visible) { if (IsInstanceValid(_panel)) _panel!.Visible = visible; }
    public override string _GetPluginName() => "Project Graph";
    public override Texture2D _GetPluginIcon() => EditorInterface.Singleton.GetEditorTheme().GetIcon("GraphEdit", "EditorIcons");
    private static void OpenAsset(string path)
    {
        if (path.Length == 0 || !path.StartsWith("res://", StringComparison.Ordinal)) return;
        var editor = EditorInterface.Singleton;
        if (path.GetExtension().ToLowerInvariant() is "tscn" or "scn") { editor.OpenSceneFromPath(path); return; }
        var resource = ResourceLoader.Load(path);
        if (resource == null) GD.PushWarning($"Project Graph could not open missing resource: {path}");
        else if (resource is Script script) editor.EditScript(script);
        else editor.EditResource(resource);
    }
    private static void ShowAssetInFileSystem(string path)
    { if (path.Length > 0 && path.StartsWith("res://", StringComparison.Ordinal)) EditorInterface.Singleton.SelectFile(path); }
}
#endif
