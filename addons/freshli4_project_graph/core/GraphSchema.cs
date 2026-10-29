using Godot;
using System.Collections.Generic;
using System.Linq;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;

namespace FreshLi4.ProjectGraph;

public static class GraphSchema
{
    public const int SchemaVersion = 1;
    public const string RelationReference = "references", RelationInherits = "inherits", RelationCreates = "creates";
    public const string ConfidenceExact = "exact", ConfidenceInferred = "inferred";
    public const string OriginResourceLoader = "ResourceLoader", OriginGDScriptStatic = "GDScriptStatic";
    public static readonly string[] NodeKinds = {"Scene", "Script", "Resource", "Mesh", "Texture", "Audio", "Shader", "Data"};

    public static GDictionary MakeNode(string id, string path, string kind, bool missing = false, GDictionary? metadata = null) => new()
    {
        ["id"] = id, ["label"] = path.GetFile(), ["kind"] = kind, ["path"] = path,
        ["missing"] = missing, ["metadata"] = (metadata ?? new()).Duplicate(true)
    };
    public static GDictionary MakeEdge(string source, string target, string relation = RelationReference,
        string origin = OriginResourceLoader, string confidence = ConfidenceExact, GDictionary? metadata = null) => new()
    {
        ["id"] = $"{source}|{relation}|{target}", ["source"] = source, ["target"] = target,
        ["relation"] = relation, ["origin"] = origin, ["confidence"] = confidence,
        ["metadata"] = (metadata ?? new()).Duplicate(true)
    };
    public static GDictionary MakeSnapshot(string rootPath, GArray nodes, GArray edges)
    {
        var counts = new GDictionary();
        int missing = 0;
        foreach (var value in nodes)
        {
            var node = value.AsGodotDictionary();
            var kind = node.S("kind", "Data");
            counts[kind] = counts.I(kind) + 1;
            if (node.B("missing")) missing++;
        }
        return new()
        {
            ["schema_version"] = SchemaVersion, ["generated_at"] = Time.GetDatetimeStringFromSystem(true),
            ["project"] = new GDictionary { ["name"] = ProjectSettings.GetSetting("application/config/name", "Unnamed Godot Project"), ["root"] = rootPath },
            ["nodes"] = nodes, ["edges"] = edges,
            ["stats"] = new GDictionary { ["node_count"] = nodes.Count, ["edge_count"] = edges.Count, ["missing_node_count"] = missing, ["node_type_counts"] = counts }
        };
    }
    public static string[] ValidateSnapshot(GDictionary snapshot)
    {
        var errors = new List<string>();
        if (snapshot.I("schema_version", -1) != SchemaVersion) errors.Add($"schema_version must be {SchemaVersion}");
        if (snapshot.Get("project").VariantType != Variant.Type.Dictionary) errors.Add("project must be a Dictionary");
        if (snapshot.Get("nodes").VariantType != Variant.Type.Array) errors.Add("nodes must be an Array");
        if (snapshot.Get("edges").VariantType != Variant.Type.Array) errors.Add("edges must be an Array");
        if (errors.Count != 0) return errors.ToArray();
        var nodeIds = new HashSet<string>();
        foreach (var value in snapshot.A("nodes"))
        {
            if (value.VariantType != Variant.Type.Dictionary) { errors.Add("every node must be a Dictionary"); continue; }
            var node = value.AsGodotDictionary();
            foreach (var key in new[] { "id", "label", "kind", "path", "missing", "metadata" })
                if (!node.ContainsKey(key)) errors.Add($"node is missing key: {key}");
            var id = node.S("id");
            if (id.Length == 0) errors.Add("node id must not be empty");
            else if (!nodeIds.Add(id)) errors.Add($"duplicate node id: {id}");
            if (!NodeKinds.Contains(node.S("kind"))) errors.Add($"unsupported node kind: {node.S("kind")}");
        }
        var edgeIds = new HashSet<string>();
        foreach (var value in snapshot.A("edges"))
        {
            if (value.VariantType != Variant.Type.Dictionary) { errors.Add("every edge must be a Dictionary"); continue; }
            var edge = value.AsGodotDictionary();
            foreach (var key in new[] { "id", "source", "target", "relation", "origin", "confidence", "metadata" })
                if (!edge.ContainsKey(key)) errors.Add($"edge is missing key: {key}");
            var id = edge.S("id");
            if (id.Length == 0) errors.Add("edge id must not be empty");
            else if (!edgeIds.Add(id)) errors.Add($"duplicate edge id: {id}");
            if (!nodeIds.Contains(edge.S("source"))) errors.Add($"edge source is missing: {edge.S("source")}");
            if (!nodeIds.Contains(edge.S("target"))) errors.Add($"edge target is missing: {edge.S("target")}");
        }
        return errors.ToArray();
    }
}
