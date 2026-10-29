using Godot;
using GDictionary = Godot.Collections.Dictionary;
namespace FreshLi4.ProjectGraph;

public static class GraphStore
{
    public const string DefaultExportPath = "user://freshli4_project_graph/project-graph.json";
    public static Error SaveJson(GDictionary snapshot, string path = DefaultExportPath)
    {
        var errors = GraphSchema.ValidateSnapshot(snapshot);
        if (errors.Length > 0) { GD.PushError($"Cannot save invalid project graph: {string.Join("; ", errors)}"); return Error.InvalidData; }
        var error = DirAccess.MakeDirRecursiveAbsolute(ProjectSettings.GlobalizePath(path.GetBaseDir()));
        if (error != Error.Ok && error != Error.AlreadyExists) return error;
        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
        if (file == null) return FileAccess.GetOpenError();
        file.StoreString(Json.Stringify(snapshot, "\t", true) + "\n");
        return Error.Ok;
    }
    public static GDictionary LoadJson(string path = DefaultExportPath)
    {
        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null) return new();
        var value = Json.ParseString(file.GetAsText());
        if (value.VariantType != Variant.Type.Dictionary) return new();
        var snapshot = value.AsGodotDictionary();
        return GraphSchema.ValidateSnapshot(snapshot).Length == 0 ? snapshot : new();
    }
}
