using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;
namespace FreshLi4.ProjectGraph;

public sealed class ProjectGraphScanner
{
    public static readonly string[] DefaultIgnorePatterns = {"res://addons/**", "res://.godot/**", "res://.import/**"};
    private static readonly HashSet<string> IgnoredDirectories = new() {".git", ".godot", ".import", ".mono"};
    private static readonly Dictionary<string, string> Kinds = new()
    {
        ["tscn"]="Scene", ["scn"]="Scene", ["gd"]="Script", ["cs"]="Script",
        ["tres"]="Resource", ["res"]="Resource", ["material"]="Resource", ["theme"]="Resource",
        ["glb"]="Mesh", ["gltf"]="Mesh", ["fbx"]="Mesh", ["obj"]="Mesh", ["dae"]="Mesh", ["mesh"]="Mesh",
        ["png"]="Texture", ["jpg"]="Texture", ["jpeg"]="Texture", ["webp"]="Texture", ["svg"]="Texture", ["dds"]="Texture", ["ktx"]="Texture", ["ktx2"]="Texture",
        ["wav"]="Audio", ["ogg"]="Audio", ["mp3"]="Audio", ["gdshader"]="Shader", ["shader"]="Shader",
        ["json"]="Data", ["cfg"]="Data", ["csv"]="Data", ["xml"]="Data"
    };
    private static readonly HashSet<string> DependencyExtensions = new() {"tscn", "scn", "tres", "res", "gd", "cs", "glb", "gltf"};
    private readonly Dictionary<string, GDictionary> _nodes = new(StringComparer.Ordinal), _edges = new(StringComparer.Ordinal);
    private string[] _ignore = Array.Empty<string>();

    public GDictionary ScanProject(string rootPath = "res://", string[]? customIgnorePatterns = null)
    {
        _nodes.Clear(); _edges.Clear(); _ignore = GetCombinedIgnorePatterns(customIgnorePatterns);
        var root = rootPath.Trim();
        if (root.Length == 0) root = "res://";
        else if (root != "res://") root = root.TrimEnd('/');
        var files = new List<string>();
        CollectFiles(root, files); files.Sort(StringComparer.Ordinal);
        foreach (var path in files) if (Kinds.ContainsKey(path.GetExtension().ToLowerInvariant())) AddAsset(path, false);
        foreach (var path in files) if (_nodes.ContainsKey(path) && DependencyExtensions.Contains(path.GetExtension().ToLowerInvariant())) ScanDependencies(path);
        ScanGDScriptInheritance(files);
        var nodes = new GArray(); var edges = new GArray();
        foreach (var pair in _nodes.OrderBy(pair => pair.Key, StringComparer.Ordinal)) nodes.Add(pair.Value);
        foreach (var pair in _edges.OrderBy(pair => pair.Key, StringComparer.Ordinal)) edges.Add(pair.Value);
        return GraphSchema.MakeSnapshot(root, nodes, edges);
    }
    private void CollectFiles(string path, List<string> output)
    {
        if (IsIgnoredPath(path)) return;
        using var directory = DirAccess.Open(path);
        if (directory == null) return;
        directory.ListDirBegin();
        for (var name = directory.GetNext(); name.Length > 0; name = directory.GetNext())
        {
            var entryPath = path.PathJoin(name);
            if (directory.CurrentIsDir())
            {
                if (!IgnoredDirectories.Contains(name) && !IsIgnoredPath(entryPath)) CollectFiles(entryPath, output);
            }
            else if (!name.StartsWith('.') && !IsIgnoredPath(entryPath)) output.Add(entryPath);
        }
        directory.ListDirEnd();
    }
    private void ScanDependencies(string source)
    {
        foreach (var raw in ResourceLoader.GetDependencies(source))
        {
            var path = NormalizeDependency(raw);
            if (path.Length == 0 || !path.StartsWith("res://", StringComparison.Ordinal) || IsIgnoredPath(path)) continue;
            if (!_nodes.ContainsKey(path)) AddAsset(path, !FileAccess.FileExists(path) && !ResourceLoader.Exists(path));
            var edge = GraphSchema.MakeEdge(source, path); _edges[edge.S("id")] = edge;
        }
    }
    private void ScanGDScriptInheritance(List<string> files)
    {
        var classes = new Dictionary<string, string>(StringComparer.Ordinal);
        var sources = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var path in files)
        {
            if (path.GetExtension().ToLowerInvariant() != "gd" || !_nodes.ContainsKey(path)) continue;
            using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
            var source = file?.GetAsText() ?? "";
            if (source.Length == 0) continue;
            sources[path] = source;
            foreach (var raw in source.Split('\n'))
            {
                var line = raw.Trim();
                if (!line.StartsWith("class_name ", StringComparison.Ordinal)) continue;
                var name = line[11..].Trim().Split(' ')[0].Split('#')[0].Trim();
                if (name.Length > 0) classes[name] = path;
                break;
            }
        }
        foreach (var (path, source) in sources)
        {
            var declaration = FindExtendsDeclaration(source);
            string parent = declaration.StartsWith("res://", StringComparison.Ordinal) ? declaration.SimplifyPath()
                : declaration.Contains('/') || declaration.EndsWith(".gd", StringComparison.Ordinal) ? path.GetBaseDir().PathJoin(declaration).SimplifyPath()
                : classes.GetValueOrDefault(declaration, "");
            if (parent.Length == 0 || parent == path || IsIgnoredPath(parent)) continue;
            if (!_nodes.ContainsKey(parent)) AddAsset(parent, !FileAccess.FileExists(parent) && !ResourceLoader.Exists(parent));
            _edges.Remove($"{path}|{GraphSchema.RelationReference}|{parent}");
            var edge = GraphSchema.MakeEdge(path, parent, GraphSchema.RelationInherits, GraphSchema.OriginGDScriptStatic);
            _edges[edge.S("id")] = edge;
        }
    }
    private static string FindExtendsDeclaration(string source)
    {
        foreach (var raw in source.Split('\n'))
        {
            var line = raw.Trim();
            if (!line.StartsWith("extends ", StringComparison.Ordinal)) continue;
            var expression = line[8..].Trim();
            int comment = expression.IndexOf(" #", StringComparison.Ordinal);
            if (comment >= 0) expression = expression[..comment].Trim();
            foreach (var name in new[] { "preload", "load" })
                if (expression.StartsWith(name + "(", StringComparison.Ordinal) && expression.EndsWith(')'))
                { expression = expression[(name.Length + 1)..^1].Trim(); break; }
            if (expression.Length >= 2 && ((expression.StartsWith('"') && expression.EndsWith('"')) || (expression.StartsWith('\'') && expression.EndsWith('\'')))) expression = expression[1..^1];
            return expression;
        }
        return "";
    }
    private void AddAsset(string path, bool missing)
    {
        var extension = path.GetExtension().ToLowerInvariant();
        _nodes[path] = GraphSchema.MakeNode(path, path, Kinds.GetValueOrDefault(extension, "Data"), missing, new GDictionary { ["extension"] = extension });
    }
    private static string NormalizeDependency(string raw)
    {
        if (raw.StartsWith("res://", StringComparison.Ordinal)) return raw;
        var parts = raw.Split("::", StringSplitOptions.RemoveEmptyEntries);
        foreach (var part in parts) if (part.StartsWith("res://", StringComparison.Ordinal)) return part;
        foreach (var part in parts)
            if (part.StartsWith("uid://", StringComparison.Ordinal))
            {
                var id = ResourceUid.TextToId(part);
                if (id != ResourceUid.InvalidId) return ResourceUid.GetIdPath(id);
                break;
            }
        return "";
    }
    public static string[] NormalizeIgnorePatterns(IEnumerable<string> rawPatterns)
    {
        var patterns = new List<string>();
        foreach (var raw in rawPatterns)
        {
            var pattern = raw.Trim().Replace('\\', '/');
            if (pattern.Length == 0 || pattern.StartsWith('#')) continue;
            if (!pattern.StartsWith("res://", StringComparison.Ordinal)) pattern = "res://" + pattern.TrimStart('/');
            if (!patterns.Contains(pattern, StringComparer.Ordinal)) patterns.Add(pattern);
        }
        return patterns.ToArray();
    }
    public static string[] GetCombinedIgnorePatterns(string[]? patterns = null) => NormalizeIgnorePatterns(DefaultIgnorePatterns.Concat(patterns ?? Array.Empty<string>()));
    private bool IsIgnoredPath(string path)
    {
        var normalized = path.Replace('\\', '/').TrimEnd('/');
        foreach (var pattern in _ignore)
        {
            if (pattern.EndsWith("/**", StringComparison.Ordinal) || pattern.EndsWith('/'))
            {
                var prefix = pattern.EndsWith("/**", StringComparison.Ordinal) ? pattern[..^3].TrimEnd('/') : pattern.TrimEnd('/');
                if (normalized == prefix || normalized.StartsWith(prefix + "/", StringComparison.Ordinal)) return true;
            }
            else if (pattern.Contains('*') || pattern.Contains('?')) { if (normalized.Match(pattern)) return true; }
            else if (normalized == pattern) return true;
        }
        return false;
    }
}
