using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;
namespace FreshLi4.ProjectGraph;

[Tool]
public partial class SemanticConnectionLayer : Control
{
    public static readonly Color ReferenceColor = new("#B8C0CC"), InheritanceColor = new("#6FCFDE"), InferredColor = new("#F2B84B");
    private const float LineWidth = 2.2f, DashLength = 11, DashGap = 7, ArrowLength = 12, ArrowHalfWidth = 5.5f, RouteEpsilon = .5f;
    public const float RouteClearance = 14;
    private GraphEdit? _graph;
    private Dictionary<string, GraphNode> _cards = new();
    private GArray _edges = new();
    private readonly List<(Vector2[] Points, GraphNode Source, GDictionary Style)> _routes = new();
    private bool _dirty = true;
    private GDictionary _metrics = new();
    private float _lastZoom = -1;
    private Vector2 _lastScroll = new(float.PositiveInfinity, float.PositiveInfinity);
    public void Configure(GraphEdit graph, Dictionary<string, GraphNode> cards, GArray edges)
    {
        _graph = graph; _cards = cards; _edges = edges.Duplicate(true); _dirty = true;
        TrackGeometryChanges(); QueueRedraw();
    }
    public static GDictionary EdgeStyle(GDictionary edge)
    {
        var relation = edge.S("relation", "references");
        var origin = edge.S("origin").ToLowerInvariant();
        bool inferred = edge.S("confidence", "exact") != "exact" || relation == "creates" || origin.Contains("runtime") || origin.Contains("dynamic") || edge.D("metadata").B("dynamic");
        return new() { ["color"] = inferred ? InferredColor : relation == "inherits" ? InheritanceColor : ReferenceColor,
            ["dashed"] = inferred, ["arrow"] = true, ["semantic"] = inferred ? "inferred_dynamic" : relation == "inherits" ? "inherits" : "references" };
    }
    public static Vector2[] RouteAroundObstacles(Rect2 sourceRect, Rect2 targetRect, IReadOnlyList<Rect2> obstacleRects, float clearance = RouteClearance)
    {
        var source = sourceRect.Abs(); var target = targetRect.Abs();
        var start = source.GetCenter(); var finish = target.GetCenter();
        if (start.DistanceSquaredTo(finish) < 1) return Array.Empty<Vector2>();
        var obstacles = obstacleRects.Select(r => r.Abs()).Where(r => r.Size.X > 0 && r.Size.Y > 0).Select(r => r.Grow(clearance)).ToArray();
        int blocker = FirstBlocker(start, finish, obstacles);
        if (blocker < 0) return new[] { RectBoundary(source, (finish - start).Normalized()), RectBoundary(target, (start - finish).Normalized()) };
        var relevant = new HashSet<int> { blocker };
        while (relevant.Count <= obstacles.Length)
        {
            var points = new List<Vector2> { start, finish };
            foreach (int i in relevant.Order())
            {
                var r = obstacles[i];
                points.Add(r.Position); points.Add(new(r.End.X, r.Position.Y)); points.Add(r.End); points.Add(new(r.Position.X, r.End.Y));
            }
            var neighbors = Enumerable.Range(0, points.Count).Select(_ => new List<(int To, float Distance)>()).ToArray();
            var discovered = new HashSet<int>();
            for (int a = 0; a < points.Count; a++)
                for (int b = a + 1; b < points.Count; b++)
                {
                    blocker = FirstBlocker(points[a], points[b], obstacles);
                    if (blocker >= 0) { if (!relevant.Contains(blocker)) discovered.Add(blocker); continue; }
                    float distance = points[a].DistanceTo(points[b]);
                    neighbors[a].Add((b, distance)); neighbors[b].Add((a, distance));
                }
            var indices = ShortestPath(neighbors, 0, 1);
            if (indices.Length > 0)
            {
                var route = ClipRoute(indices.Select(i => points[i]).ToArray(), source, target);
                route = RemoveCollinearPoints(route);
                if (PolylineAvoidsRects(route, obstacleRects, clearance)) return route;
            }
            int before = relevant.Count; relevant.UnionWith(discovered);
            if (relevant.Count == before) break;
        }
        return Array.Empty<Vector2>();
    }
    public static bool PolylineAvoidsRects(IReadOnlyList<Vector2> route, IReadOnlyList<Rect2> obstacles, float clearance = RouteClearance)
    {
        if (route.Count < 2) return false;
        for (int i = 0; i < route.Count - 1; i++)
            foreach (var rect in obstacles)
                if (CrossesInterior(route[i], route[i + 1], rect.Abs().Grow(clearance))) return false;
        return true;
    }
    private static int[] ShortestPath(List<(int To, float Distance)>[] neighbors, int start, int target)
    {
        var distances = Enumerable.Repeat(double.PositiveInfinity, neighbors.Length).ToArray();
        var previous = Enumerable.Repeat(-1, neighbors.Length).ToArray(); var visited = new bool[neighbors.Length]; distances[start] = 0;
        for (int step = 0; step < neighbors.Length; step++)
        {
            int current = -1; double distance = double.PositiveInfinity;
            for (int i = 0; i < neighbors.Length; i++) if (!visited[i] && distances[i] < distance) { current = i; distance = distances[i]; }
            if (current < 0 || current == target) break;
            visited[current] = true;
            foreach (var edge in neighbors[current])
            {
                double candidate = distance + edge.Distance;
                if (candidate + .001 < distances[edge.To]) { distances[edge.To] = candidate; previous[edge.To] = current; }
            }
        }
        if (!double.IsFinite(distances[target])) return Array.Empty<int>();
        var result = new List<int>();
        for (int cursor = target; cursor >= 0; cursor = previous[cursor]) { result.Add(cursor); if (cursor == start) break; }
        if (result.Count == 0 || result[^1] != start) return Array.Empty<int>();
        result.Reverse(); return result.ToArray();
    }
    private static Vector2[] ClipRoute(Vector2[] route, Rect2 source, Rect2 target)
    {
        if (route.Length < 2) return Array.Empty<Vector2>();
        var a = route[1] - source.GetCenter(); var b = route[^2] - target.GetCenter();
        if (a.LengthSquared() < .001f || b.LengthSquared() < .001f) return Array.Empty<Vector2>();
        route[0] = RectBoundary(source, a.Normalized()); route[^1] = RectBoundary(target, b.Normalized()); return route;
    }
    private static Vector2[] RemoveCollinearPoints(Vector2[] route)
    {
        if (route.Length <= 2) return route;
        var points = new List<Vector2> {route[0]};
        for (int i = 1; i < route.Length - 1; i++)
        {
            var previous = route[i] - points[^1]; var next = route[i + 1] - route[i];
            if (previous.LengthSquared() > .001f && next.LengthSquared() > .001f && Mathf.Abs(previous.Normalized().Cross(next.Normalized())) < .001f && previous.Dot(next) > 0) continue;
            points.Add(route[i]);
        }
        points.Add(route[^1]); return points.ToArray();
    }
    private static int FirstBlocker(Vector2 start, Vector2 finish, IReadOnlyList<Rect2> obstacles)
    {
        for (int i = 0; i < obstacles.Count; i++) if (CrossesInterior(start, finish, obstacles[i])) return i;
        return -1;
    }
    private static bool CrossesInterior(Vector2 start, Vector2 finish, Rect2 rect)
    {
        var inner = rect.Abs().Grow(-RouteEpsilon);
        if (inner.Size.X <= 0 || inner.Size.Y <= 0) return false;
        var delta = finish - start; float minT = 0, maxT = 1;
        for (int axis = 0; axis < 2; axis++)
        {
            float origin = start[axis], direction = delta[axis], lower = inner.Position[axis], upper = inner.End[axis];
            if (Mathf.Abs(direction) < .000001f) { if (origin <= lower || origin >= upper) return false; continue; }
            float first = (lower - origin) / direction, second = (upper - origin) / direction;
            if (first > second) (first, second) = (second, first);
            minT = Mathf.Max(minT, first); maxT = Mathf.Min(maxT, second);
            if (maxT <= minT) return false;
        }
        return maxT > .0001f && minT < .9999f;
    }
    private static Vector2 RectBoundary(Rect2 rect, Vector2 direction)
    {
        var half = rect.Size / 2;
        float x = Mathf.Abs(direction.X) < .0001f ? float.PositiveInfinity : half.X / Mathf.Abs(direction.X);
        float y = Mathf.Abs(direction.Y) < .0001f ? float.PositiveInfinity : half.Y / Mathf.Abs(direction.Y);
        return rect.GetCenter() + direction * Mathf.Min(x, y);
    }
    public GDictionary GetRoutingMetrics() { EnsureRoutes(); return _metrics.Duplicate(true); }
    public bool AllRoutesClear() { EnsureRoutes(); return _metrics.I("routed_edge_count", -1) == _metrics.I("edge_count", -2) && _metrics.I("blocked_route_count", 1) == 0; }
    public override void _Ready() { MouseFilter = MouseFilterEnum.Ignore; SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect); SetProcess(true); if (_graph != null) TrackGeometryChanges(); }
    public override void _Process(double delta)
    {
        if (_graph == null) return;
        if (!Mathf.IsEqualApprox(_lastZoom, _graph.Zoom) || !_lastScroll.IsEqualApprox(_graph.ScrollOffset))
        { _lastZoom = _graph.Zoom; _lastScroll = _graph.ScrollOffset; QueueRedraw(); }
    }
    public override void _Draw()
    {
        if (_graph == null) return;
        EnsureRoutes();
        foreach (var route in _routes)
        {
            if (route.Points.Length < 2 || !IsInstanceValid(route.Source)) continue;
            var transform = GetGlobalTransform().AffineInverse() * route.Source.GetGlobalTransform();
            var points = route.Points.Select(p => transform * (p - route.Source.PositionOffset)).ToArray();
            var color = route.Style.Get("color", ReferenceColor).AsColor();
            if (route.Style.B("dashed")) DrawDashed(points, color); else DrawPolyline(points, color, LineWidth, true);
            if (route.Style.B("arrow", true))
            {
                var tip = points[^1]; var direction = (tip - points[^2]).Normalized(); var perpendicular = new Vector2(-direction.Y, direction.X);
                var center = tip - direction * ArrowLength;
                DrawColoredPolygon(new[] {tip, center + perpendicular * ArrowHalfWidth, center - perpendicular * ArrowHalfWidth}, color);
            }
        }
    }
    private void EnsureRoutes()
    {
        if (!_dirty) return;
        _dirty = false; _routes.Clear(); int blocked = 0, detoured = 0;
        foreach (var value in _edges)
        {
            var edge = value.AsGodotDictionary(); string sourceId = edge.S("source"), targetId = edge.S("target");
            if (!_cards.TryGetValue(sourceId, out var source) || !_cards.TryGetValue(targetId, out var target) || !IsInstanceValid(source) || !IsInstanceValid(target) || !source.Visible || !target.Visible) { blocked++; continue; }
            var obstacles = _cards.Where(p => p.Key != sourceId && p.Key != targetId && IsInstanceValid(p.Value) && p.Value.Visible).Select(p => CardRect(p.Value)).ToArray();
            var route = RouteAroundObstacles(CardRect(source), CardRect(target), obstacles);
            if (route.Length < 2 || !PolylineAvoidsRects(route, obstacles)) { blocked++; continue; }
            if (route.Length > 2) detoured++;
            _routes.Add((route, source, EdgeStyle(edge)));
        }
        _metrics = new() { ["edge_count"] = _edges.Count, ["routed_edge_count"] = _routes.Count, ["blocked_route_count"] = blocked, ["detoured_edge_count"] = detoured };
    }
    private void DrawDashed(Vector2[] points, Color color)
    {
        float patternCursor = 0; bool drawing = true;
        for (int i = 0; i < points.Length - 1; i++)
        {
            var start = points[i]; var delta = points[i + 1] - start; float distance = delta.Length();
            if (distance <= .01f) continue;
            var direction = delta / distance; float cursor = 0;
            while (cursor < distance)
            {
                float phaseLength = drawing ? DashLength : DashGap, advance = Mathf.Min(phaseLength - patternCursor, distance - cursor);
                if (drawing) DrawLine(start + direction * cursor, start + direction * (cursor + advance), color, LineWidth, true);
                cursor += advance; patternCursor += advance;
                if (patternCursor >= phaseLength - .001f) { patternCursor = 0; drawing = !drawing; }
            }
        }
    }
    private static Rect2 CardRect(GraphNode card) => new Rect2(card.PositionOffset, card.Size).Abs();
    private void TrackGeometryChanges()
    {
        if (_graph != null)
        {
            if (!_graph.IsConnected(Control.SignalName.Resized, Callable.From(OnViewChanged))) _graph.Resized += OnViewChanged;
            if (!_graph.IsConnected(GraphEdit.SignalName.ScrollOffsetChanged, Callable.From<Vector2>(OnScrollChanged))) _graph.Connect(GraphEdit.SignalName.ScrollOffsetChanged, Callable.From<Vector2>(OnScrollChanged));
        }
        foreach (var card in _cards.Values)
        {
            if (!IsInstanceValid(card)) continue;
            if (!card.IsConnected(CanvasItem.SignalName.ItemRectChanged, Callable.From(OnGeometryChanged))) card.ItemRectChanged += OnGeometryChanged;
            if (!card.IsConnected(CanvasItem.SignalName.VisibilityChanged, Callable.From(OnGeometryChanged))) card.VisibilityChanged += OnGeometryChanged;
        }
    }
    private void OnGeometryChanged() { _dirty = true; QueueRedraw(); }
    private void OnViewChanged() => QueueRedraw();
    private void OnScrollChanged(Vector2 offset) => QueueRedraw();
}
