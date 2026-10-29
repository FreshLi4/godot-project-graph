using Godot;
using System.Linq;
namespace FreshLi4.ProjectGraph;

public static class ScanIgnoreSettings
{
    public const string SettingsPath = "user://freshli4_project_graph/settings.cfg";
    private const string Section = "scan", Key = "ignore_patterns";
    public static string[] LoadCustomPatterns()
    {
        using var config = new ConfigFile();
        if (config.Load(SettingsPath) != Error.Ok) return System.Array.Empty<string>();
        var stored = config.GetValue(Section, Key, System.Array.Empty<string>());
        var patterns = stored.VariantType == Variant.Type.PackedStringArray ? stored.AsStringArray()
            : stored.VariantType == Variant.Type.Array ? stored.AsGodotArray().Select(v => v.AsString()).ToArray() : System.Array.Empty<string>();
        return ProjectGraphScanner.NormalizeIgnorePatterns(patterns);
    }
    public static Error SaveCustomPatterns(string[] patterns)
    {
        var error = DirAccess.MakeDirRecursiveAbsolute(ProjectSettings.GlobalizePath(SettingsPath.GetBaseDir()));
        if (error != Error.Ok && error != Error.AlreadyExists) return error;
        using var config = new ConfigFile();
        config.SetValue(Section, Key, ProjectGraphScanner.NormalizeIgnorePatterns(patterns));
        return config.Save(SettingsPath);
    }
    public static string[] ParseText(string text) => ProjectGraphScanner.NormalizeIgnorePatterns(text.Split('\n'));
    public static string FormatText(string[] patterns) => string.Join("\n", ProjectGraphScanner.NormalizeIgnorePatterns(patterns));
    public static string FormatDefaultPatterns() => string.Join("\n", ProjectGraphScanner.GetCombinedIgnorePatterns());
}
