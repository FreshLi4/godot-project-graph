#if TOOLS
using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using FreshLi4.ProjectGraph;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;

namespace FreshLi4.ProjectGraph.Tests;

public partial class TestRunner : Node
{
    private const string FixtureRoot = "res://tests/fixtures", RoundTripPath = "user://freshli4_project_graph/tests/round-trip.json";
    private static readonly Vector2 CardSize = new(320, 320), LargeCardSize = new(420, 420);
    private const string LongFilename = FixtureRoot + "/this_is_a_deliberately_very_long_asset_filename_that_must_wrap_inside_a_fixed_width_project_graph_card_without_showing_its_resource_path.tres";
    private readonly List<string> _failures = new();
    private int _assertions;
    public override void _Ready()
    {
        var scanner = new ProjectGraphScanner(); var snapshot = scanner.ScanProject(FixtureRoot);
        Expect(GraphSchema.ValidateSnapshot(snapshot).Length == 0, "snapshot should satisfy schema v1");
        foreach (var file in new[] { "main.tscn", "actor.tscn" }) Expect(HasNode(snapshot, $"{FixtureRoot}/{file}", "Scene"), file);
        foreach (var file in new[] { "actor.gd", "base_actor.gd", "child_actor.gd" }) Expect(HasNode(snapshot, $"{FixtureRoot}/{file}", "Script"), file);
        Expect(HasNode(snapshot, $"{FixtureRoot}/shared_resource.tres", "Resource"), "shared resource");
        Expect(HasNode(snapshot, LongFilename, "Resource"), "long filename fixture should be scanned for fixed-width wrapping smoke");
        Expect(HasEdge(snapshot, $"{FixtureRoot}/main.tscn", $"{FixtureRoot}/actor.tscn"), "main scene should reference actor scene");
        Expect(HasEdge(snapshot, $"{FixtureRoot}/actor.tscn", $"{FixtureRoot}/actor.gd"), "actor scene should reference actor script");
        Expect(HasEdge(snapshot, $"{FixtureRoot}/actor.tscn", $"{FixtureRoot}/shared_resource.tres"), "actor scene should reference shared resource");
        Expect(HasEdge(snapshot, $"{FixtureRoot}/child_actor.gd", $"{FixtureRoot}/base_actor.gd", GraphSchema.RelationInherits), "GDScript inheritance should point from child to parent");
        Expect(UniqueIds(snapshot.A("nodes")), "node ids should be unique"); Expect(UniqueIds(snapshot.A("edges")), "edge ids should be unique");
        var layout = new OrganicGraphLayout(); var fixtureLayout = layout.Calculate(snapshot, CardSize); var positions = fixtureLayout.D("positions");
        Expect(positions.Count == snapshot.D("stats").I("node_count", -1), "organic layout should position every fixture node");
        Expect(positions.ContainsKey($"{FixtureRoot}/base_actor.gd") && (positions.V($"{FixtureRoot}/base_actor.gd") + CardSize / 2).IsEqualApprox(Vector2.Zero), "highest inheritance ancestor should override degree as the organic center");
        Expect(Clearance(positions, CardSize, 0), "fixture organic cards should not overlap");
        Expect(Equivalent(fixtureLayout, layout.Calculate(snapshot, CardSize)), "organic layout should be deterministic");
        var hierarchyLayout = layout.Calculate(HierarchySnapshot(), CardSize);
        Expect(hierarchyLayout.S("root") == "base", "highest GDScript ancestor should be the layout center");
        var levels = hierarchyLayout.D("hierarchy_levels");
        Expect(levels.I("base", -1) > levels.I("middle", -1) && levels.I("middle", -1) > levels.I("child", -1), "inheritance hierarchy should increase central weight toward ancestors");
        var inheritanceStyle = SemanticConnectionLayer.EdgeStyle(GraphSchema.MakeEdge("child", "base", GraphSchema.RelationInherits, GraphSchema.OriginGDScriptStatic));
        Expect(!inheritanceStyle.B("dashed", true) && inheritanceStyle.S("semantic") == "inherits", "exact inheritance should use a solid semantic arrow");
        var inferredStyle = SemanticConnectionLayer.EdgeStyle(GraphSchema.MakeEdge("factory", "spawned", GraphSchema.RelationCreates, "RuntimeAnalyzer", GraphSchema.ConfidenceInferred));
        Expect(inferredStyle.B("dashed") && inferredStyle.S("semantic") == "inferred_dynamic", "inferred or dynamic relationships should use dashed arrows");
        Expect(ProjectGraphPanel.ScrollOffsetAfterDrag(new(20, 30), new(10, -6), 2).IsEqualApprox(new(15, 33)), "left-button canvas dragging should pan relative to the current zoom");
        var source = new Rect2(0, 0, 100, 60); var target = new Rect2(360, 0, 100, 60); var blocker = new Rect2(170, -30, 120, 120);
        var route = SemanticConnectionLayer.RouteAroundObstacles(source, target, new[] {blocker});
        Expect(route.Length > 2, "semantic edges should detour when a third-party card blocks the direct line");
        Expect(SemanticConnectionLayer.PolylineAvoidsRects(route, new[] {blocker}), "semantic edge detours should preserve clearance from every blocking card");
        var blockers = new[] { new Rect2(125, -20, 80, 95), new Rect2(250, -55, 75, 110) };
        route = SemanticConnectionLayer.RouteAroundObstacles(source, target, blockers);
        Expect(route.Length > 2 && SemanticConnectionLayer.PolylineAvoidsRects(route, blockers), "visibility routing should discover secondary blockers and remain unobstructed");
        var organicSnapshot = OrganicSnapshot(8, 6, 3); var organic = layout.Calculate(organicSnapshot, CardSize);
        var organicPositions = organic.D("positions"); var organicOrphans = organic.Get("orphan_ids").AsStringArray();
        Expect(Clearance(organicPositions, CardSize, 0), "organic cards should not overlap");
        Expect(Clearance(organicPositions, CardSize, OrganicGraphLayout.NodeGap - .1f), "organic cards should leave visible connector clearance");
        Expect(FillsDisk(organicPositions, organicOrphans, "center"), "connected organic graph should occupy the disk interior instead of one ring");
        Expect(OrphansOutermost(organicPositions, organicOrphans), "degree-zero nodes should be outside every connected node");
        Expect(Equivalent(organic, layout.Calculate(organicSnapshot, CardSize)), "organic disk layout should remain deterministic");
        Expect(organic.I("crossings_after", -1) <= organic.I("crossings_before", -1), "readability refinement should never increase edge crossings");
        Expect(organic.I("community_pair_count") > 0, "shared neighbors should produce deterministic community attraction pairs");
        Expect(AllRoutesClear(organicSnapshot, organicPositions, CardSize), "every organic semantic edge should route around unrelated asset cards");
        Expect(Clearance(layout.Calculate(organicSnapshot, LargeCardSize).D("positions"), LargeCardSize, OrganicGraphLayout.NodeGap - .1f), "layout should preserve clearance for alternate fixed card envelopes");
        var clusterSnapshot = ClusterSnapshot(); var cluster = layout.Calculate(clusterSnapshot, CardSize); var clusterPositions = cluster.D("positions");
        Expect(MeanLinkedDistance(clusterSnapshot, clusterPositions) < MeanUnlinkedDistance(clusterSnapshot, clusterPositions), "directly related assets should be closer than unrelated assets");
        Expect(Clearance(clusterPositions, CardSize, OrganicGraphLayout.NodeGap - .1f), "cluster refinement should preserve card clearance");
        var crossingSnapshot = GraphSchema.MakeSnapshot("res://", new GArray { GraphSchema.MakeNode("a", "res://a.tres", "Resource"), GraphSchema.MakeNode("b", "res://b.tres", "Resource"), GraphSchema.MakeNode("c", "res://c.tres", "Resource"), GraphSchema.MakeNode("d", "res://d.tres", "Resource") },
            new GArray { GraphSchema.MakeEdge("a", "b"), GraphSchema.MakeEdge("c", "d") });
        var crossingPositions = new GDictionary { ["a"] = new Vector2(-300, -300) - CardSize / 2, ["b"] = new Vector2(300, 300) - CardSize / 2, ["c"] = new Vector2(300, -300) - CardSize / 2, ["d"] = new Vector2(-300, 300) - CardSize / 2 };
        var crossing = layout.RefinePositions(crossingSnapshot, crossingPositions, CardSize);
        Expect(crossing.I("crossings_before", -1) == 1 && crossing.I("crossings_after", -1) == 0, "angular swaps should remove a geometrically avoidable crossing");
        Expect(Clearance(crossing.D("positions"), CardSize, OrganicGraphLayout.NodeGap - .1f), "crossing refinement should preserve existing card clearance");
        var large = layout.Calculate(OrganicSnapshot(16, 12, 6), CardSize); var largePositions = large.D("positions"); var largeOrphans = large.Get("orphan_ids").AsStringArray();
        Expect(largePositions.Count == 199, "Barnes-Hut layout should position every large-graph node");
        Expect(Clearance(largePositions, CardSize, 0), "Barnes-Hut layout should preserve card collision constraints");
        Expect(FillsDisk(largePositions, largeOrphans, "center"), "Barnes-Hut layout should preserve disk occupancy");
        Expect(OrphansOutermost(largePositions, largeOrphans), "Barnes-Hut layout should keep independent nodes outermost");
        Expect(GraphStore.SaveJson(snapshot, RoundTripPath) == Error.Ok, "snapshot should save as JSON");
        var restored = GraphStore.LoadJson(RoundTripPath);
        Expect(restored.Count > 0, "saved snapshot should load");
        Expect(restored.D("stats").I("node_count", -1) == snapshot.D("stats").I("node_count", -2), "JSON round trip should preserve node count");
        var ignored = scanner.ScanProject(FixtureRoot, new[] { "tests/fixtures/shared_resource.tres" });
        Expect(!HasNode(ignored, $"{FixtureRoot}/shared_resource.tres", "Resource"), "custom Ignore should exclude a matching asset");
        Expect(!HasEdge(ignored, $"{FixtureRoot}/actor.tscn", $"{FixtureRoot}/shared_resource.tres"), "custom Ignore should exclude dependency edges to ignored assets");
        Expect(scanner.ScanProject(FixtureRoot, new[] { "tests/fixtures/**" }).D("stats").I("node_count", -1) == 0, "directory Ignore patterns should prune traversal before scanning");
        Expect(ProjectGraphScanner.NormalizeIgnorePatterns(new[] { "# comment", " third_party/** " }).SequenceEqual(new[] { "res://third_party/**" }), "Ignore patterns should normalize project-relative paths and comments");
        Expect(!scanner.ScanProject().A("nodes").Any(v => v.AsGodotDictionary().S("path").StartsWith("res://addons/", StringComparison.Ordinal)), "scanner should exclude every addon by default");
        if (_failures.Count == 0)
        {
            GD.Print($"READABILITY: crossings organic {organic.I("crossings_before")} -> {organic.I("crossings_after")}, large {large.I("crossings_before")} -> {large.I("crossings_after")}; cluster linked {MeanLinkedDistance(clusterSnapshot, clusterPositions):F1} vs unlinked {MeanUnlinkedDistance(clusterSnapshot, clusterPositions):F1}");
            GD.Print($"PASS: Project Graph core ({snapshot.D("stats").I("node_count")} nodes, {snapshot.D("stats").I("edge_count")} edges, {_assertions} assertions)");
        }
        else foreach (var failure in _failures) GD.PushError($"FAIL: {failure}");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }
    private void Expect(bool condition, string message) { _assertions++; if (!condition) _failures.Add(message); }
    private static bool Equivalent(GDictionary a, GDictionary b) => GD.VarToStr(a) == GD.VarToStr(b);
    private static bool HasNode(GDictionary snapshot, string id, string kind) => snapshot.A("nodes").Any(v => v.AsGodotDictionary().S("id") == id && v.AsGodotDictionary().S("kind") == kind);
    private static bool HasEdge(GDictionary snapshot, string source, string target, string relation = GraphSchema.RelationReference) => snapshot.A("edges").Any(v => { var edge = v.AsGodotDictionary(); return edge.S("source") == source && edge.S("target") == target && edge.S("relation") == relation; });
    private static bool UniqueIds(GArray items)
    {
        var ids = new HashSet<string>();
        foreach (var value in items) { string id = value.AsGodotDictionary().S("id"); if (id.Length == 0 || !ids.Add(id)) return false; }
        return true;
    }
    private static bool Clearance(GDictionary positions, Vector2 size, float clearance)
    {
        var ids = positions.Keys.Select(v => v.AsString()).ToArray();
        for (int a = 0; a < ids.Length; a++)
            for (int b = a + 1; b < ids.Length; b++)
            {
                var left = new Rect2(positions.V(ids[a]), size); var right = new Rect2(positions.V(ids[b]), size);
                float x = Mathf.Max(left.Position.X, right.Position.X) - Mathf.Min(left.End.X, right.End.X), y = Mathf.Max(left.Position.Y, right.Position.Y) - Mathf.Min(left.End.Y, right.End.Y);
                if (x < clearance && y < clearance) return false;
            }
        return true;
    }
    private static GDictionary OrganicSnapshot(int branches, int depth, int orphans)
    {
        var nodes = new GArray { GraphSchema.MakeNode("center", "res://center.tscn", "Scene") }; var edges = new GArray();
        for (int branch = 0; branch < branches; branch++)
        {
            string previous = "center";
            for (int d = 0; d < depth; d++) { string id = $"branch_{branch:D2}_{d:D2}"; nodes.Add(GraphSchema.MakeNode(id, $"res://{id}.tres", "Resource")); edges.Add(GraphSchema.MakeEdge(previous, id)); previous = id; }
            if (branch > 0) edges.Add(GraphSchema.MakeEdge($"branch_{branch - 1:D2}_02", $"branch_{branch:D2}_02"));
        }
        for (int i = 0; i < orphans; i++) { string id = $"orphan_{i:D2}"; nodes.Add(GraphSchema.MakeNode(id, $"res://{id}.tres", "Resource")); }
        return GraphSchema.MakeSnapshot("res://", nodes, edges);
    }
    private static GDictionary HierarchySnapshot() => GraphSchema.MakeSnapshot("res://",
        new GArray { GraphSchema.MakeNode("base", "res://base.gd", "Script"), GraphSchema.MakeNode("middle", "res://middle.gd", "Script"), GraphSchema.MakeNode("child", "res://child.gd", "Script") },
        new GArray { GraphSchema.MakeEdge("child", "middle", GraphSchema.RelationInherits, GraphSchema.OriginGDScriptStatic), GraphSchema.MakeEdge("middle", "base", GraphSchema.RelationInherits, GraphSchema.OriginGDScriptStatic) });
    private static GDictionary ClusterSnapshot()
    {
        var nodes = new GArray();
        foreach (var id in new[] { "hub_a", "a_1", "a_2", "a_3", "hub_b", "b_1", "b_2", "b_3" }) nodes.Add(GraphSchema.MakeNode(id, $"res://{id}.tres", "Resource"));
        return GraphSchema.MakeSnapshot("res://", nodes, new GArray { GraphSchema.MakeEdge("hub_a", "a_1"), GraphSchema.MakeEdge("hub_a", "a_2"), GraphSchema.MakeEdge("hub_a", "a_3"), GraphSchema.MakeEdge("a_1", "a_2"), GraphSchema.MakeEdge("hub_b", "b_1"), GraphSchema.MakeEdge("hub_b", "b_2"), GraphSchema.MakeEdge("hub_b", "b_3"), GraphSchema.MakeEdge("b_1", "b_2"), GraphSchema.MakeEdge("hub_a", "hub_b") });
    }
    private static float MeanLinkedDistance(GDictionary snapshot, GDictionary positions)
    {
        float total = 0; var edges = snapshot.A("edges");
        foreach (var value in edges) { var edge = value.AsGodotDictionary(); total += positions.V(edge.S("source")).DistanceTo(positions.V(edge.S("target"))); }
        return total / Math.Max(edges.Count, 1);
    }
    private static string PairKey(string a, string b) => string.CompareOrdinal(a, b) < 0 ? $"{a}|{b}" : $"{b}|{a}";
    private static float MeanUnlinkedDistance(GDictionary snapshot, GDictionary positions)
    {
        var linked = snapshot.A("edges").Select(v => { var edge = v.AsGodotDictionary(); return PairKey(edge.S("source"), edge.S("target")); }).ToHashSet();
        var ids = positions.Keys.Select(v => v.AsString()).Order(StringComparer.Ordinal).ToArray(); float total = 0; int count = 0;
        for (int a = 0; a < ids.Length; a++) for (int b = a + 1; b < ids.Length; b++)
            if (!linked.Contains(PairKey(ids[a], ids[b]))) { total += positions.V(ids[a]).DistanceTo(positions.V(ids[b])); count++; }
        return total / Math.Max(count, 1);
    }
    private static bool AllRoutesClear(GDictionary snapshot, GDictionary positions, Vector2 size)
    {
        foreach (var value in snapshot.A("edges"))
        {
            var edge = value.AsGodotDictionary(); string source = edge.S("source"), target = edge.S("target");
            if (!positions.ContainsKey(source) || !positions.ContainsKey(target)) return false;
            var obstacles = positions.Keys.Select(v => v.AsString()).Where(id => id != source && id != target).Select(id => new Rect2(positions.V(id), size)).ToArray();
            var route = SemanticConnectionLayer.RouteAroundObstacles(new(positions.V(source), size), new(positions.V(target), size), obstacles);
            if (!SemanticConnectionLayer.PolylineAvoidsRects(route, obstacles)) return false;
        }
        return true;
    }
    private static bool FillsDisk(GDictionary positions, string[] orphans, string centerId)
    {
        if (!positions.ContainsKey(centerId)) return false;
        var connected = positions.Keys.Select(v => v.AsString()).Where(id => id != centerId && !orphans.Contains(id)).ToArray();
        var center = positions.V(centerId) + CardSize / 2;
        float maximum = connected.Select(id => center.DistanceTo(positions.V(id) + CardSize / 2)).DefaultIfEmpty(0).Max();
        if (maximum <= 0) return false;
        var bands = new HashSet<int> {0}; int interior = 0;
        foreach (var id in connected)
        {
            float radius = center.DistanceTo(positions.V(id) + CardSize / 2) / maximum;
            bands.Add(Math.Clamp(Mathf.FloorToInt(radius * 5), 0, 4));
            if (radius > .12f && radius < .72f) interior++;
        }
        return bands.Count >= 4 && interior >= (connected.Length + 1) / 5f;
    }
    private static bool OrphansOutermost(GDictionary positions, string[] orphans)
    {
        if (orphans.Length == 0) return false;
        float maximumConnected = 0, minimumOrphan = float.PositiveInfinity;
        foreach (var value in positions.Keys)
        {
            string id = value.AsString(); float radius = (positions.V(id) + CardSize / 2).Length();
            if (orphans.Contains(id)) minimumOrphan = Mathf.Min(minimumOrphan, radius); else maximumConnected = Mathf.Max(maximumConnected, radius);
        }
        return minimumOrphan > maximumConnected + CardSize.Length() / 2;
    }
}
#endif
