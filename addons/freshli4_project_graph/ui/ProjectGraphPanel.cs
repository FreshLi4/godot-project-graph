#if TOOLS
using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;
namespace FreshLi4.ProjectGraph;

[Tool]
public partial class ProjectGraphPanel : VBoxContainer
{
    [Signal] public delegate void AssetActivatedEventHandler(string path);
    [Signal] public delegate void AssetRevealRequestedEventHandler(string path);
    public static readonly Vector2 CardSize = new(320, 320);
    private static readonly Vector2 TypeBarSize = new(292, 42);
    private const float TitleWidth = 250, TitleHeight = 248, MinimumGap = 64;
    private const int TitleMinimumLines = 3, ShowInFileSystem = 1;
    private readonly ProjectGraphScanner _scanner = new();
    private readonly OrganicGraphLayout _layout = new();
    private GDictionary _snapshot = new(), _layoutMetrics = new();
    private readonly Dictionary<string, GraphNode> _cards = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Label> _titles = new(StringComparer.Ordinal);
    private string[] _ignorePatterns = Array.Empty<string>();
    private bool _dragging;
    private string _contextPath = "";
    private Button _scanButton = null!, _layoutButton = null!, _exportButton = null!;
    private LineEdit _search = null!;
    private Label _status = null!;
    private GraphEdit _graph = null!;
    private SemanticConnectionLayer _connections = null!;
    private EditorFileDialog _exportDialog = null!;
    private ConfirmationDialog _ignoreDialog = null!;
    private TextEdit _ignoreEditor = null!;
    private AcceptDialog _legend = null!;
    private PopupMenu _contextMenu = null!;

    public static Vector2 ScrollOffsetAfterDrag(Vector2 offset, Vector2 relative, float zoom) => offset - relative / Mathf.Max(zoom, .001f);
    public override void _Ready()
    {
        SizeFlagsHorizontal = SizeFlags.ExpandFill; SizeFlagsVertical = SizeFlags.ExpandFill;
        _ignorePatterns = ScanIgnoreSettings.LoadCustomPatterns(); BuildUi();
    }
    private void BuildUi()
    {
        AddThemeConstantOverride("separation", 8);
        var toolbar = new HBoxContainer(); toolbar.AddThemeConstantOverride("separation", 8); AddChild(toolbar);
        _scanButton = new Button {Text = "Scan Project", TooltipText = "Scan res:// without instantiating scenes."};
        _scanButton.Pressed += ScanProject; toolbar.AddChild(_scanButton);
        _layoutButton = new Button {Text = "Organic Layout", TooltipText = "Restore the deterministic force-directed disk layout.", Disabled = true};
        _layoutButton.Pressed += () => ApplyOrganicLayout(); toolbar.AddChild(_layoutButton);
        var ignoreButton = new Button { Text = "Ignore…", TooltipText = "Exclude project paths before scanning. addons and Godot-generated directories are excluded by default." };
        ignoreButton.Pressed += ShowIgnore; toolbar.AddChild(ignoreButton);
        var legendButton = new Button { Text = "Legend…", TooltipText = "Node colors identify asset types. Arrow color and line style identify relationship semantics." };
        legendButton.Pressed += () => _legend.PopupCentered(new(700, 580)); toolbar.AddChild(legendButton);
        _exportButton = new Button { Text = "Export JSON", Disabled = true }; _exportButton.Pressed += ShowExport; toolbar.AddChild(_exportButton);
        _search = new LineEdit { PlaceholderText = "Search name, path, or type", ClearButtonEnabled = true, CustomMinimumSize = new(280, 0) };
        _search.TextChanged += ApplySearch; toolbar.AddChild(_search);
        _status = new Label { Text = "Ready. Click Scan Project.", SizeFlagsHorizontal = SizeFlags.ExpandFill, HorizontalAlignment = HorizontalAlignment.Right, TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis };
        toolbar.AddChild(_status);
        _graph = new GraphEdit {Name = "AssetGraph", SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ExpandFill,
            MinimapEnabled = true, ShowArrangeButton = false, ZoomMin = .02f, ConnectionLinesCurvature = .35f,
            TooltipText = "Drag empty space with the left mouse button to pan. Drag a card to move that asset."};
        _graph.AddValidConnectionType(0, 0); _graph.Connect(Control.SignalName.GuiInput, Callable.From<InputEvent>(OnGraphInput)); AddChild(_graph);
        _connections = new SemanticConnectionLayer { Name = "SemanticConnections", MouseFilter = MouseFilterEnum.Ignore }; _graph.AddChild(_connections);
        _exportDialog = new EditorFileDialog { Title = "Export Project Graph JSON", Access = EditorFileDialog.AccessEnum.Filesystem,
            FileMode = EditorFileDialog.FileModeEnum.SaveFile, Filters = new[] { "*.json ; JSON files" }, CurrentFile = "project-graph.json" };
        _exportDialog.FileSelected += ExportJson; AddChild(_exportDialog);
        _ignoreDialog = new ConfirmationDialog { Title = "Project Graph Scan Ignore" }; AddChild(_ignoreDialog);
        _ignoreDialog.Confirmed += SaveIgnore; _ignoreDialog.GetOkButton().Text = "Save and Rescan";
        var content = new VBoxContainer { CustomMinimumSize = new(680, 420) }; content.AddThemeConstantOverride("separation", 8); _ignoreDialog.AddChild(content);
        content.AddChild(new Label { Text = "Always ignored" });
        content.AddChild(new Label { Text = ScanIgnoreSettings.FormatDefaultPatterns(), Modulate = new(1, 1, 1, .65f), TooltipText = "Godot engine resources outside res:// never enter the project scan." });
        content.AddChild(new Label { Text = "Custom patterns · one per line" });
        _ignoreEditor = new TextEdit { PlaceholderText = "Examples:\nres://third_party/**\nres://art/source/*.psd\n# Lines beginning with # are comments", SizeFlagsVertical = SizeFlags.ExpandFill }; content.AddChild(_ignoreEditor);
        content.AddChild(new Label { Text = "Patterns are stored in user://freshli4_project_graph/settings.cfg and applied before traversal and dependency collection.", AutowrapMode = TextServer.AutowrapMode.WordSmart });
        BuildLegend();
        _contextMenu = new PopupMenu { Name = "AssetContextMenu" }; _contextMenu.AddItem("Show in FileSystem", ShowInFileSystem);
        _contextMenu.IdPressed += id => { if (id == ShowInFileSystem && _contextPath.Length > 0) EmitSignal(SignalName.AssetRevealRequested, _contextPath); }; AddChild(_contextMenu);
    }
    private void ScanProject()
    {
        _scanButton.Disabled = true; _status.Text = "Scanning project...";
        _snapshot = _scanner.ScanProject("res://", _ignorePatterns); RenderSnapshot();
        _exportButton.Disabled = false; _layoutButton.Disabled = false; _scanButton.Disabled = false; ApplySearch(_search.Text);
    }
    public async void RunEditorSmoke()
    {
        ScanProject();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        ApplyOrganicLayout(false);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        int count = _graph.GetChildren().OfType<GraphNode>().Count();
        int distinct = _cards.Values.Select(c => c.PositionOffset.Round()).Distinct().Count();
        if (count > 0 && (count == 1 || distinct > 1) && CardsHaveFixedSize() && CardsHaveClearance(MinimumGap) && SemanticUiIsValid() && ReadabilityIsValid())
        {
            var metrics = _connections.GetRoutingMetrics();
            GD.Print($"PASS: Project Graph editor panel smoke ({count} graph nodes, {metrics.I("routed_edge_count")}/{metrics.I("edge_count")} routed, {metrics.I("detoured_edge_count")} detours, 0 blocked)");
        }
        else
        {
            GD.PushError("Project Graph editor panel smoke rendered overlapping or invalid cards");
            GetTree().Quit(1);
            return;
        }
        GetTree().Quit(0);
    }
    private void RenderSnapshot()
    {
        _graph.ClearConnections();
        foreach (var card in _cards.Values) { _graph.RemoveChild(card); card.QueueFree(); }
        _cards.Clear(); _titles.Clear(); _connections.Configure(_graph, _cards, new());
        var nodes = _snapshot.A("nodes");
        for (int i = 0; i < nodes.Count; i++)
        {
            var node = nodes[i].AsGodotDictionary(); var card = MakeCard(node, $"asset_{i:D5}");
            _graph.AddChild(card); _cards[node.S("id")] = card;
        }
        ApplyOrganicLayout(false); Callable.From(FinalizeFixedCardLayout).CallDeferred();
    }
    private GraphNode MakeCard(GDictionary node, string name)
    {
        string kind = node.S("kind", "Data"), path = node.S("path"), id = node.S("id"); bool missing = node.B("missing");
        var color = ColorForKind(kind, missing);
        var card = new GraphNode { Name = name, Title = "", CustomMinimumSize = CardSize, Size = CardSize, Resizable = false, Selectable = true, Draggable = true };
        string title = path.GetFile(); if (title.Length == 0) title = node.S("label", id);
        card.TooltipText = title; card.SetMeta("asset_id", id); card.SetMeta("asset_path", path); card.SetMeta("asset_missing", missing); card.SetMeta("fixed_card_size", CardSize);
        card.GuiInput += e => OnCardInput(e, card);
        var titlebar = card.GetTitlebarHBox();
        foreach (var label in titlebar.GetChildren().OfType<Label>()) label.Visible = false;
        var fullTitle = new Label { Text = title, CustomMinimumSize = new(TitleWidth, TitleHeight), SizeFlagsHorizontal = SizeFlags.ExpandFill,
            AutowrapMode = TextServer.AutowrapMode.Arbitrary, VerticalAlignment = VerticalAlignment.Center, ClipText = true, MouseFilter = MouseFilterEnum.Ignore };
        fullTitle.SetMeta("full_file_name", true); titlebar.AddChild(fullTitle); _titles[id] = fullTitle;
        var bar = new CenterContainer { CustomMinimumSize = TypeBarSize, MouseFilter = MouseFilterEnum.Ignore }; bar.SetMeta("card_type_bar", true); card.AddChild(bar);
        bar.AddChild(new Label { Text = kind + (missing ? " · missing" : ""), AutowrapMode = TextServer.AutowrapMode.WordSmart,
            CustomMinimumSize = new(TypeBarSize.X - 16, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, Modulate = color, MouseFilter = MouseFilterEnum.Ignore });
        return card;
    }
    private void RefreshConnections()
    {
        _graph.ClearConnections(); var edges = new GArray();
        foreach (var value in _snapshot.A("edges"))
        {
            var edge = value.AsGodotDictionary();
            if (_cards.TryGetValue(edge.S("source"), out var source) && _cards.TryGetValue(edge.S("target"), out var target) && source.Visible && target.Visible) edges.Add(edge);
        }
        _connections.Configure(_graph, _cards, edges);
    }
    private void ApplyOrganicLayout(bool fitView = true)
    {
        if (_snapshot.Count == 0) return;
        var result = _layout.Calculate(_snapshot, CardSize);
        _layoutMetrics = new() { ["crossings_before"] = result.I("crossings_before"), ["crossings_after"] = result.I("crossings_after"), ["mean_edge_length"] = result.F("mean_edge_length") };
        var positions = result.D("positions");
        foreach (var pair in _cards) { pair.Value.Size = CardSize; pair.Value.PositionOffset = positions.V(pair.Key); }
        RefreshConnections(); if (fitView) Callable.From(FitGraphToView).CallDeferred();
    }
    private async void FinalizeFixedCardLayout()
    {
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (_snapshot.Count == 0) return;
        ApplyOrganicLayout(false); Callable.From(FitGraphToView).CallDeferred();
    }
    private static Vector2 MeasureCard(GraphNode card) => card.Size.LengthSquared() > 1 ? card.Size : CardSize;
    private static Control? TypeBar(GraphNode card) => card.GetChildren().OfType<Control>().FirstOrDefault(c => c.GetMeta("card_type_bar", false).AsBool());
    private float MinimumTitleHeight() => GetThemeDefaultFont().GetHeight(GetThemeDefaultFontSize()) * TitleMinimumLines;
    private bool CardsHaveFixedSize()
    {
        if (!Mathf.IsEqualApprox(CardSize.X, CardSize.Y)) return false;
        foreach (var pair in _cards)
        {
            var card = pair.Value;
            if (!card.Size.IsEqualApprox(CardSize) || !card.Selectable || !card.Draggable) return false;
            if (!_titles.TryGetValue(pair.Key, out var title) || title.Size.Y < MinimumTitleHeight() || title.GetParent() is ScrollContainer) return false;
            var bar = TypeBar(card);
            if (bar == null || bar.Size.Y > TypeBarSize.Y + 1 || bar.MouseFilter != MouseFilterEnum.Ignore) return false;
        }
        return true;
    }
    private bool SemanticUiIsValid()
    {
        if (_graph.GetConnectionList().Count != 0 || _titles.Count != _cards.Count || _contextMenu.ItemCount != 1 || !_graph.IsConnected(Control.SignalName.GuiInput, Callable.From<InputEvent>(OnGraphInput))) return false;
        foreach (var pair in _titles)
        {
            var title = pair.Value; var node = FindNodeData(pair.Key); var bar = TypeBar(_cards[pair.Key]);
            if (title.Text != node.S("path").GetFile() || title.AutowrapMode != TextServer.AutowrapMode.Arbitrary || title.CustomMinimumSize.Y < MinimumTitleHeight() || title.MouseFilter != MouseFilterEnum.Ignore || title.GetParent() is ScrollContainer || bar == null || ContainsText(bar, "res://")) return false;
        }
        if (!_connections.AllRoutesClear()) return false;
        bool foundInheritance = false;
        foreach (var value in _snapshot.A("edges"))
        {
            var edge = value.AsGodotDictionary(); if (edge.S("relation") != "inherits") continue;
            foundInheritance = true; var style = SemanticConnectionLayer.EdgeStyle(edge);
            if (style.B("dashed", true) || style.S("semantic") != "inherits") return false;
        }
        return foundInheritance;
    }
    private bool ReadabilityIsValid() => _layoutMetrics.I("crossings_before", -1) >= 0 && _layoutMetrics.I("crossings_after", -1) >= 0 && _layoutMetrics.I("crossings_after", -1) <= _layoutMetrics.I("crossings_before", -1) && _layoutMetrics.F("mean_edge_length", -1) > 0;
    private static bool ContainsText(Node node, string needle) => node is Label label && label.Text.Contains(needle) || node.GetChildren().Any(child => ContainsText(child, needle));
    private bool CardsHaveClearance(float clearance)
    {
        var cards = _cards.Values.Where(c => c.Visible).ToArray();
        for (int i = 0; i < cards.Length; i++)
            for (int j = i + 1; j < cards.Length; j++)
            {
                var a = new Rect2(cards[i].PositionOffset, MeasureCard(cards[i])); var b = new Rect2(cards[j].PositionOffset, MeasureCard(cards[j]));
                float x = Mathf.Max(a.Position.X, b.Position.X) - Mathf.Min(a.End.X, b.End.X), y = Mathf.Max(a.Position.Y, b.Position.Y) - Mathf.Min(a.End.Y, b.End.Y);
                if (x < clearance && y < clearance) return false;
            }
        return true;
    }
    private void FitGraphToView()
    {
        if (_cards.Count == 0 || _graph.Size.X <= 1 || _graph.Size.Y <= 1) return;
        Rect2? bounds = null;
        foreach (var card in _cards.Values.Where(c => c.Visible)) { var rect = new Rect2(card.PositionOffset, MeasureCard(card)); bounds = bounds.HasValue ? bounds.Value.Merge(rect) : rect; }
        if (!bounds.HasValue) return;
        var box = bounds.Value; var view = _graph.Size - new Vector2(96, 96);
        _graph.Zoom = Mathf.Clamp(Mathf.Min(view.X / Mathf.Max(box.Size.X, 1), view.Y / Mathf.Max(box.Size.Y, 1)), _graph.ZoomMin, 1);
        _graph.ScrollOffset = box.GetCenter() - _graph.Size / (2 * _graph.Zoom);
    }
    private void ApplySearch(string raw)
    {
        string query = raw.Trim().ToLowerInvariant(); int visible = 0;
        foreach (var pair in _cards)
        {
            var node = FindNodeData(pair.Key);
            string searchable = $"{node.S("label")} {node.S("path")} {node.S("kind")}";
            pair.Value.Visible = query.Length == 0 || searchable.ToLowerInvariant().Contains(query);
            if (pair.Value.Visible) visible++;
        }
        RefreshConnections();
        if (_snapshot.Count == 0) { _status.Text = "Ready. Click Scan Project."; return; }
        var stats = _snapshot.D("stats");
        string crossing = _layoutMetrics.I("crossings_before") > 0 ? $" · layout crossings {_layoutMetrics.I("crossings_before")}→{_layoutMetrics.I("crossings_after")}" : "";
        _status.Text = $"{visible}/{stats.I("node_count")} nodes · {stats.I("edge_count")} edges · {stats.I("missing_node_count")} missing{crossing}";
    }
    private GDictionary FindNodeData(string id) => _snapshot.A("nodes").Select(v => v.AsGodotDictionary()).FirstOrDefault(n => n.S("id") == id) ?? new();
    private void OnCardInput(InputEvent input, GraphNode card)
    {
        if (input is InputEventMouseButton {ButtonIndex: MouseButton.Left, DoubleClick: true}) { EmitSignal(SignalName.AssetActivated, card.GetMeta("asset_path", "")); card.AcceptEvent(); }
        else if (input is InputEventMouseButton {ButtonIndex: MouseButton.Right, Pressed: true})
        {
            _contextPath = card.GetMeta("asset_path", "").AsString();
            _contextMenu.SetItemDisabled(0, _contextPath.Length == 0 || !_contextPath.StartsWith("res://", StringComparison.Ordinal) || card.GetMeta("asset_missing", false).AsBool());
            _contextMenu.Popup(new Rect2I((Vector2I)GetViewport().GetMousePosition().Round(), Vector2I.One)); card.AcceptEvent();
        }
    }
    private void OnGraphInput(InputEvent input)
    {
        if (input is InputEventMouseButton {ButtonIndex: MouseButton.Left} button)
        {
            if (button.Pressed && !button.DoubleClick) { _dragging = true; _graph.MouseDefaultCursorShape = CursorShape.Drag; _graph.AcceptEvent(); }
            else if (!button.Pressed && _dragging) { _dragging = false; _graph.MouseDefaultCursorShape = CursorShape.Arrow; _graph.AcceptEvent(); }
        }
        else if (input is InputEventMouseMotion motion && _dragging)
        {
            if ((motion.ButtonMask & MouseButtonMask.Left) == 0) { _dragging = false; _graph.MouseDefaultCursorShape = CursorShape.Arrow; return; }
            _graph.ScrollOffset = ScrollOffsetAfterDrag(_graph.ScrollOffset, motion.Relative, _graph.Zoom); _graph.AcceptEvent();
        }
    }
    private void BuildLegend()
    {
        _legend = new AcceptDialog { Title = "Project Graph Legend" }; _legend.GetOkButton().Text = "Close"; AddChild(_legend);
        var content = new VBoxContainer { CustomMinimumSize = new(660, 520) }; content.AddThemeConstantOverride("separation", 10); _legend.AddChild(content);
        content.AddChild(new Label { Text = "Relationship lines" });
        content.AddChild(new RichTextLabel { BbcodeEnabled = true, FitContent = true, CustomMinimumSize = new(0, 118),
            Text = "[color=#B8C0CC]━━━━▶[/color]  Static reference · source uses target\n[color=#6FCFDE]━━━━▶[/color]  Inheritance · child points to parent; higher ancestors are pulled toward the center\n[color=#F2B84B]━ ━ ━▶[/color]  Inferred / dynamic · not an exact static dependency\n\nArrowheads always point from the relationship source to its target." });
        content.AddChild(new Label { Text = "Asset node colors" });
        var grid = new GridContainer { Columns = 2 }; grid.AddThemeConstantOverride("h_separation", 12); grid.AddThemeConstantOverride("v_separation", 6); content.AddChild(grid);
        foreach (var kind in GraphSchema.NodeKinds) AddLegendRow(grid, kind, ColorForKind(kind, false));
        AddLegendRow(grid, "Missing / broken", ColorForKind("Data", true));
        content.AddChild(new Label { Text = "Blue means Scene only. Node colors never encode direction or confidence; those meanings belong exclusively to the relationship lines above.", AutowrapMode = TextServer.AutowrapMode.WordSmart });
    }
    private static void AddLegendRow(GridContainer grid, string text, Color color)
    {
        grid.AddChild(new ColorRect { Color = color, CustomMinimumSize = new(22, 18), MouseFilter = MouseFilterEnum.Ignore });
        grid.AddChild(new Label { Text = $"{text} · {color.ToHtml(false)}" });
    }
    private void ShowExport() { if (_snapshot.Count > 0) _exportDialog.PopupCenteredRatio(.7f); }
    private void ShowIgnore() { _ignoreEditor.Text = ScanIgnoreSettings.FormatText(_ignorePatterns); _ignoreDialog.PopupCentered(new(720, 520)); _ignoreEditor.GrabFocus(); }
    private void SaveIgnore()
    {
        var patterns = ScanIgnoreSettings.ParseText(_ignoreEditor.Text); var error = ScanIgnoreSettings.SaveCustomPatterns(patterns);
        if (error != Error.Ok) { _status.Text = $"Could not save Ignore settings: {error}"; GD.PushError($"Project Graph Ignore settings failed: {error}"); return; }
        _ignorePatterns = patterns; ScanProject();
    }
    private void ExportJson(string path)
    {
        var error = GraphStore.SaveJson(_snapshot, path);
        _status.Text = error == Error.Ok ? $"Exported {path}" : $"Export failed: {error}";
        if (error != Error.Ok) GD.PushError($"Project Graph export failed: {error}");
    }
    private static Color ColorForKind(string kind, bool missing) => new(missing ? "#EB5757" : kind switch
    { "Scene" => "#5DA9E9", "Script" => "#F2C94C", "Resource" => "#BB86FC", "Mesh" => "#56CC9D", "Texture" => "#F2994A", "Audio" => "#EB6F92", "Shader" => "#6FCFDE", _ => "#A0AEC0" });
}
#endif
