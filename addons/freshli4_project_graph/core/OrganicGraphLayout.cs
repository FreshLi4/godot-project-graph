using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;
namespace FreshLi4.ProjectGraph;

// Deterministic fixed-step force layout; no editor or idle simulation dependency.
public sealed class OrganicGraphLayout
{
    public static readonly Vector2 DefaultNodeSize = new(320, 320);
    private static readonly float GoldenAngle = Mathf.Pi * (3 - Mathf.Sqrt(5));
    private const float StartAngle = -Mathf.Pi / 2, SeedSpacing = 235, LinkStrength = .038f,
        CommunityStrength = .0065f, CommunityDistanceFactor = 1.45f, RepulsionStrength = 42,
        CenterStrength = .0048f, DiskCompressionStrength = .016f, TargetDiskPadding = 1.18f,
        VelocityScale = .34f, VelocityDamping = .72f, InitialMaxStep = 46, FinalMaxStep = 4,
        BarnesHutTheta = .72f, OrphanGap = 180, MinOrphanRadius = 520, MaxEdgeLengthIncrease = 1.18f;
    public const float NodeGap = 96;
    private const int MaxCommunityHubDegree = 64, SmallGraphIterations = 110, LargeGraphIterations = 72,
        BarnesHutThreshold = 180, MaxQuadtreeDepth = 22, CollisionPasses = 320,
        InheritanceLevelWeight = 100, DirectChildWeight = 12, CrossingSwapPasses = 3,
        LargeCrossingSwapPasses = 1, FullCrossingOptimizationNodes = 240,
        FullCrossingOptimizationEdges = 480, MaxCrossingOptimizationNodes = 1200,
        MaxCrossingOptimizationEdges = 2400;

    private sealed record Topology(HashSet<int>[] Adjacency, List<Vector2I> Edges, List<Vector2I> Inheritance);
    private static List<string> NodeIds(GDictionary snapshot) => snapshot.A("nodes").Select(v => v.AsGodotDictionary().S("id")).Where(id => id.Length > 0).Order(StringComparer.Ordinal).ToList();
    private static Dictionary<string, int> Indices(List<string> ids) => ids.Select((id, i) => (id, i)).ToDictionary(v => v.id, v => v.i, StringComparer.Ordinal);
    private static GDictionary Metrics(int before = 0, int after = 0, float length = 0, int communities = 0) => new()
    { ["crossings_before"] = before, ["crossings_after"] = after, ["mean_edge_length"] = length, ["community_pair_count"] = communities };

    public GDictionary Calculate(GDictionary snapshot, Vector2? requestedSize = null)
    {
        var size = requestedSize ?? DefaultNodeSize;
        var ids = NodeIds(snapshot); var indices = Indices(ids);
        var topology = BuildTopology(ids.Count, indices, snapshot.A("edges"));
        var hierarchy = new int[ids.Count];
        for (int pass = 0; pass < ids.Count; pass++)
        {
            bool changed = false;
            foreach (var pair in topology.Inheritance)
                if (hierarchy[pair.X] + 1 > hierarchy[pair.Y]) { hierarchy[pair.Y] = hierarchy[pair.X] + 1; changed = true; }
            if (!changed) break;
        }
        var children = new int[ids.Count];
        foreach (var pair in topology.Inheritance) children[pair.Y]++;
        var degrees = topology.Adjacency.Select(s => s.Count).ToArray();
        var importance = Enumerable.Range(0, ids.Count).Select(i => degrees[i] + hierarchy[i] * InheritanceLevelWeight + children[i] * DirectChildWeight).ToArray();
        var connected = Enumerable.Range(0, ids.Count).Where(i => degrees[i] > 0)
            .OrderByDescending(i => importance[i]).ThenByDescending(i => degrees[i]).ThenBy(i => ids[i], StringComparer.Ordinal).ToArray();
        var orphans = Enumerable.Range(0, ids.Count).Where(i => degrees[i] == 0).ToArray();
        var positions = new Vector2[ids.Count];
        for (int rank = 1; rank < connected.Length; rank++)
        {
            float angle = StartAngle + GoldenAngle * rank;
            positions[connected[rank]] = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * (SeedSpacing * Mathf.Sqrt(rank));
        }
        var metrics = connected.Length > 0 ? Relax(positions, connected, topology.Edges, degrees, importance, size) : Metrics();
        float outerRadius = 0;
        foreach (var index in connected) outerRadius = Mathf.Max(outerRadius, positions[index].Length() + size.Length() / 2);
        if (orphans.Length > 0)
        {
            float radius = Mathf.Max(outerRadius + OrphanGap + size.Length() / 2, MinOrphanRadius);
            if (orphans.Length > 1) radius = Mathf.Max(radius, (size.Length() + NodeGap) / (2 * Mathf.Sin(Mathf.Pi / orphans.Length)));
            for (int i = 0; i < orphans.Length; i++)
            {
                float angle = StartAngle + Mathf.Tau * i / orphans.Length;
                positions[orphans[i]] = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
            }
        }
        var byId = new GDictionary(); var degreeById = new GDictionary(); var hierarchyById = new GDictionary();
        for (int i = 0; i < ids.Count; i++) { byId[ids[i]] = positions[i] - size / 2; degreeById[ids[i]] = degrees[i]; hierarchyById[ids[i]] = hierarchy[i]; }
        metrics["positions"] = byId; metrics["degrees"] = degreeById; metrics["hierarchy_levels"] = hierarchyById;
        metrics["root"] = connected.Length > 0 ? ids[connected[0]] : "";
        metrics["orphan_ids"] = orphans.Select(i => ids[i]).ToArray();
        return metrics;
    }
    private static Topology BuildTopology(int count, Dictionary<string, int> indices, GArray edges)
    {
        var adjacency = Enumerable.Range(0, count).Select(_ => new HashSet<int>()).ToArray();
        var unique = new HashSet<(int, int)>(); var inherits = new HashSet<(int, int)>();
        foreach (var value in edges)
        {
            var edge = value.AsGodotDictionary();
            if (!indices.TryGetValue(edge.S("source"), out int source) || !indices.TryGetValue(edge.S("target"), out int target) || source == target) continue;
            if (edge.S("relation") == "inherits") inherits.Add((source, target));
            int low = Math.Min(source, target), high = Math.Max(source, target);
            if (!unique.Add((low, high))) continue;
            adjacency[low].Add(high); adjacency[high].Add(low);
        }
        return new(adjacency, unique.OrderBy(p => p.Item1).ThenBy(p => p.Item2).Select(p => new Vector2I(p.Item1, p.Item2)).ToList(),
            inherits.OrderBy(p => p.Item1).ThenBy(p => p.Item2).Select(p => new Vector2I(p.Item1, p.Item2)).ToList());
    }
    private static HashSet<int>[] BuildAdjacency(int count, List<Vector2I> edges)
    {
        var adjacency = Enumerable.Range(0, count).Select(_ => new HashSet<int>()).ToArray();
        foreach (var edge in edges) { adjacency[edge.X].Add(edge.Y); adjacency[edge.Y].Add(edge.X); }
        return adjacency;
    }
    private static List<Vector3I> BuildCommunityPairs(HashSet<int>[] adjacency)
    {
        var weights = new Dictionary<(int, int), int>();
        foreach (var set in adjacency)
        {
            if (set.Count < 2 || set.Count > MaxCommunityHubDegree) continue;
            var neighbors = set.Order().ToArray();
            for (int left = 0; left < neighbors.Length; left++)
                for (int right = left + 1; right < neighbors.Length; right++)
                {
                    int a = neighbors[left], b = neighbors[right];
                    if (adjacency[a].Contains(b)) continue;
                    weights[(a, b)] = weights.GetValueOrDefault((a, b)) + 1;
                }
        }
        return weights.OrderBy(p => p.Key.Item1).ThenBy(p => p.Key.Item2).Select(p => new Vector3I(p.Key.Item1, p.Key.Item2, p.Value)).ToList();
    }
    private static GDictionary Relax(Vector2[] all, int[] connected, List<Vector2I> edges, int[] degrees, int[] importance, Vector2 size)
    {
        var positions = connected.Select(i => all[i]).ToArray();
        var localDegrees = connected.Select(i => degrees[i]).ToArray();
        var localImportance = connected.Select(i => importance[i]).ToArray();
        var localIndices = connected.Select((global, local) => (global, local)).ToDictionary(p => p.global, p => p.local);
        var localEdges = edges.Where(e => localIndices.ContainsKey(e.X) && localIndices.ContainsKey(e.Y))
            .Select(e => new Vector2I(localIndices[e.X], localIndices[e.Y])).ToList();
        var adjacency = BuildAdjacency(positions.Length, localEdges);
        var communities = BuildCommunityPairs(adjacency);
        var velocities = new Vector2[positions.Length];
        var masses = localDegrees.Select(d => (float)(d + 1)).ToArray();
        int maximumImportance = Math.Max(1, localImportance.Max());
        int iterations = positions.Length <= BarnesHutThreshold ? SmallGraphIterations : LargeGraphIterations;
        float linkLength = Mathf.Max(size.X + NodeGap, size.Y + NodeGap);
        float diskRadius = Mathf.Sqrt(positions.Length * (size.X + NodeGap) * (size.Y + NodeGap) / Mathf.Pi) * TargetDiskPadding;
        for (int iteration = 0; iteration < iterations; iteration++)
        {
            var forces = new Vector2[positions.Length];
            if (positions.Length <= BarnesHutThreshold) AccumulateExactRepulsion(positions, masses, forces, size);
            else AccumulateBarnesHutRepulsion(positions, masses, forces, size);
            foreach (var edge in localEdges)
            {
                var delta = positions[edge.Y] - positions[edge.X];
                float distance = Mathf.Max(delta.Length(), .001f);
                int endpointDegree = Math.Max(1, Math.Min(localDegrees[edge.X], localDegrees[edge.Y]));
                var force = delta / distance * (distance - linkLength) * (LinkStrength / Mathf.Sqrt(endpointDegree));
                forces[edge.X] += force; forces[edge.Y] -= force;
            }
            foreach (var pair in communities)
            {
                var delta = positions[pair.Y] - positions[pair.X];
                float distance = Mathf.Max(delta.Length(), .001f), targetDistance = linkLength * CommunityDistanceFactor;
                if (distance <= targetDistance) continue;
                var force = delta / distance * (distance - targetDistance) * CommunityStrength * Mathf.Sqrt(pair.Z);
                forces[pair.X] += force; forces[pair.Y] -= force;
            }
            for (int i = 1; i < positions.Length; i++)
            {
                var force = -positions[i] * CenterStrength * Mathf.Lerp(1, 2.6f, (float)localImportance[i] / maximumImportance);
                float distance = positions[i].Length();
                if (distance > diskRadius) force += -positions[i].Normalized() * (distance - diskRadius) * DiskCompressionStrength;
                forces[i] += force;
            }
            float maxStep = Mathf.Lerp(InitialMaxStep, FinalMaxStep, (float)iteration / Math.Max(iterations - 1, 1));
            positions[0] = Vector2.Zero; velocities[0] = Vector2.Zero;
            for (int i = 1; i < positions.Length; i++)
            {
                velocities[i] = ((velocities[i] + forces[i] * VelocityScale) * VelocityDamping).LimitLength(maxStep);
                positions[i] += velocities[i];
            }
            if (iteration % 8 == 7) ResolveCollisions(positions, size, 0, 1);
        }
        ResolveCollisions(positions, size, 0, CollisionPasses); positions[0] = Vector2.Zero;
        var metrics = ReduceEdgeCrossings(positions, localEdges, adjacency, size, 0);
        metrics["community_pair_count"] = communities.Count;
        for (int i = 0; i < connected.Length; i++) all[connected[i]] = positions[i];
        return metrics;
    }
    public GDictionary RefinePositions(GDictionary snapshot, GDictionary input, Vector2? requestedSize = null)
    {
        var size = requestedSize ?? DefaultNodeSize; var ids = NodeIds(snapshot); var indices = Indices(ids);
        var positions = ids.Select(id => input.V(id) + size / 2).ToArray();
        var topology = BuildTopology(ids.Count, indices, snapshot.A("edges"));
        int pinned = positions.Length == 0 ? -1 : Enumerable.Range(0, positions.Length).OrderBy(i => positions[i].LengthSquared()).First();
        var metrics = ReduceEdgeCrossings(positions, topology.Edges, topology.Adjacency, size, pinned);
        var output = new GDictionary();
        for (int i = 0; i < ids.Count; i++) output[ids[i]] = positions[i] - size / 2;
        metrics["positions"] = output; return metrics;
    }
    private static GDictionary ReduceEdgeCrossings(Vector2[] positions, List<Vector2I> edges, HashSet<int>[] adjacency, Vector2 size, int pinned)
    {
        int crossings = CountCrossings(positions, edges); float totalLength = EdgeLength(positions, edges);
        int count = Math.Max(edges.Count, 1); float mean = totalLength / count;
        var metrics = Metrics(crossings, crossings, mean);
        if (crossings == 0 || positions.Length > MaxCrossingOptimizationNodes || edges.Count > MaxCrossingOptimizationEdges) return metrics;
        var incident = Enumerable.Range(0, positions.Length).Select(_ => new HashSet<int>()).ToArray();
        for (int i = 0; i < edges.Count; i++) { incident[edges[i].X].Add(i); incident[edges[i].Y].Add(i); }
        float maximumMeanLength = mean * MaxEdgeLengthIncrease, bandWidth = Mathf.Max(size.Y + NodeGap, size.X * .8f);
        int passes = positions.Length <= FullCrossingOptimizationNodes && edges.Count <= FullCrossingOptimizationEdges ? CrossingSwapPasses : LargeCrossingSwapPasses;
        for (int pass = 0; pass < passes; pass++)
        {
            bool improved = false;
            var bands = new SortedDictionary<int, List<int>>();
            for (int i = 0; i < positions.Length; i++)
            {
                if (i == pinned) continue;
                int band = Math.Max(1, Mathf.RoundToInt(positions[i].Length() / Mathf.Max(bandWidth, 1)));
                if (!bands.TryGetValue(band, out var members)) bands[band] = members = new();
                members.Add(i);
            }
            foreach (var band in bands.Values)
            {
                band.Sort();
                foreach (var pair in SwapCandidates(band, positions, adjacency))
                {
                    int a = pair.X, b = pair.Y;
                    var affected = new HashSet<int>(incident[a]); affected.UnionWith(incident[b]);
                    int previousCrossings = CountCrossings(positions, edges, affected);
                    float previousLength = EdgeLength(positions, edges, affected);
                    (positions[a], positions[b]) = (positions[b], positions[a]);
                    int candidateCrossings = crossings + CountCrossings(positions, edges, affected) - previousCrossings;
                    float candidateLength = totalLength + EdgeLength(positions, edges, affected) - previousLength;
                    bool accept = candidateCrossings < crossings && candidateLength / count <= maximumMeanLength || candidateCrossings == crossings && candidateLength < totalLength - .01f;
                    if (accept) { crossings = candidateCrossings; totalLength = candidateLength; improved = true; }
                    else (positions[a], positions[b]) = (positions[b], positions[a]);
                }
            }
            if (!improved) break;
        }
        metrics["crossings_after"] = crossings; metrics["mean_edge_length"] = totalLength / count;
        return metrics;
    }
    private static List<Vector2I> SwapCandidates(List<int> band, Vector2[] positions, HashSet<int>[] adjacency)
    {
        if (band.Count < 2) return new();
        var angles = band.Select(i => (Index: i, Angle: Mathf.Atan2(positions[i].Y, positions[i].X))).ToList();
        angles.Sort((a, b) => !Mathf.IsEqualApprox(a.Angle, b.Angle) ? a.Angle.CompareTo(b.Angle) : a.Index.CompareTo(b.Index));
        var pairs = new HashSet<(int, int)>();
        void Add(int a, int b) { if (a != b) pairs.Add((Math.Min(a, b), Math.Max(a, b))); }
        for (int i = 0; i < angles.Count; i++) Add(angles[i].Index, angles[(i + 1) % angles.Count].Index);
        foreach (int index in band)
        {
            var center = Vector2.Zero;
            foreach (int neighbor in adjacency[index].Order()) center += positions[neighbor];
            if (adjacency[index].Count == 0 || center.LengthSquared() < .001f) continue;
            float desired = Mathf.Atan2(center.Y, center.X), closestDifference = float.PositiveInfinity; int closest = -1;
            foreach (int candidate in band)
            {
                if (candidate == index) continue;
                float angle = Mathf.Atan2(positions[candidate].Y, positions[candidate].X);
                float difference = Mathf.Abs(Mathf.Wrap(angle - desired, -Mathf.Pi, Mathf.Pi));
                if (difference < closestDifference - .0001f || Mathf.IsEqualApprox(difference, closestDifference) && candidate < closest)
                { closestDifference = difference; closest = candidate; }
            }
            if (closest >= 0) Add(index, closest);
        }
        return pairs.OrderBy(p => p.Item1).ThenBy(p => p.Item2).Select(p => new Vector2I(p.Item1, p.Item2)).ToList();
    }
    private static int CountCrossings(Vector2[] positions, List<Vector2I> edges, HashSet<int>? affected = null)
    {
        int crossings = 0;
        for (int i = 0; i < edges.Count; i++)
            for (int j = i + 1; j < edges.Count; j++)
            {
                if (affected != null && !affected.Contains(i) && !affected.Contains(j)) continue;
                var a = edges[i]; var b = edges[j];
                if (a.X == b.X || a.X == b.Y || a.Y == b.X || a.Y == b.Y) continue;
                if (SegmentsCross(positions[a.X], positions[a.Y], positions[b.X], positions[b.Y])) crossings++;
            }
        return crossings;
    }
    private static bool SegmentsCross(Vector2 a, Vector2 b, Vector2 c, Vector2 d)
    {
        float ac = (b - a).Cross(c - a), ad = (b - a).Cross(d - a), ca = (d - c).Cross(a - c), cb = (d - c).Cross(b - c);
        if (Mathf.Abs(ac) <= .001f || Mathf.Abs(ad) <= .001f || Mathf.Abs(ca) <= .001f || Mathf.Abs(cb) <= .001f) return false;
        return (ac > 0) != (ad > 0) && (ca > 0) != (cb > 0);
    }
    private static float EdgeLength(Vector2[] positions, List<Vector2I> edges, HashSet<int>? subset = null)
    {
        float total = 0;
        if (subset != null) { foreach (int i in subset) total += positions[edges[i].X].DistanceTo(positions[edges[i].Y]); }
        else foreach (var edge in edges) total += positions[edge.X].DistanceTo(positions[edge.Y]);
        return total;
    }
    private static Vector2 StableDirection(int a, int b)
    { float angle = GoldenAngle * (a * 131 + b * 17 + 1); return new(Mathf.Cos(angle), Mathf.Sin(angle)); }
    private static void AccumulateExactRepulsion(Vector2[] positions, float[] masses, Vector2[] forces, Vector2 size)
    {
        float minimum = Mathf.Max(size.Length() * .42f, 1);
        for (int a = 0; a < positions.Length; a++)
            for (int b = a + 1; b < positions.Length; b++)
            {
                var delta = positions[a] - positions[b];
                if (delta.LengthSquared() < .0001f) delta = StableDirection(a, b);
                var force = delta.Normalized() * RepulsionStrength * masses[a] * masses[b] / Mathf.Max(delta.Length(), minimum);
                forces[a] += force; forces[b] -= force;
            }
    }
    private sealed class Quad
    {
        public Vector2 Center, MassCenter;
        public float HalfSize, Mass;
        public readonly List<int> Indices = new();
        public Quad[] Children = Array.Empty<Quad>();
        public Quad(Vector2 center, float halfSize) { Center = center; HalfSize = halfSize; }
    }
    private static int ChildIndex(Vector2 center, Vector2 point) => (point.X >= center.X ? 1 : 0) + (point.Y >= center.Y ? 2 : 0);
    private static void Insert(Quad node, int index, Vector2[] positions, float[] masses, int depth)
    {
        float combined = node.Mass + masses[index];
        node.MassCenter = (node.MassCenter * node.Mass + positions[index] * masses[index]) / combined; node.Mass = combined;
        if (node.Children.Length == 0)
        {
            if (node.Indices.Count == 0 || depth >= MaxQuadtreeDepth || node.HalfSize <= .5f) { node.Indices.Add(index); return; }
            float half = node.HalfSize / 2;
            node.Children = new[] { new Quad(node.Center + new Vector2(-half, -half), half), new Quad(node.Center + new Vector2(half, -half), half),
                new Quad(node.Center + new Vector2(-half, half), half), new Quad(node.Center + new Vector2(half, half), half) };
            foreach (int existing in node.Indices) Insert(node.Children[ChildIndex(node.Center, positions[existing])], existing, positions, masses, depth + 1);
            node.Indices.Clear();
        }
        Insert(node.Children[ChildIndex(node.Center, positions[index])], index, positions, masses, depth + 1);
    }
    private static Vector2 QuadRepulsion(int index, Vector2 position, float mass, Quad node, Vector2[] positions, float[] masses, float minimum)
    {
        if (node.Mass <= 0) return Vector2.Zero;
        var force = Vector2.Zero;
        if (node.Children.Length == 0)
        {
            foreach (int other in node.Indices)
            {
                if (other == index) continue;
                var delta = position - positions[other];
                if (delta.LengthSquared() < .0001f) delta = StableDirection(index, other);
                force += delta.Normalized() * RepulsionStrength * mass * masses[other] / Mathf.Max(delta.Length(), minimum);
            }
            return force;
        }
        var toMass = position - node.MassCenter; float distance = Mathf.Max(toMass.Length(), .001f);
        if (node.HalfSize * 2 / distance < BarnesHutTheta)
            return toMass.Normalized() * RepulsionStrength * mass * node.Mass / Mathf.Max(distance, minimum);
        foreach (var child in node.Children) force += QuadRepulsion(index, position, mass, child, positions, masses, minimum);
        return force;
    }
    private static void AccumulateBarnesHutRepulsion(Vector2[] positions, float[] masses, Vector2[] forces, Vector2 size)
    {
        var min = positions[0]; var max = positions[0];
        foreach (var position in positions) { min = new(Mathf.Min(min.X, position.X), Mathf.Min(min.Y, position.Y)); max = new(Mathf.Max(max.X, position.X), Mathf.Max(max.Y, position.Y)); }
        var tree = new Quad((min + max) / 2, Mathf.Max(Mathf.Max(max.X - min.X, max.Y - min.Y) / 2 + 1, 2));
        for (int i = 0; i < positions.Length; i++) Insert(tree, i, positions, masses, 0);
        float minimum = Mathf.Max(size.Length() * .42f, 1);
        for (int i = 0; i < positions.Length; i++) forces[i] += QuadRepulsion(i, positions[i], masses[i], tree, positions, masses, minimum);
    }
    private static void ResolveCollisions(Vector2[] positions, Vector2 size, int pinned, int passes)
    {
        if (positions.Length < 2) return;
        float cellSize = Mathf.Max(size.X, size.Y) + NodeGap;
        Vector2I Cell(Vector2 p) => new(Mathf.FloorToInt(p.X / cellSize), Mathf.FloorToInt(p.Y / cellSize));
        for (int pass = 0; pass < passes; pass++)
        {
            var grid = new Dictionary<Vector2I, List<int>>();
            for (int i = 0; i < positions.Length; i++)
            {
                var cell = Cell(positions[i]);
                if (!grid.TryGetValue(cell, out var members)) grid[cell] = members = new();
                members.Add(i);
            }
            bool moved = false;
            for (int a = 0; a < positions.Length; a++)
            {
                var cell = Cell(positions[a]);
                for (int y = cell.Y - 1; y < cell.Y + 2; y++)
                    for (int x = cell.X - 1; x < cell.X + 2; x++)
                    {
                        if (!grid.TryGetValue(new(x, y), out var members)) continue;
                        foreach (int b in members)
                        {
                            if (b <= a) continue;
                            var delta = positions[b] - positions[a];
                            float overlapX = size.X + NodeGap - Mathf.Abs(delta.X), overlapY = size.Y + NodeGap - Mathf.Abs(delta.Y);
                            if (overlapX <= 0 || overlapY <= 0) continue;
                            var offset = Vector2.Zero;
                            if (overlapX < overlapY)
                            { float sign = Mathf.Sign(delta.X); if (Mathf.IsZeroApprox(sign)) sign = (a + b) % 2 == 0 ? 1 : -1; offset.X = sign * (overlapX + .01f); }
                            else
                            { float sign = Mathf.Sign(delta.Y); if (Mathf.IsZeroApprox(sign)) sign = (a + b) % 2 == 0 ? 1 : -1; offset.Y = sign * (overlapY + .01f); }
                            if (a == pinned) positions[b] += offset;
                            else if (b == pinned) positions[a] -= offset;
                            else { positions[a] -= offset / 2; positions[b] += offset / 2; }
                            moved = true;
                        }
                    }
            }
            positions[pinned] = Vector2.Zero;
            if (!moved) return;
        }
    }
}
